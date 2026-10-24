# q05 — Stop mounting the ServiceAccount token

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q05_sa_automount_false
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `opal` 에 비교용 Pod `legacy` 가 있고, 이 Pod 에는 `default` ServiceAccount 토큰이 `/var/run/secrets/kubernetes.io/serviceaccount` 에 마운트되어 있다.
ServiceAccount `backend` 와 Pod `backend` 는 아직 없다.

## Task

The `backend` application in namespace `opal` never talks to the Kubernetes API, so it must not
receive an API token.

1. Create a ServiceAccount `backend` in namespace `opal` with `automountServiceAccountToken`
   set to `false`.
2. Create a Pod `backend` in namespace `opal` with image `nginx:1.27-alpine` that uses
   ServiceAccount `backend`. Also set `automountServiceAccountToken: false` in the Pod spec.
3. Run `kubectl -n opal exec backend -- ls /var/run/secrets/kubernetes.io/serviceaccount` and
   write its complete output (stdout and stderr) to `/opt/course/d05/token.txt`.

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

[↑ 문항 목록](../README.md) · [← q04](../q04_role_rolebinding_sa_least_privilege/question.md) · [q06 →](../q06_anonymous_rbac_binding_remove/question.md)
