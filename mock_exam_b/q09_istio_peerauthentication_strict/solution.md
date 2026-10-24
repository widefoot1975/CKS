# q09 — Enforce Istio mTLS with PeerAuthentication STRICT · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Istio is installed in the cluster. Traffic to the workloads in namespace `bank` must be mutually
> authenticated and encrypted.
>
> 1. Enable automatic Istio sidecar injection for namespace `bank` and make sure that every Pod of
>    the Deployments `ledger` and `teller` runs with an `istio-proxy` sidecar. Do not enable
>    injection for namespace `outside`.
> 2. Create a PeerAuthentication named `default` in namespace `bank` that enforces mutual TLS in
>    `STRICT` mode for all workloads in the namespace.
> 3. Request `http://ledger.bank.svc.cluster.local` with a timeout of 3 seconds from a Pod of
>    `teller` and from a Pod of `stranger`, and write two lines `teller <http_code>` and
>    `stranger <http_code>` to `/opt/course/b09/result.txt`. Use `000` when no HTTP response is
>    received. `teller` must get `200`, `stranger` must not.

**해석**

클러스터에 Istio 가 설치돼 있다. `bank` 의 워크로드로 가는 트래픽은 상호 인증·암호화되어야 한다.

1. `bank` 에 Istio 사이드카 자동 주입을 켜고, Deployment `ledger`, `teller` 의 모든 Pod 가 `istio-proxy` 사이드카와 함께 돌게 한다.
   `outside` 에는 주입을 켜지 않는다.
2. `bank` 의 모든 워크로드에 mTLS `STRICT` 를 강제하는 PeerAuthentication `default` 를 `bank` 에 만든다.
3. `teller` Pod 와 `stranger` Pod 에서 3초 타임아웃으로 `http://ledger.bank.svc.cluster.local` 을 요청하고 `teller <코드>`,
   `stranger <코드>` 두 줄을 `/opt/course/b09/result.txt` 에 쓴다. 응답이 없으면 `000`. `teller` 는 `200`, `stranger` 는 200 이 아니어야 한다.

## 모범 풀이

**1) 사이드카 주입 — 라벨만으로는 기존 Pod 가 바뀌지 않는다**

```bash
alias k=kubectl
k label ns bank istio-injection=enabled
k -n bank get pod                     # 여전히 1/1
```

> 함정 1: 사이드카는 **Pod 가 만들어질 때** istiod 의 mutating webhook 이 넣습니다. 라벨을 붙인 뒤에도 기존 Pod 는 그대로이므로
> 워크로드를 재시작해야 합니다.

```bash
k -n bank rollout restart deploy ledger teller
k -n bank rollout status deploy ledger; k -n bank rollout status deploy teller
k -n bank get pod -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name
# ledger-...   true,true   nginx,istio-proxy
# teller-...   true,true   curl,istio-proxy
```

(Istio 1.26 은 사이드카를 init container `restartPolicy: Always` 의 네이티브 사이드카로 넣을 수도 있어 `spec.initContainers` 에 `istio-proxy`
가 보일 수 있습니다. 어느 쪽이든 READY 가 `2/2` 이면 됩니다.)

`istio.io/rev=<revision>` 라벨은 리비전 기반 설치용이고, `istio-injection=enabled` 와 동시에 쓰면 `istio-injection` 이 우선합니다.

**2) PeerAuthentication STRICT**

```bash
cat <<'EOF' | k apply -f -
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: bank
spec:
  mtls:
    mode: STRICT
EOF
```

`selector` 가 없으면 네임스페이스의 모든 워크로드에 적용됩니다(관례상 이름 `default`). 루트 네임스페이스(`istio-system`)에 두면
메시 전체 정책이 됩니다.

| mode | 서버 사이드카가 받는 것 |
|---|---|
| `PERMISSIVE` (기본) | mTLS 와 평문 둘 다 |
| `STRICT` | mTLS 만 — 사이드카 없는 클라이언트의 평문은 거부 |
| `DISABLE` | 평문만 |

> 함정 2: PeerAuthentication 은 **서버 쪽 사이드카(Envoy)** 가 집행합니다. 사이드카가 없는 Pod 에 STRICT 를 걸어도 아무 일도
> 일어나지 않습니다. 1번에서 재시작을 빼먹으면 stranger 가 계속 200 을 받습니다.

클라이언트 `teller` 는 자기 사이드카가 "auto mTLS" 로 상대가 메시 워크로드임을 알고 자동으로 mTLS 를 씁니다. `stranger` 는 사이드카가
없어 평문 HTTP 를 보내고, ledger 의 Envoy 가 TLS 핸드셰이크가 아닌 바이트를 받아 연결을 끊습니다(curl exit 56
`Connection reset by peer` 또는 52 `Empty reply`).

**3) 요청과 기록**

```bash
mkdir -p /opt/course/b09
T=$(k -n bank exec deploy/teller -c curl -- curl -s -m 3 -o /dev/null -w '%{http_code}' http://ledger.bank.svc.cluster.local)
S=$(k -n outside exec deploy/stranger -- curl -s -m 3 -o /dev/null -w '%{http_code}' http://ledger.bank.svc.cluster.local || true)
printf 'teller %s\nstranger %s\n' "$T" "$S" | tee /opt/course/b09/result.txt
# teller 200
# stranger 000
```

사이드카가 생긴 Pod 에 `exec` 할 때는 `-c` 로 앱 컨테이너를 고르는 습관을 들입니다(Istio 는 `kubectl.kubernetes.io/default-container`
어노테이션도 넣어 주지만 다른 메시는 아닐 수 있음).

## 검증

```bash
k get ns bank outside -L istio-injection                         # bank=enabled, outside 비어 있음
k -n bank get peerauthentication default -o jsonpath='{.spec.mtls.mode}{"\n"}'    # STRICT
k -n outside get pod                                              # 1/1 (사이드카 없음)
istioctl x describe pod $(k -n bank get pod -l app=ledger -o name | head -1 | cut -d/ -f2) -n bank 2>/dev/null | grep -i -A2 mtls
cat /opt/course/b09/result.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 주입 = `kubectl label ns <ns> istio-injection=enabled` + `rollout restart`. mTLS 강제 = `PeerAuthentication{name: default, spec.mtls.mode: STRICT}` (security.istio.io/v1).
- **헷갈리는 지점**: PeerAuthentication 은 "받는 쪽"이 무엇을 허용하는지, DestinationRule 의 `trafficPolicy.tls` 는 "보내는 쪽"이 무엇을 쓰는지입니다. 누가 접근할 수 있는지(인가)는 AuthorizationPolicy 입니다. Cilium 의 kube-proxy 대체(socket LB)가 Pod 네임스페이스에서 동작하면 Service IP 가 소켓 단계에서 바뀌어 사이드카 iptables 리다이렉트를 우회할 수 있으므로 `socketLB.hostNamespaceOnly=true` 가 필요합니다.

## 참고 문서

- 검색어: `PeerAuthentication`, `mutual TLS migration`, `sidecar injection`
- https://istio.io/latest/docs/reference/config/security/peer_authentication/
- https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/
- https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q10 →](../q10_secret_file_mount_resource_names/question.md)
