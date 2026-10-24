# q06 — Lock down an exposed admin UI

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q06_exposed_admin_ui_lockdown
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `ops` 에 관리 화면 역할을 하는 Deployment `admin-ui`(nginx, `hostNetwork: true`, ServiceAccount `admin-ui`)와 NodePort `30880` 의 Service `admin-ui` 가 있다.
ServiceAccount `admin-ui` 는 이름만 봐서는 알기 어려운 ClusterRoleBinding 을 통해 `cluster-admin` 권한을 갖고 있다.

## Task

The internal admin UI `admin-ui` in namespace `ops` is reachable from outside the cluster and runs
with far too many privileges. Lock it down:

1. Service `admin-ui` must only be reachable inside the cluster: type `ClusterIP`, port `80`.
2. ServiceAccount `ops/admin-ui` must not receive any permission through a ClusterRoleBinding
   anymore. Find and delete every ClusterRoleBinding that grants `cluster-admin` to this
   ServiceAccount, directly or through one of its groups. Do not delete other ClusterRoleBindings.
3. Create a Role `admin-ui-view` in `ops` that allows `get`, `list` and `watch` on `pods`,
   `services` and `configmaps`, and bind it to ServiceAccount `admin-ui` with a RoleBinding
   `admin-ui-view`.
4. Deployment `admin-ui` must no longer use the host network namespace. It keeps using
   ServiceAccount `admin-ui`.
5. ServiceAccount `default` in namespace `ops` must not have its token mounted automatically.
6. Write three lines to `/opt/course/c06/can-i.txt` with the answers (`yes`/`no`) of
   `kubectl auth can-i` as `system:serviceaccount:ops:admin-ui` for:
   `get secrets -n ops`, `list pods -n ops`, `delete nodes`.

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

[↑ 문항 목록](../README.md) · [← q05](../q05_rbac_dangerous_verbs_escalate_bind/question.md) · [q07 →](../q07_apparmor_seccomp_multicontainer/question.md)
