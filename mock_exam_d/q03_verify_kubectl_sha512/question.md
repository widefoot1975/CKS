# q03 — Verify a kubectl binary against its official SHA-512

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q03_verify_kubectl_sha512
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/d03/kubectl` 에 클러스터와 같은 버전이라고 주장하는 kubectl 바이너리가 있다(누군가 전달한 파일이라 진짜인지 모른다).
setup 이 `dl.k8s.io` 에서 바이너리를 받으므로 인터넷 연결이 필요하다.

## Task

A colleague handed over the binary `/opt/course/d03/kubectl` and claims it is the official
`linux/amd64` kubectl of the same version as this cluster's API server.

1. Download the official SHA-512 checksum for that kubectl version from `dl.k8s.io` and save it
   to `/opt/course/d03/kubectl.sha512`.
2. Compare it with the checksum of `/opt/course/d03/kubectl`. Write exactly `MATCH` or
   `MISMATCH` to `/opt/course/d03/result.txt`.
3. If the result is `MISMATCH`, delete `/opt/course/d03/kubectl`.

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

[↑ 문항 목록](../README.md) · [← q02](../q02_kube_bench_apiserver_profiling/question.md) · [q04 →](../q04_role_rolebinding_sa_least_privilege/question.md)
