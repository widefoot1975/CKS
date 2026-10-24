# q10 — Switch encryption at rest from identity to aescbc · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Secrets in this cluster are stored unencrypted although an encryption configuration exists.
>
> 1. Edit `/etc/kubernetes/enc/enc.yaml` so that new Secrets are written encrypted with the
>    `aescbc` provider and key `key1`, while Secrets that are still stored unencrypted remain
>    readable. Do not change the key.
> 2. Make kube-apiserver use the changed configuration. kube-apiserver must be running again
>    afterwards.
> 3. Rewrite all existing Secrets in namespace `vault` so that they are stored encrypted.
> 4. Read Secret `db-pass` in namespace `vault` directly from etcd and write the prefix of the
>    stored value (format `k8s:enc:<provider>:v1:<key name>`) to `/opt/course/e10/prefix.txt`.

**해석**

암호화 설정 파일이 있는데도 이 클러스터의 Secret 은 암호화되지 않은 채 저장된다.

1. `/etc/kubernetes/enc/enc.yaml` 을 고쳐 새 Secret 은 `aescbc` provider·키 `key1` 로 암호화해 쓰고, 아직 평문으로 저장된 Secret 도
   계속 읽을 수 있게 한다. 키는 바꾸지 않는다.
2. kube-apiserver 가 바뀐 설정을 쓰게 한다. 작업 후 kube-apiserver 가 다시 실행 중이어야 한다.
3. namespace `vault` 의 기존 Secret 을 모두 다시 써서 암호화된 상태로 저장되게 한다.
4. etcd 에서 `vault/db-pass` 를 직접 읽어 저장된 값의 접두어(`k8s:enc:<provider>:v1:<key name>` 형식)를 `/opt/course/e10/prefix.txt` 에 쓴다.

## 모범 풀이

**0) 현재 상태 — providers 는 위에서부터**

```bash
grep encryption-provider-config /etc/kubernetes/manifests/kube-apiserver.yaml
# - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
cat /etc/kubernetes/enc/enc.yaml
```

```yaml
providers:
  - identity: {}          # ← 첫 번째 provider 가 "쓰기" 에 쓰인다 → 평문 저장
  - aescbc:
      keys:
        - name: key1
          secret: <base64 32바이트>
```

쓰기는 **첫 번째** provider 로만 하고, 읽기는 목록을 위에서부터 차례로 시도합니다. 그래서 `identity` 가 맨 앞이면 aescbc 키가 있어도
아무것도 암호화되지 않습니다.

**1) 순서 바꾸기 (aescbc 첫째, identity 마지막)**

```bash
cp /etc/kubernetes/enc/enc.yaml /root/enc.yaml.bak
vi /etc/kubernetes/enc/enc.yaml
```

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:               # 쓰기: aescbc/key1
          keys:
            - name: key1
              secret: <그대로>
      - identity: {}          # 읽기 전용 폴백: 아직 평문인 기존 데이터
```

`identity` 를 지우면 아직 평문인 Secret 을 읽을 수 없게 되어(`no matching prefix`) 해당 Secret 을 쓰는 파드·컨트롤러가 깨집니다.

**2) kube-apiserver 재시작 — 설정 파일만 바꾸면 반영되지 않습니다**

kubelet 은 `/etc/kubernetes/manifests/` 의 **매니페스트** 변경만 감지합니다. 매니페스트는 그대로이고 그것이 가리키는 파일 내용만
바뀌었으므로 static pod 는 재시작되지 않고, kube-apiserver 는 암호화 설정을 시작할 때만 읽습니다(`--encryption-provider-config-automatic-reload=true`
를 준 경우만 자동 반영).

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak   # 만약을 위한 백업
crictl ps --name kube-apiserver                                  # 현재 컨테이너 ID
crictl stop $(crictl ps --name kube-apiserver -q)                # kubelet 이 같은 매니페스트로 다시 띄운다
# 또는: mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/ && sleep 20 && mv /root/kube-apiserver.yaml /etc/kubernetes/manifests/
watch crictl ps --name kube-apiserver                            # 새 컨테이너 ID, Running
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; echo ready
```

뜨지 않으면 `crictl ps -a --name kube-apiserver` 로 Exited 컨테이너를 찾아 `crictl logs <id>`, 또는 `/var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log`
를 봅니다. YAML 오류(들여쓰기, 키 길이)라면 `/root/enc.yaml.bak` 으로 되돌리고 다시 재시작합니다.

**3) 기존 Secret 다시 쓰기**

```bash
kubectl -n vault get secrets -o json | kubectl replace -f -
# secret/api-key replaced
# secret/db-pass replaced
```

암호화는 **쓸 때** 일어나므로 설정을 바꿔도 기존 데이터는 평문 그대로입니다. 내용 변경 없이 같은 오브젝트를 다시 쓰면(update) 새 쓰기
provider(aescbc)로 저장됩니다. 클러스터 전체라면 `kubectl get secrets -A -o json | kubectl replace -f -` 입니다.

**4) etcd 에서 직접 확인**

```bash
ETCD=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system exec $ETCD -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/vault/db-pass --print-value-only | hexdump -C | head -3
# 00000000  6b 38 73 3a 65 6e 63 3a  61 65 73 63 62 63 3a 76  |k8s:enc:aescbc:v|
# 00000010  31 3a 6b 65 79 31 3a ...                          |1:key1:.........|
echo 'k8s:enc:aescbc:v1:key1' > /opt/course/e10/prefix.txt
```

호스트에 `etcdctl` 이 있으면 같은 인증서 경로로 바로 실행해도 됩니다(etcd 인증서는 `/etc/kubernetes/pki/etcd/`). 평문일 때는 값이
`k8s\0` (protobuf) 로 시작하고 `S3cr3t-e10` 이 그대로 보입니다.

## 검증

```bash
head -12 /etc/kubernetes/enc/enc.yaml                     # aescbc 가 첫째, identity 가 마지막
kubectl -n kube-system get pod -l component=kube-apiserver   # Running, AGE 가 방금
kubectl -n vault get secret db-pass -o jsonpath='{.data.password}' | base64 -d; echo   # S3cr3t-e10 (복호화되어 정상 조회)
for s in db-pass api-key; do
  kubectl -n kube-system exec $ETCD -- etcdctl --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
    get /registry/secrets/vault/$s --print-value-only | head -c 22; echo
done                                                      # 둘 다 k8s:enc:aescbc:v1:key1
cat /opt/course/e10/prefix.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: providers 의 **첫 번째 = 쓰기**, 나머지 = 읽기 폴백. `aescbc`(또는 `secretbox`/`kms`) 첫째 + `identity` 마지막 → apiserver 재시작 → `kubectl get secrets -o json | kubectl replace -f -` → etcdctl 로 `k8s:enc:aescbc:v1:<key>` 확인.
- **헷갈리는 지점**: 설정 파일 내용만 바꾸면 static pod 가 재시작되지 않습니다(`crictl stop` 또는 매니페스트를 잠시 옮기기). 매니페스트 백업을 `/etc/kubernetes/manifests/` 안에 두면 kubelet 이 그것도 static pod 로 띄우려 하니 다른 디렉터리에 둡니다. 새 설정 파일을 처음 붙일 때는 hostPath 볼륨·volumeMount 가 함께 있어야 합니다(이 문제는 이미 있음).

## 참고 문서

- 검색어: `encrypting confidential data at rest`, `EncryptionConfiguration`, `etcdctl`
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- https://kubernetes.io/docs/concepts/security/secrets-good-practices/
- https://etcd.io/docs/v3.5/dev-guide/interacting_v3/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q11 →](../q11_istio_peerauthentication_strict_basic/question.md)
