# q11 — Enable Cilium WireGuard transparent encryption · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Pod-to-Pod traffic between the nodes of the cluster must be encrypted. The CNI Cilium was
> installed with Helm as release `cilium` in namespace `kube-system`.
>
> 1. Enable Cilium transparent encryption with type `wireguard` by upgrading the Helm release
>    `cilium`. Keep all values that are currently set and keep the currently installed chart
>    version.
> 2. Make sure that every Cilium agent Pod runs with the new configuration and is Ready.
> 3. Write the line containing `Encryption` from `cilium-dbg status` of the Cilium agent running on
>    node `cks-c1-w1` to `/opt/course/c11/encryption.txt`.
> 4. Write the full output of `cilium-dbg encrypt status` of the same agent to
>    `/opt/course/c11/encrypt-status.txt`.

**해석**

노드 사이의 Pod-Pod 트래픽을 암호화해야 한다. CNI Cilium 은 Helm 릴리스 `kube-system/cilium` 으로 설치되어 있다.

1. Helm 릴리스 `cilium` 을 업그레이드해 타입 `wireguard` 의 투명 암호화를 켠다. 지금 설정된 values 는 모두 유지하고, 설치된 차트 버전도 유지한다.
2. 모든 Cilium 에이전트 Pod 가 새 설정으로 실행되고 Ready 인지 확인한다.
3. `cks-c1-w1` 에서 도는 에이전트의 `cilium-dbg status` 중 `Encryption` 줄을 `/opt/course/c11/encryption.txt` 에 쓴다.
4. 같은 에이전트의 `cilium-dbg encrypt status` 전체 출력을 `/opt/course/c11/encrypt-status.txt` 에 쓴다.

## 모범 풀이

**1) 현재 릴리스와 차트 버전 확인**

```bash
helm -n kube-system list -f '^cilium$'
# NAME    NAMESPACE    REVISION  ...  STATUS    CHART          APP VERSION
# cilium  kube-system  1         ...  deployed  cilium-1.18.3  1.18.3
helm -n kube-system get values cilium          # 사용자가 준 values (예: kubeProxyReplacement, k8sServiceHost ...)
helm repo list | grep cilium || helm repo add cilium https://helm.cilium.io/
helm repo update cilium
```

**2) 업그레이드 — `--version` 과 `--reuse-values`**

```bash
VER=$(helm -n kube-system list -f '^cilium$' -o json | jq -r '.[0].chart' | sed 's/^cilium-//')
helm upgrade cilium cilium/cilium -n kube-system --version "$VER" \
  --reuse-values \
  --set encryption.enabled=true \
  --set encryption.type=wireguard
kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}{"\n"}'   # true
```

| 옵션 | 빠뜨리면 |
|---|---|
| `--version $VER` | 저장소의 **최신 차트**로 올라가 Cilium 자체가 업그레이드됨 (요구 위반, 장애 위험) |
| `--reuse-values` | 기존 values 가 사라지고 차트 기본값으로 돌아감 → `kubeProxyReplacement`, API 서버 주소 등이 빠져 네트워크 장애 |
| `encryption.type=wireguard` | 기본 타입은 `ipsec` 이라 키 Secret 이 없어서 에이전트가 실패 |

(cilium CLI 를 쓴다면 `cilium upgrade --version $VER --reuse-values --set encryption.enabled=true --set encryption.type=wireguard` 도 같은 Helm 동작입니다.)

**3) 에이전트 재시작**

```bash
kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=300s
kubectl -n kube-system get pod -l k8s-app=cilium -o wide
```

Helm 은 ConfigMap `cilium-config` 만 바꾸고, 기본 설정에서는 에이전트 Pod 를 자동으로 다시 띄우지 않습니다(`rollOutCiliumPods=true`
일 때만 자동). 재시작해야 에이전트가 `cilium_wg0` 인터페이스를 만들고 각 노드의 공개키를 노드 어노테이션
(`network.cilium.io/wg-pub-key`)으로 교환합니다.

**4) 확인과 기록**

```bash
AG=$(kubectl -n kube-system get pod -l k8s-app=cilium --field-selector spec.nodeName=cks-c1-w1 -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec $AG -c cilium-agent -- cilium-dbg status | grep Encryption | tee /opt/course/c11/encryption.txt
# Encryption:   Wireguard   [NodeEncryption: Disabled, cilium_wg0 (Pubkey: 3x...=, Port: 51871, Peers: 1)]
kubectl -n kube-system exec $AG -c cilium-agent -- cilium-dbg encrypt status | tee /opt/course/c11/encrypt-status.txt
# Encryption: Wireguard
# Interface: cilium_wg0
#         Public key: 3x...=
#         Number of peers: 1
```

`Peers: 1` 은 2노드 클러스터에서 상대 노드 하나와 터널이 맺어졌다는 뜻입니다. WireGuard 는 노드 **사이** 트래픽만 암호화하고,
같은 노드 안의 Pod 끼리는 암호화하지 않습니다. 노드(host) 네트워크 트래픽까지 암호화하려면 `encryption.nodeEncryption=true` 를 추가합니다.

되돌리기(필요할 때만): `helm upgrade cilium cilium/cilium -n kube-system --version "$VER" --reuse-values --set encryption.enabled=false`
후 `rollout restart ds/cilium`.

## 검증

```bash
helm -n kube-system list -f '^cilium$'          # REVISION 증가, CHART 버전은 그대로
helm -n kube-system get values cilium | grep -A2 encryption
kubectl get node -o custom-columns=NAME:.metadata.name,WGKEY:".metadata.annotations.network\.cilium\.io/wg-pub-key"
kubectl -n kube-system exec $AG -c cilium-agent -- ip -br link show cilium_wg0     # 인터페이스 존재
cat /opt/course/c11/encryption.txt /opt/course/c11/encrypt-status.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `helm upgrade <rel> <chart> --version <현재> --reuse-values --set encryption.enabled=true --set encryption.type=wireguard` → `rollout restart ds/cilium` → `cilium-dbg status | grep Encryption`.
- **헷갈리는 지점**: 에이전트 안의 명령은 `cilium-dbg` 입니다(`cilium` 은 바깥 CLI). `--reuse-values` 는 이전 릴리스 값을 쓰되 새 차트 기본값의 변경은 반영하지 않습니다(`--reset-then-reuse-values` 와 다름). 커널에 WireGuard 모듈이 없으면 에이전트 로그에 오류가 나옵니다.

## 참고 문서

- 검색어: `cilium wireguard transparent encryption`, `cilium helm upgrade reuse-values`
- https://docs.cilium.io/en/stable/security/network/encryption-wireguard/
- https://docs.cilium.io/en/stable/operations/upgrade/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q12 →](../q12_dockerfile_distroless_nonroot_build/question.md)
