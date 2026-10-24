# q04 — Least-privilege Role for a ServiceAccount

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q04_role_rolebinding_sa_least_privilege
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `jade` 에 ServiceAccount `reporter` 와 Pod 두 개가 있다. `reporter` 는 어떤 RoleBinding 을 통해 ClusterRole `edit` 권한을 갖고 있다(이름은 직접 찾는다).

## Task

ServiceAccount `reporter` in namespace `jade` only needs to read Pods in its own namespace, but
it currently has far more permissions.

1. Find and delete the RoleBinding in namespace `jade` that grants `reporter` its current
   permissions.
2. Create a Role `pod-reader` in namespace `jade` that allows only the verbs `get`, `list` and
   `watch` on `pods`, and bind it to `reporter` with a RoleBinding `reporter-pod-reader`.
3. Using `kubectl auth can-i` as `reporter`, check the four requests below and write one answer
   (`yes` or `no`) per line, in this order, to `/opt/course/d04/can-i.txt`:
   `list pods -n jade`, `delete pods -n jade`, `get secrets -n jade`, `list pods -n default`.

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

[↑ 문항 목록](../README.md) · [← q03](../q03_verify_kubectl_sha512/question.md) · [q05 →](../q05_sa_automount_false/question.md)
