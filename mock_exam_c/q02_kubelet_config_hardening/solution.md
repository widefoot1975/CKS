# q02 — Harden the worker kubelet configuration · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The kubelet on worker node `cks-c1-w1` was reconfigured insecurely. Work on `cks-c1-w1`
> (`ssh cks-c1-w1`, then `sudo -i`) and change only the kubelet config file
> `/var/lib/kubelet/config.yaml`; do not add kubelet command-line flags.
>
> 1. Disable anonymous authentication and enable webhook authentication. Keep the existing
>    `x509.clientCAFile`.
> 2. Set the authorization mode to `Webhook`.
> 3. Disable the read-only port (`10255`).
> 4. Enable client certificate rotation.
> 5. Do **not** set `protectKernelDefaults`.
> 6. Restart the kubelet. Node `cks-c1-w1` must be `Ready` again and `kubectl logs` / `kubectl exec`
>    to Pods on that node must keep working.
> 7. On `cks-c1`, write two lines to `/opt/course/c02/check.txt`:
>    - line 1: the HTTP status code of an unauthenticated `curl -sk https://<InternalIP of cks-c1-w1>:10250/pods`
>    - line 2: `open` or `closed` — whether TCP port `10255` on `cks-c1-w1` still answers

**해석**

워커 `cks-c1-w1` 의 kubelet 이 안전하지 않게 설정되어 있다. `cks-c1-w1` 에서(`ssh cks-c1-w1` 후 `sudo -i`) kubelet 설정 파일
`/var/lib/kubelet/config.yaml` 만 고치고, kubelet 명령행 플래그는 추가하지 않는다.

1. 익명 인증을 끄고 webhook 인증을 켠다. 기존 `x509.clientCAFile` 은 유지한다.
2. 인가 모드를 `Webhook` 으로 한다.
3. 읽기 전용 포트(10255)를 끈다.
4. 클라이언트 인증서 회전을 켠다.
5. `protectKernelDefaults` 는 설정하지 **않는다**.
6. kubelet 을 재시작한다. 노드가 다시 `Ready` 가 되고 그 노드 Pod 에 대한 `kubectl logs`/`exec` 가 계속 되어야 한다.
7. `cks-c1` 에서 `/opt/course/c02/check.txt` 에 두 줄을 쓴다. 1행: 인증 없이 `https://<워커 IP>:10250/pods` 를 curl 했을 때의 HTTP
   상태 코드, 2행: 워커의 TCP 10255 가 아직 응답하는지(`open`/`closed`).

## 모범 풀이

**1) 현재 상태 확인 (cks-c1)**

```bash
NODE_IP=$(kubectl get node cks-c1-w1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
curl -sk https://$NODE_IP:10250/pods | head -c 200; echo    # {"kind":"PodList",... ← 누구나 읽힘
curl -s http://$NODE_IP:10255/pods | head -c 200; echo       # 인증·TLS 없는 읽기 전용 포트
```

**2) 워커에서 설정 파일 수정**

```bash
ssh cks-c1-w1
sudo -i
cp /var/lib/kubelet/config.yaml /root/kubelet-config.yaml.bak    # 내 백업
vi /var/lib/kubelet/config.yaml
```

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false              # ← true 였음
  webhook:
    cacheTTL: 0s
    enabled: true               # ← false 였음 (Bearer 토큰을 TokenReview 로 확인)
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook                 # ← AlwaysAllow 였음 (SubjectAccessReview 로 RBAC 확인)
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
readOnlyPort: 0                 # ← 10255 였음. 줄을 지워도 설정 파일 기본값은 0
rotateCertificates: true        # ← false 였음
# protectKernelDefaults 는 넣지 않는다
```

```bash
systemctl restart kubelet
systemctl status kubelet --no-pager | head -5        # active (running)
journalctl -u kubelet -n 30 --no-pager               # 설정 파싱 에러가 없는지
ss -ltnp | grep -E ':10250|:10255'                   # 10250 만 남아야 한다
exit; exit
```

| 설정 | 안전한 값 | 왜 |
|---|---|---|
| `authentication.anonymous.enabled` | `false` | 인증서·토큰 없는 요청을 `system:anonymous` 로 받지 않음 → 401 |
| `authentication.webhook.enabled` | `true` | ServiceAccount 토큰 등 Bearer 토큰을 API 서버 TokenReview 로 검증 |
| `authentication.x509.clientCAFile` | 클러스터 CA | API 서버의 `apiserver-kubelet-client` 인증서를 인증 |
| `authorization.mode` | `Webhook` | 인증된 요청도 RBAC(SubjectAccessReview, `nodes/proxy` 등)로 확인 |
| `readOnlyPort` | `0` | 10255 는 인증 없는 평문 HTTP |
| `rotateCertificates` | `true` | 만료 전에 CSR 로 클라이언트 인증서 자동 갱신 |

**`protectKernelDefaults` 를 켜지 않는 이유**: 이 값이 `true` 면 kubelet 은 커널 sysctl 을 고치지 않고, 기대값(`vm.overcommit_memory=1`,
`vm.panic_on_oom=0`, `kernel.panic=10`, `kernel.panic_on_oops=1`, `kernel.keys.root_maxkeys`, `kernel.keys.root_maxbytes`)과 다르면
**시작 자체를 거부**합니다. 미리 `/etc/sysctl.d/` 로 값을 맞춰 두지 않은 노드에서 켜면 kubelet 이 죽어 노드가 `NotReady` 가 됩니다.
CIS 권고 항목이지만, 시험에서 요구하지 않았으면 건드리지 않는 것이 안전합니다.

`kubectl logs`/`exec` 는 API 서버가 kubelet 10250 에 클라이언트 인증서(`/etc/kubernetes/pki/apiserver-kubelet-client.crt`, kubeadm 에서
`kubeadm:cluster-admins` 그룹)로 접속하므로 x509 + Webhook 인가에서 그대로 허용됩니다.

**3) 결과 기록 (cks-c1)**

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://$NODE_IP:10250/pods      # 401
curl -s -m 3 http://$NODE_IP:10255/pods >/dev/null && echo open || echo closed   # closed
printf '401\nclosed\n' > /opt/course/c02/check.txt
```

## 검증

```bash
kubectl get node cks-c1-w1                                     # Ready
kubectl get --raw "/api/v1/nodes/cks-c1-w1/proxy/configz" | python3 -m json.tool | grep -E '"enabled"|"mode"|readOnlyPort|rotateCertificates'
POD=$(kubectl get pod -A --field-selector spec.nodeName=cks-c1-w1 -o jsonpath='{.items[0].metadata.namespace}/{.items[0].metadata.name}')
kubectl logs -n ${POD%/*} ${POD#*/} --tail=1                   # logs 정상
cat /opt/course/c02/check.txt
```

`/configz` 는 kubelet 이 **실제로 읽어 들인** 설정을 보여 주므로 파일만 고치고 재시작을 잊었는지 확인할 수 있습니다.

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: kubelet 4종 = `anonymous.enabled: false`, `webhook.enabled: true`, `authorization.mode: Webhook`, `readOnlyPort: 0`. 고친 뒤 `systemctl restart kubelet`.
- **헷갈리는 지점**: anonymous 만 끄고 `AlwaysAllow` 를 두면 인증된 아무 주체(유효한 SA 토큰 소지자 포함)가 kubelet API 전체를 쓸 수 있습니다. kubeadm 은 kubelet 플래그를 `/var/lib/kubelet/kubeadm-flags.env` 에 두는데, 같은 항목이 플래그로 있으면 플래그가 설정 파일보다 우선합니다. 파일 들여쓰기를 틀리면 kubelet 이 시작하지 못하니 `journalctl -u kubelet` 을 꼭 봅니다.

## 참고 문서

- 검색어: `kubelet authentication authorization`, `kubelet config file`, `KubeletConfiguration`
- https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/
- https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/
- https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q03 →](../q03_ingress_tls_fix_secret_host/question.md)
