# q06 — Allow anonymous access only to health endpoints

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q06_anonymous_auth_health_endpoints_only
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 kube-apiserver 매니페스트에는 `--anonymous-auth=true` 가 명시돼 있고, ClusterRoleBinding `anon-ns-reader` 가 `system:anonymous` 에게 namespaces 조회 권한을 준다. 그래서 인증서 없이 `curl -k https://<cks-c1 IP>:6443/api/v1/namespaces` 가 `200` 이다.
원본 매니페스트는 `/opt/course/b06/backup/kube-apiserver.yaml` 에 있고 cleanup 이 되돌린다.

## Task

Anonymous requests to the kube-apiserver on `cks-c1` are currently accepted for every path.
Anonymous access must stay possible for health checks only.

1. Create the file `/etc/kubernetes/authn/authentication-config.yaml` containing an
   `AuthenticationConfiguration` that enables anonymous authentication only for the paths
   `/livez`, `/readyz` and `/healthz`.
2. Configure the kube-apiserver to use this file with `--authentication-config`. The
   kube-apiserver must not have the `--anonymous-auth` flag any more. The kube-apiserver must be
   running and healthy afterwards.
3. Delete the ClusterRoleBinding `anon-ns-reader` and the ClusterRole `anon-ns-reader`.
4. Without any credentials, request `/livez`, `/readyz`, `/version` and `/api/v1/namespaces` on
   `https://<cks-c1 InternalIP>:6443` and write one line per path in the form `<path> <http_code>`
   to `/opt/course/b06/codes.txt`, in this order.

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

[↑ 문항 목록](../README.md) · [← q05](../q05_sa_legacy_token_cleanup/question.md) · [q07 →](../q07_seccomp_localhost_profile_audit_to_errno/question.md)
