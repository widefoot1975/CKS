# q05 — Disable token automount on the default ServiceAccount

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q05_sa_default_automount_off_dedicated_sa
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `hr` 에 Deployment `hr-portal`(curl)과 `hr-static`(nginx)이 있고, 둘 다 ServiceAccount `default` 를 쓰며 토큰이 마운트되어 있다. Role `portal-api` 와 이를 ServiceAccount `hr-portal-sa` 에 묶는 RoleBinding 이 이미 있지만, `hr-portal-sa` 자체는 아직 없다. `/opt/course/f05/` 는 비어 있다.

## Task

In namespace `hr`, only Deployment `hr-portal` talks to the Kubernetes API. No other Pod in the
namespace should get an API token by default.

1. Configure ServiceAccount `default` in namespace `hr` so that its token is not mounted into Pods
   automatically.
2. Create ServiceAccount `hr-portal-sa` in namespace `hr` and change Deployment `hr-portal` to use
   it. Pods of `hr-portal` must still get a token mounted.
3. Make sure all Pods of both Deployments run with the new settings. Then, from a Pod of
   `hr-portal`, list the Pods of namespace `hr` through the API with the mounted token and write
   only the HTTP status code to `/opt/course/f05/api-code.txt`.

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

[↑ 문항 목록](../README.md) · [← q04](../q04_remove_wildcard_rbac_rule/question.md) · [q06 →](../q06_csr_approve_user_kubeconfig/question.md)
