# q05 — Short-lived ServiceAccount token with a custom audience · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> An external CI system authenticates with ServiceAccount `ci-deployer` in namespace `cicd`.
> It only accepts tokens issued for audience `https://ci.cks.local`.
>
> 1. Request a token for ServiceAccount `ci-deployer` that is valid for 30 minutes and has
>    the audience `https://ci.cks.local`. Save only the token to `/opt/course/e05/token`.
>    Do not create a Secret.
> 2. Decode the token payload. Write the audience value to `/opt/course/e05/aud.txt` and the
>    token lifetime in seconds (`exp` minus `iat`) to `/opt/course/e05/lifetime.txt`.

**해석**

외부 CI 시스템이 namespace `cicd` 의 ServiceAccount `ci-deployer` 로 인증한다. 이 시스템은 audience 가 `https://ci.cks.local` 인 토큰만 받는다.

1. ServiceAccount `ci-deployer` 용으로 30분짜리, audience `https://ci.cks.local` 토큰을 발급받아 토큰만 `/opt/course/e05/token` 에 저장한다.
   Secret 은 만들지 않는다.
2. 토큰 payload 를 디코딩해 audience 값을 `/opt/course/e05/aud.txt` 에, 토큰 수명(초, `exp` − `iat`)을 `/opt/course/e05/lifetime.txt` 에 쓴다.

## 모범 풀이

**1) TokenRequest API 로 토큰 발급**

```bash
kubectl -n cicd create token ci-deployer --duration=30m --audience=https://ci.cks.local > /opt/course/e05/token
wc -c /opt/course/e05/token          # 수백~천여 바이트, eyJ... 로 시작
```

`kubectl create token` 은 TokenRequest API(`serviceaccounts/token` 서브리소스)를 호출해 **etcd 에 저장되지 않는** 시간 제한
토큰을 받습니다. `--audience` 를 주지 않으면 API 서버의 기본 audience(`--api-audiences`, kubeadm 은 `https://kubernetes.default.svc.cluster.local`)가
들어갑니다. `--duration` 은 최소 10분이며, API 서버의 `--service-account-max-token-expiration` 보다 길게 요청하면 그 값으로 잘립니다.

**2) payload 디코딩**

JWT 는 `header.payload.signature` 이고 각 부분은 **패딩 없는 base64url** 입니다. `base64 -d` 가 읽을 수 있게 `-_` → `+/` 로 바꾸고
`=` 패딩을 채웁니다.

```bash
P=$(cut -d. -f2 /opt/course/e05/token | tr '_-' '/+')
while [ $(( ${#P} % 4 )) -ne 0 ]; do P="$P="; done
echo "$P" | base64 -d | jq .
# {
#   "aud": ["https://ci.cks.local"],
#   "exp": 1793...,
#   "iat": 1793...,
#   "iss": "https://kubernetes.default.svc.cluster.local",
#   "kubernetes.io": { "namespace": "cicd", "serviceaccount": { "name": "ci-deployer", ... } },
#   "sub": "system:serviceaccount:cicd:ci-deployer"
# }
echo "$P" | base64 -d | jq -r '.aud[0]'     > /opt/course/e05/aud.txt
echo "$P" | base64 -d | jq -r '.exp - .iat' > /opt/course/e05/lifetime.txt
cat /opt/course/e05/aud.txt /opt/course/e05/lifetime.txt
# https://ci.cks.local
# 1800
```

jq 만으로도 됩니다: `jq -R 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | @base64d | fromjson' /opt/course/e05/token`.

| 토큰 종류 | 저장 위치 | 만료 | audience |
|---|---|---|---|
| `kubectl create token` (TokenRequest) | 저장 안 됨 | `--duration` (기본 1h) | `--audience` |
| 파드의 projected SA 토큰 | kubelet 이 파일로 마운트, 자동 갱신 | `expirationSeconds` (기본 1h) | `audience` 필드 |
| 레거시 `kubernetes.io/service-account-token` Secret | etcd | 없음 | API 서버 기본값 |

## 검증

```bash
cat /opt/course/e05/aud.txt                       # https://ci.cks.local
cat /opt/course/e05/lifetime.txt                  # 1800
kubectl -n cicd get secret --field-selector type=kubernetes.io/service-account-token   # No resources found
# 이 토큰은 API 서버용 audience 가 아니므로 API 서버는 거부한다 (401)
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -s --cacert /etc/kubernetes/pki/ca.crt -H "Authorization: Bearer $(cat /opt/course/e05/token)" \
  -o /dev/null -w '%{http_code}\n' $APISERVER/api        # 401
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `kubectl -n <ns> create token <sa> --duration=30m --audience=<aud>` — Secret 을 만들지 않는 단기 토큰. JWT payload 는 `cut -d. -f2` 후 base64url 디코딩.
- **헷갈리는 지점**: audience 는 "이 토큰을 받을 쪽"이라 외부 audience 로 발급한 토큰은 API 서버가 받지 않습니다(토큰 오용 방지). API 서버에도 쓰려면 `--audience` 를 여러 번 주어 기본 audience 를 함께 넣습니다. `aud` 는 JSON 배열이라 `.aud` 가 아니라 `.aud[0]` 으로 문자열을 꺼냅니다.

## 참고 문서

- 검색어: `kubectl create token`, `TokenRequest`, `service account token audience`
- https://kubernetes.io/docs/concepts/security/service-accounts/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q06 →](../q06_networkpolicy_block_apiserver_egress/question.md)
