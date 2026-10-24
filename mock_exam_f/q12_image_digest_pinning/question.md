# q12 — Pin container images by digest

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Supply Chain Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q12_image_digest_pinning
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `f12` 에 Deployment `api`(replicas 2)가 `Running` 이고, 컨테이너 `web`(`nginx:1.27-alpine`)과 `sidecar`(`busybox:1.36`)는 이미지를 **태그**로 참조한다. `/opt/course/f12/` 는 비어 있다.

## Task

Image tags are mutable. Deployment `api` in namespace `f12` must keep running exactly the image
content it runs now, even if someone pushes a new image under the same tag.

1. Find the image digest that each running container of Deployment `api` actually uses and write
   one line per container in the form `<container-name> <imageID>` (as reported in the Pod status)
   to `/opt/course/f12/digests.txt`.
2. Change Deployment `api` so that both containers reference their image by digest only, in the
   form `docker.io/library/<name>@sha256:<digest>` (no tag), using the digests from step 1.
3. Wait until the rollout is complete. All Pods of `api` must be `Running` and Ready.

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

[↑ 문항 목록](../README.md) · [← q11](../q11_user_namespaces_hostusers_false/question.md) · [q13 →](../q13_trivy_config_manifest_scan/question.md)
