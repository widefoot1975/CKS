# q05 — Stop mounting the ServiceAccount token · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The `backend` application in namespace `opal` never talks to the Kubernetes API, so it must not
> receive an API token.
>
> 1. Create a ServiceAccount `backend` in namespace `opal` with `automountServiceAccountToken`
>    set to `false`.
> 2. Create a Pod `backend` in namespace `opal` with image `nginx:1.27-alpine` that uses
>    ServiceAccount `backend`. Also set `automountServiceAccountToken: false` in the Pod spec.
> 3. Run `kubectl -n opal exec backend -- ls /var/run/secrets/kubernetes.io/serviceaccount` and
>    write its complete output (stdout and stderr) to `/opt/course/d05/token.txt`.

**해석**

namespace `opal` 의 `backend` 애플리케이션은 쿠버네티스 API 를 전혀 쓰지 않으므로 API 토큰을 받으면 안 된다.

1. namespace `opal` 에 `automountServiceAccountToken: false` 인 ServiceAccount `backend` 를 만든다.
2. ServiceAccount `backend` 를 쓰는 이미지 `nginx:1.27-alpine` 의 Pod `backend` 를 `opal` 에 만든다. Pod spec 에도
   `automountServiceAccountToken: false` 를 넣는다.
3. `kubectl -n opal exec backend -- ls /var/run/secrets/kubernetes.io/serviceaccount` 를 실행해 출력 전체(stdout, stderr)를
   `/opt/course/d05/token.txt` 에 쓴다.

## 모범 풀이

**1) ServiceAccount**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend
  namespace: opal
automountServiceAccountToken: false     # spec 이 아니라 최상위 필드
```

`kubectl create serviceaccount` 에는 이 옵션이 없으므로 YAML 로 만들거나, 만든 뒤
`kubectl -n opal patch sa backend -p '{"automountServiceAccountToken":false}'` 로 바꿉니다.

**2) Pod**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: opal
spec:
  serviceAccountName: backend
  automountServiceAccountToken: false   # Pod 값이 SA 값보다 우선
  containers:
  - name: backend
    image: nginx:1.27-alpine
```

```bash
alias k=kubectl
k apply -f sa.yaml -f pod.yaml
k -n opal wait --for=condition=Ready pod/backend
```

| SA 설정 | Pod 설정 | 토큰 마운트 |
|---|---|---|
| (없음) | (없음) | 마운트됨 (기본값) |
| `false` | (없음) | 안 됨 |
| `false` | `true` | **마운트됨** — Pod 가 우선 |
| (없음)/`true` | `false` | 안 됨 |

SA 에만 걸면 누군가 Pod 에 `true` 를 넣는 순간 다시 마운트되므로 두 곳에 다 걸어 둡니다. 토큰은 1.24 이후 Secret 이 아니라
kubelet 이 발급하는 **projected volume `kube-api-access-xxxxx`** 로 들어오므로, 설정이 맞으면 이 볼륨 자체가 Pod 에 생기지 않습니다.
Pod 의 `serviceAccountName` 과 `automountServiceAccountToken` 은 만든 뒤 바꿀 수 없어 틀렸다면 지우고 다시 만듭니다.

**3) 확인 결과 저장**

```bash
k -n opal exec backend -- ls /var/run/secrets/kubernetes.io/serviceaccount > /opt/course/d05/token.txt 2>&1
cat /opt/course/d05/token.txt
# ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
# command terminated with exit code 1
```

비교용 `legacy` Pod 에서는 같은 명령이 `ca.crt namespace token` 을 보여 줍니다.

## 검증

```bash
k -n opal get sa backend -o jsonpath='{.automountServiceAccountToken}{"\n"}'          # false
k -n opal get pod backend -o jsonpath='{.spec.serviceAccountName} {.spec.automountServiceAccountToken}{"\n"}'   # backend false
k -n opal get pod backend -o jsonpath='{.spec.volumes}{"\n"}'                          # kube-api-access-* 없음
k -n opal exec legacy -- ls /var/run/secrets/kubernetes.io/serviceaccount              # ca.crt namespace token
cat /opt/course/d05/token.txt                                                          # No such file or directory
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `automountServiceAccountToken: false` 는 SA 최상위와 Pod `spec` 두 곳에 있고 Pod 가 우선한다.
- **헷갈리는 지점**: 필드 이름은 `automountServiceAccountToken`(Token 단수, `serviceAccount` 가 아니라 `ServiceAccount`)입니다. `2>&1` 을 빼면 `No such file` 메시지가 파일에 남지 않습니다. 토큰이 정말 필요한 앱은 마운트를 끄고 `projected` 볼륨의 `serviceAccountToken`(audience, expirationSeconds)을 직접 넣어 범위를 좁힙니다.

## 참고 문서

- 검색어: `configure service accounts`, `automountServiceAccountToken`
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/concepts/security/service-accounts/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q06 →](../q06_anonymous_rbac_binding_remove/question.md)
