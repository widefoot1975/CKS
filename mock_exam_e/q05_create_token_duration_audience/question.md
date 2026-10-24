# q05 — Short-lived ServiceAccount token with a custom audience

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q05_create_token_duration_audience
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `cicd` 에 ServiceAccount `ci-deployer` 가 있고, 이 SA 의 토큰 Secret 은 없다(v1.24 이후 자동 생성되지 않음).
`/opt/course/e05/` 는 비어 있다. JWT 디코딩에 `jq` 와 `base64` 를 쓸 수 있다.

## Task

An external CI system authenticates with ServiceAccount `ci-deployer` in namespace `cicd`.
It only accepts tokens issued for audience `https://ci.cks.local`.

1. Request a token for ServiceAccount `ci-deployer` that is valid for 30 minutes and has
   the audience `https://ci.cks.local`. Save only the token to `/opt/course/e05/token`.
   Do not create a Secret.
2. Decode the token payload. Write the audience value to `/opt/course/e05/aud.txt` and the
   token lifetime in seconds (`exp` minus `iat`) to `/opt/course/e05/lifetime.txt`.

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

[↑ 문항 목록](../README.md) · [← q04](../q04_clusterrole_readonly_user_can_i/question.md) · [q06 →](../q06_networkpolicy_block_apiserver_egress/question.md)
