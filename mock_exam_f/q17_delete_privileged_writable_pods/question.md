# q17 — Delete privileged and writable Pods

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 8 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q17_delete_privileged_writable_pods
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `f17` 에 단독 Pod 다섯 개(`alpha`, `beta`, `gamma`, `delta`, `epsilon`)가 `Running` 이다. 일부는 컨테이너가 두 개다. `/opt/course/f17/` 는 비어 있다.

## Task

Only immutable containers may run in namespace `f17`: a container must not be privileged and its
root filesystem must be read-only.

1. Find every Pod in namespace `f17` that has at least one container that is privileged or does
   not have `readOnlyRootFilesystem: true`. Write their names, one per line and sorted
   alphabetically, to `/opt/course/f17/pods.txt`.
2. Delete exactly these Pods.
3. Write the output of `kubectl -n f17 get pods` to `/opt/course/f17/remaining.txt`. The remaining
   Pods must still be `Running`.

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

[↑ 문항 목록](../README.md) · [← q16](../q16_audit_policy_secrets_metadata/question.md)
