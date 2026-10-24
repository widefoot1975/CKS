# q04 — Find and replace excessive RBAC bindings · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The ServiceAccounts of namespace `apps` have collected too many permissions.
>
> 1. Find every RoleBinding and ClusterRoleBinding in the cluster that grants a ServiceAccount of
>    namespace `apps` (as a subject directly **or through a group**) either the ClusterRole
>    `cluster-admin` or a Role/ClusterRole that contains the verb `*`. Write them to
>    `/opt/course/b04/excessive.txt`, one per line, as `<Kind>/<namespace>/<name>` (use `-` as the
>    namespace of a ClusterRoleBinding), e.g. `RoleBinding/apps/foo`.
> 2. Delete these bindings. Also delete the custom Roles/ClusterRoles they referenced (never delete
>    built-in ClusterRoles such as `cluster-admin`). Do not touch other bindings.
> 3. Create a Role `configmap-reader` in namespace `apps` that allows only `get` and `list` on
>    `configmaps`, and a RoleBinding `configmap-reader` that grants it to the ServiceAccounts `web`
>    and `worker` of namespace `apps`.
> 4. Write the output of
>    `kubectl auth can-i --list -n apps --as=system:serviceaccount:apps:worker` to
>    `/opt/course/b04/worker-can-i.txt`. It must not contain the verb `*` anywhere.

**해석**

`apps` 네임스페이스의 ServiceAccount 들이 권한을 너무 많이 갖고 있다.

1. `apps` 의 ServiceAccount 에게(직접 subject 로든 **그룹을 통해서든**) `cluster-admin` 또는 verb `*` 를 가진 Role/ClusterRole 을 주는
   RoleBinding·ClusterRoleBinding 을 모두 찾아 `<Kind>/<namespace>/<name>` 형식(ClusterRoleBinding 의 namespace 는 `-`)으로 한 줄씩
   `/opt/course/b04/excessive.txt` 에 쓴다.
2. 그 바인딩들을 지우고, 그것들이 참조하던 **직접 만든** Role/ClusterRole 도 지운다(`cluster-admin` 같은 기본 ClusterRole 은 지우지 않는다).
   다른 바인딩은 건드리지 않는다.
3. `apps` 에 `configmaps` 의 `get`, `list` 만 허용하는 Role `configmap-reader` 와, 이를 SA `web`, `worker` 에 주는 RoleBinding
   `configmap-reader` 를 만든다.
4. `kubectl auth can-i --list -n apps --as=system:serviceaccount:apps:worker` 출력을 `/opt/course/b04/worker-can-i.txt` 에 쓴다.
   어디에도 verb `*` 가 없어야 한다.

## 모범 풀이

**1) apps 의 SA 를 가리키는 바인딩 전부 찾기**

ServiceAccount 는 세 가지 방법으로 바인딩의 subject 가 될 수 있습니다.

| subject | 해당하는 SA |
|---|---|
| `kind: ServiceAccount, name: web, namespace: apps` | 그 SA 하나 |
| `kind: Group, name: system:serviceaccounts:apps` | `apps` 의 **모든** SA |
| `kind: Group, name: system:serviceaccounts` / `system:authenticated` | 클러스터의 모든 SA(모든 인증 주체) |

```bash
alias k=kubectl
k get rolebindings,clusterrolebindings -A -o json | jq -r '
  .items[]
  | select(any(.subjects[]?;
        (.kind=="ServiceAccount" and .namespace=="apps")
     or (.kind=="Group" and (.name=="system:serviceaccounts:apps" or .name=="system:serviceaccounts" or .name=="system:authenticated"))))
  | "\(.kind)/\(.metadata.namespace // "-")/\(.metadata.name) -> \(.roleRef.kind)/\(.roleRef.name)"'
# RoleBinding/apps/reporter-cm -> Role/reporter-cm
# RoleBinding/apps/worker-full -> Role/worker-full
# ClusterRoleBinding/-/apps-secret-ops -> ClusterRole/secret-ops
# ClusterRoleBinding/-/system:basic-user -> ClusterRole/system:basic-user
# ClusterRoleBinding/-/system:discovery -> ClusterRole/system:discovery
# ClusterRoleBinding/-/system:public-info-viewer -> ClusterRole/system:public-info-viewer
# ClusterRoleBinding/-/web-cluster-admin -> ClusterRole/cluster-admin
```

> 함정: `k get clusterrolebindings -o wide | grep apps` 는 SA 열(`apps/web`)과 그룹 열(`system:serviceaccounts:apps`) 모두 걸리지만,
> `grep 'apps/'` 나 SA 이름(`web`, `worker`)으로만 찾으면 **그룹으로 묶인 `apps-secret-ops`** 를 놓칩니다.

이제 각 롤에 `*` 가 있는지 봅니다. `system:*` 기본 바인딩은 `*` 가 없으니 제외됩니다.

```bash
k -n apps get role reporter-cm worker-full -o yaml | grep -B3 -A3 'verbs'
k get clusterrole secret-ops -o jsonpath='{.rules}{"\n"}'
# [{"apiGroups":[""],"resources":["secrets"],"verbs":["*"]}]
k -n apps get role worker-full -o jsonpath='{.rules}{"\n"}'
# [{"apiGroups":["*"],"resources":["*"],"verbs":["*"]}]
```

```bash
mkdir -p /opt/course/b04
cat > /opt/course/b04/excessive.txt <<'EOF'
ClusterRoleBinding/-/web-cluster-admin
RoleBinding/apps/worker-full
ClusterRoleBinding/-/apps-secret-ops
EOF
```

**2) 지우기**

```bash
k delete clusterrolebinding web-cluster-admin apps-secret-ops
k -n apps delete rolebinding worker-full
k -n apps delete role worker-full
k get clusterrolebinding -o json | jq -r '.items[] | select(.roleRef.name=="secret-ops") | .metadata.name'   # 다른 사용처 없음 확인
k delete clusterrole secret-ops
```

`reporter-cm`(configmaps get/list)과 `observe` 의 `prom-view`(다른 네임스페이스 SA)는 조건에 맞지 않으므로 그대로 둡니다.

**3) 최소 권한 Role/RoleBinding**

```bash
k -n apps create role configmap-reader --verb=get,list --resource=configmaps
k -n apps create rolebinding configmap-reader --role=configmap-reader \
  --serviceaccount=apps:web --serviceaccount=apps:worker
```

**4) can-i 로 확인**

```bash
k auth can-i --list -n apps --as=system:serviceaccount:apps:worker > /opt/course/b04/worker-can-i.txt
cat /opt/course/b04/worker-can-i.txt
# Resources                                       Non-Resource URLs   Resource Names   Verbs
# selfsubjectreviews.authentication.k8s.io        []                  []               [create]
# selfsubjectaccessreviews.authorization.k8s.io   []                  []               [create]
# selfsubjectrulesreviews.authorization.k8s.io    []                  []               [create]
# configmaps                                      []                  []               [get list]
#                                                 [/api/*]            []               [get]
# ...
grep -F '[*]' /opt/course/b04/worker-can-i.txt || echo "no wildcard"
```

`--as=system:serviceaccount:<ns>:<name>` 로 가장하면 apiserver 가 SA 의 그룹(`system:serviceaccounts`, `system:serviceaccounts:apps`,
`system:authenticated`)도 자동으로 붙여 줍니다. 그래서 그룹 바인딩이 남아 있으면 `secrets [*]` 처럼 바로 드러납니다.

## 검증

```bash
k auth can-i '*' '*' --as=system:serviceaccount:apps:web                    # no
k auth can-i delete secrets -n apps --as=system:serviceaccount:apps:reporter  # no (그룹 바인딩 제거 확인)
k auth can-i list configmaps -n apps --as=system:serviceaccount:apps:worker   # yes
k auth can-i get configmaps -n apps --as=system:serviceaccount:apps:reporter  # yes (기존 reporter-cm 유지)
k get clusterrolebinding prom-view                                            # 남아 있어야 한다
cat /opt/course/b04/excessive.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: SA 를 찾을 때는 `ServiceAccount` subject + `system:serviceaccounts:<ns>` + `system:serviceaccounts` + `system:authenticated` 그룹까지 본다. 확인은 `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa> -n <ns>`.
- **헷갈리는 지점**: RoleBinding 이 ClusterRole 을 참조하면 권한은 그 RoleBinding 의 네임스페이스로 한정됩니다(ClusterRoleBinding 만 클러스터 전체). `cluster-admin` 등 `kubernetes.io/bootstrapping=rbac-defaults` 라벨이 붙은 기본 롤은 지워도 apiserver 가 재시작 시 다시 만들지만, 지우는 것 자체가 장애를 낼 수 있으니 절대 지우지 않습니다.

## 참고 문서

- 검색어: `rbac`, `kubectl auth can-i`, `service account groups`
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/concepts/security/service-accounts/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q05 →](../q05_sa_legacy_token_cleanup/question.md)
