# q16 — Enable API server auditing with a given policy

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q16_audit_enable_given_policy
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 감사 정책 파일 `/etc/kubernetes/audit/d16-policy.yaml` 이 `cks-c1` 에 있지만 kube-apiserver 는 감사 로그를 남기지 않는다. 원본 매니페스트는 `/opt/course/d16/backup/kube-apiserver.yaml` 에 백업되어 있고 cleanup 이 이것으로 되돌린다.
kube-apiserver 에 이미 `--audit-policy-file` 이 있으면(다른 문제의 흔적) setup 이 멈추니 그 문제의 cleanup 을 먼저 실행한다.

## Task

Auditing is not enabled on the API server of this cluster. The audit policy has already been
written to `/etc/kubernetes/audit/d16-policy.yaml` on `cks-c1`. Do not change the policy.

1. Configure the kube-apiserver to use this policy and write the audit log to
   `/var/log/kubernetes/audit/audit.log`, keeping at most `2` rotated log files, each at most
   `10` MB.
2. When the API server is back, create a Secret `audit-probe` in namespace `default` with
   `kubectl create secret generic audit-probe --from-literal=k=v` and read it once with
   `kubectl get secret audit-probe`. Write all audit log lines that mention `audit-probe` to
   `/opt/course/d16/probe.log`.

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

[↑ 문항 목록](../README.md) · [← q15](../q15_falco_shell_alert_delete_pod/question.md) · [q17 →](../q17_readonly_rootfs_pod/question.md)
