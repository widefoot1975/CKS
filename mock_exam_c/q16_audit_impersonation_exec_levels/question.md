# q16 — Audit impersonation and pods/exec

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q16_audit_impersonation_exec_levels
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 감사(audit) 로그는 꺼져 있고, kube-apiserver 원본 매니페스트는 `/opt/course/c16/backup/kube-apiserver.yaml` 에 백업되어 있다. namespace `c16` 에는
1분마다 실행되는 CronJob `sync`(ServiceAccount `robot`, 다른 사용자로 가장해 API 를 호출한다)와 Pod `shell` 이 있다. 이미 감사 로그가 설정된 클러스터면 setup 이 멈춘다.
`jq` 가 있으면 편하다. cleanup 은 매니페스트를 복구하고 `/etc/kubernetes/audit/`, `/var/log/kubernetes/audit/` 를 지운다.

## Task

Enable API auditing on the kube-apiserver of `cks-c1` and use it to investigate.

1. Create the audit policy `/etc/kubernetes/audit/policy.yaml` (`audit.k8s.io/v1`):
   - never generate events for the stage `RequestReceived`
   - log `pods/exec` and `pods/attach` requests in all namespaces at level `RequestResponse`
   - log every request made by any ServiceAccount of namespace `c16` at level `RequestResponse`,
     including requests in which such a ServiceAccount impersonates another user
   - do not log requests to the non-resource URLs `/healthz*`, `/livez*` and `/readyz*`
   - log everything else at level `Metadata`
2. Configure the kube-apiserver to use this policy and write the log to
   `/var/log/kubernetes/audit/audit.log`, rotating at `50` MB and keeping `2` old files.
3. When the kube-apiserver is running again, run `kubectl -n c16 exec shell -- id` and wait until
   CronJob `sync` has run at least once after auditing was enabled.
4. Find the audit event in which a request was made with impersonation. Write one line to
   `/opt/course/c16/impersonation.txt`:
   `user=<authenticated user> impersonated=<impersonated user> resource=<resource> namespace=<namespace>`
5. Write the `level` and the `requestURI` of the audit event of your `exec` request, one per line,
   to `/opt/course/c16/exec.txt`.

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

[↑ 문항 목록](../README.md) · [← q15](../q15_falco_macro_list_append_exceptions/question.md) · [q17 →](../q17_incident_privileged_hostpath_pod/question.md)
