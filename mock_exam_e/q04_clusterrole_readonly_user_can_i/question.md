# q04 — Read-only ClusterRole for a user, checked with can-i

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q04_clusterrole_readonly_user_can_i
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 ClusterRole `e04-readonly` 와 ClusterRoleBinding `e04-readonly-audit-joe` 는 없고, 사용자 `audit-joe` 에게는 아무 권한도 없다.
사용자 인증서는 만들지 않는다. 권한 확인은 관리자 kubeconfig 에서 `--as audit-joe`(impersonation)로 한다.

## Task

User `audit-joe` from the audit team needs cluster-wide read-only access to a few resource
types, and nothing else.

1. Create a ClusterRole named `e04-readonly` that allows only the verbs `get`, `list` and
   `watch` on `pods`, `services`, `namespaces` and `deployments` (API group `apps`).
2. Bind it to user `audit-joe` cluster-wide with a ClusterRoleBinding named
   `e04-readonly-audit-joe`.
3. Run the following checks and write the four answers (`yes`/`no`), one per line in this
   order, to `/opt/course/e04/can-i.txt`:
   - `kubectl auth can-i list pods -A --as audit-joe`
   - `kubectl auth can-i get deployments.apps -n kube-system --as audit-joe`
   - `kubectl auth can-i delete pods -n default --as audit-joe`
   - `kubectl auth can-i list secrets -A --as audit-joe`

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

[↑ 문항 목록](../README.md) · [← q03](../q03_ingress_tls_basic/question.md) · [q05 →](../q05_create_token_duration_audience/question.md)
