# q01 — Block Pod egress to the cloud metadata endpoint · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The cloud metadata endpoint `169.254.169.254` can hand out node credentials. Pods in namespace
> `berlin` must not be able to reach it.
>
> 1. Create a NetworkPolicy named `deny-metadata` in namespace `berlin` that selects all Pods in the
>    namespace and blocks egress to `169.254.169.254/32`. All other egress traffic of these Pods
>    (to other Pods, to cluster DNS and to the Internet) must stay allowed. Do not restrict ingress.
> 2. From Pod `client`, request `http://webapp` and write only the HTTP status code to
>    `/opt/course/f01/webapp.txt`.
> 3. From Pod `client`, run `curl -s -m 3 http://169.254.169.254/` and write only the exit code of
>    `curl` to `/opt/course/f01/metadata.txt`.

**해석**

클라우드 메타데이터 주소 `169.254.169.254` 는 노드 자격 증명을 내줄 수 있다. namespace `berlin` 의 Pod 는 여기에 닿으면 안 된다.

1. namespace `berlin` 에 NetworkPolicy `deny-metadata` 를 만든다. 네임스페이스의 모든 Pod 를 선택하고 `169.254.169.254/32` 로
   나가는 트래픽만 막는다. 그 밖의 egress(다른 Pod, 클러스터 DNS, 인터넷)는 계속 허용되어야 한다. ingress 는 제한하지 않는다.
2. Pod `client` 에서 `http://webapp` 에 요청하고 HTTP 상태 코드만 `/opt/course/f01/webapp.txt` 에 쓴다.
3. Pod `client` 에서 `curl -s -m 3 http://169.254.169.254/` 를 실행하고 `curl` 의 종료 코드만 `/opt/course/f01/metadata.txt` 에 쓴다.

## 모범 풀이

**1) NetworkPolicy — "전부 허용, 단 하나만 제외" 는 `ipBlock.except`**

NetworkPolicy 에는 deny 규칙이 없습니다. Pod 가 Egress 정책에 한 번이라도 선택되면 **허용 목록에 있는 것만** 나갈 수 있으므로,
"전체 허용 + 예외 하나" 를 허용 목록으로 표현해야 합니다.

```yaml
# /opt/course/f01/deny-metadata.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-metadata
  namespace: berlin
spec:
  podSelector: {}              # 네임스페이스의 모든 Pod
  policyTypes:
  - Egress                     # Ingress 를 넣지 않음 → ingress 는 그대로
  egress:
  - to:                        # 규칙 1: 인터넷 전체, 메타데이터 주소만 제외
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
  - to:                        # 규칙 2: 클러스터 안의 모든 Pod (DNS 포함)
    - namespaceSelector: {}
```

```bash
alias k=kubectl
k apply -f /opt/course/f01/deny-metadata.yaml
k -n berlin describe networkpolicy deny-metadata
```

규칙 2 가 필요한 이유: 쿠버네티스 문서는 `ipBlock` 을 **클러스터 외부 IP** 용으로 정의하고, Pod IP 가 `ipBlock` 에 잡히는지는 CNI 마다 다릅니다.
Cilium 의 CIDR 규칙은 기본적으로 Cilium 이 관리하는 엔드포인트(Pod)에는 적용되지 않으므로, `0.0.0.0/0` 만 두면 Pod 간 통신과
kube-dns 조회가 막힐 수 있습니다. `namespaceSelector: {}` 로 모든 네임스페이스의 Pod 를 따로 허용하면 CNI 와 상관없이 안전합니다.

| 쓰는 방법 | 결과 |
|---|---|
| `policyTypes: [Egress]` + `egress: []` | 모든 egress 차단 (DNS 까지) |
| `ipBlock` 0.0.0.0/0 + `except` 만 | 인터넷은 되지만 CNI 에 따라 Pod·DNS 가 막힐 수 있음 |
| `ipBlock` + `except` **그리고** `namespaceSelector: {}` (별도 `to` 항목) | 의도대로: 메타데이터만 차단 |

**2) webapp 은 계속 된다**

```bash
k -n berlin exec client -- curl -s -o /dev/null -w '%{http_code}' http://webapp > /opt/course/f01/webapp.txt
cat /opt/course/f01/webapp.txt        # 200
```

**3) 메타데이터는 막힌다**

```bash
k -n berlin exec client -- curl -s -m 3 http://169.254.169.254/; echo $? > /opt/course/f01/metadata.txt
cat /opt/course/f01/metadata.txt      # 28  (Operation timed out — 패킷이 정책에서 버려짐)
```

`kubectl exec` 는 컨테이너 안 명령의 종료 코드를 그대로 돌려줍니다. Cilium 은 거부된 패킷을 조용히 버리므로 연결 거부(7)가 아니라
시간 초과(28)가 나옵니다.

## 검증

```bash
k -n berlin get networkpolicy deny-metadata -o jsonpath='{.spec.egress[0].to[0].ipBlock}{"\n"}'
# {"cidr":"0.0.0.0/0","except":["169.254.169.254/32"]}
k -n berlin exec client -- curl -s -o /dev/null -w '%{http_code}\n' http://webapp.berlin.svc.cluster.local   # 200 (DNS 동작)
k -n berlin exec client -- curl -s -o /dev/null -w '%{http_code}\n' -m 5 https://kubernetes.io             # 200 (인터넷 허용)
cat /opt/course/f01/webapp.txt /opt/course/f01/metadata.txt                                                # 200 / 28
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: "하나만 막기" = `ipBlock: {cidr: 0.0.0.0/0, except: [169.254.169.254/32]}`. Egress 정책을 거는 순간 나머지는 전부 허용 목록에 적어야 한다.
- **헷갈리는 지점**: `to` 배열 안의 두 항목은 OR, 한 항목 안에 `ipBlock` 과 `namespaceSelector` 를 같이 쓰는 것은 허용되지 않습니다(`ipBlock` 은 단독). Cilium 에서는 노드 IP(kube-apiserver 의 hostNetwork 등)도 `ipBlock` 에 잡히지 않는 것이 기본이라, Pod 가 API 서버를 불러야 하는 경우에는 별도 고려가 필요합니다.

## 참고 문서

- 검색어: `network policies`, `ipBlock except`
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://docs.cilium.io/en/stable/security/policy/language/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q02 →](../q02_cis_static_pod_manifest_permissions/question.md)
