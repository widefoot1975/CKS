# q04 — Remove a wildcard rule from a Role

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q04_remove_wildcard_rbac_rule
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `finance` 에 ServiceAccount `finance-app`, Role 두 개와 RoleBinding 두 개가 있고, 그중 하나의 Role 에 모든 API 그룹·리소스·동사를 허용하는 규칙이 섞여 있다. `/opt/course/f04/` 는 비어 있다.

## Task

ServiceAccount `finance-app` in namespace `finance` only needs to read ConfigMaps and
Deployments, but it is currently able to delete Secrets.

1. Find the Role in namespace `finance` that gives `finance-app` this access and write its name to
   `/opt/course/f04/role.txt`.
2. Edit that Role and remove only the rule that uses wildcards (`*`). Keep its other rules and do
   not change or delete any RoleBinding.
3. Write the output of
   `kubectl auth can-i --list -n finance --as=system:serviceaccount:finance:finance-app` to
   `/opt/course/f04/can-i.txt`. `finance-app` must no longer be able to delete Secrets, but must
   still be able to list ConfigMaps and Deployments.

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

[↑ 문항 목록](../README.md) · [← q03](../q03_ingress_tls_wrong_secret_name/question.md) · [q05 →](../q05_sa_default_automount_off_dedicated_sa/question.md)
