# q01 — Default-deny ingress with one allowed client · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespace `ruby` runs Deployment `web` behind Service `web` (port `80`) and two client Pods,
> `client` and `stranger`. Currently every Pod can reach `web`.
>
> 1. Create a NetworkPolicy `default-deny-ingress` in namespace `ruby` that selects all Pods in
>    the namespace and denies all incoming traffic. Outgoing traffic must not be restricted.
> 2. Create a NetworkPolicy `allow-client-to-web` in namespace `ruby` that allows incoming
>    traffic to the Pods with label `app=web` only from Pods with label `role=client` in the same
>    namespace, and only on TCP port `80`.
> 3. From Pod `client` and from Pod `stranger`, run
>    `curl -s -m 3 -o /dev/null -w '%{http_code}' http://web` and write the printed value to
>    `/opt/course/d01/client.txt` and `/opt/course/d01/stranger.txt` respectively.

**해석**

namespace `ruby` 에서 Deployment `web` 이 Service `web`(포트 `80`) 뒤에 있고 클라이언트 Pod `client`, `stranger` 가 있다.
지금은 모든 Pod 가 `web` 에 접속할 수 있다.

1. namespace `ruby` 의 모든 Pod 를 선택해 들어오는 트래픽을 모두 막는 NetworkPolicy `default-deny-ingress` 를 만든다.
   나가는 트래픽은 제한하지 않는다.
2. 같은 namespace 의 `role=client` Pod 에서 `app=web` Pod 로 들어오는 TCP `80` 트래픽만 허용하는 NetworkPolicy
   `allow-client-to-web` 을 만든다.
3. Pod `client` 와 Pod `stranger` 에서 각각 `curl -s -m 3 -o /dev/null -w '%{http_code}' http://web` 을 실행해 출력값을
   `/opt/course/d01/client.txt`, `/opt/course/d01/stranger.txt` 에 쓴다.

## 모범 풀이

**1) 기본 차단 정책 — ingress 만**

```bash
alias k=kubectl
k -n ruby get pod --show-labels
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: ruby
spec:
  podSelector: {}          # 빈 셀렉터 = namespace 의 모든 Pod
  policyTypes:
  - Ingress                # Egress 를 적지 않으므로 나가는 트래픽은 그대로
```

`ingress:` 항목을 아예 쓰지 않으면 "허용 규칙 0개" 라서 들어오는 트래픽이 모두 막힙니다. `policyTypes` 에 `Egress` 를
넣으면 DNS 까지 막혀 `curl http://web` 의 이름 해석부터 실패하므로, 이 문제에서는 넣으면 안 됩니다.

**2) 허용 정책**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client-to-web
  namespace: ruby
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:         # namespaceSelector 없이 podSelector 만 → 같은 namespace 의 Pod
        matchLabels:
          role: client
    ports:
    - protocol: TCP
      port: 80
```

```bash
k apply -f default-deny-ingress.yaml -f allow-client-to-web.yaml
k -n ruby get netpol
```

NetworkPolicy 는 **더하기만** 됩니다. 어떤 Pod 를 선택한 정책이 하나라도 있으면 그 Pod 는 "기본 차단" 상태가 되고,
선택한 정책들의 허용 규칙의 합집합만 통과합니다. 그래서 deny-all 과 allow 정책을 따로 두어도 충돌하지 않습니다.
`port: 80` 은 Service 포트가 아니라 **Pod(컨테이너) 포트**입니다. 이 문제는 둘 다 80 이라 차이가 없지만
Service `port: 80 → targetPort: 8080` 이라면 정책에는 `8080` 을 써야 합니다.

**3) 확인 결과 저장**

```bash
k -n ruby exec client   -- curl -s -m 3 -o /dev/null -w '%{http_code}' http://web > /opt/course/d01/client.txt
k -n ruby exec stranger -- curl -s -m 3 -o /dev/null -w '%{http_code}' http://web > /opt/course/d01/stranger.txt
cat /opt/course/d01/client.txt      # 200
cat /opt/course/d01/stranger.txt    # 000  (3초 타임아웃, exit code 28)
```

`stranger` 쪽 `kubectl exec` 는 curl 이 28 로 끝나서 `command terminated with exit code 28` 을 stderr 에 찍지만,
`-w` 의 `000` 은 stdout 으로 나오므로 파일에는 `000` 만 남습니다.

## 검증

```bash
k -n ruby get netpol
# NAME                   POD-SELECTOR   AGE
# allow-client-to-web    app=web        ...
# default-deny-ingress   <none>         ...
k -n ruby describe netpol allow-client-to-web | sed -n '/Allowing ingress/,/Not affecting/p'
k -n ruby exec stranger -- nslookup web >/dev/null && echo "DNS OK (egress 는 열려 있음)"
cat /opt/course/d01/client.txt /opt/course/d01/stranger.txt     # 200 / 000
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `podSelector: {}` + `policyTypes: [Ingress]` + `ingress` 없음 = 들어오는 것 전부 차단. 정책은 OR 로 합쳐지고 허용만 할 수 있다.
- **헷갈리는 지점**: `policyTypes` 를 생략하면 `ingress` 만 있다고 보고 Ingress 정책이 되지만, `egress:` 를 적는 순간 Egress 도 포함됩니다. `from` 에 `podSelector` 만 쓰면 같은 namespace, `namespaceSelector` 와 같은 항목(`-` 하나)에 쓰면 AND, 다른 항목(`-` 두 개)이면 OR 입니다.

## 참고 문서

- 검색어: `network policies`, `default deny`
- https://kubernetes.io/docs/concepts/services-networking/network-policies/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q02 →](../q02_kube_bench_apiserver_profiling/question.md)
