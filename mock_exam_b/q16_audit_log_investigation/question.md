# q16 — Investigate the audit log and reduce its noise

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q16_audit_log_investigation
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 kube-apiserver 는 감사 정책 `/etc/kubernetes/audit/policy.yaml`(모든 요청 `Metadata`)로 `/var/log/kubernetes/audit/audit.log` 에 감사 로그를 쓰고 있다. setup 이 그 사이에 namespace `finance` 에서 여러 사용자·ServiceAccount 로 ConfigMap 삭제, Secret 조회 같은 활동을 일으켜 두었다(활동에 쓴 Pod 와 인증서는 이미 지웠다).
원본 매니페스트는 `/opt/course/b16/backup/kube-apiserver.yaml` 에 있고 cleanup 이 되돌린다. 이미 감사 로그가 켜진 클러스터라면 setup 은 멈추므로 다른 문항의 cleanup 을 먼저 실행한다. `jq` 가 없으면 setup 이 설치한다.

## Task

Audit logging is enabled on the kube-apiserver of `cks-c1`; the log is
`/var/log/kubernetes/audit/audit.log` and the policy is `/etc/kubernetes/audit/policy.yaml`.
Something happened in namespace `finance`.

1. Answer the following questions from the audit log and write the answers to
   `/opt/course/b16/answers.txt` in exactly this format:
   ```
   configmap_deleted_by: <username>
   secrets_listed_by: <username>
   secrets_listed_from: <source IP>
   ```
   - Which user deleted the ConfigMap `app-config` in namespace `finance`?
   - Which ServiceAccount listed the Secrets of namespace `finance` (a `list` request on the
     Secrets of that namespace, not a `get` of a single Secret)? Give its full username.
   - From which source IP did that ServiceAccount send the request?
2. The log is too noisy. Change the audit policy so that `watch` requests made by the users
   `system:kube-proxy` and `system:serviceaccount:kube-system:cilium` are no longer logged, while
   everything else is still logged as before. Make sure the running kube-apiserver uses the new
   policy and is healthy.

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

[↑ 문항 목록](../README.md) · [← q15](../q15_falco_investigate_existing_alerts/question.md) · [q17 →](../q17_crictl_find_malicious_process/question.md)
