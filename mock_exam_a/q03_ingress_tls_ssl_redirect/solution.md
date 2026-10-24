# q03 — TLS Ingress with a SAN certificate and a forced HTTPS redirect · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Expose Service `shop-web` in namespace `shop` over HTTPS only, for host `shop.a03.test`.
>
> 1. With `openssl`, create a self-signed certificate valid for `365` days with an RSA `2048`
>    key. Subject `CN=shop.a03.test`, and the certificate must contain the Subject Alternative
>    Name `DNS:shop.a03.test`. Write the key to `/opt/course/a03/tls.key` and the certificate to
>    `/opt/course/a03/tls.crt`.
> 2. Create a TLS Secret `shop-tls` from these files in namespace `shop`.
> 3. Create an Ingress `shop` in namespace `shop` with IngressClass `nginx` that routes path
>    `/` (Prefix) of host `shop.a03.test` to Service `shop-web` port `80`, terminates TLS with
>    Secret `shop-tls`, and always redirects plain HTTP to HTTPS using the ingress-nginx
>    annotation for a forced redirect.
> 4. Write the HTTP status code and the redirect URL returned for `http://shop.a03.test/`
>    (via the HTTP NodePort) to `/opt/course/a03/http.txt`, in the form `<code> <url>`.
> 5. Request `https://shop.a03.test/` via the HTTPS NodePort, verifying the server certificate
>    with `/opt/course/a03/tls.crt` (do not use `-k`), and write the response body to
>    `/opt/course/a03/https.txt`.

**해석**

namespace `shop` 의 Service `shop-web` 을 호스트 `shop.a03.test` 에 대해 HTTPS 로만 노출한다.

1. `openssl` 로 365일짜리 자체 서명 인증서(RSA 2048)를 만든다. Subject 는 `CN=shop.a03.test`, SAN 에 `DNS:shop.a03.test` 가 들어가야 한다.
   키는 `/opt/course/a03/tls.key`, 인증서는 `/opt/course/a03/tls.crt`.
2. 이 파일로 `shop` 에 TLS Secret `shop-tls` 를 만든다.
3. `shop` 에 IngressClass `nginx` 를 쓰는 Ingress `shop` 을 만든다. 호스트 `shop.a03.test` 의 경로 `/`(Prefix)를 `shop-web:80` 으로 보내고,
   `shop-tls` 로 TLS 를 종료하며, ingress-nginx 의 **강제** 리다이렉트 어노테이션으로 HTTP 를 항상 HTTPS 로 돌린다.
4. HTTP NodePort 로 `http://shop.a03.test/` 를 요청했을 때의 상태 코드와 리다이렉트 URL 을 `<code> <url>` 형식으로 `/opt/course/a03/http.txt` 에 쓴다.
5. HTTPS NodePort 로 `https://shop.a03.test/` 를 `-k` 없이 `/opt/course/a03/tls.crt` 로 검증하며 요청하고, 응답 본문을 `/opt/course/a03/https.txt` 에 쓴다.

## 모범 풀이

**1) SAN 이 들어간 자체 서명 인증서**

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /opt/course/a03/tls.key -out /opt/course/a03/tls.crt \
  -subj "/CN=shop.a03.test" -addext "subjectAltName=DNS:shop.a03.test"
openssl x509 -in /opt/course/a03/tls.crt -noout -subject -ext subjectAltName -enddate
# subject=CN=shop.a03.test
# X509v3 Subject Alternative Name:
#     DNS:shop.a03.test
```

요즘 TLS 클라이언트(curl/OpenSSL, 브라우저, Go)는 호스트 이름을 **SAN 으로만** 검사하고 CN 은 무시합니다. `-addext` 를 빼면 `-k` 로는
되는데 `--cacert` 로 검증하면 `no alternative certificate subject name matches` 로 실패합니다. `-addext` 는 OpenSSL 1.1.1 이상에서 됩니다.

**2) TLS Secret — Ingress 와 같은 namespace**

```bash
kubectl -n shop create secret tls shop-tls --cert=/opt/course/a03/tls.crt --key=/opt/course/a03/tls.key
kubectl -n shop get secret shop-tls -o jsonpath='{.type}{"\n"}'       # kubernetes.io/tls (키: tls.crt, tls.key)
```

**3) Ingress**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop
  namespace: shop
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"     # 문자열 "true" (따옴표 필수)
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - shop.a03.test
    secretName: shop-tls
  rules:
  - host: shop.a03.test
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shop-web
            port:
              number: 80
```

```bash
kubectl apply -f shop-ingress.yaml
kubectl -n shop describe ingress shop | grep -A3 TLS       # shop-tls terminates shop.a03.test
```

| 어노테이션 | 기본값 | 의미 |
|---|---|---|
| `nginx.ingress.kubernetes.io/ssl-redirect` | `true` (TLS 가 있을 때) | `tls` 절이 있는 호스트만 HTTPS 로 리다이렉트 |
| `nginx.ingress.kubernetes.io/force-ssl-redirect` | `false` | TLS 절이 없거나 TLS 를 앞단 LB 가 종료해도 **항상** 리다이렉트 |

`tls` 절이 있으면 ingress-nginx 는 기본으로도 308 을 돌려주지만, 문제는 강제 리다이렉트 어노테이션을 요구합니다. 어노테이션 값은
YAML 에서 불리언이 아니라 **문자열**이어야 하므로 `"true"` 로 씁니다(따옴표가 없으면 `kubectl apply` 가 타입 오류를 냅니다).

**4) · 5) 확인과 기록**

```bash
NP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
NPS=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
NODE=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' -H 'Host: shop.a03.test' http://$NODE:$NP/ > /opt/course/a03/http.txt
cat /opt/course/a03/http.txt                      # 308 https://shop.a03.test/

curl -s --cacert /opt/course/a03/tls.crt --resolve shop.a03.test:$NPS:$NODE https://shop.a03.test:$NPS/ > /opt/course/a03/https.txt
cat /opt/course/a03/https.txt                     # shop-ok
```

`--resolve 호스트:포트:IP` 는 DNS 없이 이름을 IP 에 고정하므로, TLS SNI 와 인증서 이름 검사가 모두 `shop.a03.test` 로 이루어집니다.
`-H 'Host: …'` 만 쓰면 SNI 가 IP 로 나가서 ingress-nginx 가 기본 가짜 인증서(`Kubernetes Ingress Controller Fake Certificate`)를 줍니다.
리다이렉트 URL 은 표준 포트 443 을 가리키므로 NodePort 환경에서는 `-L` 로 따라가지 말고 코드와 URL 만 기록합니다.

## 검증

```bash
cat /opt/course/a03/http.txt /opt/course/a03/https.txt        # 308 https://shop.a03.test/ , shop-ok
openssl s_client -connect $NODE:$NPS -servername shop.a03.test </dev/null 2>/dev/null | openssl x509 -noout -subject
# subject=CN=shop.a03.test   (가짜 인증서가 아님)
kubectl -n shop get ingress shop -o jsonpath='{.metadata.annotations}{"\n"}'
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=20 | grep -i shop-tls   # Secret 오류가 없어야 한다
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `openssl req -x509 -nodes -newkey rsa:2048 -days 365 -subj "/CN=h" -addext "subjectAltName=DNS:h"` → `kubectl create secret tls` → Ingress `tls.hosts` + `secretName`. 검증은 `--resolve` + `--cacert`.
- **헷갈리는 지점**: Secret 은 Ingress 와 **같은 namespace** 에 있어야 하고, 이름·키가 틀리면 에러 없이 가짜 인증서로 대체됩니다. 리다이렉트 코드는 ingress-nginx 기본 308(메서드 유지)입니다. 어노테이션 값은 문자열입니다.

## 참고 문서

openssl 은 `openssl req -help` 로 옵션을 확인합니다.

- 검색어: `ingress tls`, `force-ssl-redirect`, `kubectl create secret tls`
- https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
- https://kubernetes.github.io/ingress-nginx/user-guide/tls/
- https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q04 →](../q04_csr_user_least_privilege_role/question.md)
