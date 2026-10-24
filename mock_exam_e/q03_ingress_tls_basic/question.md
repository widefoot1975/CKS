# q03 — Add TLS to an Ingress with a self-signed certificate

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q03_ingress_tls_basic
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `shop` 에 Deployment·Service `shop`(80 → 8080)과 HTTP 전용 Ingress `shop`(class `nginx`, host `shop.cks.local`)이 있다.
ingress-nginx 컨트롤러(`controller-v1.12.1`, NodePort)가 없으면 setup 이 설치하므로 인터넷 연결이 필요하다. 컨트롤러는 공용 구성요소라 `cleanup.sh` 가 지우지 않는다.

## Task

The shop Ingress must serve HTTPS for host `shop.cks.local`.

1. Create a self-signed certificate and private key for `shop.cks.local` with `openssl`
   (RSA 2048, valid 365 days, CN and subjectAltName `DNS:shop.cks.local`). Save them as
   `/opt/course/e03/shop.crt` and `/opt/course/e03/shop.key`.
2. Create a TLS Secret named `shop-tls` in namespace `shop` from these files.
3. Change Ingress `shop` so that host `shop.cks.local` is served over TLS with Secret `shop-tls`.
4. Request `https://shop.cks.local:<https NodePort>/` through the ingress-nginx controller,
   verifying the server certificate with `/opt/course/e03/shop.crt` (no `-k`), and write the
   response body to `/opt/course/e03/curl.txt`.

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

[↑ 문항 목록](../README.md) · [← q02](../q02_kubelet_anonymous_auth_disable/question.md) · [q04 →](../q04_clusterrole_readonly_user_can_i/question.md)
