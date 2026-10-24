# q05 — Lock down ServiceAccount tokens and use an audience-bound projected token

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q05_serviceaccount_automount_projected_token
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `ledger` 에는 SA `default` 로 도는 Deployment `ledger-api`(busybox)와 SA `monitor` 가 있다. 클러스터에는 `ledger` 와 관련된 ClusterRoleBinding 이 여러 개 있고, 그중 일부는 `cluster-admin` 을 준다. SA `ledger-api` 는 아직 없다.
호스트에 `jq` 가 있으면 편하다.

## Task

Workloads in namespace `ledger` have far too much API access.

1. Find every ClusterRoleBinding that grants ClusterRole `cluster-admin` to ServiceAccounts
   of namespace `ledger` (directly or through a group), delete them, and write their names,
   one per line and sorted alphabetically, to `/opt/course/a05/crb.txt`. Do not delete any
   other binding.
2. ServiceAccount `default` in `ledger` must no longer mount its token automatically.
3. Create ServiceAccount `ledger-api` in `ledger` that does not mount its token
   automatically.
4. Change Deployment `ledger-api` to use ServiceAccount `ledger-api`. Its Pods must not get
   the default API token mounted. Instead mount a projected ServiceAccount token in volume
   `vault-token` at `/var/run/secrets/vault` (read-only), file name `token`, audience `vault`,
   expiry `3600` seconds.
5. Write the `aud` claim of the token found in a running Pod at
   `/var/run/secrets/vault/token` to `/opt/course/a05/aud.txt`.

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

[↑ 문항 목록](../README.md) · [← q04](../q04_csr_user_least_privilege_role/question.md) · [q06 →](../q06_noderestriction_admission/question.md)
