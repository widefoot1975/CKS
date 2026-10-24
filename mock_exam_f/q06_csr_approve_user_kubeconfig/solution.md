# q06 — Sign a user certificate with a CSR and build a kubeconfig · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> A new developer `jane` needs access to namespace `dev` with a client certificate signed by the
> cluster CA.
>
> 1. Create a CertificateSigningRequest named `jane` from `/opt/course/f06/jane.csr`. Use the signer
>    for kube-apiserver client certificates, the usage `client auth` and an expiration of `86400`
>    seconds.
> 2. Approve the request and save the issued certificate (PEM) to `/opt/course/f06/jane.crt`.
> 3. Create the kubeconfig file `/opt/course/f06/jane.kubeconfig` with a cluster `kubernetes` (same
>    API server URL and CA as the admin kubeconfig), a user `jane` using `jane.crt` and `jane.key`
>    (embed all certificate data), and a context `jane@kubernetes` with default namespace `dev`.
>    Make it the current context.
> 4. Run `kubectl --kubeconfig /opt/course/f06/jane.kubeconfig get pods` and write the output to
>    `/opt/course/f06/pods.txt`.

**해석**

새 개발자 `jane` 이 클러스터 CA 가 서명한 클라이언트 인증서로 namespace `dev` 에 접근해야 한다.

1. `/opt/course/f06/jane.csr` 로 CertificateSigningRequest `jane` 을 만든다. kube-apiserver 클라이언트 인증서용 signer, usage `client auth`,
   만료 `86400` 초를 쓴다.
2. 요청을 승인하고 발급된 인증서(PEM)를 `/opt/course/f06/jane.crt` 에 저장한다.
3. kubeconfig 파일 `/opt/course/f06/jane.kubeconfig` 를 만든다. 클러스터 `kubernetes`(admin kubeconfig 와 같은 API 서버 URL·CA),
   `jane.crt`·`jane.key` 를 쓰는 사용자 `jane`(인증서 데이터는 모두 파일 안에 포함), 기본 namespace 가 `dev` 인 컨텍스트 `jane@kubernetes`.
   이 컨텍스트를 현재 컨텍스트로 둔다.
4. `kubectl --kubeconfig /opt/course/f06/jane.kubeconfig get pods` 를 실행해 출력을 `/opt/course/f06/pods.txt` 에 쓴다.

## 모범 풀이

**1) CSR 오브젝트 만들기**

```bash
alias k=kubectl
cd /opt/course/f06
openssl req -in jane.csr -noout -subject          # subject=CN = jane
cat <<EOF | k apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane
spec:
  request: $(base64 -w0 < jane.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF
k get csr jane          # CONDITION Pending
```

`spec.request` 는 PEM 파일 전체를 **한 줄 base64** 로 넣습니다(`-w0`). 사용자 이름은 CSR 의 CN, 그룹은 O 에서 나옵니다.

| signerName | 용도 |
|---|---|
| `kubernetes.io/kube-apiserver-client` | 사용자·클라이언트 인증서 (수동 승인) |
| `kubernetes.io/kube-apiserver-client-kubelet` | kubelet 의 클라이언트 인증서 (자동 승인 가능) |
| `kubernetes.io/kubelet-serving` | kubelet 서빙 인증서 |

**2) 승인하고 인증서 꺼내기**

```bash
k certificate approve jane
k get csr jane          # Approved,Issued
k get csr jane -o jsonpath='{.status.certificate}' | base64 -d > jane.crt
openssl x509 -in jane.crt -noout -subject -issuer -enddate
# subject=CN = jane
# issuer=CN = kubernetes
# notAfter=...  (약 24시간 뒤)
```

**3) kubeconfig 만들기**

```bash
SERVER=$(k config view --minify -o jsonpath='{.clusters[0].cluster.server}')
KC=/opt/course/f06/jane.kubeconfig
k config --kubeconfig=$KC set-cluster kubernetes --server=$SERVER \
  --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs=true
k config --kubeconfig=$KC set-credentials jane \
  --client-certificate=jane.crt --client-key=jane.key --embed-certs=true
k config --kubeconfig=$KC set-context jane@kubernetes --cluster=kubernetes --user=jane --namespace=dev
k config --kubeconfig=$KC use-context jane@kubernetes
```

`--embed-certs=true` 가 없으면 파일 경로만 들어가서 다른 호스트로 옮기면 동작하지 않습니다.

**4) jane 으로 접속**

```bash
k --kubeconfig=$KC get pods | tee /opt/course/f06/pods.txt
# NAME    READY   STATUS    RESTARTS   AGE
# hello   1/1     Running   0          3m
k --kubeconfig=$KC auth whoami        # Username jane
```

## 검증

```bash
k get csr jane -o jsonpath='{.spec.signerName} {.spec.expirationSeconds} {.status.conditions[0].type}{"\n"}'
# kubernetes.io/kube-apiserver-client 86400 Approved
grep -c 'client-certificate-data\|certificate-authority-data\|client-key-data' $KC     # 3
k --kubeconfig=$KC config current-context                                             # jane@kubernetes
k --kubeconfig=$KC get pods -n kube-system 2>&1 | tail -1                              # Forbidden (dev 만 허용)
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: CSR → `kubectl certificate approve` → `.status.certificate | base64 -d` → `config set-cluster/set-credentials/set-context --embed-certs`.
- **헷갈리는 지점**: 승인만 하고 `Issued` 가 안 붙으면 signerName 이나 usages 가 틀린 것입니다(`kube-apiserver-client` 는 `client auth` 필요, `server auth` 는 거부). `expirationSeconds` 는 최소 600 이고, 컨트롤러 매니저의 `--cluster-signing-duration` 보다 길게 줄 수 없습니다. 인증서는 폐기(revoke)할 방법이 없으므로 짧은 만료가 중요합니다.

## 참고 문서

- 검색어: `certificate signing requests`, `normal user`, `kubeconfig`
- https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/
- https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q07 →](../q07_apparmor_complain_to_enforce/question.md)
