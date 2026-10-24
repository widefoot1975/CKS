# q14 — Fix misconfigurations reported by trivy config · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The directory `/opt/course/c14/` contains a `Dockerfile` and the Kubernetes manifest
> `k8s/deploy.yaml`. Use Trivy's misconfiguration scanner on the whole directory.
>
> 1. Write the number of `HIGH` and `CRITICAL` misconfigurations Trivy reports for the directory
>    (both files together) to `/opt/course/c14/before.txt` (just the number).
> 2. Fix the `Dockerfile` so that Trivy reports no `HIGH` or `CRITICAL` misconfiguration. The image
>    must still be based on Ubuntu (use tag `24.04`) and still install `curl`.
> 3. Fix `k8s/deploy.yaml` so that Trivy reports no `HIGH` or `CRITICAL` misconfiguration. Use image
>    `nginxinc/nginx-unprivileged:1.27-alpine` (listens on port `8080`). Do not use host namespaces,
>    host paths or privileged mode. Give the container CPU and memory requests and limits.
> 4. Apply `k8s/deploy.yaml`. Deployment `report` in namespace `reports` must have all replicas
>    Ready.
> 5. Write the new number of `HIGH` and `CRITICAL` misconfigurations to `/opt/course/c14/after.txt`.

**해석**

`/opt/course/c14/` 에 `Dockerfile` 과 쿠버네티스 매니페스트 `k8s/deploy.yaml` 이 있다. 디렉터리 전체에 Trivy 의 설정 오류(misconfiguration) 검사를 쓴다.

1. 두 파일을 합쳐 Trivy 가 보고하는 `HIGH`·`CRITICAL` 설정 오류 개수를 `/opt/course/c14/before.txt` 에 숫자만 쓴다.
2. `Dockerfile` 을 고쳐 `HIGH`·`CRITICAL` 이 없게 한다. 베이스는 Ubuntu(태그 `24.04`)이고 `curl` 은 계속 설치한다.
3. `k8s/deploy.yaml` 을 고쳐 `HIGH`·`CRITICAL` 이 없게 한다. 이미지는 `nginxinc/nginx-unprivileged:1.27-alpine`(포트 8080). 호스트
   namespace·hostPath·privileged 는 쓰지 않고, 컨테이너에 CPU·메모리 requests/limits 를 준다.
4. `k8s/deploy.yaml` 을 적용한다. `reports` 의 Deployment `report` 레플리카가 모두 Ready 여야 한다.
5. 새 `HIGH`·`CRITICAL` 개수를 `/opt/course/c14/after.txt` 에 쓴다.

## 모범 풀이

**1) 처음 검사와 개수**

```bash
cd /opt/course/c14
trivy config --severity HIGH,CRITICAL .
trivy config --severity HIGH,CRITICAL -f json . | jq '[.Results[]?.Misconfigurations[]?] | length' | tee /opt/course/c14/before.txt
```

JSON 의 `Misconfigurations` 에는 기본적으로 **실패한 항목만** 들어가므로 길이가 곧 개수입니다(`--include-non-failures` 를 주면 통과
항목도 들어가 숫자가 틀어집니다). 출력 예(Trivy 규칙 버전에 따라 ID·심각도가 조금 다를 수 있습니다):

| 파일 | 대표 항목 | 원인 |
|---|---|---|
| Dockerfile | DS002 (HIGH) | 마지막 `USER` 가 root |
| Dockerfile | DS029 (HIGH) | `apt-get install` 에 `--no-install-recommends` 없음 |
| deploy.yaml | KSV017 (HIGH) | `privileged: true` |
| deploy.yaml | KSV009 (HIGH) | `hostNetwork: true` |
| deploy.yaml | KSV006 (HIGH) | `/var/run/docker.sock` hostPath |
| deploy.yaml | KSV014, KSV118 (HIGH) | 읽기 전용 루트 FS 아님, 기본 security context 사용 |

**2) Dockerfile**

```dockerfile
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN groupadd -g 10001 app && useradd -u 10001 -g app -M -s /usr/sbin/nologin app
COPY --chown=10001:10001 app.sh /app.sh
USER 10001:10001
HEALTHCHECK CMD curl -fs http://localhost:8080/ || exit 1
ENTRYPOINT ["/app.sh"]
```

`:latest` 대신 고정 태그(DS001), 캐시 정리, 마지막 `USER` 를 non-root 숫자로, `HEALTHCHECK`(DS026, LOW)까지 넣으면 낮은 등급도 함께 사라집니다.

**3) deploy.yaml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report
  namespace: reports
spec:
  replicas: 2
  selector:
    matchLabels:
      app: report
  template:
    metadata:
      labels:
        app: report
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: report
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false
          privileged: false
          readOnlyRootFilesystem: true
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

`hostNetwork`, `privileged`, docker.sock hostPath 를 지웠습니다. `readOnlyRootFilesystem: true` 로 바꾸면 nginx-unprivileged 가
`/tmp` 에 pid 파일과 임시 디렉터리를 만들어야 하므로 `/tmp` 에 emptyDir 를 붙이지 않으면 CrashLoopBackOff 가 됩니다(함정).
UID 를 10000 넘게 하라는 LOW 항목(KSV020/021)은 이번 기준(HIGH 이상) 밖이고, 이미지의 기본 사용자 101 을 그대로 씁니다.

**4) 적용과 재검사**

```bash
kubectl apply -f k8s/deploy.yaml
kubectl -n reports rollout status deploy report
trivy config --severity HIGH,CRITICAL -f json . | jq '[.Results[]?.Misconfigurations[]?] | length' | tee /opt/course/c14/after.txt   # 0
```

## 검증

```bash
trivy config --severity HIGH,CRITICAL --exit-code 1 /opt/course/c14 >/dev/null; echo rc=$?    # rc=0
kubectl -n reports get deploy report                                    # 2/2
kubectl -n reports exec deploy/report -- touch /x 2>&1 | head -1         # Read-only file system
kubectl -n reports exec deploy/report -- wget -qO- localhost:8080 | head -3
cat /opt/course/c14/before.txt /opt/course/c14/after.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `trivy config <디렉터리>` 는 Dockerfile·쿠버네티스 YAML·Helm·Terraform 을 함께 검사한다. `--severity` 로 거르고 `--exit-code 1` 로 CI 게이트를 만든다.
- **헷갈리는 지점**: `trivy image` 는 취약점(CVE), `trivy config` 는 설정 오류입니다. `readOnlyRootFilesystem` 을 켜면 앱이 쓰는 경로(`/tmp`, 캐시)에 emptyDir 가 필요합니다. Dockerfile 은 **마지막** `USER` 만 봅니다.

## 참고 문서

시험 중에는 Trivy 문서를 열 수 없으므로 `trivy config --help` 로 확인합니다.

- 검색어: `security context`, `pod security standards`, `resource management for pods`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q15 →](../q15_falco_macro_list_append_exceptions/question.md)
