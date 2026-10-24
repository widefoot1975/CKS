# q13 — Fix manifests with kube-linter and kubesec · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The manifests in `/opt/course/b13/manifests/` must pass a security review before they are
> deployed to namespace `catalog`.
>
> 1. Run `kube-linter` on the directory `/opt/course/b13/manifests/` with **only** these checks:
>    `no-read-only-root-fs`, `run-as-non-root`, `unset-cpu-requirements`,
>    `unset-memory-requirements` and `latest-tag`. Save the output to
>    `/opt/course/b13/lint-before.txt`.
> 2. Fix both manifests so that this exact kube-linter run reports no findings. Rules:
>    - In `catalog.yaml` use the image `nginxinc/nginx-unprivileged:1.27-alpine` with container port
>      `8080`; the nginx server must still work with a read-only root filesystem.
>    - Keep the image and the command of `worker.yaml`.
>    - Containers must run with a numeric UID greater than `10000`, must not allow privilege
>      escalation and must drop all capabilities.
>    - Set CPU and memory requests and limits on every container.
>    Save the output of the final run to `/opt/course/b13/lint-after.txt`.
> 3. Scan `catalog.yaml` with `kubesec` and write only its score (a number) to
>    `/opt/course/b13/kubesec-score.txt`. The score must be at least `7`.
> 4. Apply both manifests. All Pods in namespace `catalog` must be `Running` and Ready.

**해석**

`/opt/course/b13/manifests/` 의 매니페스트를 `catalog` 에 배포하기 전에 보안 검토를 통과시켜야 한다.

1. `kube-linter` 를 **이 다섯 개 검사만** 켜서(`no-read-only-root-fs`, `run-as-non-root`, `unset-cpu-requirements`, `unset-memory-requirements`,
   `latest-tag`) 디렉터리에 돌리고 출력을 `/opt/course/b13/lint-before.txt` 에 저장한다.
2. 같은 실행이 아무것도 보고하지 않도록 두 매니페스트를 고친다. `catalog.yaml` 은 이미지 `nginxinc/nginx-unprivileged:1.27-alpine`, 포트 `8080`
   으로 바꾸고 읽기 전용 루트 파일시스템에서도 nginx 가 동작해야 한다. `worker.yaml` 의 이미지·명령은 유지한다. 컨테이너는 10000 보다 큰
   숫자 UID 로 돌고, 권한 상승 금지, 모든 capability 제거. 모든 컨테이너에 CPU·메모리 requests/limits. 마지막 실행 결과는 `lint-after.txt`.
3. `catalog.yaml` 을 `kubesec` 으로 스캔해 점수(숫자)만 `/opt/course/b13/kubesec-score.txt` 에 쓴다. 7 이상이어야 한다.
4. 두 매니페스트를 apply 한다. `catalog` 의 모든 Pod 가 `Running`·Ready 여야 한다.

## 모범 풀이

**1) 지정한 검사만 돌리기**

```bash
cd /opt/course/b13
kube-linter lint --help | grep -E 'include|do-not-auto-add-defaults'
kube-linter lint manifests/ --do-not-auto-add-defaults \
  --include no-read-only-root-fs,run-as-non-root,unset-cpu-requirements,unset-memory-requirements,latest-tag \
  > lint-before.txt 2>&1 || true
cat lint-before.txt
# manifests/catalog.yaml: (object: catalog/catalog apps/v1, Kind=Deployment) The container "web" is using an invalid container image, "nginx:latest". ... (check: latest-tag, ...)
# manifests/catalog.yaml: ... container "web" does not have a read-only root file system (check: no-read-only-root-fs, ...)
# manifests/catalog.yaml: ... container "web" is not set to runAsNonRoot (check: run-as-non-root, ...)
# manifests/catalog.yaml: ... container "web" has cpu request 0 (check: unset-cpu-requirements, ...)
# ...
# Error: found 9 lint errors
```

> 함정 1: `--include` 만 주면 **기본 검사 묶음에 추가**될 뿐이라 `no-anti-affinity`, `dangling-service` 같은 다른 기본 검사 결과도 섞여 나옵니다.
> "이 검사만"은 `--do-not-auto-add-defaults --include ...` 입니다. kube-linter 는 결과가 있으면 종료 코드 1 이므로 `|| true` 로 받습니다.

**2) 매니페스트 고치기**

`manifests/catalog.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: catalog
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:
          runAsNonRoot: true
          runAsUser: 10101
          runAsGroup: 10101
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
```

`manifests/worker.yaml` (이미지·명령 유지)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-worker
  namespace: catalog
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog-worker
  template:
    metadata:
      labels:
        app: catalog-worker
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo processing; sleep 30; done"]
        securityContext:
          runAsNonRoot: true
          runAsUser: 10102
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            cpu: 100m
            memory: 64Mi
```

> 함정 2: nginx-unprivileged 는 8080 에서 비 root 로 돌지만 PID 파일과 임시 디렉터리를 `/tmp` 에 씁니다. `readOnlyRootFilesystem: true` 만
> 켜면 `open() "/tmp/nginx.pid" failed (30: Read-only file system)` 로 CrashLoopBackOff 가 납니다. `/tmp` 에 `emptyDir` 를 마운트합니다.
> (공식 `nginx` 이미지라면 `/var/cache/nginx`, `/var/run` 도 필요하고 80 포트 때문에 root 가 필요합니다.)

```bash
kube-linter lint manifests/ --do-not-auto-add-defaults \
  --include no-read-only-root-fs,run-as-non-root,unset-cpu-requirements,unset-memory-requirements,latest-tag \
  > lint-after.txt 2>&1; echo "exit=$?"
cat lint-after.txt            # No lint errors found!
```

**3) kubesec 점수**

```bash
kubesec scan manifests/catalog.yaml | jq '.[0] | {score, critical: [.scoring.critical[]?.id]}'
# { "score": 9, "critical": [] }
kubesec scan manifests/catalog.yaml | jq '.[0].score' > kubesec-score.txt
cat kubesec-score.txt
```

kubesec 은 대부분의 항목을 **컨테이너 `securityContext`** 에서 찾습니다(`containers[] .securityContext .runAsNonRoot == true`). 그래서 Pod 수준에만
설정하면 점수가 덜 오를 수 있어 컨테이너 수준에 둡니다. 점수 항목 예: `ReadOnlyRootFilesystem`, `RunAsNonRoot`, `RunAsUser`(UID > 10000),
`LimitsCPU`/`LimitsMemory`/`RequestsCPU`/`RequestsMemory`, `CapDropAll` 등이 각 +1, `ServiceAccountName`·AppArmor 등은 더 큰 가점입니다. 반대로
`privileged`, `hostNetwork`, `CapSysAdmin` 등은 **critical**(음수)로 점수를 크게 깎습니다.

**4) 배포**

```bash
kubectl apply -f manifests/
kubectl -n catalog rollout status deploy catalog
kubectl -n catalog rollout status deploy catalog-worker
kubectl -n catalog get pod
```

## 검증

```bash
cat /opt/course/b13/lint-after.txt                      # No lint errors found!
grep -c 'check:' /opt/course/b13/lint-before.txt        # 0 보다 큼
cat /opt/course/b13/kubesec-score.txt                   # 7 이상
kubectl -n catalog get pod                              # 모두 1/1 Running
kubectl -n catalog exec deploy/catalog -- wget -qO- http://127.0.0.1:8080 | head -4    # Welcome to nginx!
kubectl -n catalog exec deploy/catalog -- id            # uid=10101
kubectl -n catalog exec deploy/catalog -- touch /x      # Read-only file system
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `kube-linter lint <dir> --do-not-auto-add-defaults --include a,b,c`. `kubesec scan <file> | jq '.[0].score'`. 읽기 전용 루트 FS 는 쓰기 경로마다 `emptyDir`.
- **헷갈리는 지점**: `latest-tag` 는 `:latest` 뿐 아니라 태그 없는 이미지도 문제로 봅니다. `unset-cpu-requirements` 는 requests 와 limits 를 모두 봅니다. kube-linter·kubesec 은 허용 문서가 아니므로 `kube-linter checks list`, `kube-linter lint --help`, `kubesec scan --help` 로 확인합니다.

## 참고 문서

- 검색어: `security context`, `resource management for pods and containers`, `pod security standards`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q14 →](../q14_vap_params_configmap_registries/question.md)
