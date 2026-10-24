# q04 — Least-privilege Role for a ServiceAccount · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> ServiceAccount `reporter` in namespace `jade` only needs to read Pods in its own namespace, but
> it currently has far more permissions.
>
> 1. Find and delete the RoleBinding in namespace `jade` that grants `reporter` its current
>    permissions.
> 2. Create a Role `pod-reader` in namespace `jade` that allows only the verbs `get`, `list` and
>    `watch` on `pods`, and bind it to `reporter` with a RoleBinding `reporter-pod-reader`.
> 3. Using `kubectl auth can-i` as `reporter`, check the four requests below and write one answer
>    (`yes` or `no`) per line, in this order, to `/opt/course/d04/can-i.txt`:
>    `list pods -n jade`, `delete pods -n jade`, `get secrets -n jade`, `list pods -n default`.

**해석**

namespace `jade` 의 ServiceAccount `reporter` 는 자기 namespace 의 Pod 만 읽으면 되는데, 지금은 훨씬 많은 권한을 갖고 있다.

1. `reporter` 에 지금 권한을 주는 `jade` namespace 의 RoleBinding 을 찾아 삭제한다.
2. `pods` 에 대해 `get`, `list`, `watch` 만 허용하는 Role `pod-reader` 를 `jade` 에 만들고, RoleBinding `reporter-pod-reader` 로
   `reporter` 에 묶는다.
3. `reporter` 로서 `kubectl auth can-i` 로 아래 네 요청을 확인해 순서대로 한 줄에 하나씩(`yes`/`no`) `/opt/course/d04/can-i.txt` 에 쓴다:
   `list pods -n jade`, `delete pods -n jade`, `get secrets -n jade`, `list pods -n default`.

## 모범 풀이

**1) 지금 권한의 출처 찾기**

```bash
alias k=kubectl
k -n jade get rolebinding -o wide
# NAME            ROLE               AGE   USERS   GROUPS   SERVICEACCOUNTS
# legacy-tools    ClusterRole/edit   1m                     jade/reporter
k get clusterrolebinding -o wide | grep 'jade/reporter' || echo "클러스터 범위 바인딩 없음"
k -n jade delete rolebinding legacy-tools
```

`-o wide` 는 RoleBinding/ClusterRoleBinding 의 `subjects` 를 USERS·GROUPS·SERVICEACCOUNTS 열로 보여 주므로, 이름으로
추측하지 않고 대상 SA 로 찾을 수 있습니다. RoleBinding 이 **ClusterRole** 을 참조해도 권한은 그 RoleBinding 의 namespace
안으로만 제한됩니다. 그래도 `edit` 은 secrets 읽기·쓰기, Pod 생성까지 포함하므로 최소 권한이 아닙니다.

**2) Role 과 RoleBinding**

```bash
k -n jade create role pod-reader --verb=get,list,watch --resource=pods
k -n jade create rolebinding reporter-pod-reader --role=pod-reader --serviceaccount=jade:reporter
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: jade
rules:
- apiGroups: [""]          # core API 그룹 = 빈 문자열
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: reporter-pod-reader
  namespace: jade
subjects:
- kind: ServiceAccount
  name: reporter
  namespace: jade          # SA subject 에는 namespace 가 필수
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
```

`--serviceaccount` 형식은 `<namespace>:<이름>` 입니다. `--user=reporter` 로 쓰면 일반 사용자 `reporter` 에 묶여 SA 에는
아무 권한도 생기지 않습니다. `roleRef` 는 만든 뒤에 바꿀 수 없어 잘못 만들었으면 지우고 다시 만듭니다.

**3) can-i 매트릭스**

```bash
SA=system:serviceaccount:jade:reporter
{
  k auth can-i list pods   -n jade    --as=$SA
  k auth can-i delete pods -n jade    --as=$SA
  k auth can-i get secrets -n jade    --as=$SA
  k auth can-i list pods   -n default --as=$SA
} > /opt/course/d04/can-i.txt
cat /opt/course/d04/can-i.txt
# yes
# no
# no
# no
```

`can-i` 는 `no` 일 때 종료 코드 1 을 돌려주지만 `yes`/`no` 는 stdout 으로 나오므로 그대로 파일에 모입니다.
`--as` 에는 SA 의 전체 사용자 이름 `system:serviceaccount:<ns>:<sa>` 를 씁니다.

## 검증

```bash
k -n jade get rolebinding -o wide                        # reporter-pod-reader 만 jade/reporter 를 가리킨다
k auth can-i --list -n jade --as=system:serviceaccount:jade:reporter | grep -v selfsubject
# pods   []   []   [get list watch]
paste -sd, /opt/course/d04/can-i.txt                      # yes,no,no,no
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `k create role ... --verb --resource` / `k create rolebinding ... --role --serviceaccount=ns:name` / `k auth can-i <verb> <res> --as=system:serviceaccount:ns:name`.
- **헷갈리는 지점**: 권한은 더해지기만 하므로 좁은 Role 을 추가해도 넓은 바인딩을 지우지 않으면 소용없습니다. 그룹 `system:serviceaccounts:jade` 나 `system:serviceaccounts` 에 묶인 바인딩도 이 SA 에 적용되니 GROUPS 열도 확인합니다.

## 참고 문서

- 검색어: `rbac`, `rolebinding serviceaccount`, `auth can-i`
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/concepts/security/service-accounts/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q05 →](../q05_sa_automount_false/question.md)
