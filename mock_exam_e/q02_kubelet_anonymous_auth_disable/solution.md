# q02 — Disable anonymous access to the kubelet API · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The kubelet on worker node `cks-c1-w1` answers API requests from anyone.
>
> 1. On worker node `cks-c1-w1`, change the kubelet configuration so that anonymous requests
>    are rejected and requests are authorized by the API server (`Webhook` mode). Apply the
>    change.
> 2. On `cks-c1`, run `curl -sk -o /dev/null -w '%{http_code}' https://<cks-c1-w1 InternalIP>:10250/pods`
>    and write the HTTP status code to `/opt/course/e02/status.txt`.
> 3. `kubectl logs` and `kubectl exec` for Pods on `cks-c1-w1` must keep working, and the node
>    must be `Ready`.

**해석**

워커 노드 `cks-c1-w1` 의 kubelet 이 누구의 API 요청에나 응답한다.

1. `cks-c1-w1` 에서 kubelet 설정을 바꿔 익명 요청은 거부하고, 요청 인가는 API 서버에 맡기게(`Webhook` 모드) 한다. 변경을 적용한다.
2. `cks-c1` 에서 `curl -sk -o /dev/null -w '%{http_code}' https://<cks-c1-w1 InternalIP>:10250/pods` 를 실행해 HTTP 상태 코드를
   `/opt/course/e02/status.txt` 에 쓴다.
3. `cks-c1-w1` 에 있는 파드에 대한 `kubectl logs`·`kubectl exec` 가 계속 동작해야 하고, 노드는 `Ready` 여야 한다.

## 모범 풀이

**0) 현재 상태 확인 (cks-c1)**

```bash
WIP=$(kubectl get node cks-c1-w1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
curl -sk https://$WIP:10250/pods | head -c 150; echo     # {"kind":"PodList",... ← 인증 없이 노출
```

**1) 워커에서 kubelet 설정 수정**

```bash
ssh cks-c1-w1
sudo -i
ps -ef | grep [k]ubelet | grep -o -- '--config=[^ ]*'      # --config=/var/lib/kubelet/config.yaml
cp /var/lib/kubelet/config.yaml /root/kubelet-config.yaml.bak
vi /var/lib/kubelet/config.yaml
```

```yaml
authentication:
  anonymous:
    enabled: false          # true → false
  webhook:
    cacheTTL: 0s
    enabled: true           # Bearer 토큰을 TokenReview 로 확인
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook             # AlwaysAllow → Webhook (SubjectAccessReview)
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
```

```bash
systemctl restart kubelet
systemctl is-active kubelet          # active
journalctl -u kubelet -n 20 --no-pager   # 설정 파싱 오류가 없는지
exit; exit                           # cks-c1 로 돌아온다
```

kubelet 은 설정 파일을 시작할 때만 읽으므로 **재시작**해야 적용됩니다. kubeadm 클러스터에서는 플래그(`--anonymous-auth`,
`--authorization-mode`)가 아니라 `--config` 파일의 필드로 관리하는 것이 표준입니다(플래그가 있으면 플래그가 우선하므로
`/var/lib/kubelet/kubeadm-flags.env` 와 systemd drop-in 에 같은 플래그가 없는지도 확인).

**2) 상태 코드 기록 (cks-c1)**

```bash
mkdir -p /opt/course/e02
curl -sk -o /dev/null -w '%{http_code}' https://$WIP:10250/pods > /opt/course/e02/status.txt
cat /opt/course/e02/status.txt       # 401
```

| `anonymous.enabled` | `authorization.mode` | 인증서 없는 요청 결과 |
|---|---|---|
| `true` | `AlwaysAllow` | 200 — 누구나 파드 목록·exec 가능 (설정 직후 상태) |
| `true` | `Webhook` | 403 — `system:anonymous` 로 인증되지만 `nodes/proxy` 권한이 없어 거부 |
| `false` | `Webhook` | **401** — 인증 단계에서 바로 거부 (정답) |

**3) logs / exec 확인**

API 서버는 kubelet 에 클라이언트 인증서(`/etc/kubernetes/pki/apiserver-kubelet-client.crt`)로 접속하므로 x509 인증으로
통과하고, `Webhook` 인가에서 그 사용자의 RBAC 권한(kubeadm 이 부여)으로 허용됩니다.

## 검증

```bash
cat /opt/course/e02/status.txt                                   # 401
kubectl get node cks-c1-w1                                       # Ready
P=$(kubectl get pod -A --field-selector spec.nodeName=cks-c1-w1 -o jsonpath='{.items[0].metadata.namespace}/{.items[0].metadata.name}')
kubectl -n ${P%/*} logs ${P#*/} --tail=2                         # 로그가 나온다
ssh cks-c1-w1 sudo grep -A2 -E '^  anonymous:|^authorization:' /var/lib/kubelet/config.yaml
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: kubelet 하드닝 3종 = `authentication.anonymous.enabled: false`, `authentication.webhook.enabled: true`, `authorization.mode: Webhook` (+ `readOnlyPort: 0`). 바꾼 뒤 `systemctl restart kubelet`.
- **헷갈리는 지점**: 익명을 꺼도 `AlwaysAllow` 이면 인증된 누구나(노드에 접근 가능한 모든 SA 토큰 등) 모든 것을 할 수 있으니 둘 다 바꿔야 합니다. 401 은 인증 실패, 403 은 인가 실패입니다. 설정 파일 들여쓰기를 틀리면 kubelet 이 뜨지 않으니 `journalctl -u kubelet` 으로 확인하고 백업으로 되돌립니다.

## 참고 문서

- 검색어: `kubelet authentication authorization`, `kubelet config file`
- https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/
- https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q03 →](../q03_ingress_tls_basic/question.md)
