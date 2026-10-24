# q03 — Add TLS to an Ingress with a self-signed certificate · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The shop Ingress must serve HTTPS for host `shop.cks.local`.
>
> 1. Create a self-signed certificate and private key for `shop.cks.local` with `openssl`
>    (RSA 2048, valid 365 days, CN and subjectAltName `DNS:shop.cks.local`). Save them as
>    `/opt/course/e03/shop.crt` and `/opt/course/e03/shop.key`.
> 2. Create a TLS Secret named `shop-tls` in namespace `shop` from these files.
> 3. Change Ingress `shop` so that host `shop.cks.local` is served over TLS with Secret `shop-tls`.
> 4. Request `https://shop.cks.local:<https NodePort>/` through the ingress-nginx controller,
>    verifying the server certificate with `/opt/course/e03/shop.crt` (no `-k`), and write the
>    response body to `/opt/course/e03/curl.txt`.

**해석**

shop Ingress 가 host `shop.cks.local` 에 대해 HTTPS 를 제공해야 한다.

1. `openssl` 로 `shop.cks.local` 용 자체 서명 인증서와 개인키를 만든다(RSA 2048, 365일, CN 과 subjectAltName `DNS:shop.cks.local`).
   `/opt/course/e03/shop.crt`, `/opt/course/e03/shop.key` 로 저장한다.
2. 이 파일로 namespace `shop` 에 TLS Secret `shop-tls` 를 만든다.
3. Ingress `shop` 을 고쳐 host `shop.cks.local` 을 Secret `shop-tls` 로 TLS 서비스하게 한다.
4. ingress-nginx 컨트롤러를 거쳐 `https://shop.cks.local:<https NodePort>/` 를 요청하되 `-k` 없이 `/opt/course/e03/shop.crt` 로
   서버 인증서를 검증하고, 응답 본문을 `/opt/course/e03/curl.txt` 에 쓴다.

## 모범 풀이

**1) 자체 서명 인증서**

```bash
cd /opt/course/e03
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout shop.key -out shop.crt \
  -subj "/CN=shop.cks.local" -addext "subjectAltName=DNS:shop.cks.local"
openssl x509 -in shop.crt -noout -subject -ext subjectAltName
# subject=CN = shop.cks.local
# X509v3 Subject Alternative Name: DNS:shop.cks.local
```

`-nodes` 는 개인키를 암호화하지 않습니다(컨트롤러가 비밀번호 없이 읽어야 함). 최신 클라이언트(curl, 브라우저)는 CN 이 아니라
**SAN** 으로 호스트를 검증하므로 `-addext subjectAltName` 이 빠지면 4단계 검증이 실패합니다.

**2) TLS Secret**

```bash
kubectl -n shop create secret tls shop-tls --cert=shop.crt --key=shop.key
kubectl -n shop get secret shop-tls      # TYPE kubernetes.io/tls, DATA 2 (tls.crt, tls.key)
```

**3) Ingress 에 tls 추가**

```bash
kubectl -n shop edit ingress shop
```

```yaml
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - shop.cks.local          # rules[].host 와 정확히 같아야 한다
    secretName: shop-tls      # Ingress 와 같은 namespace 의 Secret
  rules:
  - host: shop.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shop
            port:
              number: 80
```

ingress-nginx 는 tls 가 설정된 host 에 대해 HTTP 요청을 기본으로 HTTPS 로 **308 리다이렉트**합니다(`ssl-redirect` 기본 true).

**4) NodePort 로 요청**

```bash
HP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
NIP=$(kubectl get node cks-c1-w1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
curl -s --cacert /opt/course/e03/shop.crt --resolve shop.cks.local:$HP:$NIP \
  https://shop.cks.local:$HP/ > /opt/course/e03/curl.txt
cat /opt/course/e03/curl.txt            # shop-e03
```

`--resolve 호스트:포트:IP` 는 DNS 없이 이름을 IP 로 고정하면서 SNI 와 Host 헤더는 `shop.cks.local` 로 보냅니다. IP 로 직접
`https://$NIP:$HP` 를 부르면 SNI 가 없어 컨트롤러가 기본(가짜) 인증서 `Kubernetes Ingress Controller Fake Certificate` 를 내밀고,
`--cacert` 검증도 실패합니다.

## 검증

```bash
kubectl -n shop get ingress shop          # PORTS 80, 443
kubectl -n shop describe ingress shop | grep -A1 TLS   # shop-tls terminates shop.cks.local
openssl s_client -connect $NIP:$HP -servername shop.cks.local </dev/null 2>/dev/null | openssl x509 -noout -subject
# subject=CN = shop.cks.local
P80=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
curl -s -o /dev/null -w '%{http_code}\n' --resolve shop.cks.local:$P80:$NIP http://shop.cks.local:$P80/   # 308 (HTTPS 로 리다이렉트)
cat /opt/course/e03/curl.txt              # shop-e03
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `openssl req -x509 -newkey rsa:2048 -nodes -keyout k -out c -days 365 -subj /CN=h -addext subjectAltName=DNS:h` → `kubectl create secret tls` → Ingress `spec.tls[].hosts` + `secretName`.
- **헷갈리는 지점**: Secret 은 Ingress 와 **같은 namespace** 에 있어야 합니다. 타입이 `Opaque` 이거나 키 이름이 `tls.crt`/`tls.key` 가 아니면 컨트롤러가 무시하고 가짜 인증서를 씁니다. `tls.hosts` 와 `rules.host` 가 다르면 해당 host 는 TLS 가 적용되지 않습니다.

## 참고 문서

- 검색어: `ingress tls`, `create secret tls`, `ssl-redirect`
- https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
- https://kubernetes.github.io/ingress-nginx/user-guide/tls/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q04 →](../q04_clusterrole_readonly_user_can_i/question.md)
