# q13 — Scan workload images with Trivy and stop the CRITICAL ones

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q13_trivy_scan_delete_critical
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `cks-c1` 에는 Trivy **v0.69.3** 이 설치되어 있다(없을 때만 설치. v0.69.4 는 악성 릴리스였으므로 버전을 고정한다). namespace `kobra` 에는 Deployment 4개와 단독 Pod 1개가 실행 중이며, 일부는 init 컨테이너를 쓴다.
Trivy 는 첫 실행 때 취약점 DB 를 내려받고 이미지를 레지스트리에서 직접 가져오므로 인터넷이 필요하다. `jq` 가 있으면 편하다.

## Task

The security team does not allow images with known `CRITICAL` vulnerabilities in namespace
`kobra`.

1. Using `trivy`, scan every image used by the Pods in namespace `kobra` (all containers,
   including init containers) for vulnerabilities of severity `CRITICAL`.
2. Write every image that has at least one `CRITICAL` vulnerability, one per line, sorted
   alphabetically, exactly as written in the Pod spec, to
   `/opt/course/a13/critical-images.txt`.
3. Stop every workload that uses such an image: scale Deployments to `0` replicas (do not
   delete them) and delete standalone Pods. Workloads whose images have no `CRITICAL`
   vulnerability must keep running.

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

[↑ 문항 목록](../README.md) · [← q12](../q12_dockerfile_minimize_kubesec/question.md) · [q14 →](../q14_vap_permitted_registries_no_latest/question.md)
