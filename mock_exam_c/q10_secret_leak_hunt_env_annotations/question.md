# q10 — Hunt down leaked secret values

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q10_secret_leak_hunt_env_annotations
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `billing` 에 ConfigMap `app-config`, `kubectl apply` 로 만든 Secret `billing-db`, Deployment `billing-api` 가 있다.
비밀번호 `Pa55-billing-2025` 와 토큰 `tok-7f3a9c` 가 여러 객체에 평문으로 흩어져 있다.

## Task

The database password `Pa55-billing-2025` and the API token `tok-7f3a9c` of the `billing`
application leaked into several objects in namespace `billing`.

1. Check all ConfigMaps, Secrets and Deployments in namespace `billing` for these two values in
   **plain text** (not base64-encoded). Write every object that contains at least one of them to
   `/opt/course/c10/findings.txt`, one per line as `<kind>/<name>` in lowercase (for example
   `configmap/foo`), sorted.
2. Rotate the credentials: Secret `billing-db` must contain the keys `DB_PASSWORD` with value
   `R0tated-billing-2026` and `API_TOKEN` with value `tok-rotated-2026`. No field or annotation of
   the Secret may contain a credential in plain text.
3. Change Deployment `billing-api` so that it no longer receives the credentials as environment
   variables. Mount Secret `billing-db` as a read-only volume at `/etc/billing/secrets` instead.
   `DB_HOST` must still come from ConfigMap `app-config`.
4. Remove the key `DB_PASSWORD` from ConfigMap `app-config`.
5. Afterwards,
   `kubectl -n billing get all,configmap,secret -o yaml | grep -cE 'Pa55-billing-2025|tok-7f3a9c'`
   must print `0`, and the running Pod must be able to read
   `/etc/billing/secrets/DB_PASSWORD`.

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

[↑ 문항 목록](../README.md) · [← q09](../q09_vap_tenant_pod_security/question.md) · [q11 →](../q11_cilium_wireguard_encryption/question.md)
