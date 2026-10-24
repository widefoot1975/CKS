# q17 — Read-only root filesystem for an nginx Deployment · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> An attacker who gets into a container should not be able to change its files. Make the
> container of Deployment `cache` in namespace `pearl` immutable.
>
> 1. Set `readOnlyRootFilesystem: true` on container `nginx` of Deployment `cache`.
> 2. nginx still needs to write to `/var/cache/nginx` and `/var/run`. Mount an `emptyDir`
>    volume at each of these two paths. The Deployment's Pod must be `Running` and Ready.
> 3. Run `kubectl -n pearl exec deploy/cache -- touch /usr/share/nginx/html/hacked.html` and write
>    its complete output (stdout and stderr) to `/opt/course/d17/touch.txt`.

**해석**

컨테이너에 침입한 공격자가 파일을 바꿀 수 없어야 한다. namespace `pearl` 의 Deployment `cache` 컨테이너를 불변(immutable)으로 만든다.

1. Deployment `cache` 의 컨테이너 `nginx` 에 `readOnlyRootFilesystem: true` 를 설정한다.
2. nginx 는 `/var/cache/nginx` 와 `/var/run` 에는 계속 써야 한다. 두 경로에 각각 `emptyDir` 볼륨을 마운트한다. Deployment 의 Pod 는
   `Running` · Ready 여야 한다.
3. `kubectl -n pearl exec deploy/cache -- touch /usr/share/nginx/html/hacked.html` 를 실행해 출력 전체(stdout, stderr)를
   `/opt/course/d17/touch.txt` 에 쓴다.

## 모범 풀이

**1) · 2) Deployment 수정**

```bash
alias k=kubectl
k -n pearl edit deploy cache
```

```yaml
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        securityContext:
          readOnlyRootFilesystem: true     # 컨테이너 수준에만 있는 필드
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
```

```bash
k -n pearl rollout status deploy cache
k -n pearl logs deploy/cache | head
# ... 10-listen-on-ipv6-by-default.sh: info: can not modify /etc/nginx/conf.d/default.conf (read-only file system?)
# ... start worker processes
```

nginx 는 시작할 때 `/var/cache/nginx/client_temp` 같은 임시 디렉터리를 만들고 PID 파일을 `/var/run/nginx.pid`(alpine 에서는
`/var/run` → `/run` 심볼릭 링크)에 씁니다. 읽기 전용으로만 바꾸면
`mkdir() "/var/cache/nginx/client_temp" failed (30: Read-only file system)` 로 CrashLoopBackOff 가 납니다.
그래서 쓰기가 필요한 경로만 `emptyDir` 로 열어 줍니다. 엔트리포인트 스크립트의 `can not modify` 메시지는 정보성이라 무시해도 됩니다.

| 확인 | 결과 |
|---|---|
| `readOnlyRootFilesystem` 만 | CrashLoopBackOff (`Read-only file system`) |
| + `/var/cache/nginx` 만 | PID 파일 쓰기 실패로 계속 실패 |
| + `/var/cache/nginx`, `/var/run` | Running |

**3) 쓰기 차단 확인**

```bash
k -n pearl exec deploy/cache -- touch /usr/share/nginx/html/hacked.html > /opt/course/d17/touch.txt 2>&1
cat /opt/course/d17/touch.txt
# touch: /usr/share/nginx/html/hacked.html: Read-only file system
# command terminated with exit code 1
```

## 검증

```bash
k -n pearl get pod -l app=cache                                               # 1/1 Running, RESTARTS 0
k -n pearl get deploy cache -o jsonpath='{.spec.template.spec.containers[0].securityContext}{"\n"}'   # {"readOnlyRootFilesystem":true}
k -n pearl exec deploy/cache -- sh -c 'touch /var/cache/nginx/ok && echo cache writable'
k -n pearl exec deploy/cache -- wget -qO- http://localhost | head -4           # Welcome to nginx!
cat /opt/course/d17/touch.txt                                                 # Read-only file system
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 불변 컨테이너 = `readOnlyRootFilesystem: true` + 쓰기가 필요한 경로만 `emptyDir`. 어디에 쓰는지는 로그의 `Read-only file system` 경로로 찾는다.
- **헷갈리는 지점**: `readOnlyRootFilesystem` 은 Pod `securityContext` 에는 없고 컨테이너에만 있습니다. `/tmp` 를 쓰는 앱도 많아 `/tmp` 용 `emptyDir` 이 자주 필요합니다. `emptyDir` 은 Pod 가 지워지면 사라지므로 공격자가 남긴 파일도 재시작 시 사라집니다.

## 참고 문서

- 검색어: `configure a security context`, `readOnlyRootFilesystem`, `emptyDir`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/storage/volumes/#emptydir

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md)
