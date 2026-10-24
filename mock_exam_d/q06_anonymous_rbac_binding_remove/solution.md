# q06 — Remove an anonymous RBAC binding · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Someone made the cluster readable without credentials. Do not disable anonymous authentication on
> the API server (its health endpoints are used by probes); fix the authorization instead.
>
> 1. Send an anonymous request (no client certificate, no token) to
>    `https://<API server address>:6443/api/v1/namespaces/default/pods` and write only the HTTP
>    status code to `/opt/course/d06/before.txt`.
> 2. Find the ClusterRoleBinding that grants ClusterRole `view` to `system:anonymous`, write its
>    name to `/opt/course/d06/binding.txt` and delete it. Do not delete the kubeadm default
>    bindings `system:public-info-viewer` and `kubeadm:bootstrap-signer-clusterinfo`.
> 3. Send the same anonymous request again and write the HTTP status code to
>    `/opt/course/d06/after.txt`.

**해석**

누군가 클러스터를 자격 증명 없이 읽을 수 있게 만들었다. API 서버의 익명 인증은 끄지 않는다(프로브가 health 엔드포인트를 쓰기 때문).
대신 인가(RBAC)를 고친다.

1. 클라이언트 인증서도 토큰도 없이 `https://<API 서버 주소>:6443/api/v1/namespaces/default/pods` 로 익명 요청을 보내 HTTP 상태
   코드만 `/opt/course/d06/before.txt` 에 쓴다.
2. `system:anonymous` 에 ClusterRole `view` 를 주는 ClusterRoleBinding 을 찾아 이름을 `/opt/course/d06/binding.txt` 에 쓰고 삭제한다.
   kubeadm 기본 바인딩 `system:public-info-viewer` 와 `kubeadm:bootstrap-signer-clusterinfo` 는 지우지 않는다.
3. 같은 익명 요청을 다시 보내 HTTP 상태 코드를 `/opt/course/d06/after.txt` 에 쓴다.

## 모범 풀이

**1) 익명 요청**

```bash
alias k=kubectl
S=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}'); echo $S    # https://<ip>:6443
curl -sk -o /dev/null -w '%{http_code}' $S/api/v1/namespaces/default/pods > /opt/course/d06/before.txt
cat /opt/course/d06/before.txt        # 200
curl -sk $S/api/v1/namespaces/default/pods | head -5     # "kind": "PodList" ...
```

`-k` 는 서버 인증서 검증만 건너뜁니다. 클라이언트 인증서(`--cert`)나 `Authorization: Bearer` 헤더가 없으니 API 서버는 이
요청을 사용자 `system:anonymous`, 그룹 `system:unauthenticated` 로 인증합니다. 그 다음 RBAC 가 허용하면 200, 아니면 403 입니다.
(익명 인증이 꺼져 있으면 인증 단계에서 401 이 납니다.)

**2) 바인딩 찾기 — subjects 로 검색**

```bash
k get clusterrolebinding -o wide | grep -E 'system:anonymous|system:unauthenticated'
# system:public-info-viewer     ClusterRole/system:public-info-viewer   ...   system:authenticated, system:unauthenticated
# telemetry-readonly            ClusterRole/view                        ...   system:anonymous
k get rolebinding -A -o wide | grep -E 'system:anonymous|system:unauthenticated'
# kube-public   kubeadm:bootstrap-signer-clusterinfo   Role/kubeadm:bootstrap-signer-clusterinfo   ...   system:anonymous
```

```bash
echo telemetry-readonly > /opt/course/d06/binding.txt
k get clusterrolebinding telemetry-readonly -o yaml          # roleRef ClusterRole/view, subjects User system:anonymous
k delete clusterrolebinding telemetry-readonly
```

| 기본 바인딩 | 주는 권한 | 지우면 |
|---|---|---|
| `system:public-info-viewer` (ClusterRoleBinding) | `/healthz`, `/livez`, `/readyz`, `/version` 읽기 | 익명 health 체크가 403 → 로드밸런서·프로브 실패 |
| `kubeadm:bootstrap-signer-clusterinfo` (kube-public RoleBinding) | ConfigMap `cluster-info` 읽기 | `kubeadm join` 의 discovery 실패 |

이 두 개는 일부러 익명에게 열어 둔 최소 권한이라 남깁니다. `jq` 가 있으면
`k get clusterrolebinding -o json | jq -r '.items[] | select(.subjects[]?.name=="system:anonymous") | .metadata.name'` 로도 찾습니다.

**3) 다시 요청**

```bash
curl -sk -o /dev/null -w '%{http_code}' $S/api/v1/namespaces/default/pods > /opt/course/d06/after.txt
cat /opt/course/d06/after.txt        # 403
curl -sk $S/api/v1/namespaces/default/pods | grep message
# "message": "pods is forbidden: User \"system:anonymous\" cannot list resource \"pods\" in API group \"\" in the namespace \"default\"",
```

## 검증

```bash
k auth can-i list pods -n default --as=system:anonymous          # no
curl -sk $S/livez; echo                                          # ok  (익명 health 는 그대로)
k get clusterrolebinding system:public-info-viewer               # 남아 있음
k -n kube-public get rolebinding kubeadm:bootstrap-signer-clusterinfo
cat /opt/course/d06/before.txt /opt/course/d06/binding.txt /opt/course/d06/after.txt    # 200 / telemetry-readonly / 403
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 익명 요청 = 사용자 `system:anonymous` + 그룹 `system:unauthenticated`. 인증 실패는 401, 인가 실패는 403.
- **헷갈리는 지점**: `--anonymous-auth=false` 는 kubeadm 의 apiserver liveness probe(익명 `/livez`)까지 깨뜨릴 수 있어, 끄려면 `AuthenticationConfiguration` 의 `anonymous.conditions` 로 health 경로만 허용하는 방식을 씁니다. 그룹 `system:unauthenticated` 에 묶인 바인딩도 익명에게 똑같이 적용되므로 GROUPS 열도 봅니다.

## 참고 문서

- 검색어: `anonymous requests`, `rbac default roles and role bindings`
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q07 →](../q07_apparmor_load_apply_pod/question.md)
