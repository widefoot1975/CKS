# q05 — Remove dangerous RBAC permissions in a tenant namespace

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q05_rbac_dangerous_verbs_escalate_bind
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `tenant-x` 에 ServiceAccount `ci`, `auditor`, `ops`, `web` 과 Role 4개, 그리고 RoleBinding 으로 묶인 ClusterRole 2개(직접 만든 것 1개, 기본 제공 `view`)가 있다.
일부 규칙에 위험한 권한이 섞여 있다. `jq` 가 있으면 편하다.

## Task

The tenant namespace `tenant-x` collected risky RBAC rules. A rule is **dangerous** if it grants any
of the following:

- the verbs `escalate`, `bind` or `impersonate` (on any resource)
- any verb on `secrets` through the wildcard verb `*`
- the verb `create` on `pods/exec`

Consider all Roles in namespace `tenant-x` and every ClusterRole that is referenced by a
RoleBinding in `tenant-x`, but ignore the default ClusterRoles shipped with Kubernetes (`admin`,
`edit`, `view`, `cluster-admin` and `system:*`).

1. Write every Role / ClusterRole that contains at least one dangerous rule to
   `/opt/course/c05/dangerous.txt`, one per line in the form `Role/<name>` or `ClusterRole/<name>`,
   sorted alphabetically.
2. Remove the dangerous rules from those objects. All other rules must stay exactly as they are,
   and do not delete any Role, ClusterRole, RoleBinding or ServiceAccount.
3. Write the output of
   `kubectl auth can-i --list --as=system:serviceaccount:tenant-x:ops -n tenant-x` to
   `/opt/course/c05/ops-after.txt`.

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

[↑ 문항 목록](../README.md) · [← q04](../q04_kubeadm_worker_upgrade_patch/question.md) · [q06 →](../q06_exposed_admin_ui_lockdown/question.md)
