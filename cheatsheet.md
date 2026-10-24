# 시험장 치트시트 (CKS)

외울 것이 아니라, **모의시험 볼 때마다 실제로 쓴 것만** 남겨서 줄여 나가는 문서입니다.

## 0. 호스트에 들어갈 때마다

```bash
ssh <문제가 지정한 호스트>     # 지정 호스트가 아닌 곳에서 작업하면 0점
sudo -i                       # 정적 파드 매니페스트, kubelet, /etc 작업은 root 로
ssh <node>                    # 워커 작업(AppArmor, Falco, kubelet)은 그 노드로 한 번 더
# ... 풀이 ...
exit                          # 베이스 터미널로 돌아온 뒤 다음 문제로
```

```bash
export do='--dry-run=client -o yaml' now='--force --grace-period=0'
```

> yaml 붙여넣기가 밀려서 깨지면 vim에서 `:set paste` 후 붙이고 `:set nopaste`.

## 1. kube-apiserver 를 고칠 때 (거의 매 세트 나온다)

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak   # manifests 안에 백업 두지 않기
vim /etc/kubernetes/manifests/kube-apiserver.yaml
watch crictl ps | grep kube-apiserver               # 사라졌다가 새 ID 로 돌아오면 성공
crictl ps -a | grep kube-apiserver ; crictl logs <id>
tail /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log
journalctl -u kubelet --since '5 min ago' | grep -i apiserver   # yaml 문법 오류는 여기
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
```

새 설정 파일(audit policy, EncryptionConfiguration, AdmissionConfiguration, AuthenticationConfiguration)을 쓰면 **플래그 + volumeMounts + volumes(hostPath)** 세 군데를 다 고칩니다. 하나라도 빠지면 apiserver 가 안 뜹니다.

```yaml
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    volumeMounts:
    - { name: audit, mountPath: /etc/kubernetes/audit, readOnly: true }
    - { name: audit-log, mountPath: /var/log/kubernetes/audit }
  volumes:
  - { name: audit, hostPath: { path: /etc/kubernetes/audit, type: DirectoryOrCreate } }
  - { name: audit-log, hostPath: { path: /var/log/kubernetes/audit, type: DirectoryOrCreate } }
```

## 2. Cluster Setup

```bash
# kube-bench
kube-bench run --targets master | grep -E 'FAIL|WARN'      # node, etcd, controlplane, policies
kube-bench run --targets node --check 4.2.1
# 바이너리 검증
sha512sum kubelet ; curl -sL https://dl.k8s.io/v1.35.0/bin/linux/amd64/kubelet.sha512
echo "$(curl -sL https://dl.k8s.io/v1.35.0/bin/linux/amd64/kubectl.sha512)  kubectl" | sha512sum -c
# TLS 인증서
openssl req -x509 -nodes -newkey rsa:2048 -days 365 -keyout tls.key -out tls.crt -subj '/CN=shop.example.com' -addext 'subjectAltName=DNS:shop.example.com'
k create secret tls web-tls --cert=tls.crt --key=tls.key -n ns
curl -kv --resolve shop.example.com:<port>:<nodeIP> https://shop.example.com:<port>/
openssl s_client -connect <ip>:443 -servername shop.example.com </dev/null | openssl x509 -noout -subject -ext subjectAltName
```

- 자주 나오는 kube-bench 항목: apiserver `--profiling=false`, `--authorization-mode=Node,RBAC`, `--enable-admission-plugins=NodeRestriction`, etcd `--client-cert-auth=true`, kubelet `anonymous.enabled: false`·`authorization.mode: Webhook`·`readOnlyPort: 0`, 매니페스트 권한 600, etcd 데이터 디렉터리 700
- Ingress TLS 강제: ingress-nginx 는 tls 가 있으면 기본으로 308 리다이렉트, 명시하려면 `nginx.ingress.kubernetes.io/ssl-redirect: "true"`(`force-ssl-redirect` 는 tls 없어도)
- 메타데이터 차단: egress `ipBlock: {cidr: 0.0.0.0/0, except: [169.254.169.254/32]}`

```yaml
# 기본 거부 + DNS 허용 — 가장 많이 쓰는 두 장
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: ns }
spec: { podSelector: {}, policyTypes: [Ingress, Egress] }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-dns, namespace: ns }
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to: [{ namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: kube-system } } }]
    ports: [{ port: 53, protocol: UDP }, { port: 53, protocol: TCP }]
```

## 3. Cluster Hardening

```bash
k auth can-i --list --as=system:serviceaccount:ns:sa -n ns
k auth can-i get secrets --as=dev-ana -n ns ; k auth whoami
k get clusterrolebinding -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name + " " + ([.subjects[]?|.kind+":"+.name]|join(","))'
# CSR 로 사용자 만들기
openssl genrsa -out ana.key 2048 ; openssl req -new -key ana.key -out ana.csr -subj '/CN=dev-ana/O=dev'
cat <<EOF | k apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata: { name: dev-ana }
spec: { request: $(base64 -w0 ana.csr), signerName: kubernetes.io/kube-apiserver-client, expirationSeconds: 86400, usages: [client auth] }
EOF
k certificate approve dev-ana ; k get csr dev-ana -o jsonpath='{.status.certificate}' | base64 -d > ana.crt
k config set-credentials dev-ana --client-key=ana.key --client-certificate=ana.crt --embed-certs
k config set-context dev-ana --cluster=kubernetes --user=dev-ana
# ServiceAccount
k create token sa -n ns --duration=10m --audience=vault
k patch sa default -n ns -p '{"automountServiceAccountToken":false}'
k get secret -A --field-selector type=kubernetes.io/service-account-token
# 업그레이드 (워커)
k drain cks-c1-w1 --ignore-daemonsets --delete-emptydir-data
apt-mark unhold kubeadm kubelet kubectl && apt-get install -y kubeadm=1.35.x-* kubelet=1.35.x-* kubectl=1.35.x-* && apt-mark hold kubeadm kubelet kubectl
kubeadm upgrade node ; systemctl daemon-reload ; systemctl restart kubelet ; k uncordon cks-c1-w1
```

- 위험한 RBAC: `*` 동사/리소스, `escalate`, `bind`, `impersonate`, secrets `list`/`watch`, `pods/exec`, `nodes/proxy`, `serviceaccounts/token` create
- `--anonymous-auth=false` 는 kubeadm 의 `/livez` probe 까지 막을 수 있다 → AuthenticationConfiguration 의 `anonymous.conditions` 로 헬스 경로만 허용 (`--anonymous-auth` 와 함께 쓸 수 없음)
- NodeRestriction: kubelet 은 자기 Node·자기 노드의 Pod 만 수정, `node-restriction.kubernetes.io/` 라벨은 못 붙인다

## 4. System Hardening

```bash
# AppArmor (워커에서)
apparmor_parser -q /etc/apparmor.d/k8s-deny-write ; aa-status | grep k8s ; aa-enforce /etc/apparmor.d/<profile>
# seccomp 프로필 위치 (워커)
ls /var/lib/kubelet/seccomp/profiles/
# 호스트 공격면
ss -tlpn | grep <port> ; systemctl status <svc> ; systemctl disable --now <svc> ; systemctl mask <svc>
apt list --installed | grep <pkg> ; apt-get purge -y <pkg>
find / -xdev -perm -4000 -type f 2>/dev/null ; chmod u-s <bin>
gpasswd -d <user> sudo ; usermod -L -s /usr/sbin/nologin <user>
lsmod | grep <mod> ; echo 'install dccp /bin/false' >> /etc/modprobe.d/cks-blacklist.conf ; modprobe -r dccp
```

```yaml
securityContext:                       # Pod 수준
  seccompProfile: { type: Localhost, localhostProfile: profiles/no-chmod.json }   # /var/lib/kubelet/seccomp 기준 상대 경로
containers:
- name: app
  securityContext:                     # 컨테이너 수준
    appArmorProfile: { type: Localhost, localhostProfile: k8s-deny-write }        # 파일명 아니라 프로필 이름
```

## 5. Minimize Microservice Vulnerabilities

```bash
k label ns team pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35
k label --dry-run=server --overwrite ns team pod-security.kubernetes.io/enforce=restricted   # 위반 파드 미리 보기
# etcd 에서 Secret 직접 읽기
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt --key=/etc/kubernetes/pki/apiserver-etcd-client.key \
  get /registry/secrets/<ns>/<name> | hexdump -C | head        # k8s:enc:aescbc:v1:key1 이면 암호화됨
k get secrets -A -o json | k replace -f -                       # 기존 Secret 재암호화
head -c 32 /dev/urandom | base64                                # aescbc 키
```

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources: [secrets]
  providers:
  - aescbc: { keys: [{ name: key1, secret: <base64 32바이트> }] }
  - identity: {}                      # 맨 앞 provider 로 암호화, 나머지는 읽기용
```

- restricted 4종: `runAsNonRoot: true`(+숫자 UID), `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`
- RuntimeClass: `handler: runsc` → 파드 `runtimeClassName: gvisor`, 확인은 `k exec p -- dmesg` (gVisor 메시지)
- user namespaces: `spec.hostUsers: false` → `cat /proc/self/uid_map` 이 `0 0 4294967295` 가 아니면 적용됨
- Istio mTLS: `k label ns bank istio-injection=enabled` → `k rollout restart` → `PeerAuthentication` `mtls.mode: STRICT`
- Cilium 암호화: `cilium-dbg status | grep Encryption`, `cilium-dbg encrypt status` (agent 파드 안에서)

## 6. Supply Chain Security

```bash
trivy image --severity HIGH,CRITICAL nginx:1.19 ; trivy image -q --format json img | jq '.Results[].Vulnerabilities|length'
trivy config ./manifests ; trivy sbom sbom.spdx.json ; trivy image --format cyclonedx -o sbom.cdx.json img
k get pods -n ns -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'
bom generate --image nginx:1.27-alpine --format json --output sbom.spdx.json ; bom document outline sbom.spdx.json
kubesec scan pod.yaml ; kube-linter lint ./manifests ; kube-linter checks list
podman build -t app:v2 . ; podman images app ; podman inspect --format '{{.Config.User}}' app:v2
crictl inspecti nginx:1.27-alpine | jq -r '.status.repoDigests[]'      # 다이제스트 고정
```

- Dockerfile 최소화: 멀티 스테이지, 태그 고정(가능하면 `@sha256:`), 최종 스테이지에 셸·패키지 관리자 없음(distroless), `USER 65532`(숫자), Secret 을 `ENV`/`ARG` 로 넣지 않기, `RUN` 합치기
- ImagePolicyWebhook: `--enable-admission-plugins=...,ImagePolicyWebhook` + `--admission-control-config-file` + 볼륨. `defaultAllow: false` 면 백엔드가 죽었을 때 전부 거부

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: { name: allowed-registries }
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules: [{ apiGroups: [""], apiVersions: [v1], operations: [CREATE, UPDATE], resources: [pods] }]
  validations:
  - expression: "object.spec.containers.all(c, c.image.startsWith('registry.k8s.io/'))"
    message: "only registry.k8s.io images"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata: { name: allowed-registries }
spec:
  policyName: allowed-registries
  validationActions: [Deny]
  matchResources: { namespaceSelector: { matchLabels: { registry-policy: enforced } } }
```

## 7. Monitoring, Logging and Runtime Security

```bash
# Falco (워커)
systemctl status falco-modern-bpf ; journalctl -u falco-modern-bpf -f --since '5 min ago'
vim /etc/falco/falco_rules.local.yaml ; falco --validate /etc/falco/falco_rules.local.yaml ; systemctl restart falco-modern-bpf
# 컨테이너 ID → 파드
crictl ps --id <id> ; crictl inspect <id> | jq -r '.status.labels["io.kubernetes.pod.name"], .status.labels["io.kubernetes.pod.namespace"]'
crictl pods --id <podid> ; ps -ef | grep <proc> ; cat /proc/<pid>/cgroup ; ls -l /proc/<pid>/exe
# 감사 로그
jq -c 'select(.objectRef.resource=="secrets" and .verb=="list") | [.user.username,.sourceIPs[0],.objectRef.namespace]' /var/log/kubernetes/audit/audit.log
```

```yaml
# falco_rules.local.yaml — 새 규칙 / 기존 규칙 출력 바꾸기
- rule: Shell in payments
  desc: shell spawned in payments namespace
  condition: spawned_process and container and proc.name in (sh, bash, ash) and k8s.ns.name = payments
  output: "%evt.time,%k8s.ns.name,%k8s.pod.name,%proc.name,%user.uid"
  priority: WARNING
- rule: Terminal shell in container
  output: "%evt.time,%container.id,%proc.name"
  override: { output: replace }
```

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: [RequestReceived]
rules:                                 # 위에서부터 처음 맞는 규칙 하나만 적용
- level: None
  users: [system:kube-proxy]
  verbs: [watch]
- level: Metadata
  resources: [{ group: "", resources: [secrets, configmaps] }]
- level: RequestResponse
  resources: [{ group: "", resources: [pods] }]
  namespaces: [prod]
- level: Metadata
```

- 불변 컨테이너: `readOnlyRootFilesystem: true` + 쓰기가 필요한 경로만 `emptyDir`, `privileged`·`allowPrivilegeEscalation` 끄기
- 감사 로그 플래그: `--audit-log-path`, `--audit-log-maxage`(일), `--audit-log-maxbackup`(개수), `--audit-log-maxsize`(MB)
