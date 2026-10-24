# q12 — Build a distroless non-root Go image

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Supply Chain Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q12_dockerfile_distroless_nonroot_build
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/c12/app/` 에 Go 소스(`main.go`, `go.mod`)와 root 로 실행되는 단일 단계 `Dockerfile`(`golang:1.24` 전체 이미지)이 있고, 이미지 `c12-app:v2` 는 없다.
`cks-c1` 에 `podman` 이 있어야 한다. Trivy 가 없으면 setup 이 **v0.69.3** 을 `/usr/local/bin` 에 설치한다(v0.69.4 는 악성 릴리스라 쓰지 않는다).
베이스 이미지(`docker.io`, `gcr.io`)와 Trivy DB(`ghcr.io`, `mirror.gcr.io`)를 받기 위해 인터넷 연결이 필요하다. Trivy 는 정리할 때 지우지 않는다.

## Task

The Go web service in `/opt/course/c12/app/` is packaged in a large image that runs as root.
Do not change `main.go` or `go.mod`.

1. Rewrite `/opt/course/c12/app/Dockerfile` as a multi-stage build:
   - build stage named `build` from `docker.io/library/golang:1.26-alpine` that compiles a
     statically linked binary (`CGO_ENABLED=0`)
   - final stage from `gcr.io/distroless/static-debian12:nonroot` that contains only the binary
   - the final image runs as numeric user and group `65532:65532` and starts the binary with an
     exec-form `ENTRYPOINT`
2. Build the image with `podman` and tag it `c12-app:v2`. The image must be smaller than 20 MB.
3. Save the image as a docker-archive to `/opt/course/c12/c12-app-v2.tar`.
4. Scan the archive with Trivy for `HIGH` and `CRITICAL` vulnerabilities. There must be none.
   Write the Trivy table output to `/opt/course/c12/trivy.txt`.
5. Run the image as container `c12-test` with host port `18080` mapped to container port `8080`,
   write the response of `curl -s http://localhost:18080/` to `/opt/course/c12/curl.txt`, then
   remove the container.

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

[↑ 문항 목록](../README.md) · [← q11](../q11_cilium_wireguard_encryption/question.md) · [q13 →](../q13_imagepolicywebhook_admission_config/question.md)
