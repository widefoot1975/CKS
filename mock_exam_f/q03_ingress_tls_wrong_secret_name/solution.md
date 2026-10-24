# q03 — Fix an Ingress that serves the wrong TLS certificate · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Ingress `shop` in namespace `shop` is configured for TLS, but clients receive the ingress
> controller's default certificate instead of the certificate for `shop.cks.local`.
>
> 1. Find out why, and fix Ingress `shop` so that it uses the TLS Secret that already exists in
>    namespace `shop`. Do not create, modify or delete any Secret.
> 2. Connect to the ingress-nginx controller's HTTPS NodePort on node `cks-c1` with SNI
>    `shop.cks.local` and write the subject of the presented certificate (as printed by
>    `openssl x509 -noout -subject`) to `/opt/course/f03/subject.txt`.
> 3. Request `https://shop.cks.local/` through the same NodePort, trusting only
>    `/opt/course/f03/tls.crt` (no `-k`), and write the response body to `/opt/course/f03/curl.txt`.

**해석**

namespace `shop` 의 Ingress `shop` 은 TLS 로 설정되어 있지만, 클라이언트는 `shop.cks.local` 인증서가 아니라 인그레스 컨트롤러의 기본 인증서를 받는다.

1. 원인을 찾고, Ingress `shop` 이 namespace `shop` 에 이미 있는 TLS Secret 을 쓰도록 고친다. Secret 은 만들거나 고치거나 지우지 않는다.
2. 노드 `cks-c1` 의 ingress-nginx 컨트롤러 HTTPS NodePort 에 SNI `shop.cks.local` 로 접속하고, 받은 인증서의 subject(`openssl x509 -noout -subject` 출력)를
   `/opt/course/f03/subject.txt` 에 쓴다.
3. 같은 NodePort 로 `https://shop.cks.local/` 에 요청하되 `/opt/course/f03/tls.crt` 만 신뢰하고(`-k` 금지), 응답 본문을 `/opt/course/f03/curl.txt` 에 쓴다.

## 모범 풀이

**1) 원인 — Ingress 가 없는 Secret 이름을 가리킨다**

```bash
alias k=kubectl
k -n shop get ingress shop -o jsonpath='{.spec.tls}{"\n"}'
# [{"hosts":["shop.cks.local"],"secretName":"shop-certificate"}]
k -n shop get secret
# NAME       TYPE                DATA   AGE
# shop-tls   kubernetes.io/tls   2      3m
k -n ingress-nginx logs deploy/ingress-nginx-controller | grep -i 'shop-certificate' | tail -2
# ... Error getting SSL certificate "shop/shop-certificate": local SSL certificate shop/shop-certificate was not found. Using default certificate
```

ingress-nginx 는 `tls.secretName` 의 Secret 을 **Ingress 와 같은 namespace** 에서 찾고, 없으면 오류 대신 자기 기본(가짜) 인증서로
계속 서비스합니다. 그래서 겉으로는 HTTPS 가 "동작" 합니다.

```bash
k -n shop patch ingress shop --type=json \
  -p '[{"op":"replace","path":"/spec/tls/0/secretName","value":"shop-tls"}]'
k -n shop describe ingress shop | grep -A2 TLS
#  TLS:
#    shop-tls terminates shop.cks.local
```

`k -n shop edit ingress shop` 으로 `secretName: shop-tls` 로 바꿔도 같습니다.

**2) 인증서 subject 확인**

```bash
IP=$(k get node cks-c1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
P=$(k -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo | openssl s_client -connect $IP:$P -servername shop.cks.local 2>/dev/null \
  | openssl x509 -noout -subject | tee /opt/course/f03/subject.txt
# subject=CN = shop.cks.local
```

`-servername` 이 SNI 입니다. 빠뜨리면 컨트롤러는 어떤 host 인지 몰라 기본 인증서(`CN = Kubernetes Ingress Controller Fake Certificate`)를 줍니다.
고치기 전에 같은 명령을 돌려 보면 차이를 바로 볼 수 있습니다. 컨트롤러가 설정을 다시 읽는 데 몇 초 걸리므로 바로 안 바뀌면 잠시 기다립니다.

**3) 인증서 검증까지 통과하는 요청**

```bash
curl -s --cacert /opt/course/f03/tls.crt --resolve shop.cks.local:$P:$IP \
  https://shop.cks.local:$P/ | tee /opt/course/f03/curl.txt
# shop-web
```

`--resolve 이름:포트:IP` 는 DNS 없이 이름을 IP 로 고정하므로 TLS SNI·Host 헤더·인증서 이름 검사가 모두 `shop.cks.local` 로 이루어집니다.
`-k` 없이 성공했다는 것은 인증서의 SAN 이 `shop.cks.local` 이고 체인이 신뢰된다는 뜻입니다.

## 검증

```bash
k -n shop get ingress shop -o jsonpath='{.spec.tls[0].secretName}{"\n"}'     # shop-tls
k -n shop get secret                                                         # shop-tls 하나뿐 (새로 만들지 않음)
cat /opt/course/f03/subject.txt                                              # subject=CN = shop.cks.local
cat /opt/course/f03/curl.txt                                                 # shop-web
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `spec.tls[].secretName` 은 Ingress 와 **같은 namespace** 의 `kubernetes.io/tls` Secret(`tls.crt`, `tls.key`). 이름이 틀리면 ingress-nginx 는 조용히 기본 인증서를 쓴다.
- **헷갈리는 지점**: `tls.hosts` 와 `rules[].host` 가 일치해야 그 host 에 인증서가 붙습니다. `openssl s_client` 에 `-servername` 을 빼면 고친 뒤에도 가짜 인증서가 보여 틀렸다고 착각하기 쉽습니다. 원인 확인은 컨트롤러 로그의 `Using default certificate` 문구가 가장 빠릅니다.

## 참고 문서

- 검색어: `ingress tls`, `ingress-nginx default ssl certificate`
- https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
- https://kubernetes.github.io/ingress-nginx/user-guide/tls/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q04 →](../q04_remove_wildcard_rbac_rule/question.md)
