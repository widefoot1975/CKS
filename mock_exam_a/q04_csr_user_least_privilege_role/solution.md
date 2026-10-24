# q04 — Certificate user via a CSR with a least-privilege Role · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Developer `dev-ana` needs access to namespace `team-ana` with a client certificate.
>
> 1. Create an RSA `2048` private key `/opt/course/a04/dev-ana.key` and a certificate signing
>    request `/opt/course/a04/dev-ana.csr` with common name `dev-ana` and organization
>    `dev-team`.
> 2. Create a Kubernetes CertificateSigningRequest `dev-ana` for it that uses signer
>    `kubernetes.io/kube-apiserver-client`, usage `client auth` and is valid for `24` hours.
>    Approve it and save the issued certificate to `/opt/course/a04/dev-ana.crt`.
> 3. Create the kubeconfig `/opt/course/a04/dev-ana.kubeconfig` with embedded certificates,
>    a context `dev-ana@kubernetes` for user `dev-ana` with default namespace `team-ana`, set as
>    current context. It must point to the same API server as the admin kubeconfig.
> 4. Create a Role `ana-dev` and a RoleBinding `ana-dev` in `team-ana` for user `dev-ana` so
>    that she can get, list and watch Pods, get and list Deployments, and change the replica
>    count of Deployments with `kubectl scale`. She must not be able to change any other field
>    of a Deployment, nor access anything else.
> 5. Scale Deployment `ana-app` to `2` replicas using her kubeconfig.
> 6. Using her kubeconfig, answer these with `kubectl auth can-i` and write the answers
>    (`yes`/`no`, one per line, in this order) to `/opt/course/a04/can-i.txt`:
>    `list pods`, `delete pods`, `update deployments`, `patch deployments` (subresource
>    `scale`), `get secrets`, `list pods` in namespace `default`.

**해석**

개발자 `dev-ana` 가 클라이언트 인증서로 namespace `team-ana` 에 접근해야 한다.

1. RSA 2048 개인키 `/opt/course/a04/dev-ana.key` 와 CN `dev-ana`, O `dev-team` 인 CSR 파일 `/opt/course/a04/dev-ana.csr` 을 만든다.
2. 서명자 `kubernetes.io/kube-apiserver-client`, 용도 `client auth`, 유효기간 24시간인 CertificateSigningRequest `dev-ana` 를 만들고
   승인한 뒤, 발급된 인증서를 `/opt/course/a04/dev-ana.crt` 에 저장한다.
3. 인증서를 포함(embed)한 kubeconfig `/opt/course/a04/dev-ana.kubeconfig` 를 만든다. 사용자 `dev-ana`, 기본 namespace `team-ana` 인
   context `dev-ana@kubernetes` 를 현재 context 로 하고, admin kubeconfig 와 같은 API 서버를 가리켜야 한다.
4. `team-ana` 에 Role `ana-dev` 와 RoleBinding `ana-dev` 를 만들어, Pod 는 get·list·watch, Deployment 는 get·list, 그리고
   `kubectl scale` 로 레플리카 수만 바꿀 수 있게 한다. Deployment 의 다른 필드는 못 바꾸고, 그 밖의 것에는 접근하지 못해야 한다.
5. 그녀의 kubeconfig 로 Deployment `ana-app` 을 2 레플리카로 scale 한다.
6. 그녀의 kubeconfig 로 `kubectl auth can-i` 를 실행해 다음 질문의 답(`yes`/`no`)을 순서대로 한 줄씩 `/opt/course/a04/can-i.txt` 에 쓴다:
   `list pods`, `delete pods`, `update deployments`, `patch deployments`(subresource `scale`), `get secrets`, namespace `default` 의 `list pods`.

## 모범 풀이

**1) 키와 CSR — CN 은 사용자 이름, O 는 그룹**

```bash
cd /opt/course/a04
openssl genrsa -out dev-ana.key 2048
openssl req -new -key dev-ana.key -subj "/CN=dev-ana/O=dev-team" -out dev-ana.csr
openssl req -in dev-ana.csr -noout -subject        # subject=CN=dev-ana, O=dev-team
```

**2) CertificateSigningRequest → 승인 → 인증서 꺼내기**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-ana
spec:
  request: $(base64 -w0 < dev-ana.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF
kubectl get csr dev-ana                   # CONDITION Pending
kubectl certificate approve dev-ana
kubectl get csr dev-ana                   # Approved,Issued
kubectl get csr dev-ana -o jsonpath='{.status.certificate}' | base64 -d > dev-ana.crt
openssl x509 -in dev-ana.crt -noout -subject -issuer -dates
# subject=O=dev-team, CN=dev-ana   issuer=CN=kubernetes   notAfter = 24시간 뒤
```

`request` 는 PEM 파일 전체를 **줄바꿈 없는** base64 로 넣어야 합니다(`base64 -w0`). `expirationSeconds` 는 최소 600 이고,
kube-controller-manager 의 `--cluster-signing-duration`(기본 1년)보다 길게 줄 수 없습니다. `kubernetes.io/kube-apiserver-client`
서명자는 usages 로 `client auth`(그리고 선택적으로 `digital signature`, `key encipherment`)만 허용합니다. 승인·발급된 CSR 객체는
약 1시간 뒤 자동으로 지워지므로 인증서는 바로 파일로 꺼내 둡니다.

**3) kubeconfig**

```bash
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
KC=/opt/course/a04/dev-ana.kubeconfig
kubectl config set-cluster kubernetes --server=$SERVER --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs --kubeconfig=$KC
kubectl config set-credentials dev-ana --client-certificate=dev-ana.crt --client-key=dev-ana.key --embed-certs --kubeconfig=$KC
kubectl config set-context dev-ana@kubernetes --cluster=kubernetes --user=dev-ana --namespace=team-ana --kubeconfig=$KC
kubectl config use-context dev-ana@kubernetes --kubeconfig=$KC
kubectl --kubeconfig=$KC get pods          # 아직 RBAC 이 없으므로 Forbidden (인증은 성공했다는 뜻)
```

**4) Role · RoleBinding — scale 은 서브리소스**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ana-dev
  namespace: team-ana
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments/scale"]
  verbs: ["get", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ana-dev
  namespace: team-ana
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ana-dev
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: dev-ana
```

`kubectl scale` 은 Deployment 본체가 아니라 `/scale` **서브리소스**를 수정합니다. `deployments` 에 `update`/`patch` 를 주면 scale 은
되지만 이미지·securityContext 까지 바꿀 수 있어 최소 권한이 아닙니다. 반대로 `deployments/scale` 만 주면 레플리카 수만 바뀝니다.
Deployment 는 core 그룹(`""`)이 아니라 `apps` 그룹이라는 점도 자주 틀립니다.

**5) · 6) 실행과 권한 표**

```bash
KC=/opt/course/a04/dev-ana.kubeconfig
kubectl --kubeconfig=$KC scale deploy ana-app --replicas=2       # deployment.apps/ana-app scaled
{
  kubectl --kubeconfig=$KC auth can-i list pods
  kubectl --kubeconfig=$KC auth can-i delete pods
  kubectl --kubeconfig=$KC auth can-i update deployments
  kubectl --kubeconfig=$KC auth can-i patch deployments --subresource=scale
  kubectl --kubeconfig=$KC auth can-i get secrets
  kubectl --kubeconfig=$KC auth can-i list pods -n default
} > /opt/course/a04/can-i.txt
cat /opt/course/a04/can-i.txt          # yes no no yes no no (한 줄씩)
```

`can-i` 는 답이 `no` 면 종료 코드 1 을 돌려주지만 `no` 를 표준출력에 찍으므로 파일에는 그대로 남습니다.

## 검증

```bash
paste -sd' ' /opt/course/a04/can-i.txt                                         # yes no no yes no no
kubectl -n team-ana get deploy ana-app                                          # READY 2/2
kubectl --kubeconfig=/opt/course/a04/dev-ana.kubeconfig config current-context  # dev-ana@kubernetes
kubectl --kubeconfig=/opt/course/a04/dev-ana.kubeconfig auth whoami
# Username: dev-ana   Groups: [dev-team system:authenticated]
kubectl --kubeconfig=/opt/course/a04/dev-ana.kubeconfig set image deploy/ana-app nginx=nginx:1.27   # Forbidden
kubectl auth can-i --list -n team-ana --as dev-ana --as-group dev-team
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: openssl 키 → CSR(`/CN=사용자/O=그룹`) → CSR 객체(`base64 -w0`, `signerName`, `expirationSeconds`, `usages: [client auth]`) → `kubectl certificate approve` → `.status.certificate | base64 -d`.
- **헷갈리는 지점**: `--as dev-ana` 로 흉내 내면 그룹 `dev-team` 은 따라오지 않으므로 그룹에 바인딩했다면 `--as-group` 도 줘야 합니다. scale 권한은 `deployments/scale` 서브리소스, 로그는 `pods/log`, exec 는 `pods/exec`(create) 처럼 서브리소스는 따로 허용합니다. 인증서 사용자는 API 로 폐기(revoke)할 수 없으므로 짧은 `expirationSeconds` 가 중요합니다.

## 참고 문서

- 검색어: `certificate signing requests normal user`, `rbac`, `kubectl config set-credentials`
- https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q05 →](../q05_serviceaccount_automount_projected_token/question.md)
