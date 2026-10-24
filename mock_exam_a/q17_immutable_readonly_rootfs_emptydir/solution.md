# q17 — Immutable Pods with read-only root filesystems · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Containers in namespace `glacier` must be immutable at runtime.
>
> 1. Change Deployment `glacier-web` so that container `nginx` has a read-only root
>    filesystem. nginx must still work: give it writable `emptyDir` volumes only at
>    `/var/cache/nginx`, `/var/run` and `/tmp`. The Pods must be `Running` and Ready and answer
>    HTTP requests on port `80`.
> 2. Write the output (stdout and stderr) of `touch /usr/share/nginx/html/hacked` executed in
>    container `nginx` of a `glacier-web` Pod to `/opt/course/a17/web-write-test.txt`.
> 3. Find every other Pod in `glacier` that is not immutable, meaning that at least one of its
>    containers or init containers runs privileged or does not have
>    `readOnlyRootFilesystem: true`. Write their names, one per line and sorted
>    alphabetically, to `/opt/course/a17/deleted.txt` and delete these Pods. Immutable Pods
>    must keep running.

**해석**

namespace `glacier` 의 컨테이너는 실행 중에 바뀌지 않아야(immutable) 한다.

1. Deployment `glacier-web` 의 컨테이너 `nginx` 가 읽기 전용 루트 파일시스템을 쓰게 바꾼다. nginx 가 계속 동작하도록 `/var/cache/nginx`,
   `/var/run`, `/tmp` 에만 쓰기 가능한 `emptyDir` 볼륨을 준다. Pod 는 `Running`·Ready 이고 80 포트에서 HTTP 에 응답해야 한다.
2. `glacier-web` Pod 의 `nginx` 컨테이너에서 실행한 `touch /usr/share/nginx/html/hacked` 출력(표준출력·표준에러)을 `/opt/course/a17/web-write-test.txt` 에 쓴다.
3. `glacier` 의 다른 Pod 중 immutable 이 아닌 것, 즉 컨테이너나 init 컨테이너 중 하나라도 privileged 로 돌거나 `readOnlyRootFilesystem: true` 가
   없는 Pod 를 모두 찾아 이름을 알파벳 순으로 한 줄씩 `/opt/course/a17/deleted.txt` 에 쓰고 삭제한다. immutable 한 Pod 는 계속 돌아야 한다.

## 모범 풀이

**1) glacier-web — readOnlyRootFilesystem + emptyDir 3개**

```bash
kubectl -n glacier edit deploy glacier-web
```

```yaml
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        securityContext:
          readOnlyRootFilesystem: true      # 컨테이너 수준에만 있는 필드
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
      - name: tmp
        emptyDir: {}
```

```bash
kubectl -n glacier rollout status deploy glacier-web
kubectl -n glacier logs deploy/glacier-web | head -5
# ... 10-listen-on-ipv6-by-default.sh: info: can not modify /etc/nginx/conf.d/default.conf (read-only file system?)   ← 정상
```

nginx 는 기동할 때 `/var/cache/nginx/client_temp` 같은 임시 디렉터리와 `/var/run/nginx.pid` 를 만듭니다. 볼륨 없이 읽기 전용으로만 바꾸면
`mkdir() "/var/cache/nginx/client_temp" failed (30: Read-only file system)` 으로 `CrashLoopBackOff` 가 됩니다.
`readOnlyRootFilesystem` 은 PodSecurityContext 에 없는 **컨테이너 전용** 필드라 Pod 수준에 쓰면 `unknown field` 로 거부됩니다.

**2) 쓰기 시험**

```bash
kubectl -n glacier exec deploy/glacier-web -c nginx -- touch /usr/share/nginx/html/hacked > /opt/course/a17/web-write-test.txt 2>&1 || true
cat /opt/course/a17/web-write-test.txt
# touch: /usr/share/nginx/html/hacked: Read-only file system
# command terminated with exit code 1
POD_IP=$(kubectl -n glacier get pod -l app=glacier-web -o jsonpath='{.items[0].status.podIP}')
kubectl -n glacier run curl-a17 --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- curl -s -o /dev/null -w '%{http_code}\n' http://$POD_IP   # 200
```

**3) immutable 이 아닌 Pod 찾기 — init 컨테이너까지**

```bash
kubectl -n glacier get pod -o json | jq -r '
  .items[]
  | select(.metadata.ownerReferences == null)
  | select([.spec.initContainers[]?, .spec.containers[]]
           | any(.securityContext.privileged == true or .securityContext.readOnlyRootFilesystem != true))
  | .metadata.name' | sort | tee /opt/course/a17/deleted.txt
# glacier-logger
# glacier-sidecar
# glacier-tool
kubectl -n glacier delete pod $(cat /opt/course/a17/deleted.txt)
```

jq 가 없으면 Pod 마다 확인합니다.

```bash
for p in glacier-cache glacier-tool glacier-logger glacier-sidecar; do
  echo "== $p"
  kubectl -n glacier get pod $p -o jsonpath='{range .spec.initContainers[*]}init {.name}: {.securityContext}{"\n"}{end}{range .spec.containers[*]}{.name}: {.securityContext}{"\n"}{end}'
done
```

| Pod | 상태 | 판정 |
|---|---|---|
| `glacier-cache` | 읽기 전용 + 쓰기는 emptyDir `/cache` | 유지 |
| `glacier-tool` | 읽기 전용이지만 **privileged** (mount 를 다시 rw 로 바꿀 수 있음) | 삭제 |
| `glacier-logger` | securityContext 없음, `/var/log/app.log` 를 루트 파일시스템에 씀 | 삭제 |
| `glacier-sidecar` | 메인은 읽기 전용, **init 컨테이너**가 쓰기 가능 | 삭제 |

`readOnlyRootFilesystem: true` 만 보고 `glacier-tool` 을 남기거나, `.spec.containers` 만 보고 `glacier-sidecar` 를 남기는 것이 함정입니다.
Deployment 소유 Pod 는 지워도 되살아나므로 대상에서 빼고(1번에서 고침), 단독 Pod 만 삭제합니다.

## 검증

```bash
kubectl -n glacier get pod                         # glacier-web-… 1/1 Running, glacier-cache 1/1 Running 만 남음
cat /opt/course/a17/deleted.txt                    # glacier-logger / glacier-sidecar / glacier-tool
grep -i 'read-only' /opt/course/a17/web-write-test.txt
kubectl -n glacier get deploy glacier-web -o jsonpath='{.spec.template.spec.containers[0].securityContext}{"\n"}{.spec.template.spec.containers[0].volumeMounts[*].mountPath}{"\n"}'
# {"readOnlyRootFilesystem":true}
# /var/cache/nginx /var/run /tmp
kubectl -n glacier exec deploy/glacier-web -- touch /tmp/ok && echo "/tmp writable (emptyDir)"
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: immutable 컨테이너 = `readOnlyRootFilesystem: true`(컨테이너 수준) + 앱이 쓰는 경로만 `emptyDir` + privileged 금지. nginx 는 `/var/cache/nginx`, `/var/run`(pid), `/tmp`.
- **헷갈리는 지점**: privileged 컨테이너는 루트 파일시스템을 다시 마운트할 수 있으므로 읽기 전용이어도 immutable 이 아닙니다. init·사이드카 컨테이너도 각각 설정이 필요합니다. 런타임 중 변경 탐지는 Falco(`Write below binary dir` 등 규칙)와 함께 씁니다.

## 참고 문서

- 검색어: `readOnlyRootFilesystem`, `security context`, `emptyDir`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/storage/volumes/#emptydir
- https://kubernetes.io/docs/concepts/security/pod-security-standards/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md)
