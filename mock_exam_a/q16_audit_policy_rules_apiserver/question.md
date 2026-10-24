# q16 — Audit policy with ordered rules and log rotation

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q16_audit_policy_rules_apiserver
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 kube-apiserver 에는 감사(audit) 로그 설정이 없고, namespace `prod` 에 Pod `prod-web`, Secret `prod-db`, ConfigMap `prod-cfg` 가 있다. 원본 매니페스트는 `/opt/course/a16/backup/` 에 있고 `cleanup.sh` 가 되돌린다. 호스트에 `jq` 가 있으면 편하다.

## Task

Enable API audit logging on cluster `cks-c1`.

1. Create the audit policy `/etc/kubernetes/audit/policy.yaml` with these requirements:
   - do not create events for the stage `RequestReceived`
   - `get`, `list` and `watch` requests on `nodes` are not logged at all
   - `secrets` and `configmaps` are logged at level `Metadata` in every namespace,
     including `prod`
   - `pods` in namespace `prod` are logged at level `RequestResponse`
   - every other request in namespace `prod` is logged at level `Request`
   - everything else is logged at level `Metadata`
2. Configure the kube-apiserver to use this policy and to write the log to
   `/var/log/kubernetes/audit/audit.log`, keeping at most `2` old log files and deleting them
   after `7` days. The kube-apiserver must be running and healthy afterwards.
3. Run `kubectl -n prod get secret prod-db` and write the audit event of this request (one
   JSON line) to `/opt/course/a16/secret-event.json`.
4. Run `kubectl -n prod label pod prod-web audited=yes` and write the audit event of this
   request (one JSON line) to `/opt/course/a16/pod-event.json`.

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

[↑ 문항 목록](../README.md) · [← q15](../q15_falco_custom_rule_shell_output/question.md) · [q17 →](../q17_immutable_readonly_rootfs_emptydir/question.md)
