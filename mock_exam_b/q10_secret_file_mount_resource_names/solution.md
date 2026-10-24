# q10 — Mount a Secret as a file and restrict access by resourceNames · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Deployment `api` in namespace `pay` reads its database password from an environment variable.
>
> 1. Change Deployment `api` so that the container no longer has the environment variable
>    `DB_PASSWORD`. Instead, mount Secret `db-cred` as a volume at `/etc/db` (read-only), with file
>    permissions `0400` for all files of the volume.
> 2. Make Secret `db-cred` immutable without changing its data.
> 3. Create a Role `db-cred-reader` and a RoleBinding `db-cred-reader` in namespace `pay` so that
>    ServiceAccount `api` can `get` the Secret `db-cred` and nothing else. Write the answers
>    (`yes`/`no`) of `kubectl auth can-i` for these three checks as ServiceAccount `api`, one per
>    line in this order, to `/opt/course/b10/can-i.txt`:
>    `get secret/db-cred`, `get secret/stripe-key`, `list secrets` (all in namespace `pay`).
> 4. Read the stored entry of Secret `db-cred` directly from etcd and write the raw output as a hex dump
>    (`hexdump -C`) to `/opt/course/b10/etcd-db-cred.txt`.

**해석**

`pay` 의 Deployment `api` 가 DB 비밀번호를 환경 변수로 읽는다.

1. 컨테이너에서 환경 변수 `DB_PASSWORD` 를 없애고, 대신 Secret `db-cred` 를 `/etc/db` 에 읽기 전용 볼륨으로 마운트한다. 볼륨의 모든 파일
   권한은 `0400`.
2. 데이터는 그대로 두고 Secret `db-cred` 를 immutable 로 만든다.
3. `pay` 에 Role·RoleBinding `db-cred-reader` 를 만들어 SA `api` 가 Secret `db-cred` 의 `get` 만 할 수 있게 한다. SA `api` 로 `get secret/db-cred`,
   `get secret/stripe-key`, `list secrets` 를 `kubectl auth can-i` 로 확인한 `yes`/`no` 를 순서대로 `/opt/course/b10/can-i.txt` 에 쓴다.
4. etcd 에서 Secret `db-cred` 의 저장 항목을 직접 읽어 원시 출력을 `hexdump -C` 형식으로 `/opt/course/b10/etcd-db-cred.txt` 에 쓴다.

## 모범 풀이

**1) 환경 변수 → 파일 마운트**

환경 변수는 `kubectl describe`/`exec env`, `/proc/<pid>/environ`, 크래시 덤프·자식 프로세스로 쉽게 새고 값이 바뀌어도 재시작 전까지 갱신되지
않습니다. 파일 마운트(tmpfs)는 권한으로 접근을 좁힐 수 있고 값 변경도 자동 반영됩니다(subPath 제외).

```bash
alias k=kubectl
k -n pay edit deploy api
```

```yaml
    spec:
      serviceAccountName: api
      containers:
      - name: api
        image: busybox:1.36
        command: ["sh", "-c", "echo started; sleep 1d"]
        # env: DB_PASSWORD 블록 삭제
        volumeMounts:
        - name: db-cred
          mountPath: /etc/db
          readOnly: true
      volumes:
      - name: db-cred
        secret:
          secretName: db-cred
          defaultMode: 0400          # YAML 8진수. JSON(patch)이라면 256
```

> 함정 1: `defaultMode` 는 정수입니다. YAML 은 `0400` 을 8진수로 읽지만 JSON 에는 8진수가 없어 `kubectl patch -p '{"...":0400}'` 은
> 오류이고 `"0400"`(문자열)도 거부됩니다. JSON 에서는 10진수 `256` 을 씁니다. `kubectl get -o yaml` 로 보면 `256` 으로 표시됩니다.

```bash
k -n pay rollout status deploy api
k -n pay exec deploy/api -- ls -lL /etc/db
# -r--------    1 root     root     ... password
# -r--------    1 root     root     ... username
k -n pay exec deploy/api -- env | grep DB_ || echo "no DB_ env"
```

마운트 경로의 파일은 `..data/` 로 가는 심볼릭 링크라 `ls -l` 은 `lrwxrwxrwx` 로 보입니다. 실제 권한은 `-L` 로 봅니다. 컨테이너가 root 가
아닌 UID 로 돈다면 `0400` 파일은 root 소유라 읽을 수 없으므로 `fsGroup` 을 주거나(이때 그룹 읽기 비트가 더해져 `0440`) 권한을 다시 설계해야 합니다.

**2) immutable**

```bash
k -n pay patch secret db-cred -p '{"immutable":true}'
k -n pay get secret db-cred -o jsonpath='{.immutable}{"\n"}'    # true
```

immutable 은 **되돌릴 수 없습니다.** 값을 바꾸려면 Secret 을 지우고 다시 만들어야 하고, 이미 마운트한 Pod 는 재시작해야 새 Secret 을 봅니다.
대신 kubelet 이 이 Secret 을 watch 하지 않아 apiserver 부하가 줄고 실수로 값을 바꾸는 일도 막습니다.

**3) resourceNames 로 하나의 Secret 만**

```bash
k -n pay create role db-cred-reader --verb=get --resource=secrets --resource-name=db-cred
k -n pay create rolebinding db-cred-reader --role=db-cred-reader --serviceaccount=pay:api
for c in "get secret/db-cred" "get secret/stripe-key" "list secrets"; do
  k auth can-i $c -n pay --as=system:serviceaccount:pay:api
done | tee /opt/course/b10/can-i.txt
# yes
# no
# no
```

> 함정 2: `resourceNames` 는 요청 URL 에 이름이 들어가는 동작(`get`, `update`, `patch`, `delete`)에만 의미가 있습니다. `list`/`watch` 는
> 이름 없이 컬렉션을 요청하므로 `resourceNames` 와 함께 주면 허용되지 않습니다(`fieldSelector=metadata.name=<이름>` 을 붙인 list/watch 만 허용).
> `create` 는 요청 시점에 이름을 알 수 없어 `resourceNames` 로 제한할 수 없습니다. 그래서 verb 는 `get` 하나만 줍니다.

**4) etcd 에서 직접 읽기**

```bash
# 호스트에 etcdctl 이 있으면
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key=/etc/kubernetes/pki/apiserver-etcd-client.key \
  get /registry/secrets/pay/db-cred | hexdump -C > /opt/course/b10/etcd-db-cred.txt

# 없으면 etcd Pod 안의 etcdctl (Pod 에는 /etc/kubernetes/pki/etcd 만 마운트돼 있다)
kubectl -n kube-system exec etcd-cks-c1 -- etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  get /registry/secrets/pay/db-cred | hexdump -C > /opt/course/b10/etcd-db-cred.txt

grep -A1 password /opt/course/b10/etcd-db-cred.txt
# 00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
# ...       6b 38 73 00 0a 0c 0a 02  76 31 12 06 53 65 63 72  |k8s.....v1..Secr|
# ...       ... 70 61 73 73 77 6f 72 64 12 0d 62 31 30 2d ...  |password..b10-S3|
```

키 경로는 `/registry/secrets/<namespace>/<name>` 입니다. 출력의 첫 부분은 키, 뒤는 값으로, 값은 `k8s\x00` 로 시작하는 **protobuf** 인코딩입니다.
`kubectl get secret -o yaml` 에서 보는 base64 는 API 응답의 표현일 뿐, etcd 에는 비밀번호가 **평문 바이트** 그대로 들어 있습니다(base64 조차
아님). 암호화를 켜면 값이 `k8s:enc:aescbc:v1:<키 이름>:` 로 시작합니다.

## 검증

```bash
k -n pay get deploy api -o jsonpath='{.spec.template.spec.containers[0].env}{"\n"}{.spec.template.spec.volumes}{"\n"}'
# (비어 있음)
# [{"name":"db-cred","secret":{"defaultMode":256,"secretName":"db-cred"}}]
k -n pay exec deploy/api -- cat /etc/db/password; echo
k -n pay patch secret db-cred -p '{"data":{"password":"eA=="}}'      # 거부: field is immutable when `immutable` is set
cat /opt/course/b10/can-i.txt
grep -c 'k8s' /opt/course/b10/etcd-db-cred.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `volumes[].secret.defaultMode: 0400`(JSON 은 256) + `volumeMounts[].readOnly: true`. `immutable: true` 는 단방향. `--resource-name` 은 get/update/patch/delete 에만.
- **헷갈리는 지점**: Secret 의 base64 는 암호화가 아닙니다. etcd 에 평문으로 저장되므로 etcd 접근 권한(etcd 클라이언트 인증서, 데이터 디렉터리, 백업 파일) 자체가 Secret 접근 권한입니다. secret·configMap·downwardAPI·projected 볼륨은 이미 읽기 전용으로 마운트되지만, 과제가 요구하면 `readOnly: true` 를 명시합니다.

## 참고 문서

- 검색어: `secrets`, `secrets good practices`, `rbac resourceNames`, `operating etcd`
- https://kubernetes.io/docs/concepts/configuration/secret/
- https://kubernetes.io/docs/concepts/security/secrets-good-practices/
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q11 →](../q11_user_namespaces_hostusers_false/question.md)
