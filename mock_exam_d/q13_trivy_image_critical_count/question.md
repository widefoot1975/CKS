# q13 — Count CRITICAL vulnerabilities with Trivy

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Supply Chain Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q13_trivy_image_critical_count
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `quartz` 에 Deployment `legacy`(`nginx:1.19`)와 `current`(`nginx:1.27-alpine`)가 각각 replicas 1 로 돈다.
`trivy` 가 없으면 setup 이 **v0.69.3** 을 `/usr/local/bin` 에 설치한다(v0.69.4 는 악성 릴리스였으므로 `latest` 를 쓰지 않는다). 첫 스캔 때 취약점 DB 를 받으므로 인터넷이 필요하다. cleanup 은 trivy 를 지우지 않는다.
CRITICAL 개수는 Trivy DB 가 갱신될 때마다 달라지므로 정답 숫자는 정해져 있지 않다.

## Task

Namespace `quartz` runs two Deployments, `legacy` and `current`. Trivy is installed on `cks-c1`.

1. Scan the image of each Deployment in namespace `quartz` with `trivy image`, reporting only
   vulnerabilities of severity `CRITICAL`. Write one line per Deployment in the format
   `<deployment> <image> <number of CRITICAL vulnerabilities>` to
   `/opt/course/d13/critical.txt`.
2. Scale every Deployment in namespace `quartz` whose image has at least one `CRITICAL`
   vulnerability to `0` replicas. Do not delete any Deployment.

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

[↑ 문항 목록](../README.md) · [← q12](../q12_dockerfile_nonroot_pinned_tag/question.md) · [q14 →](../q14_kubesec_score_fix_pod/question.md)
