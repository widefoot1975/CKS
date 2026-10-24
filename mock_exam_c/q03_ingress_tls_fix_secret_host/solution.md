# q03 — Repair a broken TLS Ingress · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> HTTPS for Ingress `store` in namespace `store` (host `store.cks.local`) is broken: clients receive
> the controller's default certificate.
>
> 1. Create a new RSA 2048-bit private key `/opt/course/c03/store.key` and a self-signed certificate
>    `/opt/course/c03/store.crt`, valid for 365 days, with subject `CN=store.cks.local` and the
>    Subject Alternative Name `DNS:store.cks.local`.
> 2. Store them in a Secret named `store-tls` of type `kubernetes.io/tls` in namespace `store`.
>    Delete the misplaced Secret `store-tls` in namespace `default`.
> 3. Fix the `tls` section of Ingress `store` so that host `store.cks.local` is served with Secret
>    `store-tls`. Do not change the rules of the Ingress.
> 4. Connect to the HTTPS NodePort of Service `ingress-nginx/ingress-nginx-controller` on the
>    InternalIP of `cks-c1-w1` with SNI `store.cks.local`, and write the certificate's subject and
>    Subject Alternative Name (output of `openssl x509 -noout -subject -ext subjectAltName`) to
>    `/opt/course/c03/cert.txt`.

**해석**

namespace `store` 의 Ingress `store`(host `store.cks.local`) HTTPS 가 고장 나서 클라이언트가 컨트롤러 기본 인증서를 받는다.

1. RSA 2048 개인키 `/opt/course/c03/store.key` 와 365일짜리 자체 서명 인증서 `/opt/course/c03/store.crt` 를 만든다. subject 는
   `CN=store.cks.local`, SAN 은 `DNS:store.cks.local`.
2. 이를 namespace `store` 의 `kubernetes.io/tls` 타입 Secret `store-tls` 로 저장한다. `default` 에 잘못 만든 Secret `store-tls` 는 지운다.
3. Ingress `store` 의 `tls` 부분을 고쳐 host `store.cks.local` 이 Secret `store-tls` 로 서비스되게 한다. rules 는 바꾸지 않는다.
4. `cks-c1-w1` InternalIP 의 ingress-nginx HTTPS NodePort 로 SNI `store.cks.local` 을 주고 접속해, 인증서의 subject 와 SAN
   (`openssl x509 -noout -subject -ext subjectAltName` 출력)을 `/opt/course/c03/cert.txt` 에 쓴다.

## 모범 풀이

**1) 무엇이 틀렸는지 확인**

```bash
alias k=kubectl
k -n store get ingress store -o yaml | grep -A4 'tls:'
#   tls:
#   - hosts:
#     - www.store.cks.local          ← rule 의 host(store.cks.local)와 다름
#     secretName: store-tls
k -n store get secret store-tls                     # NotFound ← Ingress 와 같은 namespace 에 없다
k -n default get secret store-tls -o jsonpath='{.type}{"\n"}{.data}' | cut -c1-80   # Opaque, 키 cert/key
k -n ingress-nginx logs deploy/ingress-nginx-controller | grep -i store-tls | tail -3
```

ingress-nginx 가 기본 인증서를 내보내는 경우는 세 가지가 겹쳐 있었습니다.

| 원인 | 결과 |
|---|---|
| Secret 이 Ingress 와 **다른 namespace** | `secretName` 은 같은 namespace 만 참조 — 찾지 못함 |
| 타입 `Opaque`, 키 `cert`/`key` | 컨트롤러는 `tls.crt`/`tls.key` 키를 읽음 — 인증서 없음 |
| `tls.hosts` 가 `www.store.cks.local` | SNI `store.cks.local` 과 매칭되는 TLS 설정이 없음 → 기본 인증서 |
| CN 만 있고 SAN 없음 | 최신 클라이언트(Go, curl/OpenSSL 1.1.1+ 검증)는 CN 을 보지 않고 SAN 만 봄 |

**2) 키·인증서 만들기 (SAN 포함)**

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /opt/course/c03/store.key -out /opt/course/c03/store.crt \
  -subj "/CN=store.cks.local" -addext "subjectAltName=DNS:store.cks.local"
openssl x509 -in /opt/course/c03/store.crt -noout -subject -ext subjectAltName
# subject=CN = store.cks.local
# X509v3 Subject Alternative Name:
#     DNS:store.cks.local
```

**3) TLS Secret 을 올바른 namespace 에, 잘못된 것은 삭제**

```bash
k -n store create secret tls store-tls --cert=/opt/course/c03/store.crt --key=/opt/course/c03/store.key
k -n store get secret store-tls -o jsonpath='{.type}{"\n"}'      # kubernetes.io/tls
k -n default delete secret store-tls
```

`kubectl create secret tls` 가 타입 `kubernetes.io/tls` 와 키 이름 `tls.crt`/`tls.key` 를 자동으로 맞추고, 인증서와 키가 짝이 맞는지도 검사합니다.

**4) Ingress 의 tls.hosts 수정**

```bash
k -n store patch ingress store --type=json -p='[{"op":"replace","path":"/spec/tls/0/hosts","value":["store.cks.local"]}]'
```

```yaml
spec:
  tls:
  - hosts:
    - store.cks.local
    secretName: store-tls
```

**5) SNI 로 접속해 인증서 확인**

```bash
NODE_IP=$(k get node cks-c1-w1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
HTTPS_NP=$(k -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
openssl s_client -connect $NODE_IP:$HTTPS_NP -servername store.cks.local </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -ext subjectAltName | tee /opt/course/c03/cert.txt
```

`-servername` 을 빼면 SNI 가 없어서 컨트롤러가 기본 인증서를 돌려주므로 반드시 넣습니다.

## 검증

```bash
cat /opt/course/c03/cert.txt                     # subject=CN = store.cks.local / DNS:store.cks.local
curl -s --cacert /opt/course/c03/store.crt --resolve store.cks.local:$HTTPS_NP:$NODE_IP https://store.cks.local:$HTTPS_NP/
# store            ← -k 없이 인증서 검증까지 통과
k -n default get secret store-tls                # NotFound
k -n store describe ingress store | grep -A2 TLS # store-tls terminates store.cks.local
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: TLS Secret = 같은 namespace + 타입 `kubernetes.io/tls` + 키 `tls.crt`/`tls.key`. `tls.hosts` 는 rule 의 host 와 같아야 하고, 인증서에는 SAN 이 필요하다.
- **헷갈리는 지점**: Fake Certificate 가 보이면 Secret 을 못 찾았거나 SNI 가 안 맞는 것입니다. `openssl s_client` 에 `-servername` 을 빼고 확인하면 고친 뒤에도 기본 인증서가 보여 헷갈립니다. Ingress 를 고치고 몇 초 뒤 컨트롤러가 설정을 다시 읽습니다.

## 참고 문서

- 검색어: `ingress tls`, `tls secret`, `ingress-nginx tls`
- https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
- https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets
- https://kubernetes.github.io/ingress-nginx/user-guide/tls/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q04 →](../q04_kubeadm_worker_upgrade_patch/question.md)
