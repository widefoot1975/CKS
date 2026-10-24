# q05 — Clean up legacy ServiceAccount token Secrets · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespace `legacy` still contains long-lived ServiceAccount token Secrets from an old CI setup.
>
> 1. Find all Secrets of type `kubernetes.io/service-account-token` in namespace `legacy`. Write one
>    line per Secret to `/opt/course/b05/legacy-tokens.txt` in the form
>    `<secret-name> <last-used-date>`, where `<last-used-date>` is the date the API server recorded
>    as the last use of the token, or `never` if it was never used.
> 2. Delete every legacy token Secret in `legacy` that was never used. Keep the others.
> 3. Deployment `report` does not need to call the Kubernetes API. Make sure its Pods get no
>    ServiceAccount token mounted. Change only the Pod template of the Deployment, not the
>    ServiceAccount.
> 4. Create a token for ServiceAccount `ci-bot` that is valid for 10 minutes and has the audience
>    `https://ci.b05.internal`. Save only the token to `/opt/course/b05/ci-bot.token`.

**해석**

`legacy` 네임스페이스에 예전 CI 가 남긴 장기(만료 없는) ServiceAccount 토큰 Secret 들이 있다.

1. `legacy` 의 `kubernetes.io/service-account-token` 타입 Secret 을 모두 찾아 `<secret 이름> <마지막 사용일>` 형식으로 한 줄씩
   `/opt/course/b05/legacy-tokens.txt` 에 쓴다. 마지막 사용일은 API 서버가 기록한 날짜이고, 한 번도 안 쓰였으면 `never`.
2. 한 번도 쓰이지 않은 레거시 토큰 Secret 은 지우고 나머지는 남긴다.
3. Deployment `report` 는 API 를 쓰지 않으니 그 Pod 에 SA 토큰이 마운트되지 않게 한다. ServiceAccount 가 아니라 Deployment 의
   Pod 템플릿만 바꾼다.
4. SA `ci-bot` 의 토큰을 유효기간 10분, audience `https://ci.b05.internal` 로 만들어 토큰만 `/opt/course/b05/ci-bot.token` 에 저장한다.

## 모범 풀이

**1) 레거시 토큰과 마지막 사용일**

v1.24 부터 ServiceAccount 를 만들어도 토큰 Secret 이 자동으로 생기지 않습니다. 지금 남아 있는 `service-account-token` Secret 은 누군가
**직접** 만든 것이고 만료가 없습니다. API 서버(LegacyServiceAccountTokenTracking, GA v1.28)는 이런 토큰이 인증에 쓰이면 Secret 에
라벨 `kubernetes.io/legacy-token-last-used: <YYYY-MM-DD>` 를 붙입니다.

```bash
alias k=kubectl
k -n legacy get secret --field-selector type=kubernetes.io/service-account-token -L kubernetes.io/legacy-token-last-used
# NAME            TYPE                                  DATA   AGE   LEGACY-TOKEN-LAST-USED
# ci-bot-token    kubernetes.io/service-account-token   3      2m    2026-10-24
# metrics-token   kubernetes.io/service-account-token   3      2m
# old-app-token   kubernetes.io/service-account-token   3      2m

mkdir -p /opt/course/b05
k -n legacy get secret --field-selector type=kubernetes.io/service-account-token \
  -o jsonpath='{range .items[*]}{.metadata.name} {.metadata.labels.kubernetes\.io/legacy-token-last-used}{"\n"}{end}' \
  | awk '{print $1, ($2==""?"never":$2)}' > /opt/course/b05/legacy-tokens.txt
cat /opt/course/b05/legacy-tokens.txt
# ci-bot-token 2026-10-24
# metrics-token never
# old-app-token never
```

jsonpath 에서 라벨 키의 `.` 은 `\.` 로 이스케이프합니다. `kubernetes.io/legacy-token-invalid-since` 라벨이 있다면 컨트롤러 매니저의 정리
기능(LegacyServiceAccountTokenCleanUp, 기본 1년 미사용)이 이미 무효로 표시한 토큰입니다.

**2) 안 쓰인 토큰 지우기**

```bash
k -n legacy delete secret metrics-token old-app-token
```

`metrics` SA 를 쓰는 `report` 파드가 있어도 영향이 없습니다. 요즘 파드는 Secret 이 아니라 kubelet 이 TokenRequest 로 받는 **projected
토큰**(기본 약 1시간, 자동 갱신)을 마운트하기 때문입니다.

**3) report 파드에서 토큰 마운트 끄기**

```bash
k -n legacy patch deploy report --type=merge -p '{"spec":{"template":{"spec":{"automountServiceAccountToken":false}}}}'
k -n legacy rollout status deploy report
```

| 설정 위치 | 효과 | 우선순위 |
|---|---|---|
| `ServiceAccount.automountServiceAccountToken: false` | 그 SA 를 쓰는 모든 파드의 기본값 | 낮음 |
| `Pod.spec.automountServiceAccountToken: false` | 그 파드만 | **높음** (SA 설정을 덮어쓴다) |

파드 수준이 우선하므로 "이 워크로드만" 끄는 데는 Pod 템플릿이 정확합니다. Deployment 의 `spec.template` 이 바뀌어 새 ReplicaSet 으로
롤링됩니다.

**4) 짧은 수명 + audience 지정 토큰**

```bash
k -n legacy create token ci-bot --duration=10m --audience=https://ci.b05.internal > /opt/course/b05/ci-bot.token
cut -d. -f2 /opt/course/b05/ci-bot.token | tr '_-' '/+' | base64 -d 2>/dev/null; echo
# {"aud":["https://ci.b05.internal"],"exp":...,"iat":...,"iss":"https://kubernetes.default.svc.cluster.local",
#  "kubernetes.io":{"namespace":"legacy","serviceaccount":{"name":"ci-bot",...}},"sub":"system:serviceaccount:legacy:ci-bot"}
```

`exp - iat` 가 600 이면 10분입니다. API 서버의 최소 유효기간이 10분이라 그보다 짧게 요청하면 거부됩니다. audience 가 API 서버의
`--api-audiences` 와 다르므로 이 토큰으로는 **쿠버네티스 API 에 인증할 수 없습니다**. 외부 시스템(CI)이 `aud` 를 검증하는 용도로만 쓰입니다.
(JWT 는 base64url 이고 패딩이 없어 `base64 -d` 가 경고를 낼 수 있는데 내용은 보입니다.)

## 검증

```bash
k -n legacy get secret --field-selector type=kubernetes.io/service-account-token        # ci-bot-token 만
k -n legacy get pod -l app=report -o jsonpath='{.items[0].spec.automountServiceAccountToken}{"\n"}'   # false
k -n legacy exec deploy/report -- ls /var/run/secrets/kubernetes.io/serviceaccount     # No such file or directory
k -n legacy get sa metrics -o jsonpath='{.automountServiceAccountToken}{"\n"}'          # 비어 있음(SA 는 그대로)
APISERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -sk -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $(cat /opt/course/b05/ci-bot.token)" $APISERVER/api   # 401 (audience 불일치)
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 레거시 토큰 = `type: kubernetes.io/service-account-token` + 어노테이션 `kubernetes.io/service-account.name`. 사용 여부는 라벨 `kubernetes.io/legacy-token-last-used`. 새 토큰은 `kubectl create token <sa> --duration --audience`.
- **헷갈리는 지점**: `automountServiceAccountToken` 은 Pod 수준이 SA 수준보다 우선합니다. `kubectl create token` 은 Secret 을 만들지 않고 어디에도 저장되지 않으므로, 잃어버리면 다시 발급해야 합니다. `--duration` 은 API 서버의 `--service-account-max-token-expiration` 을 넘길 수 없습니다.

## 참고 문서

- 검색어: `legacy service account token`, `kubectl create token`, `configure service accounts automount`
- https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/concepts/security/service-accounts/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q06 →](../q06_anonymous_auth_health_endpoints_only/question.md)
