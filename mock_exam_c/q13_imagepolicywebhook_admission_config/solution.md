# q13 — Configure the ImagePolicyWebhook admission plugin · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The cluster must only run images approved by an external image scanner reachable at
> `https://image-checker.local:8443/check`. Configure the `ImagePolicyWebhook` admission plugin on
> the kube-apiserver of `cks-c1`. All configuration files are in `/etc/kubernetes/policywebhook/`.
>
> 1. Complete `/etc/kubernetes/policywebhook/admission-config.yaml`: use the kubeconfig file
>    `/etc/kubernetes/policywebhook/kubeconfig.yaml`, cache allowed responses for `100` seconds and
>    denied responses for `50` seconds, use a retry backoff of `500` milliseconds, and **deny** Pods
>    when the backend cannot be reached.
> 2. Complete `/etc/kubernetes/policywebhook/kubeconfig.yaml` so that the backend server is
>    `https://image-checker.local:8443/check`, verified with `ca.crt`, and the API server
>    authenticates with `apiserver-client.crt` / `apiserver-client.key` from the same directory.
> 3. Enable the `ImagePolicyWebhook` admission plugin (keep the plugins that are already enabled) and
>    point the kube-apiserver to the admission configuration file. Make sure the kube-apiserver
>    can read the files.
> 4. The kube-apiserver must be running again. Try
>    `kubectl run c13-test --image=nginx:1.27-alpine` and write the complete error message to
>    `/opt/course/c13/denied.txt`. Leave the plugin enabled.

**해석**

클러스터는 `https://image-checker.local:8443/check` 의 외부 이미지 스캐너가 승인한 이미지만 실행해야 한다. `cks-c1` 의 kube-apiserver 에
`ImagePolicyWebhook` admission 플러그인을 설정한다. 설정 파일은 모두 `/etc/kubernetes/policywebhook/` 에 있다.

1. `admission-config.yaml` 을 완성한다: kubeconfig `/etc/kubernetes/policywebhook/kubeconfig.yaml` 사용, 허용 응답 캐시 100초,
   거부 응답 캐시 50초, 재시도 간격 500ms, 백엔드에 닿지 못하면 Pod 를 **거부**.
2. `kubeconfig.yaml` 을 완성한다: 백엔드 서버 `https://image-checker.local:8443/check`, `ca.crt` 로 검증, API 서버는 같은 디렉터리의
   `apiserver-client.crt`/`apiserver-client.key` 로 인증.
3. 기존 플러그인은 유지하면서 `ImagePolicyWebhook` 을 켜고 kube-apiserver 가 admission 설정 파일을 쓰게 한다. kube-apiserver 가 파일을 읽을 수 있게 한다.
4. kube-apiserver 가 다시 실행되어야 한다. `kubectl run c13-test --image=nginx:1.27-alpine` 을 시도해 에러 메시지 전체를
   `/opt/course/c13/denied.txt` 에 쓴다. 플러그인은 켜 둔다.

## 모범 풀이

**1) admission-config.yaml**

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/policywebhook/kubeconfig.yaml
      allowTTL: 100          # 초
      denyTTL: 50            # 초
      retryBackoff: 500      # 밀리초
      defaultAllow: false    # 백엔드 오류 시 거부 (fail closed)
```

`configuration` 아래에 바로 `imagePolicy:` 를 쓰는 인라인 형식입니다. 별도 파일로 뺄 때는 `path:` 로 가리키고 그 파일은
`apiVersion: imagepolicy.config.k8s.io/v1alpha1`, `kind: ImagePolicyWebhookConfiguration` 형식입니다. 백엔드와 주고받는 요청 객체는
`ImageReview`(`imagepolicy.k8s.io/v1alpha1`)입니다.

**2) kubeconfig.yaml — clusters = 백엔드, users = API 서버 자신**

```yaml
apiVersion: v1
kind: Config
clusters:
- name: image-checker
  cluster:
    certificate-authority: /etc/kubernetes/policywebhook/ca.crt
    server: https://image-checker.local:8443/check
contexts:
- name: image-checker
  context:
    cluster: image-checker
    user: api-server
current-context: image-checker
users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/policywebhook/apiserver-client.crt
    client-key: /etc/kubernetes/policywebhook/apiserver-client.key
```

**3) kube-apiserver 수정 — 백업은 manifests 디렉터리 밖에**

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.c13   # manifests/ 안에 두면 static pod 로 또 읽힌다
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
    - --admission-control-config-file=/etc/kubernetes/policywebhook/admission-config.yaml
    # ... 나머지 플래그는 그대로
    volumeMounts:
    - mountPath: /etc/kubernetes/policywebhook
      name: policywebhook
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/policywebhook
      type: DirectoryOrCreate
    name: policywebhook
```

API 서버는 컨테이너 안에서 실행되므로, 호스트 파일 경로를 플래그에만 쓰고 **hostPath 볼륨을 빠뜨리면** `no such file or directory`
로 기동에 실패합니다. 기존 `--enable-admission-plugins` 줄에 덧붙여야 하며, 같은 플래그를 두 줄로 쓰면 마지막 줄만 적용됩니다.

**4) 재기동 지켜보기와 복구**

```bash
watch -n2 'crictl ps --name kube-apiserver'          # 이전 컨테이너가 내려가고 새 컨테이너가 Running 으로 (30~90초)
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; echo ready
# 안 올라오면
crictl ps -a --name kube-apiserver                   # Exited 반복?
ls /var/log/pods/ | grep kube-apiserver
tail -20 /var/log/pods/kube-system_kube-apiserver-cks-c1_*/kube-apiserver/*.log
journalctl -u kubelet --since '5 min ago' | grep -i apiserver | tail
# 고치지 못하면 백업 복구
cp /root/kube-apiserver.yaml.c13 /etc/kubernetes/manifests/kube-apiserver.yaml
```

**5) 거부 확인**

```bash
kubectl run c13-test --image=nginx:1.27-alpine 2>&1 | tee /opt/course/c13/denied.txt
# Error from server (Forbidden): pods "c13-test" is forbidden: Post "https://image-checker.local:8443/check?timeout=30s":
#   dial tcp: lookup image-checker.local on 127.0.0.53:53: no such host
```

백엔드가 없으니 웹훅 호출이 실패하고, `defaultAllow: false` 이므로 **암묵적 거부(implicit deny)** 가 됩니다. `true` 였다면 같은
상황에서 모든 이미지가 허용되어 플러그인이 있으나 마나 합니다. 이 상태에서는 시스템 Pod 를 포함해 클러스터의 모든 새 Pod 가
거부되고, 재시작한 static pod 의 mirror Pod 도 `kubectl get pod` 에 안 보일 수 있습니다(컨테이너는 `crictl ps` 로 보임).
그래서 확인 후 바로 `cleanup.sh` 로 되돌립니다.

## 검증

```bash
crictl ps --name kube-apiserver                                 # Running
ps aux | grep -o 'enable-admission-plugins=[^ ]*'               # NodeRestriction,ImagePolicyWebhook
ps aux | grep -o 'admission-control-config-file=[^ ]*'
grep -E 'defaultAllow|allowTTL|denyTTL|retryBackoff|kubeConfigFile' /etc/kubernetes/policywebhook/admission-config.yaml
grep server: /etc/kubernetes/policywebhook/kubeconfig.yaml
cat /opt/course/c13/denied.txt
sudo bash cleanup.sh                                            # 확인이 끝나면 복구
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 3종 세트 = `--enable-admission-plugins=...,ImagePolicyWebhook` + `--admission-control-config-file=...` + 설정 디렉터리 hostPath 볼륨. `defaultAllow: false` = 백엔드 장애 시 거부.
- **헷갈리는 지점**: TTL 두 개는 초, `retryBackoff` 는 밀리초입니다. kubeconfig 의 `clusters` 는 원격 서비스, `users` 는 API 서버의 클라이언트 자격입니다. API 서버가 안 뜰 때 `kubectl` 은 당연히 안 되므로 `crictl` 과 `/var/log/pods` 로 봅니다.

## 참고 문서

- 검색어: `ImagePolicyWebhook`, `admission controllers`, `admission-control-config-file`
- https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook
- https://kubernetes.io/docs/reference/config-api/apiserver-config.v1/
- https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q14 →](../q14_trivy_config_misconfig_fix/question.md)
