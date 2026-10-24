# q09 — Enforce Pod Security baseline while warning on restricted

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q09_psa_baseline_enforce_restricted_warn
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `atlas` 에는 Pod Security 라벨이 하나도 없고, Deployment `atlas-web`, `atlas-cache`, `atlas-agent` 가 각각 1 레플리카로 실행 중이다. 셋의 securityContext 는 서로 다르다.

## Task

Namespace `atlas` must be protected by Pod Security Admission.

1. Before changing anything, find out which running Pods would violate the Pod Security
   Standards `baseline` and `restricted`, using a server-side dry run of the namespace
   label. Write the complete warning output of the `baseline` check to
   `/opt/course/a09/baseline.txt` and of the `restricted` check to
   `/opt/course/a09/restricted.txt`.
2. Fix Deployment `atlas-agent` so that its Pods satisfy `baseline`: it must not run
   privileged, and its volume `host-log` must become an `emptyDir` volume (same name, same
   mount path). Change nothing else.
3. Label namespace `atlas` so that `baseline` is enforced, and `restricted` produces
   warnings and audit annotations. Pin all three modes to version `v1.35`.
4. All three Deployments must have their Pods `Running` under the new labels.
5. Write the names of the Deployments whose Pods still violate `restricted`, one per line
   and sorted alphabetically, to `/opt/course/a09/restricted-violators.txt`.

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

[↑ 문항 목록](../README.md) · [← q08](../q08_host_listening_service_disable/question.md) · [q10 →](../q10_etcd_encryption_at_rest_rewrite/question.md)
