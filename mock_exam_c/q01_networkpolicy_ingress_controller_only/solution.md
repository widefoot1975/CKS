# q01 — Allow ingress only from the Ingress controller and restrict egress · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespace `shop` runs Deployment `web` (Pod label `app=web`, container port `80`). It is published
> through Service `web` and Ingress `web` (host `shop.cks.local`, IngressClass `nginx`). Today every
> Pod in the cluster can reach the `web` Pods directly, and Pods in `shop` can connect anywhere.
>
> 1. Create a NetworkPolicy `web-from-ingress` in namespace `shop`. Pods with label `app=web` must
>    accept ingress only on TCP port `80`, and only from Pods labeled
>    `app.kubernetes.io/name=ingress-nginx` **and** `app.kubernetes.io/component=controller` that run in
>    namespace `ingress-nginx`. A Pod with the same labels in any other namespace must not be allowed.
> 2. Create a NetworkPolicy `shop-egress` in namespace `shop` that selects all Pods in the namespace
>    and allows egress only to:
>    - the CoreDNS Pods (`k8s-app=kube-dns` in namespace `kube-system`) on UDP and TCP port `53`
>    - any IP address on TCP ports `80` and `443`, except `169.254.169.254/32`
>
>    All other egress, including the kubelet port `10250` on the nodes, must be denied.
> 3. Write three lines to `/opt/course/c01/result.txt`:
>    - line 1: the HTTP status code returned by the Ingress for host `shop.cks.local`, requested from
>      `cks-c1` through the HTTP NodePort of Service `ingress-nginx/ingress-nginx-controller` on the
>      InternalIP of node `cks-c1-w1`
>    - line 2: `open` or `blocked` — `curl -m 3 http://web.shop.svc.cluster.local` from Pod `default/outsider`
>    - line 3: `open` or `blocked` — `curl -k -m 3 https://<InternalIP of cks-c1-w1>:10250/healthz` from Pod `shop/tester`

**해석**

namespace `shop` 의 Deployment `web`(라벨 `app=web`, 포트 80)은 Service `web` 과 Ingress `web` 으로 공개되어 있다. 지금은 클러스터의
모든 Pod 가 `web` Pod 에 직접 닿고, `shop` 의 Pod 는 어디로든 나갈 수 있다.

1. `shop` 에 NetworkPolicy `web-from-ingress` 를 만든다. `app=web` Pod 는 TCP 80 으로만, 그리고 namespace `ingress-nginx` 에서
   도는 `app.kubernetes.io/name=ingress-nginx` **이면서** `app.kubernetes.io/component=controller` 인 Pod 에서만 들어오는 트래픽을 받는다.
   다른 namespace 에 같은 라벨의 Pod 가 있어도 허용되면 안 된다.
2. `shop` 의 모든 Pod 를 고르는 NetworkPolicy `shop-egress` 를 만들고, 나가는 트래픽은 다음만 허용한다.
   - `kube-system` 의 CoreDNS Pod(`k8s-app=kube-dns`) UDP·TCP 53
   - `169.254.169.254/32` 를 뺀 모든 IP 의 TCP 80·443

   노드의 kubelet 포트 10250 을 포함해 나머지 egress 는 모두 막혀야 한다.
3. `/opt/course/c01/result.txt` 에 세 줄을 쓴다. 1행: `cks-c1` 에서 `cks-c1-w1` InternalIP 의 ingress-nginx HTTP NodePort 로 host
   `shop.cks.local` 을 요청했을 때의 HTTP 상태 코드, 2행: `default/outsider` 에서 `web` Service 로의 curl 결과(`open`/`blocked`),
   3행: `shop/tester` 에서 워커 kubelet 10250 으로의 curl 결과.

## 모범 풀이

**1) 컨트롤러 Pod 의 라벨과 namespace 라벨 확인**

```bash
alias k=kubectl
k -n ingress-nginx get pod --show-labels | grep controller
# ingress-nginx-controller-...  app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx,...
k get ns ingress-nginx --show-labels
# ingress-nginx  ...  kubernetes.io/metadata.name=ingress-nginx,...
```

`kubernetes.io/metadata.name` 라벨은 API 서버가 모든 namespace 에 자동으로 붙이므로 namespace 를 이름으로 고를 때 쓰기 좋습니다.

**2) ingress 정책 — namespaceSelector 와 podSelector 를 *한 항목* 에**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-from-ingress
  namespace: shop
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes: ["Ingress"]
  ingress:
  - from:
    - namespaceSelector:            # 같은 항목 안 = AND
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
      podSelector:
        matchLabels:
          app.kubernetes.io/name: ingress-nginx
          app.kubernetes.io/component: controller
    ports:
    - protocol: TCP
      port: 80
```

| 쓴 모양 | 의미 |
|---|---|
| `- namespaceSelector: …` 다음 줄에 `  podSelector: …` (같은 `-` 항목) | ingress-nginx namespace **안의** 컨트롤러 Pod (AND) |
| `- namespaceSelector: …` / `- podSelector: …` (각각 `-`) | ingress-nginx namespace 의 **모든** Pod **또는** `shop` namespace 안의 같은 라벨 Pod (OR) |
| `- podSelector: …` 만 | 정책이 있는 namespace(`shop`) 안의 Pod 만 — 다른 namespace 는 절대 안 고름 |

`ports` 는 Service 포트가 아니라 **Pod(컨테이너) 포트**입니다. ingress-nginx 는 Service 를 거치지 않고 EndpointSlice 의 Pod IP 로 직접
연결하므로, 출발지는 컨트롤러 Pod IP 입니다(baremetal 매니페스트는 hostNetwork 가 아니라 NodePort 이므로 Pod IP 가 그대로 보입니다).

**3) egress 정책**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: shop-egress
  namespace: shop
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

```bash
k apply -f web-from-ingress.yaml -f shop-egress.yaml
k -n shop get netpol
```

10250 은 허용 목록에 없는 포트이므로 따로 막을 규칙이 필요 없습니다. NetworkPolicy 에는 deny 규칙이 없고, Pod 가 Egress 정책에
하나라도 선택되면 "허용된 것만 통과" 가 됩니다. 덧붙여 Cilium 은 기본 설정에서 노드 IP 를 CIDR 이 아니라 `host`/`remote-node`
아이덴티티로 다루므로 `0.0.0.0/0` ipBlock 이 노드를 고르지 않습니다(노드로의 egress 가 필요하면 CiliumNetworkPolicy `toEntities`
를 씁니다). 어느 쪽이든 10250 은 막힙니다.

**4) 결과 기록**

```bash
NODE_IP=$(k get node cks-c1-w1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
HTTP_NP=$(k -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: shop.cks.local' http://$NODE_IP:$HTTP_NP/     # 200
k -n default exec outsider -- curl -s -m 3 http://web.shop.svc.cluster.local >/dev/null && echo open || echo blocked   # blocked
k -n shop exec tester -- curl -sk -m 3 https://$NODE_IP:10250/healthz >/dev/null && echo open || echo blocked        # blocked

printf '200\nblocked\nblocked\n' > /opt/course/c01/result.txt
```

## 검증

```bash
k -n shop describe netpol web-from-ingress     # From: NamespaceSelector: ...=ingress-nginx AND PodSelector: ... 한 줄로 보여야 한다
k -n shop exec tester -- nslookup web.shop.svc.cluster.local          # DNS 는 된다
k -n shop exec tester -- curl -s -m 3 -o /dev/null -w '%{http_code}\n' http://example.com   # 외부 80 은 열림 (인터넷이 있으면 200)
k -n shop exec tester -- curl -s -m 3 http://169.254.169.254/ ; echo $?   # 28 (timeout)
cat /opt/course/c01/result.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `from`/`to` 리스트의 한 항목 안에 `namespaceSelector` 와 `podSelector` 를 같이 쓰면 AND, 항목을 나누면 OR. DNS 는 UDP·TCP 53 둘 다.
- **헷갈리는 지점**: egress 정책을 걸면 DNS 까지 막혀서 "이름 해석 실패" 가 timeout 처럼 보입니다. ipBlock 의 `except` 는 그 ipBlock 항목 안에서만 빠지므로, 다른 `to` 항목이 같은 IP 를 허용하면 뚫립니다. ingress 정책의 포트는 Service 포트가 아니라 Pod 포트입니다.

## 참고 문서

- 검색어: `network policies`, `namespaceSelector podSelector`, `ipBlock except`
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.github.io/ingress-nginx/deploy/baremetal/
- https://docs.cilium.io/en/stable/security/policy/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q02 →](../q02_kubelet_config_hardening/question.md)
