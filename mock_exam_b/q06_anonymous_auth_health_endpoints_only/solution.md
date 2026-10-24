# q06 — Allow anonymous access only to health endpoints · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Anonymous requests to the kube-apiserver on `cks-c1` are currently accepted for every path.
> Anonymous access must stay possible for health checks only.
>
> 1. Create the file `/etc/kubernetes/authn/authentication-config.yaml` containing an
>    `AuthenticationConfiguration` that enables anonymous authentication only for the paths
>    `/livez`, `/readyz` and `/healthz`.
> 2. Configure the kube-apiserver to use this file with `--authentication-config`. The
>    kube-apiserver must not have the `--anonymous-auth` flag any more. The kube-apiserver must be
>    running and healthy afterwards.
> 3. Delete the ClusterRoleBinding `anon-ns-reader` and the ClusterRole `anon-ns-reader`.
> 4. Without any credentials, request `/livez`, `/readyz`, `/version` and `/api/v1/namespaces` on
>    `https://<cks-c1 InternalIP>:6443` and write one line per path in the form `<path> <http_code>`
>    to `/opt/course/b06/codes.txt`, in this order.

**해석**

지금 `cks-c1` 의 kube-apiserver 는 모든 경로에서 익명 요청을 받아들인다. 익명 접근은 헬스 체크에만 남겨야 한다.

1. `/livez`, `/readyz`, `/healthz` 경로에서만 익명 인증을 켜는 `AuthenticationConfiguration` 을 `/etc/kubernetes/authn/authentication-config.yaml` 에 만든다.
2. kube-apiserver 가 `--authentication-config` 로 이 파일을 쓰게 한다. `--anonymous-auth` 플래그는 없어야 하고, apiserver 는 정상 동작해야 한다.
3. ClusterRoleBinding `anon-ns-reader` 와 ClusterRole `anon-ns-reader` 를 지운다.
4. 인증 정보 없이 `/livez`, `/readyz`, `/version`, `/api/v1/namespaces` 를 요청해 `<path> <http_code>` 를 순서대로 `/opt/course/b06/codes.txt` 에 쓴다.

## 모범 풀이

**왜 `--anonymous-auth=false` 가 아닌가**

kubeadm 의 kube-apiserver static pod 는 `livenessProbe`·`readinessProbe`·`startupProbe` 가 **인증 없이** `https://<IP>:6443/livez`,
`/readyz` 를 호출합니다. 익명 인증을 통째로 끄면 이 프로브가 `401` 을 받아 실패하고, kubelet 이 apiserver 컨테이너를 계속 재시작합니다.
그래서 v1.32(beta)부터 쓸 수 있고 v1.34 에서 GA 된 **AuthenticationConfiguration 의 `anonymous.conditions`** 로 경로를 제한합니다.

**1) 설정 파일**

```bash
sudo -i
mkdir -p /etc/kubernetes/authn
cat > /etc/kubernetes/authn/authentication-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1      # v1.34+ (v1.32~1.33 은 v1beta1)
kind: AuthenticationConfiguration
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
```

**2) apiserver 매니페스트 — 백업, 편집, 확인**

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak     # 매니페스트 디렉터리 밖
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --authentication-config=/etc/kubernetes/authn/authentication-config.yaml   # 추가
    # - --anonymous-auth=true                                                     # 삭제!
    - --advertise-address=...
    ...
    volumeMounts:
    - mountPath: /etc/kubernetes/authn                                            # 추가
      name: authn-config
      readOnly: true
  ...
  volumes:
  - hostPath:                                                                     # 추가
      path: /etc/kubernetes/authn
      type: DirectoryOrCreate
    name: authn-config
```

> 함정 1: `anonymous` 를 설정 파일에 두면 `--anonymous-auth` 플래그와 **함께 쓸 수 없습니다**. 플래그가 남아 있으면 apiserver 가
> "anonymous ... cannot be set when ... authentication configuration file" 류의 오류로 바로 종료합니다.
>
> 함정 2: apiserver 는 컨테이너 안에서 파일을 읽습니다. `/etc/kubernetes/authn` 을 **hostPath volume + volumeMount** 로 넣지 않으면
> "no such file or directory" 로 뜨지 않습니다(kubeadm 기본 마운트는 `/etc/kubernetes/pki` 뿐).

```bash
watch crictl ps --name kube-apiserver            # 새 컨테이너가 Running 으로 남는지 (CREATED 가 갱신)
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; echo ok
# 안 뜨면 원인 확인
crictl ps -a --name kube-apiserver | head -3
tail -20 /var/log/pods/kube-system_kube-apiserver-cks-c1_*/kube-apiserver/*.log
# 복구: cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

**3) 익명용 권한 제거**

```bash
kubectl delete clusterrolebinding anon-ns-reader
kubectl delete clusterrole anon-ns-reader
```

인증 단계에서 익명이 거부되면 권한이 있어도 쓸 수 없지만, 설정이 되돌아가는 순간 다시 노출되므로 인가(RBAC)에서도 지워 이중으로 막습니다.

**4) 확인과 기록**

```bash
IP=$(kubectl get node cks-c1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
for p in /livez /readyz /version /api/v1/namespaces; do
  echo "$p $(curl -sk -o /dev/null -w '%{http_code}' https://$IP:6443$p)"
done | tee /opt/course/b06/codes.txt
# /livez 200
# /readyz 200
# /version 401
# /api/v1/namespaces 401
```

| 경로 | 인증 단계 | 인가 단계 | 결과 |
|---|---|---|---|
| `/livez`, `/readyz`, `/healthz` | 조건에 맞음 → `system:anonymous` | `system:public-info-viewer` 가 허용 | 200 |
| `/version` | 조건 밖 → 인증 실패 | — | 401 (이전에는 public-info-viewer 로 200) |
| `/api/v1/namespaces` | 조건 밖 → 인증 실패 | — | 401 (이전에는 anon-ns-reader 로 200) |

`401 Unauthorized` 는 "누구인지 모름(인증 실패)", `403 Forbidden` 은 "누구인지는 알지만 권한 없음(인가 실패)" 입니다.

## 검증

```bash
grep -E 'anonymous-auth|authentication-config' /etc/kubernetes/manifests/kube-apiserver.yaml   # authentication-config 만
kubectl -n kube-system get pod kube-apiserver-cks-c1                                           # Running, RESTARTS 증가 없음
kubectl get clusterrolebinding,clusterrole anon-ns-reader                                       # NotFound
cat /opt/course/b06/codes.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `AuthenticationConfiguration.anonymous: {enabled: true, conditions: [{path: /livez}, ...]}` + `--authentication-config` + hostPath 마운트, 그리고 `--anonymous-auth` 삭제.
- **헷갈리는 지점**: `--authentication-config` 는 `--oidc-*` 플래그와도 함께 쓸 수 없습니다(JWT 인증기는 파일의 `jwt:` 로 옮깁니다). kubelet 의 `authentication.anonymous.enabled` 는 별개의 설정(10250 포트)입니다. API 버전은 v1.34 이상 `apiserver.config.k8s.io/v1`, 그 전에는 `v1beta1` 입니다.

## 참고 문서

- 검색어: `anonymous requests`, `authentication configuration`, `structured authentication`
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q07 →](../q07_seccomp_localhost_profile_audit_to_errno/question.md)
