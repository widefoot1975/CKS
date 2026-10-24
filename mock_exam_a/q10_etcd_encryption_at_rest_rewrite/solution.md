# q10 — Encrypt Secrets at rest and rewrite the existing data · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Secrets of cluster `cks-c1` are stored unencrypted in etcd.
>
> 1. Create the encryption configuration `/etc/kubernetes/enc/enc.yaml` that encrypts
>    resource `secrets` with the `aescbc` provider using one key named `key1` (a new random
>    32-byte key), and can still read data that is not yet encrypted.
> 2. Configure the kube-apiserver to use this file. The kube-apiserver must be running and
>    healthy afterwards.
> 3. Make sure that all Secrets that already exist in the cluster are stored encrypted.
> 4. Read the raw etcd value of Secret `db-creds` in namespace `finance` with `etcdctl` and
>    write its `hexdump -C` output to `/opt/course/a10/etcd-db-creds.txt`.

**해석**

클러스터 `cks-c1` 의 Secret 이 etcd 에 암호화되지 않은 채 저장되어 있다.

1. `secrets` 리소스를 `aescbc` 프로바이더(새로 만든 무작위 32바이트 키 하나, 이름 `key1`)로 암호화하면서, 아직 암호화되지 않은 데이터도
   읽을 수 있는 암호화 설정 `/etc/kubernetes/enc/enc.yaml` 을 만든다.
2. kube-apiserver 가 이 파일을 쓰게 한다. 끝난 뒤 apiserver 는 정상 동작해야 한다.
3. 클러스터에 이미 있는 모든 Secret 이 암호화되어 저장되게 한다.
4. `etcdctl` 로 namespace `finance` 의 Secret `db-creds` 의 etcd 원본 값을 읽어 `hexdump -C` 출력을 `/opt/course/a10/etcd-db-creds.txt` 에 쓴다.

## 모범 풀이

**1) EncryptionConfiguration — 첫 번째 프로바이더가 쓰기용**

```bash
mkdir -p /etc/kubernetes/enc
KEY=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/enc.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${KEY}
      - identity: {}
EOF
chmod 600 /etc/kubernetes/enc/enc.yaml
```

apiserver 는 **목록의 첫 번째 프로바이더로 암호화해서 쓰고**, 읽을 때는 위에서부터 차례로 시도합니다. 마지막의 `identity: {}` 가
아직 평문인 기존 데이터를 읽게 해 줍니다. `identity` 를 맨 앞에 두면 설정은 "성공" 하지만 아무것도 암호화되지 않습니다.
키는 정확히 32바이트(AES-256)를 base64 로 인코딩한 값이어야 합니다.

| 프로바이더 | 강도 | 비고 |
|---|---|---|
| `identity` | 없음 | 평문. 읽기 호환용으로 마지막에 둔다 |
| `aescbc` | 약함 | 패딩 오라클 취약점 때문에 공식 문서는 권장하지 않음 (문제 요구) |
| `aesgcm` | 보통 | 키를 자주(20만 쓰기 이내) 교체해야 함 |
| `secretbox` | 강함 | XSalsa20-Poly1305 |
| `kms` (v2, GA v1.29) | 가장 강함 | 키가 클러스터 밖 KMS 에 있음 — 운영 권장 |

**2) apiserver — 플래그 + 볼륨 (함정: hostPath 마운트)**

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
    # ... 기존 플래그 ...
    volumeMounts:
    - name: enc
      mountPath: /etc/kubernetes/enc
      readOnly: true
    # ... 기존 마운트 ...
  volumes:
  - name: enc
    hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
  # ... 기존 볼륨 ...
```

```bash
watch crictl ps --name kube-apiserver            # 새 컨테이너 Running
kubectl get --raw=/readyz; echo                   # ok
# 안 뜨면
tail -n 5 /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log
#   error while parsing encryption provider configuration file "/etc/kubernetes/enc/enc.yaml": ... no such file or directory
crictl ps -a --name kube-apiserver; crictl logs <container-id>
# 복구: cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

apiserver 는 컨테이너 안에서 돌기 때문에 호스트의 `/etc/kubernetes/enc/enc.yaml` 을 **보지 못합니다**. 플래그만 넣고 볼륨을 빠뜨리면
"no such file or directory" 로 apiserver 가 뜨지 않습니다. kubeadm 매니페스트에 이미 마운트된 `/etc/kubernetes/pki` 안에 두는 방법도
있지만, 문제는 경로를 지정했으므로 새 볼륨을 추가합니다.

**3) 기존 Secret 다시 쓰기**

```bash
kubectl get secrets -A -o json | kubectl replace -f -
```

암호화 설정은 **새로 쓰는 데이터**에만 적용됩니다. 이미 etcd 에 있는 Secret 은 누군가 다시 쓰기 전까지 평문으로 남으므로,
모든 Secret 을 읽어서 그대로 `replace` 해 새 프로바이더로 다시 저장합니다. 키를 교체(rotation)할 때도 같은 명령을 씁니다.

**4) etcd 에서 직접 확인**

```bash
kubectl -n kube-system exec etcd-cks-c1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/finance/db-creds | hexdump -C > /opt/course/a10/etcd-db-creds.txt
head -3 /opt/course/a10/etcd-db-creds.txt
# 00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
# 00000010  73 2f 66 69 6e 61 6e 63  65 2f 64 62 2d 63 72 65  |s/finance/db-cre|
# 00000020  64 73 0a 6b 38 73 3a 65  6e 63 3a 61 65 73 63 62  |ds.k8s:enc:aescb|
```

호스트에 `etcdctl` 이 있으면 같은 인증서(`/etc/kubernetes/pki/etcd/…`)로 직접 실행해도 됩니다. 평문일 때는 `k8s` 뒤에 protobuf
데이터와 비밀번호 문자열이 그대로 보이고, 암호화되면 `k8s:enc:aescbc:v1:key1:` 접두사 뒤가 의미 없는 바이트입니다.

## 검증

```bash
ETCDCTL="kubectl -n kube-system exec etcd-cks-c1 -- etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key"
$ETCDCTL get /registry/secrets/finance/db-creds | grep -a -c 'k8s:enc:aescbc:v1:key1'        # 1
$ETCDCTL get /registry/secrets/finance/db-creds | grep -a -c 'a10-'                           # 0 (평문 값이 안 보임)
S=$(kubectl -n kube-system get secret -o jsonpath='{.items[0].metadata.name}')              # 다른 기존 Secret 도 다시 쓰였는지
$ETCDCTL get /registry/secrets/kube-system/$S | grep -a -c 'k8s:enc:aescbc:v1:key1'          # 1
kubectl -n finance get secret db-creds -o jsonpath='{.data.password}' | base64 -d; echo      # 정상 복호화
pgrep -af kube-apiserver | tr ' ' '\n' | grep encryption-provider-config
kubectl get --raw=/readyz; echo                                                              # ok
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 설정 파일(첫 프로바이더 = 암호화, 마지막 `identity`) → `--encryption-provider-config` + **hostPath 볼륨/마운트** → `kubectl get secrets -A -o json | kubectl replace -f -` → etcdctl 로 `k8s:enc:` 확인.
- **헷갈리는 지점**: 암호화를 끌 때 설정만 지우면 이미 암호화된 Secret 을 apiserver 가 읽지 못합니다. `identity` 를 맨 앞으로 옮겨 재기동 → 다시 `replace` → 그다음 설정 제거 순서여야 합니다(이 문항의 `cleanup.sh` 가 그렇게 합니다). 키는 32바이트, base64 인코딩.

## 참고 문서

- 검색어: `encrypting confidential data at rest`, `encryption configuration`, `etcdctl`
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/
- https://etcd.io/docs/v3.5/dev-guide/interacting_v3/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q11 →](../q11_runtimeclass_gvisor_sandbox/question.md)
