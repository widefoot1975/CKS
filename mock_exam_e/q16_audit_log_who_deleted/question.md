# q16 — Find who deleted a ConfigMap in the audit log

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q16_audit_log_who_deleted
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 kube-apiserver 가 감사 로그를 `/var/log/kubernetes/audit/audit.log` 에 쓰고 있다(정책 `/etc/kubernetes/audit/e16-policy.yaml`, Metadata 수준, `RequestReceived` 생략).
setup 이 namespace `billing` 에서 여러 ServiceAccount 로 ConfigMap 을 읽고 지우는 요청을 보냈고, 지금 `billing` 에는 ConfigMap `app-config` 와 `old-config` 가 없다.
원본 kube-apiserver 매니페스트는 `/opt/course/e16/backup/` 에 있고 `cleanup.sh` 가 복구한다. `jq` 를 쓸 수 있다.

## Task

ConfigMap `app-config` in namespace `billing` has disappeared. Use the audit log
`/var/log/kubernetes/audit/audit.log` on `cks-c1` to investigate.

1. Find the audit event of the request that deleted ConfigMap `app-config` in namespace
   `billing`. Write the username that made the request to `/opt/course/e16/user.txt`.
2. Write the `requestReceivedTimestamp` of this event to `/opt/course/e16/time.txt`.
3. Write the total number of `delete` requests for ConfigMaps in namespace `billing` that
   are recorded in the log to `/opt/course/e16/deletes.txt`.

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

[↑ 문항 목록](../README.md) · [← q15](../q15_falco_rule_output_change/question.md) · [q17 →](../q17_crictl_find_root_container/question.md)
