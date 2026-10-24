# q01 — Allow ingress only from one namespace · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The API in namespace `orion` must only be reachable from the watchtower monitoring stack.
>
> 1. Create a NetworkPolicy named `api-allow-watchtower` in namespace `orion` that selects the
>    Pods with label `app=api` and allows ingress to them **only** from Pods in namespace
>    `watchtower`, on TCP port `8080`. Do not change any namespace labels.
> 2. From Pod `probe` in namespace `watchtower`, run `curl -s -m 3 http://api.orion:8080` and
>    write its output to `/opt/course/e01/watchtower.txt`.
> 3. From Pod `probe` in namespace `guest`, run the same command and write only the curl exit
>    code to `/opt/course/e01/guest.txt`.

**해석**

`orion` namespace 의 API 는 모니터링 도구(`watchtower`)에서만 접근할 수 있어야 한다.

1. `orion` namespace 에 NetworkPolicy `api-allow-watchtower` 를 만든다. 라벨 `app=api` 파드를 선택하고, `watchtower`
   namespace 의 파드에서 오는 TCP `8080` 인그레스**만** 허용한다. namespace 라벨은 바꾸지 않는다.
2. `watchtower` 의 파드 `probe` 에서 `curl -s -m 3 http://api.orion:8080` 을 실행해 출력을 `/opt/course/e01/watchtower.txt` 에 쓴다.
3. `guest` 의 파드 `probe` 에서 같은 명령을 실행하고 curl 종료 코드만 `/opt/course/e01/guest.txt` 에 쓴다.

## 모범 풀이

**1) NetworkPolicy — 자동 라벨 `kubernetes.io/metadata.name` 으로 namespace 를 고릅니다**

```bash
alias k=kubectl
k get ns watchtower --show-labels      # kubernetes.io/metadata.name=watchtower (v1.22+ 자동 부여)
k -n orion get pod --show-labels       # app=api
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow-watchtower
  namespace: orion
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: watchtower
    ports:
    - protocol: TCP
      port: 8080
```

```bash
k apply -f np.yaml
```

별도의 default-deny 정책이 없어도 됩니다. 어떤 정책이든 파드를 `podSelector` 로 **선택하는 순간** 그 파드는 해당 방향(여기서는 Ingress)으로
격리되고, 허용 목록에 있는 트래픽만 들어옵니다. 라벨을 새로 붙이라는 지시가 없으므로 namespace 를 가리킬 때는 API 서버가 모든 namespace 에
자동으로 붙이는 `kubernetes.io/metadata.name` 라벨을 씁니다.

**2) · 3) 테스트와 기록**

```bash
mkdir -p /opt/course/e01
k -n watchtower exec probe -- curl -s -m 3 http://api.orion:8080 > /opt/course/e01/watchtower.txt
cat /opt/course/e01/watchtower.txt          # orion-api

k -n guest exec probe -- sh -c 'curl -s -m 3 http://api.orion:8080; echo $?' > /opt/course/e01/guest.txt
cat /opt/course/e01/guest.txt               # 28  (timeout — 패킷이 드롭됨)
```

`sh -c '...; echo $?'` 로 파드 **안에서** 종료 코드를 찍으면 파일에 코드만 깔끔하게 남습니다(`kubectl exec` 도 원격 명령의 코드를
돌려주므로 `k -n guest exec probe -- curl ...; echo $? > 파일` 도 가능). NetworkPolicy 거부는 RST 가 아니라 드롭이라
`28`(operation timed out)이 나옵니다.

| 셀렉터 형태 | 의미 |
|---|---|
| `from: [ {namespaceSelector: …} ]` | 그 namespace 의 **모든** 파드 |
| `from: [ {namespaceSelector: …, podSelector: …} ]` (한 항목) | 그 namespace 안의 특정 파드 (AND) |
| `from: [ {namespaceSelector: …}, {podSelector: …} ]` (두 항목) | 그 namespace 전체 **또는** 정책과 같은 namespace 의 특정 파드 (OR) |

## 검증

```bash
k -n orion describe networkpolicy api-allow-watchtower
# PodSelector: app=api / Allowing ingress traffic: To Port: 8080/TCP From: NamespaceSelector: kubernetes.io/metadata.name=watchtower
cat /opt/course/e01/watchtower.txt     # orion-api
cat /opt/course/e01/guest.txt          # 28
k get ns watchtower guest --show-labels   # 라벨 그대로
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: namespace 하나만 허용 → `namespaceSelector.matchLabels: {kubernetes.io/metadata.name: <ns>}`. 파드를 선택한 정책이 하나라도 있으면 그 방향은 기본 거부가 된다.
- **헷갈리는 지점**: `podSelector` 만 쓰면 **정책이 있는 namespace(`orion`) 안의** 파드만 뜻합니다. Service 포트가 아니라 파드(컨테이너) 포트 `8080` 을 적어야 합니다(Service 가 80→8080 이어도 정책에는 8080). curl 종료 코드 `7` 은 연결 거부(정책이 아닌 포트·서비스 문제), `28` 은 타임아웃(정책 드롭)입니다.

## 참고 문서

- 검색어: `network policies`, `namespaceSelector`, `kubernetes.io/metadata.name`
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://docs.cilium.io/en/stable/security/policy/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q02 →](../q02_kubelet_anonymous_auth_disable/question.md)
