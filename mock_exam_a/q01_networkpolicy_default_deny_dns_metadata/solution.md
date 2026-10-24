# q01 — Default-deny a namespace and open only DNS, API and external egress · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespace `aurora` currently allows all traffic. Lock it down with NetworkPolicies only.
> Do not modify the existing Deployments, Pods or Services.
>
> 1. Create a NetworkPolicy `default-deny` that denies all ingress and all egress traffic for
>    every Pod in `aurora`.
> 2. Create a NetworkPolicy `allow-dns` that allows every Pod in `aurora` to send DNS queries
>    (UDP and TCP port `53`) only to the Pods labeled `k8s-app=kube-dns` in namespace
>    `kube-system`.
> 3. Create a NetworkPolicy `api-ingress` that allows traffic to Pods `app=api` only from Pods
>    `app=frontend` of the same namespace, only on the port the `api` container listens on.
>    Create a NetworkPolicy `frontend-egress` that allows Pods `app=frontend` to reach Pods
>    `app=api` on that same port.
> 4. Create a NetworkPolicy `external-egress` that allows every Pod in `aurora` egress to any
>    IP address outside the cluster, except the cloud metadata address `169.254.169.254`.
> 5. From a `frontend` Pod run `curl -s -m 3 http://api` and write its output to
>    `/opt/course/a01/frontend-api.txt`. The same request from Pod `batch` must time out.

**해석**

namespace `aurora` 는 지금 모든 트래픽을 허용한다. NetworkPolicy 만으로 잠근다. 기존 Deployment·Pod·Service 는 고치지 않는다.

1. `aurora` 의 모든 Pod 에 대해 ingress·egress 를 전부 막는 NetworkPolicy `default-deny` 를 만든다.
2. `aurora` 의 모든 Pod 가 `kube-system` 의 `k8s-app=kube-dns` Pod 로만 DNS 질의(UDP·TCP `53`)를 보낼 수 있게 하는 `allow-dns` 를 만든다.
3. `app=api` Pod 로 들어오는 트래픽을 같은 namespace 의 `app=frontend` Pod 에서, `api` 컨테이너가 실제로 듣는 포트로만 허용하는
   `api-ingress` 를 만든다. `app=frontend` Pod 가 같은 포트로 `app=api` Pod 에 나갈 수 있게 하는 `frontend-egress` 도 만든다.
4. `aurora` 의 모든 Pod 가 클러스터 밖의 모든 IP 로 나갈 수 있게 하되 클라우드 메타데이터 주소 `169.254.169.254` 만 제외하는
   `external-egress` 를 만든다.
5. `frontend` Pod 에서 `curl -s -m 3 http://api` 결과를 `/opt/course/a01/frontend-api.txt` 에 쓴다. 같은 요청을 `batch` 에서 하면 타임아웃이어야 한다.

## 모범 풀이

**0) 포트부터 확인 — Service 포트가 아니라 컨테이너 포트**

```bash
alias k=kubectl
k -n aurora get svc api -o jsonpath='{.spec.ports[0].port} -> {.spec.ports[0].targetPort}{"\n"}'   # 80 -> 8080
k -n aurora get pod --show-labels
```

NetworkPolicy 는 Service 를 모릅니다. kube-proxy/Cilium 이 Service IP:80 을 Pod IP:8080 으로 바꾼 **뒤의** 패킷에 적용되므로
`ports` 에는 **8080** 을 씁니다. 80 을 쓰면 frontend 도 막힙니다.

**1) ~ 4) 정책 다섯 개**

```yaml
# /opt/course/a01/netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: aurora
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: aurora
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
  - to:
    - namespaceSelector:                 # 같은 항목(- 하나)에 두 셀렉터 = AND
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
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-ingress
  namespace: aurora
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: ["Ingress"]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
  namespace: aurora
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes: ["Egress"]
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: external-egress
  namespace: aurora
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
```

```bash
k apply -f /opt/course/a01/netpol.yaml
k -n aurora get netpol
```

정책은 **합집합(OR)** 으로 동작합니다. `default-deny` 가 모든 것을 막아도, 다른 정책이 고른 Pod·방향·포트는 열립니다.
그래서 "막는 정책 하나 + 여는 정책 여러 개" 로 나눠 쓰는 것이 기본 패턴입니다.

**함정 세 가지**

| 함정 | 틀린 형태 | 결과 |
|---|---|---|
| AND / OR | `- namespaceSelector: …` 와 `- podSelector: …` 를 **각각 `-`** 로 씀 | kube-system 의 모든 Pod **또는** aurora 의 kube-dns 라벨 Pod → 의도보다 넓음 |
| DNS 프로토콜 | UDP 53 만 허용 | 큰 응답(TC 플래그)·일부 resolver 의 TCP 재시도가 막혀 간헐적 실패 |
| `ipBlock 0.0.0.0/0` | "전부 열었으니 DNS·api 도 되겠지" | `ipBlock` 은 **클러스터 밖** 주소용. Cilium 은 CIDR 규칙을 클러스터 Pod·노드에 적용하지 않으므로 kube-dns·api Pod 로 가는 트래픽은 별도 규칙이 필요 |

ingress 쪽만 열고 `frontend-egress` 를 빼먹는 것도 흔한 실수입니다. 기본 거부가 egress 까지 막으므로 **보내는 쪽 egress 와
받는 쪽 ingress** 가 둘 다 열려야 연결됩니다.

**5) 결과 기록**

```bash
k -n aurora exec deploy/frontend -- curl -s -m 3 http://api > /opt/course/a01/frontend-api.txt
cat /opt/course/a01/frontend-api.txt          # api-ok
```

## 검증

```bash
k -n aurora exec deploy/frontend -- curl -s -m 3 http://api                 # api-ok (DNS + 8080 허용)
k -n aurora exec batch -- curl -s -m 3 http://api; echo "exit=$?"            # exit=28 (타임아웃)
k -n aurora exec batch -- nslookup kubernetes.default.svc.cluster.local      # 응답 옴 (allow-dns)
k -n aurora exec batch -- curl -s -m 3 http://169.254.169.254/; echo "exit=$?"   # exit=28 (except)
k -n aurora exec batch -- curl -sI -m 5 https://kubernetes.io | head -1     # HTTP/2 200 (외부 허용)
k -n aurora get netpol                                                       # 5개
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 기본 거부(`podSelector: {}` + `policyTypes: [Ingress, Egress]`) 뒤에는 DNS(UDP+TCP 53) egress 를 가장 먼저 연다. 포트는 Service 포트가 아니라 Pod(컨테이너) 포트.
- **헷갈리는 지점**: `from`/`to` 배열의 **한 항목 안**에 `namespaceSelector` 와 `podSelector` 를 같이 쓰면 AND, 항목을 나누면 OR 입니다. `ipBlock` 은 Pod IP 에 쓰는 용도가 아니어서, 클러스터 내부 목적지는 셀렉터로 허용해야 합니다. 메타데이터 차단은 `except` 로 하고, `except` 는 반드시 `cidr` 범위 안에 있어야 합니다.

## 참고 문서

- 검색어: `network policies`, `declare network policy`, `ipBlock except`
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/
- https://docs.cilium.io/en/stable/security/policy/language/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q02 →](../q02_cis_kube_bench_apiserver_kubelet/question.md)
