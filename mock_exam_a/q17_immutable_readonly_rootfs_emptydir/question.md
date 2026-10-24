# q17 — Immutable Pods with read-only root filesystems

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 8 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q17_immutable_readonly_rootfs_emptydir
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `glacier` 에는 Deployment `glacier-web`(nginx, 컨테이너 `nginx`, 쓰기 가능한 루트 파일시스템)과 단독 Pod 4개(`glacier-cache`, `glacier-tool`, `glacier-logger`, `glacier-sidecar`)가 실행 중이다. 단독 Pod 들의 securityContext 는 서로 다르고, 일부는 init 컨테이너를 쓴다. 호스트에 `jq` 가 있으면 편하다.

## Task

Containers in namespace `glacier` must be immutable at runtime.

1. Change Deployment `glacier-web` so that container `nginx` has a read-only root
   filesystem. nginx must still work: give it writable `emptyDir` volumes only at
   `/var/cache/nginx`, `/var/run` and `/tmp`. The Pods must be `Running` and Ready and answer
   HTTP requests on port `80`.
2. Write the output (stdout and stderr) of `touch /usr/share/nginx/html/hacked` executed in
   container `nginx` of a `glacier-web` Pod to `/opt/course/a17/web-write-test.txt`.
3. Find every other Pod in `glacier` that is not immutable, meaning that at least one of its
   containers or init containers runs privileged or does not have
   `readOnlyRootFilesystem: true`. Write their names, one per line and sorted
   alphabetically, to `/opt/course/a17/deleted.txt` and delete these Pods. Immutable Pods
   must keep running.

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

[↑ 문항 목록](../README.md) · [← q16](../q16_audit_policy_rules_apiserver/question.md)
