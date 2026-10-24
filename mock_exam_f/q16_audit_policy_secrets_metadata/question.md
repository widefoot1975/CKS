# q16 — Audit Secret access at Metadata level

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q16_audit_policy_secrets_metadata
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 kube-apiserver 에는 감사 로그(audit) 설정이 없고, 원래 매니페스트가 `/opt/course/f16/backup/kube-apiserver.yaml` 에 백업되어 있다. namespace `f16` 에 Secret `api-key` 가 있다. `/etc/kubernetes/audit/policy.yaml` 은 아직 없다.
cleanup 은 백업한 매니페스트로 kube-apiserver 를 되돌리고 API 서버가 다시 뜰 때까지 기다린다.

## Task

The cluster must record who accesses Secrets, without writing Secret contents into the log.

1. Create the audit policy file `/etc/kubernetes/audit/policy.yaml` on `cks-c1`. It must not
   generate events for the `RequestReceived` stage, must log all requests on Secrets (core API
   group) at level `Metadata`, and must not log anything else.
2. Configure kube-apiserver to use this policy, to write the audit log to
   `/var/log/kubernetes/audit/audit.log` and to keep at most `2` rotated log files. Wait until the
   API server is available again.
3. Run `kubectl -n f16 get secret api-key`, then write one audit event (one JSON line) of exactly
   this request to `/opt/course/f16/event.json`.

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

[↑ 문항 목록](../README.md) · [← q15](../q15_falco_detect_write_below_etc/question.md) · [q17 →](../q17_delete_privileged_writable_pods/question.md)
