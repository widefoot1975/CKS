# q17 — Investigate a privileged hostPath Pod

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 8 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q17_incident_privileged_hostpath_pod
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

setup 은 kube-apiserver 원본 매니페스트를 `/opt/course/c17/backup/` 에 백업한 뒤 감사 로그(`/var/log/kubernetes/audit/audit.log`)를 켜고, namespace `marketing` 에서
사고 상황을 재현한다. 설정 직후 `marketing` 에는 정상 Deployment `campaign-web` 과, 어떤 ServiceAccount 가 API 로 직접 만든 수상한 Pod 하나가 실행 중이다.
이미 감사 로그가 설정된 클러스터면 setup 이 멈춘다(q16 을 풀었다면 q16 의 `cleanup.sh` 를 먼저 실행). cleanup 은 매니페스트를 복구하고 감사 설정·로그와 워커에 남은 파일을 지운다.
`jq` 가 있으면 편하다.

## Task

A monitoring alert reports a Pod in namespace `marketing` that runs privileged with access to the
host. API auditing is enabled; the log is `/var/log/kubernetes/audit/audit.log` on `cks-c1`.

1. **Identify.** Write the following lines (`key=value`, in this order) to `/opt/course/c17/report.txt`:
   - `pod=<name of the Pod>`
   - `node=<node the Pod runs on>`
   - `creator=<username that created the Pod, as recorded in the audit log>`
   - `created=<requestReceivedTimestamp of the audit event that created the Pod>`
   - `sourceip=<first source IP of that request>`
   - `hostfile=<absolute path on the node of the file the Pod wrote to the host filesystem>`
2. **Contain.** Delete the Pod and the workload object that created it. Remove the creator's
   permission to create Pods in `marketing` by deleting the RoleBinding that grants it. Keep the
   ServiceAccount itself.
3. **Eradicate.** Delete the file the Pod wrote on the node.
4. **Prevent.** Label namespace `marketing` so that Pod Security Admission enforces the `baseline`
   standard (version `latest`) and warns on `restricted`. Deployment `campaign-web` must keep
   running. Prove that the malicious Pod would now be rejected with a server-side dry run of its
   manifest, and save the output to `/opt/course/c17/dry-run.txt`.

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

[↑ 문항 목록](../README.md) · [← q16](../q16_audit_impersonation_exec_levels/question.md)
