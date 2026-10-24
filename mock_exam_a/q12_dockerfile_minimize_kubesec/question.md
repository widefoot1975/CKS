# q12 — Harden a Dockerfile and raise a Deployment's kubesec score

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Supply Chain Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q12_dockerfile_minimize_kubesec
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/a12/app/` 에 Go 소스 `main.go` 와 문제가 많은 `Dockerfile` 이, `/opt/course/a12/deploy.yaml` 에 적용하지 않은 Deployment 매니페스트가 있다. `kubesec` v2.14.2 가 설치되어 있다(없을 때만 GitHub 릴리스에서 받으므로 인터넷 필요).
`cks-c1` 에 `podman` 이 있어야 하고, 베이스 이미지를 받기 위해 `docker.io` 로 인터넷 연결이 되어야 한다.

## Task

The image and manifest of application `a12-app` violate several supply chain rules.

1. Rewrite `/opt/course/a12/app/Dockerfile` as a multi-stage build:
   - build stage `docker.io/library/golang:1.24-alpine`, building a static binary
     (`CGO_ENABLED=0`) from `main.go`
   - final stage `scratch` that contains only the binary
   - no `ENV` or `ARG` with the API token, and no `curl` or `wget` in the final image
   - the final image runs as user and group `65532` (numeric)
2. Build it with `podman` as `localhost/a12-app:v2`.
3. Run `kubesec scan` on `/opt/course/a12/deploy.yaml` and note the score. Then fix the
   manifest so that the scan reports no critical findings and a score of at least `7`:
   remove privileged mode and host networking, use image `localhost/a12-app:v2`, read
   `API_TOKEN` from key `token` of Secret `a12-api` instead of a literal value, use
   ServiceAccount `a12-app`, run as non-root user `65532` with a read-only root filesystem,
   no privilege escalation and all capabilities dropped, and set CPU and memory requests
   and limits. Do not apply the manifest.
4. Write the scores to `/opt/course/a12/kubesec.txt` in the form `before: <n>` and
   `after: <n>` (two lines).

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

[↑ 문항 목록](../README.md) · [← q11](../q11_runtimeclass_gvisor_sandbox/question.md) · [q13 →](../q13_trivy_scan_delete_critical/question.md)
