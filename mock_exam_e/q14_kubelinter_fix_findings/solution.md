# q14 — Fix KubeLinter findings in a Deployment manifest · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Manifest `/opt/course/e14/catalog.yaml` must pass a KubeLinter review before it is deployed.
> Use exactly these checks: `latest-tag`, `privileged-container`, `run-as-non-root`,
> `no-read-only-root-fs` (and no default checks).
>
> 1. Lint the manifest with only these four checks and save the complete output to
>    `/opt/course/e14/before.txt`.
> 2. Fix `/opt/course/e14/catalog.yaml` in place: use image
>    `nginxinc/nginx-unprivileged:1.27-alpine` with container port `8080`, remove the
>    privileged mode, run as non-root with UID `101`, make the root filesystem read-only and
>    mount an `emptyDir` volume at `/tmp` so that nginx can start.
> 3. Run the same lint command again; it must exit with code `0`. Save its output to
>    `/opt/course/e14/after.txt`. Then apply the manifest; the Pod must be `Running`.

**해석**

매니페스트 `/opt/course/e14/catalog.yaml` 은 배포 전에 KubeLinter 검토를 통과해야 한다. 검사는 정확히 `latest-tag`, `privileged-container`,
`run-as-non-root`, `no-read-only-root-fs` 네 가지만 쓴다(기본 검사는 쓰지 않는다).

1. 이 네 가지 검사로만 매니페스트를 lint 하고 전체 출력을 `/opt/course/e14/before.txt` 에 저장한다.
2. `/opt/course/e14/catalog.yaml` 을 직접 고친다. 이미지 `nginxinc/nginx-unprivileged:1.27-alpine`·컨테이너 포트 `8080`, privileged 제거,
   UID `101` 의 비 root 실행, 읽기 전용 루트 파일시스템, nginx 가 뜰 수 있게 `/tmp` 에 `emptyDir` 마운트.
3. 같은 lint 명령을 다시 실행해 종료 코드 `0` 이어야 하고, 출력을 `/opt/course/e14/after.txt` 에 저장한다. 그다음 매니페스트를 적용해 Pod 가 `Running` 이어야 한다.

## 모범 풀이

**1) 지정한 검사만 실행**

```bash
kube-linter lint --help | grep -E 'include|do-not-auto-add-defaults'
kube-linter checks list | grep -E '^Name: (latest-tag|privileged-container|run-as-non-root|no-read-only-root-fs)'
kube-linter lint /opt/course/e14/catalog.yaml --do-not-auto-add-defaults \
  --include latest-tag,privileged-container,run-as-non-root,no-read-only-root-fs \
  > /opt/course/e14/before.txt 2>&1; echo "exit=$?"
cat /opt/course/e14/before.txt
# /opt/course/e14/catalog.yaml: (object: lint/catalog apps/v1, Kind=Deployment) The container "catalog" is using an invalid container image, "nginx:latest". ... (check: latest-tag, remediation: ...)
# ... container "catalog" does not have a read-only root file system (check: no-read-only-root-fs, ...)
# ... container "catalog" is privileged (check: privileged-container, ...)
# ... container "catalog" is not set to runAsNonRoot (check: run-as-non-root, ...)
# Error: found 4 lint errors
# exit=1
```

`--include` 만 쓰면 기본 검사 묶음에 **더해서** 실행됩니다. 기본 검사를 빼려면 `--do-not-auto-add-defaults` 가 필요합니다. 결과 요약
`Error: found N lint errors` 는 stderr 로 나오므로 `2>&1` 로 함께 저장합니다.

**2) 매니페스트 수정**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: lint
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
      containers:
      - name: catalog
        image: nginxinc/nginx-unprivileged:1.27-alpine    # latest-tag 해결
        ports:
        - containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false                 # privileged: true 삭제
          readOnlyRootFilesystem: true                    # no-read-only-root-fs 해결
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
```

`nginx-unprivileged` 이미지는 8080 에서 대기하고, pid 파일과 임시 디렉터리(`client_temp` 등)를 `/tmp` 아래에 씁니다. 루트 FS 를 읽기 전용으로
만들면 이 경로만 `emptyDir` 로 쓰기 가능하게 열어 주면 됩니다. 공식 `nginx` 이미지라면 `/var/cache/nginx`, `/var/run` 도 필요하고 80 포트·root 가 필요해
`run-as-non-root` 를 만족시키기 어렵습니다.

**3) 재검사와 배포**

```bash
kube-linter lint /opt/course/e14/catalog.yaml --do-not-auto-add-defaults \
  --include latest-tag,privileged-container,run-as-non-root,no-read-only-root-fs \
  > /opt/course/e14/after.txt 2>&1; echo "exit=$?"
cat /opt/course/e14/after.txt          # No lint errors found!
# exit=0
kubectl apply -f /opt/course/e14/catalog.yaml
kubectl -n lint rollout status deploy catalog
```

| 검사 | 걸리는 조건 | 고치는 법 |
|---|---|---|
| `latest-tag` | 이미지 태그가 `latest` | 고정 태그(또는 다이제스트) |
| `privileged-container` | `securityContext.privileged: true` | 삭제 또는 `false` |
| `run-as-non-root` | `runAsNonRoot: true` 도, `runAsUser > 0` 도 없음 | Pod/컨테이너 `runAsNonRoot`·`runAsUser` |
| `no-read-only-root-fs` | `readOnlyRootFilesystem` 이 true 가 아님 | `true` + 쓰기 경로는 `emptyDir` |

## 검증

```bash
cat /opt/course/e14/before.txt | grep -c 'check:'        # 4
cat /opt/course/e14/after.txt                             # No lint errors found!
kubectl -n lint get pod -l app=catalog                    # 1/1 Running
kubectl -n lint exec deploy/catalog -- id                 # uid=101(nginx)
kubectl -n lint exec deploy/catalog -- touch /etc/x       # Read-only file system
kubectl -n lint exec deploy/catalog -- wget -qO- http://127.0.0.1:8080 | grep -o '<title>.*</title>'   # Welcome to nginx!
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `kube-linter lint <파일|디렉터리> --do-not-auto-add-defaults --include a,b,c` (반대는 `--exclude`). 검사 이름은 `kube-linter checks list`.
- **헷갈리는 지점**: 종료 코드 1 = lint 오류 있음. `readOnlyRootFilesystem` 만 켜고 `/tmp` 를 안 열면 lint 는 통과해도 nginx 가 `mkdir() "/tmp/client_temp" failed (30: Read-only file system)` 로 CrashLoop 합니다 — lint 통과와 실제 동작은 따로 확인해야 합니다. KubeLinter 문서는 시험 허용 목록에 없으니 `--help` 와 `checks list` 를 씁니다.

## 참고 문서

시험 중에는 `kube-linter lint --help`, `kube-linter checks list` 로 확인합니다.

- 검색어: `security context readOnlyRootFilesystem`, `runAsNonRoot`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q15 →](../q15_falco_rule_output_change/question.md)
