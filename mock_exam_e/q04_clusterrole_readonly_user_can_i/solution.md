# q04 — Read-only ClusterRole for a user, checked with can-i · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> User `audit-joe` from the audit team needs cluster-wide read-only access to a few resource
> types, and nothing else.
>
> 1. Create a ClusterRole named `e04-readonly` that allows only the verbs `get`, `list` and
>    `watch` on `pods`, `services`, `namespaces` and `deployments` (API group `apps`).
> 2. Bind it to user `audit-joe` cluster-wide with a ClusterRoleBinding named
>    `e04-readonly-audit-joe`.
> 3. Run the following checks and write the four answers (`yes`/`no`), one per line in this
>    order, to `/opt/course/e04/can-i.txt`:
>    - `kubectl auth can-i list pods -A --as audit-joe`
>    - `kubectl auth can-i get deployments.apps -n kube-system --as audit-joe`
>    - `kubectl auth can-i delete pods -n default --as audit-joe`
>    - `kubectl auth can-i list secrets -A --as audit-joe`

**해석**

감사 팀 사용자 `audit-joe` 는 몇 가지 리소스에 대해 클러스터 전체 읽기 전용 권한만 필요하다.

1. ClusterRole `e04-readonly` 를 만든다. `pods`, `services`, `namespaces`, `deployments`(API 그룹 `apps`)에 대해 `get`, `list`, `watch` 만 허용한다.
2. ClusterRoleBinding `e04-readonly-audit-joe` 로 사용자 `audit-joe` 에게 클러스터 전체로 바인딩한다.
3. 아래 네 가지를 확인하고 답(`yes`/`no`)을 순서대로 한 줄에 하나씩 `/opt/course/e04/can-i.txt` 에 쓴다.

## 모범 풀이

**1) ClusterRole — 리소스가 두 API 그룹에 나뉩니다**

```bash
kubectl create clusterrole e04-readonly \
  --verb=get,list,watch \
  --resource=pods,services,namespaces,deployments.apps
kubectl get clusterrole e04-readonly -o yaml
```

```yaml
rules:
- apiGroups: [""]               # core: pods, services, namespaces
  resources: ["namespaces", "pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
```

`--resource=deployments` 처럼 그룹 없이 써도 kubectl 이 discovery 로 `apps` 를 찾아 주지만, `deployments.apps` 로 쓰면
의도가 분명합니다. YAML 로 직접 쓸 때 core 그룹은 빈 문자열 `""` 입니다.

**2) ClusterRoleBinding**

```bash
kubectl create clusterrolebinding e04-readonly-audit-joe \
  --clusterrole=e04-readonly --user=audit-joe
```

사용자(User)는 쿠버네티스 오브젝트가 아니라 인증서 CN·OIDC 클레임 등에서 오는 **문자열**이라 미리 만들 필요가 없습니다.
RoleBinding 으로 ClusterRole 을 묶으면 그 namespace 에만 적용되므로, 클러스터 전체(`-A`, `namespaces` 목록)는
ClusterRoleBinding 이어야 합니다.

**3) can-i 결과 기록**

```bash
{
  kubectl auth can-i list pods -A --as audit-joe
  kubectl auth can-i get deployments.apps -n kube-system --as audit-joe
  kubectl auth can-i delete pods -n default --as audit-joe
  kubectl auth can-i list secrets -A --as audit-joe
} > /opt/course/e04/can-i.txt
cat /opt/course/e04/can-i.txt
# yes
# yes
# no
# no
```

`can-i` 는 `no` 일 때 종료 코드 1 을 돌려줍니다. `set -e` 셸 스크립트라면 중단되니 `|| true` 를 붙입니다. 출력(`yes`/`no`)은
표준출력으로 나오므로 그대로 파일에 모입니다.

## 검증

```bash
kubectl describe clusterrole e04-readonly
kubectl get clusterrolebinding e04-readonly-audit-joe -o wide     # ROLE ClusterRole/e04-readonly, USERS audit-joe
kubectl auth can-i --list --as audit-joe | grep -E 'pods|services|namespaces|deployments'
kubectl auth can-i watch services -n kube-system --as audit-joe   # yes
kubectl auth can-i create deployments -n default --as audit-joe   # no
cat /opt/course/e04/can-i.txt                                     # yes yes no no
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `kubectl create clusterrole <n> --verb=get,list,watch --resource=pods,deployments.apps` + `kubectl create clusterrolebinding <n> --clusterrole=<n> --user=<u>`, 확인은 `kubectl auth can-i <verb> <res> --as <u>`.
- **헷갈리는 지점**: 읽기 전용이라도 `secrets` 를 주면 토큰·비밀번호를 읽을 수 있으니 기본 `view` ClusterRole 도 secrets 를 빼 둡니다. `--as` 는 impersonation 이라 관리자에게 `impersonate` 권한이 있어야 동작합니다. ServiceAccount 를 확인할 때는 `--as system:serviceaccount:<ns>:<sa>` 입니다.

## 참고 문서

- 검색어: `rbac`, `clusterrolebinding`, `auth can-i`
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/reference/access-authn-authz/authorization/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q05 →](../q05_create_token_duration_audience/question.md)
