# q05 — Clean up legacy ServiceAccount token Secrets

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q05_sa_legacy_token_cleanup
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `legacy` 에 ServiceAccount `ci-bot`, `old-app`, `metrics` 와, 각각에 연결된 `kubernetes.io/service-account-token` 타입 Secret 이 있다. 그중 하나는 setup 이 실제로 API 호출에 사용했다. Deployment `report`(SA `metrics`)는 쿠버네티스 API 를 쓰지 않지만 토큰이 마운트되어 있다.

## Task

Namespace `legacy` still contains long-lived ServiceAccount token Secrets from an old CI setup.

1. Find all Secrets of type `kubernetes.io/service-account-token` in namespace `legacy`. Write one
   line per Secret to `/opt/course/b05/legacy-tokens.txt` in the form
   `<secret-name> <last-used-date>`, where `<last-used-date>` is the date the API server recorded
   as the last use of the token, or `never` if it was never used.
2. Delete every legacy token Secret in `legacy` that was never used. Keep the others.
3. Deployment `report` does not need to call the Kubernetes API. Make sure its Pods get no
   ServiceAccount token mounted. Change only the Pod template of the Deployment, not the
   ServiceAccount.
4. Create a token for ServiceAccount `ci-bot` that is valid for 10 minutes and has the audience
   `https://ci.b05.internal`. Save only the token to `/opt/course/b05/ci-bot.token`.

## My attempt

```bash

```

## Record

<!-- One row per attempt. Score = points earned (0 … Points). The first row is the mock exam itself; later rows are reviews. -->

| Date | Time (min) | Score | Note |
|---|---|---|---|
|  |  |  |  |

---

Solution → **[solution.md](solution.md)**

[↑ 문항 목록](../README.md) · [← q04](../q04_rbac_find_excessive_bindings/question.md) · [q06 →](../q06_anonymous_auth_health_endpoints_only/question.md)
