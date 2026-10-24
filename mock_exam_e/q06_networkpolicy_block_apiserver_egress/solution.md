# q06 — Block Pod egress to the Kubernetes API · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Untrusted jobs run in namespace `sandbox`. They must not be able to talk to the Kubernetes
> API server, but everything else must keep working.
>
> 1. Find the ClusterIP of Service `kubernetes` in namespace `default` and the InternalIP of
>    the control-plane node `cks-c1`. Write them, one per line in this order, to
>    `/opt/course/e06/apiserver-ips.txt`.
> 2. Create a NetworkPolicy named `deny-apiserver` in namespace `sandbox` that applies to all
>    Pods and allows egress
>    - to the cluster DNS Pods (label `k8s-app=kube-dns` in namespace `kube-system`) on UDP
>      and TCP port `53`, and
>    - to `0.0.0.0/0` except the two addresses from step 1 (as `/32`).
> 3. From Pod `runner`, run `curl -sk -m 5 https://kubernetes.default.svc/version` and write
>    only the curl exit code to `/opt/course/e06/api-test.txt`.

**해석**

신뢰할 수 없는 작업이 namespace `sandbox` 에서 돈다. 이 파드들은 쿠버네티스 API 서버와 통신할 수 없어야 하고, 나머지는 계속 동작해야 한다.

1. `default` namespace 의 Service `kubernetes` 의 ClusterIP 와 컨트롤 플레인 노드 `cks-c1` 의 InternalIP 를 찾아 이 순서로 한 줄에 하나씩
   `/opt/course/e06/apiserver-ips.txt` 에 쓴다.
2. namespace `sandbox` 에 모든 파드에 적용되는 NetworkPolicy `deny-apiserver` 를 만들고 다음 egress 만 허용한다.
   - `kube-system` 의 클러스터 DNS 파드(라벨 `k8s-app=kube-dns`)로 UDP·TCP `53`
   - `0.0.0.0/0` 중 1단계의 두 주소(`/32`)를 뺀 나머지
3. 파드 `runner` 에서 `curl -sk -m 5 https://kubernetes.default.svc/version` 을 실행하고 curl 종료 코드만 `/opt/course/e06/api-test.txt` 에 쓴다.

## 모범 풀이

**1) API 서버 주소 두 개**

```bash
SVC=$(kubectl -n default get svc kubernetes -o jsonpath='{.spec.clusterIP}')
NODE=$(kubectl get node cks-c1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
printf '%s\n%s\n' "$SVC" "$NODE" > /opt/course/e06/apiserver-ips.txt
cat /opt/course/e06/apiserver-ips.txt     # 10.96.0.1 / 192.168.x.x
kubectl -n default get endpointslice -l kubernetes.io/service-name=kubernetes   # 192.168.x.x:6443 (실제 목적지)
```

파드가 `kubernetes.default.svc:443` 으로 보내면 kube-proxy(또는 Cilium 의 eBPF 서비스 LB)가 목적지를 **노드 IP:6443** 으로 바꿉니다.
정책 엔진은 대부분 이 변환 **이후** 의 주소를 보기 때문에 ClusterIP 만 막아서는 부족하고, EndpointSlice 에 나오는 실제 주소(컨트롤 플레인
노드 IP)를 함께 빼야 합니다.

**2) NetworkPolicy**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-apiserver
  namespace: sandbox
spec:
  podSelector: {}
  policyTypes:
  - Egress
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
        - 10.96.0.1/32          # $SVC
        - 192.168.x.x/32        # $NODE — 실제 값으로 바꾼다
```

```bash
kubectl apply -f np.yaml
```

DNS 규칙은 `namespaceSelector` 와 `podSelector` 를 **한 항목**에 넣어 AND(kube-system 안의 kube-dns 파드)로 만듭니다. 이 규칙이 없으면
Cilium 에서는 DNS 가 막혀 `kubernetes.default.svc` 이름 풀이부터 실패합니다(아래 표 참조).

**3) 테스트**

```bash
kubectl -n sandbox exec runner -- sh -c 'curl -sk -m 5 https://kubernetes.default.svc/version; echo $?' > /opt/course/e06/api-test.txt
cat /opt/course/e06/api-test.txt      # 28 (timeout)
kubectl -n sandbox exec runner -- nslookup kubernetes.default.svc.cluster.local   # DNS 는 동작
```

| 목적지 | 표준 NetworkPolicy 의미 | Cilium 동작 |
|---|---|---|
| 클러스터 밖(인터넷) | `0.0.0.0/0` 이 허용 | `world` 엔티티로 매칭 → 허용 |
| 다른 파드(CoreDNS 포함) | `0.0.0.0/0` 에 포함 | ipBlock 은 클러스터가 관리하는 파드를 **매칭하지 않음** → selector 로 따로 허용해야 함 |
| 컨트롤 플레인 노드 IP:6443 | except 로 제외 → 거부 | 노드/`kube-apiserver` 엔티티는 기본적으로 ipBlock 에 안 걸림 → 어차피 거부 |

Cilium 전용으로는 CiliumNetworkPolicy 의 `egressDeny: [{toEntities: [kube-apiserver]}]` 로 IP 를 몰라도 API 서버만 정확히 막을 수 있습니다.

## 검증

```bash
kubectl -n sandbox describe networkpolicy deny-apiserver
cat /opt/course/e06/apiserver-ips.txt
cat /opt/course/e06/api-test.txt                                                          # 28
kubectl -n sandbox exec runner -- curl -s -m 5 -o /dev/null -w '%{http_code}\n' https://kubernetes.io   # 200 (인터넷이 되는 환경)
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: API 서버 차단 = ClusterIP(`kubectl get svc kubernetes`) **와** 실제 엔드포인트(`kubectl get endpointslice -l kubernetes.io/service-name=kubernetes`, 노드 IP:6443) 둘 다. Egress 정책을 걸면 DNS(UDP·TCP 53)를 반드시 같이 열어 준다.
- **헷갈리는 지점**: `except` 는 같은 `ipBlock` 의 `cidr` 안에서만 의미가 있고 CIDR 표기(`/32`)여야 합니다. NetworkPolicy 에는 deny 규칙이 없어 "전부 허용 − 예외" 를 ipBlock except 로 표현합니다. 파드가 SA 토큰을 못 쓰게 하려면 `automountServiceAccountToken: false` 도 함께 고려합니다.

## 참고 문서

- 검색어: `network policies ipBlock except`, `cilium entities kube-apiserver`
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://docs.cilium.io/en/stable/security/policy/language/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q07 →](../q07_seccomp_runtimedefault_deployment/question.md)
