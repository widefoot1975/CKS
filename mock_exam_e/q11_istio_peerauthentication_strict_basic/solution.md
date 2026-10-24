# q11 — Enforce mTLS STRICT with Istio PeerAuthentication · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Workloads in namespace `mesh-app` must only accept mutual TLS traffic from the mesh.
>
> 1. Create a PeerAuthentication named `default` in namespace `mesh-app` that sets the mTLS
>    mode to `STRICT` for all workloads in the namespace.
> 2. From Pod `client` in namespace `legacy`, run `curl -s -m 5 http://api.mesh-app` and write
>    only the curl exit code to `/opt/course/e11/legacy.txt`.
> 3. From container `client` of Pod `client` in namespace `mesh-app`, run
>    `curl -s -m 5 http://api.mesh-app` and write its output to `/opt/course/e11/mesh.txt`.

**해석**

namespace `mesh-app` 의 워크로드는 메시 안에서 오는 상호 TLS(mTLS) 트래픽만 받아야 한다.

1. namespace `mesh-app` 에 PeerAuthentication `default` 를 만들어 namespace 의 모든 워크로드에 mTLS 모드 `STRICT` 를 건다.
2. namespace `legacy` 의 파드 `client` 에서 `curl -s -m 5 http://api.mesh-app` 을 실행하고 curl 종료 코드만 `/opt/course/e11/legacy.txt` 에 쓴다.
3. namespace `mesh-app` 의 파드 `client` 의 컨테이너 `client` 에서 같은 명령을 실행하고 출력을 `/opt/course/e11/mesh.txt` 에 쓴다.

## 모범 풀이

**0) 현재 상태**

```bash
kubectl get ns mesh-app --show-labels                 # istio-injection=enabled
kubectl -n mesh-app get pod                           # api-... 2/2, client 2/2 (앱 + istio-proxy)
kubectl -n legacy get pod                             # client 1/1 (사이드카 없음)
kubectl get peerauthentication -A                     # No resources found → 기본 PERMISSIVE
```

**1) PeerAuthentication**

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: mesh-app
spec:
  mtls:
    mode: STRICT
```

```bash
kubectl apply -f pa.yaml
```

`selector` 를 생략하면 namespace 전체에 적용됩니다(이름 `default` 는 관례). Istio root namespace(`istio-system`)에 두면 메시 전체,
`selector.matchLabels` 를 주면 특정 워크로드에만 적용되고, 좁은 범위가 우선합니다.

| 모드 | 사이드카 있는 클라이언트(mTLS) | 사이드카 없는 클라이언트(평문) |
|---|---|---|
| `PERMISSIVE` (기본) | 허용 | 허용 |
| `STRICT` | 허용 | **거부** (연결 리셋) |
| `DISABLE` | 평문으로 통신 | 허용 |

**2) · 3) 테스트**

```bash
kubectl -n legacy exec client -- sh -c 'curl -s -m 5 http://api.mesh-app; echo $?' > /opt/course/e11/legacy.txt
cat /opt/course/e11/legacy.txt          # 56  (Recv failure: Connection reset by peer)

kubectl -n mesh-app exec client -c client -- curl -s -m 5 http://api.mesh-app > /opt/course/e11/mesh.txt
cat /opt/course/e11/mesh.txt            # mesh-api
```

평문 클라이언트의 요청은 서버 쪽 사이드카(istio-proxy)가 TLS 핸드셰이크가 아니라서 끊어 버리므로 타임아웃(28)이 아니라 리셋(56)이 납니다.
메시 클라이언트는 자기 사이드카가 자동으로 mTLS(auto mTLS)로 감싸 보내므로 앱 코드는 그대로 `http://` 를 씁니다. `client` 파드에는 컨테이너가
두 개라 `-c client` 로 앱 컨테이너를 지정합니다.

## 검증

```bash
kubectl -n mesh-app get peerauthentication default -o jsonpath='{.spec.mtls.mode}{"\n"}'   # STRICT
cat /opt/course/e11/legacy.txt         # 56 (0 이 아니면 됨, 보통 56)
cat /opt/course/e11/mesh.txt           # mesh-api
istioctl x describe pod $(kubectl -n mesh-app get pod -l app=api -o jsonpath='{.items[0].metadata.name}') -n mesh-app | grep -i strict
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `PeerAuthentication` (`security.istio.io/v1`) `spec.mtls.mode: STRICT` — namespace 에 두면 그 namespace, `istio-system` 에 두면 메시 전체.
- **헷갈리는 지점**: 라벨 `istio-injection=enabled` 는 **새로 만들어지는** 파드에만 사이드카를 넣으므로 라벨을 붙인 뒤에는 `kubectl rollout restart` 가 필요합니다. STRICT 는 "받는 쪽" 정책이라 서버 namespace 에 둡니다. Kubelet 의 HTTP probe 는 Istio 가 probe 를 사이드카 경유로 다시 써 주므로 STRICT 에서도 동작합니다.

## 참고 문서

- 검색어: `peer authentication`, `mutual TLS migration`, `istio STRICT`
- https://istio.io/latest/docs/reference/config/security/peer_authentication/
- https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/
- https://istio.io/latest/docs/concepts/security/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q12 →](../q12_bom_generate_spdx_sbom/question.md)
