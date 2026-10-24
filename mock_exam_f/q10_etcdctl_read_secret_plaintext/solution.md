# q10 — Read a Secret directly from etcd · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The security team wants to know whether Secrets are readable by anyone who gets access to the etcd
> data.
>
> 1. On `cks-c1`, use `etcdctl` with the etcd client TLS certificates under `/etc/kubernetes/pki/`
>    to read the etcd key of Secret `db-cred` in namespace `vault-demo`. Write the value of the key
>    exactly as returned by etcd (no decoding) to `/opt/course/f10/etcd-raw.txt`.
> 2. Find the value of the data field `password` inside that raw output and write it, exactly as it
>    appears in etcd, to `/opt/course/f10/password.txt`.
> 3. Write `PLAINTEXT` to `/opt/course/f10/result.txt` if the password can be read from the etcd
>    data without any key, otherwise write `ENCRYPTED`.

**해석**

보안팀은 etcd 데이터에 접근한 사람이 Secret 을 읽을 수 있는지 알고 싶어 한다.

1. `cks-c1` 에서 `/etc/kubernetes/pki/` 아래의 etcd 클라이언트 TLS 인증서로 `etcdctl` 을 써서 namespace `vault-demo` 의 Secret `db-cred` 에
   해당하는 etcd 키를 읽는다. etcd 가 돌려준 값을 그대로(디코딩 없이) `/opt/course/f10/etcd-raw.txt` 에 쓴다.
2. 그 원본 출력에서 데이터 필드 `password` 의 값을 찾아, etcd 에 보이는 그대로 `/opt/course/f10/password.txt` 에 쓴다.
3. 키 없이 etcd 데이터에서 비밀번호를 읽을 수 있으면 `/opt/course/f10/result.txt` 에 `PLAINTEXT`, 아니면 `ENCRYPTED` 를 쓴다.

## 모범 풀이

**1) etcd 키 읽기**

```bash
sudo -i
grep -E 'listen-client-urls|cert-file|key-file|trusted-ca-file' /etc/kubernetes/manifests/etcd.yaml
# --listen-client-urls=https://127.0.0.1:2379,https://<IP>:2379
# --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
grep etcd /etc/kubernetes/manifests/kube-apiserver.yaml
# --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
# --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key

export ETCDCTL_API=3
E="etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key=/etc/kubernetes/pki/apiserver-etcd-client.key"

$E get /registry/secrets/vault-demo --prefix --keys-only        # /registry/secrets/vault-demo/db-cred
$E get /registry/secrets/vault-demo/db-cred --print-value-only > /opt/course/f10/etcd-raw.txt
```

쿠버네티스 오브젝트는 etcd 에 `/registry/<리소스>/<namespace>/<이름>` 키로 저장됩니다. 클라이언트 인증서는 apiserver 가 쓰는
`apiserver-etcd-client` 나 `etcd/healthcheck-client` 를 쓰고, CA 는 **etcd 전용 CA**(`/etc/kubernetes/pki/etcd/ca.crt`)입니다.
클러스터 CA(`/etc/kubernetes/pki/ca.crt`)를 주면 TLS 오류가 납니다.

호스트에 `etcdctl` 이 없으면 etcd 파드 안의 것을 씁니다(인증서 경로는 파드에 마운트된 같은 경로).

```bash
kubectl -n kube-system exec etcd-cks-c1 -- etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/vault-demo/db-cred --print-value-only > /opt/course/f10/etcd-raw.txt
```

**2) 값 찾기 — base64 가 아니라 원래 바이트 그대로**

```bash
hexdump -C /opt/course/f10/etcd-raw.txt | head -20
# 00000000  6b 38 73 00 0a 0c 0a 02  76 31 12 06 53 65 63 72  |k8s.....v1..Secr|
# ...
# 000000f0  ... 70 61 73 73 77 6f 72 64  12 0a 53 33 63 72 33 74  |password..S3cr3t|
# 00000100  2d 66 31 30 ...                                       |-f10...|
strings /opt/course/f10/etcd-raw.txt | grep -A1 password
echo -n 'S3cr3t-f10' > /opt/course/f10/password.txt
```

값은 `k8s\x00` 로 시작하는 **protobuf** 형식입니다. Secret 의 `data` 필드는 API(JSON/YAML)로 볼 때만 base64 로 표시되고, etcd 에는
**원래 바이트**가 그대로 저장됩니다. 그래서 디코딩 없이도 `S3cr3t-f10` 이 보입니다.

**3) 판정**

```bash
echo PLAINTEXT > /opt/course/f10/result.txt
grep -c encryption-provider-config /etc/kubernetes/manifests/kube-apiserver.yaml   # 0 — 저장 암호화 없음
```

| etcd 값의 시작 | 의미 |
|---|---|
| `k8s\x00` + protobuf | 암호화 안 됨 (identity) |
| `k8s:enc:aescbc:v1:<키이름>:` | aescbc 로 암호화 |
| `k8s:enc:secretbox:v1:` / `k8s:enc:aesgcm:v1:` | 해당 provider 로 암호화 |
| `k8s:enc:kms:v2:` | KMS v2 로 암호화 |

## 검증

```bash
head -c 4 /opt/course/f10/etcd-raw.txt | od -c        # k   8   s  \0
grep -a -c 'S3cr3t-f10' /opt/course/f10/etcd-raw.txt   # 1
kubectl -n vault-demo get secret db-cred -o jsonpath='{.data.password}' | base64 -d; echo   # S3cr3t-f10 (같은 값)
cat /opt/course/f10/password.txt; echo; cat /opt/course/f10/result.txt                     # S3cr3t-f10 / PLAINTEXT
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `etcdctl --endpoints https://127.0.0.1:2379 --cacert etcd/ca.crt --cert apiserver-etcd-client.crt --key apiserver-etcd-client.key get /registry/secrets/<ns>/<name>`. 앞부분이 `k8s:enc:` 가 아니면 평문이다.
- **헷갈리는 지점**: "Secret 은 base64 라서 안전하다" 는 오해입니다. etcd 에는 base64 도 아닌 원래 값이 들어가고, etcd 백업 파일이나 데이터 디렉터리를 가진 사람은 그대로 읽습니다. 그래서 `EncryptionConfiguration` 으로 저장 암호화를 켜고, etcd 파일 권한(`700`)과 백업 접근을 통제합니다.

## 참고 문서

- 검색어: `encrypting confidential data at rest`, `etcdctl`, `operating etcd`
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
- https://kubernetes.io/docs/concepts/security/secrets-good-practices/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q11 →](../q11_user_namespaces_hostusers_false/question.md)
