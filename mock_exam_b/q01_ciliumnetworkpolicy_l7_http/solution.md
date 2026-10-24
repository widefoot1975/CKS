# q01 — L7 HTTP policy with CiliumNetworkPolicy · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespace `orion` runs Deployment `backend` (label `app=backend`, HTTP on port `8080`, exposed by
> Service `backend`) and two Pods: `client` (label `role=client`) and `intruder` (label `role=guest`).
> The CNI is Cilium. Do not change the existing workloads or Services.
>
> 1. Create a Kubernetes NetworkPolicy named `default-deny-ingress` in namespace `orion` that denies
>    all ingress traffic to every Pod in the namespace.
> 2. Create a CiliumNetworkPolicy named `backend-l7` in namespace `orion` that selects the Pods with
>    label `app=backend` and allows ingress only from Pods with label `role=client` to TCP port
>    `8080`, and only for HTTP `GET` requests whose path starts with `/api/v1/`.
> 3. Send the following requests to `http://backend:8080` with a timeout of 3 seconds and write one
>    line per request in the form `<pod> <method> <path> <http_code>` to
>    `/opt/course/b01/result.txt`, in this order. Use `000` when no HTTP response is received.
>    - from `client`: `GET /api/v1/items`
>    - from `client`: `POST /api/v1/items`
>    - from `client`: `GET /admin`
>    - from `intruder`: `GET /api/v1/items`

**해석**

`orion` 네임스페이스에 Deployment `backend`(라벨 `app=backend`, 8080 HTTP, Service `backend`)와 Pod `client`(`role=client`),
`intruder`(`role=guest`)가 있다. CNI 는 Cilium 이다. 기존 워크로드와 Service 는 바꾸지 않는다.

1. `orion` 의 모든 Pod 에 대한 인그레스를 막는 쿠버네티스 NetworkPolicy `default-deny-ingress` 를 만든다.
2. `app=backend` Pod 를 선택하고, `role=client` Pod 에서 TCP `8080` 으로 오는 트래픽 중 **경로가 `/api/v1/` 로 시작하는 HTTP `GET`
   요청만** 허용하는 CiliumNetworkPolicy `backend-l7` 을 만든다.
3. 아래 네 요청을 3초 타임아웃으로 `http://backend:8080` 에 보내고 `<pod> <method> <path> <http_code>` 형식으로 한 줄씩 순서대로
   `/opt/course/b01/result.txt` 에 쓴다. HTTP 응답이 없으면 `000`.

## 모범 풀이

**1) 기본 거부 (L3/L4, 쿠버네티스 표준 NetworkPolicy)**

```bash
alias k=kubectl
cat <<'EOF' | k apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: orion
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
```

**2) L7 허용 (CiliumNetworkPolicy)**

```bash
cat <<'EOF' | k apply -f -
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-l7
  namespace: orion
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        role: client
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: GET
          path: "/api/v1/.*"
EOF
k -n orion get cnp backend-l7      # VALID 열이 True 인지
```

- L7 규칙은 반드시 `toPorts[].rules.http` 아래에 둡니다. `ports` 만 있고 `rules` 가 없으면 L4 허용이라 POST 도 통과합니다.
- `method` 와 `path` 는 **정규식**이며 Envoy 에서 경로 전체와 일치해야 합니다. `/api/v1/*` 라고 쓰면 "`/api/v1` 뒤에 `/` 가 0개 이상"이라는
  뜻이 되어 `/api/v1/items` 가 **거부**됩니다. 접두사 일치는 `/api/v1/.*` 입니다.
- 네임스페이스 리소스인 CNP 의 `fromEndpoints` 는 같은 네임스페이스의 엔드포인트만 고릅니다. 다른 네임스페이스면
  `k8s:io.kubernetes.pod.namespace: <ns>` 라벨을 함께 씁니다.

| 정책 | 역할 | 결과 |
|---|---|---|
| NetworkPolicy `default-deny-ingress` | 모든 Pod 를 "인그레스 격리" 상태로 만든다 | 허용 규칙이 없는 트래픽은 L3/L4 에서 drop(응답 없음 → `000`) |
| CNP `backend-l7` | `role=client` → `8080` 을 허용하고 그 포트를 Envoy 로 보낸다 | 규칙에 맞지 않는 HTTP 요청은 Envoy 가 `403 Access denied` |

Cilium 은 두 종류의 정책을 **합집합(allow 의 OR)** 으로 계산합니다. 기본 거부 정책이 있어도 CNP 의 허용이 더해지고, 허용된 포트에
L7 규칙이 있으면 그 포트 트래픽은 모두 프록시를 거칩니다. 그래서 `client` 의 POST 는 연결은 되지만 Envoy 가 403 을 돌려주고,
`intruder` 는 L3 에서 허용 규칙이 없어 패킷이 drop 되어 타임아웃이 납니다.

**3) 요청 보내고 기록**

```bash
req() { k -n orion exec "$1" -- curl -s -m 3 -o /dev/null -w '%{http_code}' -X "$2" "http://backend:8080$3"; }
{
  echo "client GET /api/v1/items $(req client GET /api/v1/items)"
  echo "client POST /api/v1/items $(req client POST /api/v1/items)"
  echo "client GET /admin $(req client GET /admin)"
  echo "intruder GET /api/v1/items $(req intruder GET /api/v1/items || true)"
} > /opt/course/b01/result.txt
cat /opt/course/b01/result.txt
# client GET /api/v1/items 200
# client POST /api/v1/items 403
# client GET /admin 403
# intruder GET /api/v1/items 000
```

curl 은 타임아웃 시 종료 코드 28 과 함께 `%{http_code}` 로 `000` 을 출력합니다(`kubectl exec` 는 `command terminated with exit code 28`
을 stderr 로 남깁니다).

## 검증

```bash
k -n orion get netpol,cnp
k -n orion exec client -- curl -s -m 3 -X POST http://backend:8080/api/v1/items    # Access denied
k -n orion exec client -- curl -s -m 3 http://backend:8080/api/v1/items            # backend
# Cilium 에이전트에서 정책 판정 보기 (hubble 이 있으면 더 편하다)
k -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg policy get -n orion 2>/dev/null | head -40
k -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg endpoint list | grep -E 'backend|ENDPOINT'
cat /opt/course/b01/result.txt
```

`cilium-dbg endpoint list` 의 `POLICY (ingress) ENFORCEMENT` 가 backend 엔드포인트에서 `Enabled` 여야 합니다. `ds/cilium` 은 임의의
노드 에이전트로 붙으므로, backend 가 있는 노드의 cilium 파드를 골라야 그 엔드포인트가 보입니다.

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: L7 = `toPorts: [{ports: [...], rules: {http: [{method, path}]}}]`. `path` 는 정규식(`/api/v1/.*`). L7 에서 거부되면 `403`, L3/L4 에서 거부되면 응답 없음(`000`).
- **헷갈리는 지점**: 쿠버네티스 NetworkPolicy 와 CNP 는 서로 덮어쓰지 않고 허용이 합쳐집니다. 그래서 "기본 거부 + CNP 허용"이 동작합니다. CNP 를 `ingressDeny` 로 쓰면 거부가 허용보다 우선하므로 이런 문제에는 쓰지 않습니다. 요청은 Service 이름으로 보내도 정책은 DNAT 후 **Pod 포트(8080)** 기준으로 적용됩니다.

## 참고 문서

- 검색어: `network policies`, `cilium layer 7 policy`, `CiliumNetworkPolicy http`
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://docs.cilium.io/en/stable/security/policy/language/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q02 →](../q02_cis_etcd_kubelet_file_permissions/question.md)
