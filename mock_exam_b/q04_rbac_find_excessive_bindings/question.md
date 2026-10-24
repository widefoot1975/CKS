# q04 — Find and replace excessive RBAC bindings

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q04_rbac_find_excessive_bindings
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `apps` 에 ServiceAccount `web`, `worker`, `reporter` 가 있고, 이들에게 권한을 주는 RoleBinding·ClusterRoleBinding 이 여러 개 만들어져 있다(그중 일부는 과도하다). namespace `observe` 에도 관련 없는 바인딩이 하나 있다.

## Task

The ServiceAccounts of namespace `apps` have collected too many permissions.

1. Find every RoleBinding and ClusterRoleBinding in the cluster that grants a ServiceAccount of
   namespace `apps` (as a subject directly **or through a group**) either the ClusterRole
   `cluster-admin` or a Role/ClusterRole that contains the verb `*`. Write them to
   `/opt/course/b04/excessive.txt`, one per line, as `<Kind>/<namespace>/<name>` (use `-` as the
   namespace of a ClusterRoleBinding), e.g. `RoleBinding/apps/foo`.
2. Delete these bindings. Also delete the custom Roles/ClusterRoles they referenced (never delete
   built-in ClusterRoles such as `cluster-admin`). Do not touch other bindings.
3. Create a Role `configmap-reader` in namespace `apps` that allows only `get` and `list` on
   `configmaps`, and a RoleBinding `configmap-reader` that grants it to the ServiceAccounts `web`
   and `worker` of namespace `apps`.
4. Write the output of
   `kubectl auth can-i --list -n apps --as=system:serviceaccount:apps:worker` to
   `/opt/course/b04/worker-can-i.txt`. It must not contain the verb `*` anywhere.

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

[↑ 문항 목록](../README.md) · [← q03](../q03_verify_platform_binaries_sha512/question.md) · [q05 →](../q05_sa_legacy_token_cleanup/question.md)
