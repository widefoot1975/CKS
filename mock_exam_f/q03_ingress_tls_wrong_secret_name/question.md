# q03 — Fix an Ingress that serves the wrong TLS certificate

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q03_ingress_tls_wrong_secret_name
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `shop` 에 Deployment·Service `shop-web`(http-echo), TLS Secret 하나, Ingress `shop`(host `shop.cks.local`)이 있다. 지금 `https://shop.cks.local` 로 접속하면 ingress-nginx 의 기본 인증서(`Kubernetes Ingress Controller Fake Certificate`)가 나온다.
Secret 에 들어 있는 인증서와 같은 파일이 `/opt/course/f03/tls.crt` 에 있다. ingress-nginx(`controller-v1.12.1`, NodePort)가 없으면 setup 이 설치하므로 인터넷 연결이 필요하다. ingress-nginx 는 공용 인프라라 정리할 때 지우지 않는다.

## Task

Ingress `shop` in namespace `shop` is configured for TLS, but clients receive the ingress
controller's default certificate instead of the certificate for `shop.cks.local`.

1. Find out why, and fix Ingress `shop` so that it uses the TLS Secret that already exists in
   namespace `shop`. Do not create, modify or delete any Secret.
2. Connect to the ingress-nginx controller's HTTPS NodePort on node `cks-c1` with SNI
   `shop.cks.local` and write the subject of the presented certificate (as printed by
   `openssl x509 -noout -subject`) to `/opt/course/f03/subject.txt`.
3. Request `https://shop.cks.local/` through the same NodePort, trusting only
   `/opt/course/f03/tls.crt` (no `-k`), and write the response body to `/opt/course/f03/curl.txt`.

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

[↑ 문항 목록](../README.md) · [← q02](../q02_cis_static_pod_manifest_permissions/question.md) · [q04 →](../q04_remove_wildcard_rbac_rule/question.md)
