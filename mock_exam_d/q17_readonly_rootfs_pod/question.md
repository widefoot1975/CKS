# q17 — Read-only root filesystem for an nginx Deployment

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 8 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q17_readonly_rootfs_pod
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `pearl` 에 Deployment `cache`(`nginx:1.27-alpine`, replicas 1)가 돈다. 컨테이너 이름은 `nginx` 이고 `securityContext` 와 볼륨이 없어서 루트 파일시스템에 쓸 수 있다.

## Task

An attacker who gets into a container should not be able to change its files. Make the
container of Deployment `cache` in namespace `pearl` immutable.

1. Set `readOnlyRootFilesystem: true` on container `nginx` of Deployment `cache`.
2. nginx still needs to write to `/var/cache/nginx` and `/var/run`. Mount an `emptyDir`
   volume at each of these two paths. The Deployment's Pod must be `Running` and Ready.
3. Run `kubectl -n pearl exec deploy/cache -- touch /usr/share/nginx/html/hacked.html` and write
   its complete output (stdout and stderr) to `/opt/course/d17/touch.txt`.

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

[↑ 문항 목록](../README.md) · [← q16](../q16_audit_enable_given_policy/question.md)
