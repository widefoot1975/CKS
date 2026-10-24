# q03 — Repair a broken TLS Ingress

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q03_ingress_tls_fix_secret_host
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `store` 에 Deployment·Service `shopfront` 와 Ingress `store`(host `store.cks.local`)가 있다. Ingress 의 TLS 는 Secret `store-tls` 를 가리키지만
그 Secret 은 namespace `default` 에 `Opaque` 타입(키 `cert`, `key`, CN `wrong.cks.local`)으로 잘못 만들어져 있고, `tls.hosts` 도 rule 의 host 와 다르다.
그래서 HTTPS 로 접속하면 ingress-nginx 의 기본 인증서(Fake Certificate)가 나온다. `cks-c1` 에 `openssl` 이 있어야 한다.
ingress-nginx(`controller-v1.12.1`, baremetal NodePort)가 없으면 setup 이 설치하므로 인터넷 연결이 필요하며, 정리할 때 지우지 않는다.

## Task

HTTPS for Ingress `store` in namespace `store` (host `store.cks.local`) is broken: clients receive
the controller's default certificate.

1. Create a new RSA 2048-bit private key `/opt/course/c03/store.key` and a self-signed certificate
   `/opt/course/c03/store.crt`, valid for 365 days, with subject `CN=store.cks.local` and the
   Subject Alternative Name `DNS:store.cks.local`.
2. Store them in a Secret named `store-tls` of type `kubernetes.io/tls` in namespace `store`.
   Delete the misplaced Secret `store-tls` in namespace `default`.
3. Fix the `tls` section of Ingress `store` so that host `store.cks.local` is served with Secret
   `store-tls`. Do not change the rules of the Ingress.
4. Connect to the HTTPS NodePort of Service `ingress-nginx/ingress-nginx-controller` on the
   InternalIP of `cks-c1-w1` with SNI `store.cks.local`, and write the certificate's subject and
   Subject Alternative Name (output of `openssl x509 -noout -subject -ext subjectAltName`) to
   `/opt/course/c03/cert.txt`.

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

[↑ 문항 목록](../README.md) · [← q02](../q02_kubelet_config_hardening/question.md) · [q04 →](../q04_kubeadm_worker_upgrade_patch/question.md)
