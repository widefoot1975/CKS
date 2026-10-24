# q06 — Lock down an exposed admin UI · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The internal admin UI `admin-ui` in namespace `ops` is reachable from outside the cluster and runs
> with far too many privileges. Lock it down:
>
> 1. Service `admin-ui` must only be reachable inside the cluster: type `ClusterIP`, port `80`.
> 2. ServiceAccount `ops/admin-ui` must not receive any permission through a ClusterRoleBinding
>    anymore. Find and delete every ClusterRoleBinding that grants `cluster-admin` to this
>    ServiceAccount, directly or through one of its groups. Do not delete other ClusterRoleBindings.
> 3. Create a Role `admin-ui-view` in `ops` that allows `get`, `list` and `watch` on `pods`,
>    `services` and `configmaps`, and bind it to ServiceAccount `admin-ui` with a RoleBinding
>    `admin-ui-view`.
> 4. Deployment `admin-ui` must no longer use the host network namespace. It keeps using
>    ServiceAccount `admin-ui`.
> 5. ServiceAccount `default` in namespace `ops` must not have its token mounted automatically.
> 6. Write three lines to `/opt/course/c06/can-i.txt` with the answers (`yes`/`no`) of
>    `kubectl auth can-i` as `system:serviceaccount:ops:admin-ui` for:
>    `get secrets -n ops`, `list pods -n ops`, `delete nodes`.

**해석**

namespace `ops` 의 내부 관리 화면 `admin-ui` 가 클러스터 밖에서 접근되고 권한도 지나치게 크다. 잠근다.

1. Service `admin-ui` 는 클러스터 안에서만 접근되게 한다: 타입 `ClusterIP`, 포트 80.
2. ServiceAccount `ops/admin-ui` 가 ClusterRoleBinding 으로 권한을 받지 않게 한다. 이 SA 에게 직접 또는 SA 가 속한 그룹을
   통해 `cluster-admin` 을 주는 ClusterRoleBinding 을 모두 찾아 지운다. 다른 ClusterRoleBinding 은 지우지 않는다.
3. `ops` 에 `pods`·`services`·`configmaps` 의 `get`·`list`·`watch` 를 허용하는 Role `admin-ui-view` 를 만들고 RoleBinding
   `admin-ui-view` 로 SA `admin-ui` 에 묶는다.
4. Deployment `admin-ui` 는 호스트 네트워크 namespace 를 쓰지 않는다. SA `admin-ui` 는 계속 쓴다.
5. `ops` 의 ServiceAccount `default` 는 토큰이 자동 마운트되지 않게 한다.
6. `system:serviceaccount:ops:admin-ui` 로 `get secrets -n ops`, `list pods -n ops`, `delete nodes` 를 `kubectl auth can-i` 한 결과
   (`yes`/`no`)를 세 줄로 `/opt/course/c06/can-i.txt` 에 쓴다.

## 모범 풀이

**1) Service 를 ClusterIP 로**

```bash
alias k=kubectl
k -n ops get svc admin-ui            # TYPE NodePort, 80:30880/TCP
k -n ops edit svc admin-ui
```

```yaml
spec:
  type: ClusterIP          # NodePort → ClusterIP
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP          # nodePort: 30880 줄은 지운다
```

최근 버전의 API 서버는 타입을 ClusterIP 로 바꾸면 할당된 `nodePort` 를 자동으로 비워 주므로
`k -n ops patch svc admin-ui -p '{"spec":{"type":"ClusterIP"}}'` 로도 됩니다. `nodePort ... may not be used when type is 'ClusterIP'`
에러가 나오면 `nodePort` 줄을 직접 지웁니다. `externalTrafficPolicy` 같은 NodePort 전용 필드도 함께 정리됩니다.

**2) cluster-admin 을 주는 ClusterRoleBinding 찾기 — 그룹까지**

SA 는 사용자 이름 `system:serviceaccount:ops:admin-ui` 외에 그룹 `system:serviceaccounts`, `system:serviceaccounts:ops`,
`system:authenticated` 에 속합니다. 이름으로 검색하면 그룹 바인딩을 놓칩니다.

```bash
k get clusterrolebinding -o json | jq -r '
  .items[] | select(.roleRef.name=="cluster-admin") |
  select(any(.subjects[]?;
        (.kind=="ServiceAccount" and .namespace=="ops" and .name=="admin-ui")
     or (.kind=="Group" and (.name=="system:serviceaccounts" or .name=="system:serviceaccounts:ops" or .name=="system:authenticated")))) |
  .metadata.name'
# ops-monitoring
# legacy-tooling

k delete clusterrolebinding ops-monitoring legacy-tooling
```

`kubeadm:cluster-admins`(그룹 `kubeadm:cluster-admins`)나 `cluster-admin`(그룹 `system:masters`) 바인딩은 이 SA 와 무관하므로 지우면 안 됩니다.

**3) 최소 권한 Role**

```bash
k -n ops create role admin-ui-view --verb=get,list,watch --resource=pods,services,configmaps
k -n ops create rolebinding admin-ui-view --role=admin-ui-view --serviceaccount=ops:admin-ui
```

**4) hostNetwork 끄기**

```bash
k -n ops patch deploy admin-ui --type=json -p='[{"op":"remove","path":"/spec/template/spec/hostNetwork"}]'
k -n ops rollout status deploy admin-ui
```

`hostNetwork: true` 인 Pod 는 노드의 네트워크 namespace 를 그대로 쓰므로 노드의 모든 인터페이스(NodePort 없이도 `<노드IP>:80`)에서
열리고, NetworkPolicy 로도 제어하기 어렵고, 노드의 localhost 서비스에도 접근할 수 있습니다. 함께 있던
`dnsPolicy: ClusterFirstWithHostNet` 은 hostNetwork 가 없으면 `ClusterFirst` 와 같게 동작하므로 남겨도 됩니다.

**5) default SA 자동 마운트 끄기**

```bash
k -n ops patch sa default -p '{"automountServiceAccountToken": false}'
```

| 위치 | 효과 |
|---|---|
| ServiceAccount `automountServiceAccountToken: false` | 그 SA 를 쓰는 모든 Pod 의 기본값 |
| Pod spec `automountServiceAccountToken` | SA 설정보다 우선 |

`admin-ui` 는 API 를 조회해야 하므로 자기 SA 토큰은 계속 마운트합니다. 따로 SA 를 지정하지 않은 다른 Pod 들만 토큰을 받지 않게 됩니다.

**6) 기록**

```bash
AS=system:serviceaccount:ops:admin-ui
for q in "get secrets -n ops" "list pods -n ops" "delete nodes"; do k auth can-i $q --as=$AS; done | tee /opt/course/c06/can-i.txt
# no
# yes
# no
```

## 검증

```bash
k -n ops get svc admin-ui -o jsonpath='{.spec.type} {.spec.ports[0].nodePort}{"\n"}'   # ClusterIP (nodePort 빈 값)
k -n ops get deploy admin-ui -o jsonpath='{.spec.template.spec.hostNetwork} {.spec.template.spec.serviceAccountName}{"\n"}'   #  admin-ui
k -n ops get pod -l app=admin-ui -o wide            # IP 가 노드 IP 가 아니라 Pod CIDR
k get clusterrolebinding -o wide | grep -E 'ops|serviceaccounts' || echo none
k -n ops get sa default -o jsonpath='{.automountServiceAccountToken}{"\n"}'              # false
cat /opt/course/c06/can-i.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 노출 줄이기 = Service ClusterIP, hostNetwork 끄기. 권한 줄이기 = ClusterRoleBinding 대신 namespace Role, 쓰지 않는 SA 토큰은 automount 끄기.
- **헷갈리는 지점**: SA 는 그룹 `system:serviceaccounts`·`system:serviceaccounts:<ns>` 의 구성원이라 그룹 바인딩으로도 권한을 받습니다. `kubectl auth can-i --list --as=...` 로 확인해야 놓치지 않습니다. `--as` 로 그룹 권한까지 보려면 SA 형식 이름을 써야 그룹이 자동으로 붙습니다.

## 참고 문서

- 검색어: `rbac good practices`, `configure service accounts automount`, `service nodeport clusterip`
- https://kubernetes.io/docs/concepts/security/rbac-good-practices/
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/concepts/security/service-accounts/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q07 →](../q07_apparmor_seccomp_multicontainer/question.md)
