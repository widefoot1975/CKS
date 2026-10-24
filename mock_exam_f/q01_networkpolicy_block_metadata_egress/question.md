# q01 — Block Pod egress to the cloud metadata endpoint

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q01_networkpolicy_block_metadata_egress
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `berlin` 에 Deployment `webapp`(nginx, Service `webapp` port 80)과 Pod `client`(curl)가 있고, NetworkPolicy 는 하나도 없다. `/opt/course/f01/` 는 비어 있다.
NetworkPolicy 는 Cilium 이 적용한다. 메타데이터 주소 `169.254.169.254` 가 실제로 응답하는지는 랩이 돌아가는 클라우드에 따라 다르다.

## Task

The cloud metadata endpoint `169.254.169.254` can hand out node credentials. Pods in namespace
`berlin` must not be able to reach it.

1. Create a NetworkPolicy named `deny-metadata` in namespace `berlin` that selects all Pods in the
   namespace and blocks egress to `169.254.169.254/32`. All other egress traffic of these Pods
   (to other Pods, to cluster DNS and to the Internet) must stay allowed. Do not restrict ingress.
2. From Pod `client`, request `http://webapp` and write only the HTTP status code to
   `/opt/course/f01/webapp.txt`.
3. From Pod `client`, run `curl -s -m 3 http://169.254.169.254/` and write only the exit code of
   `curl` to `/opt/course/f01/metadata.txt`.

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

[↑ 문항 목록](../README.md) · [q02 →](../q02_cis_static_pod_manifest_permissions/question.md)
