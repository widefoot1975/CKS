# q03 — TLS Ingress with a SAN certificate and a forced HTTPS redirect

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q03_ingress_tls_ssl_redirect
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 클러스터에는 ingress-nginx(`controller-v1.12.1` baremetal 매니페스트, IngressClass `nginx`, NodePort Service `ingress-nginx-controller`)가 있다. 없을 때만 설치하므로 처음에는 인터넷이 필요하다.
namespace `shop` 에는 Service `shop-web`(포트 `80`, 응답 `shop-ok`)이 있고, 인증서·TLS Secret·Ingress 는 없다. 호스트에 `openssl` 이 있어야 한다.
컨트롤러는 NodePort 이므로 아래처럼 `<노드IP>:<NodePort>` 로 curl 한다.

```bash
NP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
NPS=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
NODE=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
```

## Task

Expose Service `shop-web` in namespace `shop` over HTTPS only, for host `shop.a03.test`.

1. With `openssl`, create a self-signed certificate valid for `365` days with an RSA `2048`
   key. Subject `CN=shop.a03.test`, and the certificate must contain the Subject Alternative
   Name `DNS:shop.a03.test`. Write the key to `/opt/course/a03/tls.key` and the certificate to
   `/opt/course/a03/tls.crt`.
2. Create a TLS Secret `shop-tls` from these files in namespace `shop`.
3. Create an Ingress `shop` in namespace `shop` with IngressClass `nginx` that routes path
   `/` (Prefix) of host `shop.a03.test` to Service `shop-web` port `80`, terminates TLS with
   Secret `shop-tls`, and always redirects plain HTTP to HTTPS using the ingress-nginx
   annotation for a forced redirect.
4. Write the HTTP status code and the redirect URL returned for `http://shop.a03.test/`
   (via the HTTP NodePort) to `/opt/course/a03/http.txt`, in the form `<code> <url>`.
5. Request `https://shop.a03.test/` via the HTTPS NodePort, verifying the server certificate
   with `/opt/course/a03/tls.crt` (do not use `-k`), and write the response body to
   `/opt/course/a03/https.txt`.

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

[↑ 문항 목록](../README.md) · [← q02](../q02_cis_kube_bench_apiserver_kubelet/question.md) · [q04 →](../q04_csr_user_least_privilege_role/question.md)
