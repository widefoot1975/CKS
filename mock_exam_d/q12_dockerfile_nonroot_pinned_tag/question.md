# q12 — Pin the base image and run as non-root in a Dockerfile

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q12_dockerfile_nonroot_pinned_tag
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/d12/app/` 에 `Dockerfile` 과 `app.sh` 가 있다. Dockerfile 은 `alpine:latest` 를 쓰고 마지막에 `USER root` 로 실행한다.
`cks-c1` 에 `podman` 이 있어야 하고(없으면 setup 이 멈춘다), 베이스 이미지를 받기 위해 `docker.io` 로 인터넷 연결이 필요하다.

## Task

The image built from `/opt/course/d12/app/Dockerfile` uses a moving base image tag and runs as
root.

1. Edit the Dockerfile: use the base image `docker.io/library/alpine:3.20` instead of the
   `latest` tag, and make the container run as the non-root user with UID `10001` and GID
   `10001` (numeric). Do not change other instructions.
2. Using `podman`, build the image with tag `d12-app:v1` from `/opt/course/d12/app/`.
3. Run `podman run --rm d12-app:v1` and write its output to `/opt/course/d12/run.txt`.

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

[↑ 문항 목록](../README.md) · [← q11](../q11_runtimeclass_gvisor_pod/question.md) · [q13 →](../q13_trivy_image_critical_count/question.md)
