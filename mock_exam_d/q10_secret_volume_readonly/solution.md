# q10 — Mount a Secret as a read-only volume · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Deployment `app` in namespace `topaz` receives Secret `db-cred` as environment variables.
> Environment variables leak easily (crash dumps, `env`, child processes), so switch to a file
> mount.
>
> 1. Remove the environment variables `DB_USER` and `DB_PASSWORD` from the container of
>    Deployment `app`.
> 2. Mount Secret `db-cred` as a volume named `db-cred` at `/etc/db-cred` in the container.
>    The mount must be read-only and every file must have mode `0400`.
> 3. After the rollout, write the output of `ls -lL /etc/db-cred` from the running Pod to
>    `/opt/course/d10/ls.txt`.

**해석**

namespace `topaz` 의 Deployment `app` 은 Secret `db-cred` 를 환경 변수로 받는다. 환경 변수는 크래시 덤프, `env`, 자식 프로세스 등으로
쉽게 새어 나가므로 파일 마운트로 바꾼다.

1. Deployment `app` 의 컨테이너에서 환경 변수 `DB_USER`, `DB_PASSWORD` 를 지운다.
2. Secret `db-cred` 를 이름이 `db-cred` 인 볼륨으로 컨테이너의 `/etc/db-cred` 에 마운트한다. 마운트는 읽기 전용이고 모든 파일의
   권한은 `0400` 이어야 한다.
3. 롤아웃이 끝나면 실행 중인 Pod 에서 `ls -lL /etc/db-cred` 의 출력을 `/opt/course/d10/ls.txt` 에 쓴다.

## 모범 풀이

**1) · 2) Deployment 수정**

```bash
alias k=kubectl
k -n topaz get deploy app -o yaml | sed -n '/containers:/,/dnsPolicy/p'     # env 의 secretKeyRef 확인
k -n topaz edit deploy app
```

```yaml
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
        # env: 블록(DB_USER, DB_PASSWORD) 통째로 삭제
        volumeMounts:
        - name: db-cred
          mountPath: /etc/db-cred
          readOnly: true
      volumes:
      - name: db-cred
        secret:
          secretName: db-cred
          defaultMode: 0400        # YAML 에서 0 으로 시작하면 8진수 (= 10진수 256)
```

```bash
k -n topaz rollout status deploy app
```

`defaultMode` 는 JSON 에서는 8진수를 쓸 수 없어 `256` 처럼 10진수로 적어야 합니다. YAML 에서는 `0400` 을 8진수로 읽으므로
그대로 써도 되고, `k get -o yaml` 로 다시 보면 `256` 으로 표시됩니다. 키별로 다르게 주려면 `items[].mode` 를 씁니다.
Secret·ConfigMap·projected 볼륨은 kubelet 이 이미 읽기 전용으로 마운트하지만, 매니페스트에 `readOnly: true` 를 명시해
의도를 드러내고 감사·정책 도구(kubesec, kube-linter)가 확인할 수 있게 합니다.

| 방식 | 값 갱신 | 노출 경로 |
|---|---|---|
| `env.valueFrom.secretKeyRef` | Pod 재시작 전까지 그대로 | `env`, `/proc/<pid>/environ`, 로그·덤프, 자식 프로세스 |
| `secret` 볼륨 | kubelet 이 주기적으로 갱신 (`subPath` 제외) | 파일 권한으로 제한 가능 |

**3) 확인 결과 저장**

```bash
k -n topaz exec deploy/app -- ls -lL /etc/db-cred > /opt/course/d10/ls.txt
cat /opt/course/d10/ls.txt
# total 8
# -r--------    1 root     root            11 ... password
# -r--------    1 root     root             3 ... username
```

`-L` 이 없으면 `..data/...` 를 가리키는 심볼릭 링크(`lrwxrwxrwx`)만 보입니다. 실제 파일 권한은 링크를 따라가야 보입니다.

## 검증

```bash
k -n topaz exec deploy/app -- sh -c 'env | grep DB_ || echo "no DB_ env"'     # no DB_ env
k -n topaz exec deploy/app -- cat /etc/db-cred/username; echo                  # app
k -n topaz exec deploy/app -- sh -c 'touch /etc/db-cred/x'                     # Read-only file system
k -n topaz get deploy app -o jsonpath='{.spec.template.spec.volumes[0]}{"\n"}' # "defaultMode":256
cat /opt/course/d10/ls.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `volumes[].secret.secretName` + `defaultMode: 0400` + `volumeMounts[].readOnly: true`. 확인은 `ls -lL`.
- **헷갈리는 지점**: `envFrom.secretRef` 로 통째로 넣은 경우도 같은 위험이 있습니다. 컨테이너가 non-root 이면 `0400`(root 소유) 파일을 읽지 못하므로 `fsGroup` 과 `0440` 을 같이 쓰거나 `runAsUser` 를 맞춥니다. Secret 은 etcd 에 base64 일 뿐 암호화가 아니므로 EncryptionConfiguration 은 별도입니다.

## 참고 문서

- 검색어: `secrets`, `using secrets as files from a pod`, `secrets good practices`
- https://kubernetes.io/docs/concepts/configuration/secret/
- https://kubernetes.io/docs/concepts/security/secrets-good-practices/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q11 →](../q11_runtimeclass_gvisor_pod/question.md)
