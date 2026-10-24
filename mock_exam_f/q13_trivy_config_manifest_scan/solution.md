# q13 — Fix Trivy misconfiguration findings in a manifest · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Before Deployment `catalog` goes live, its manifest must pass a misconfiguration scan.
>
> 1. Scan the directory `/opt/course/f13/manifests/` with `trivy config`, reporting only `HIGH` and
>    `CRITICAL` findings, and write the output to `/opt/course/f13/before.txt`.
> 2. Edit `/opt/course/f13/manifests/deploy.yaml` in place so that the same scan reports no `HIGH`
>    or `CRITICAL` findings. Keep the Deployment name, namespace, image and container port. The
>    container needs a writable `/tmp`.
> 3. Run the scan again, write the output to `/opt/course/f13/after.txt`, then apply the manifest.
>    The Pod of `catalog` must be `Running` and Ready.

**해석**

Deployment `catalog` 를 운영에 올리기 전에 매니페스트가 설정 오류 스캔을 통과해야 한다.

1. `/opt/course/f13/manifests/` 디렉터리를 `trivy config` 로 스캔하되 `HIGH`·`CRITICAL` 만 보고하게 하고, 출력을 `/opt/course/f13/before.txt` 에 쓴다.
2. `/opt/course/f13/manifests/deploy.yaml` 을 제자리에서 고쳐 같은 스캔에서 `HIGH`·`CRITICAL` 이 하나도 없게 한다. Deployment 이름, namespace,
   이미지, 컨테이너 포트는 유지한다. 컨테이너는 쓰기 가능한 `/tmp` 가 필요하다.
3. 다시 스캔해 출력을 `/opt/course/f13/after.txt` 에 쓰고 매니페스트를 적용한다. `catalog` 의 Pod 는 `Running`·Ready 여야 한다.

## 모범 풀이

**1) 처음 스캔**

```bash
trivy config --severity HIGH,CRITICAL /opt/course/f13/manifests/ | tee /opt/course/f13/before.txt
# deploy.yaml (kubernetes)
# Tests: ... (SUCCESSES: .., FAILURES: 3)
# Failures: 3 (HIGH: 3, CRITICAL: 0)
#
# KSV010 (HIGH): Deployment 'catalog' should not set 'spec.template.spec.hostPID' to true
# KSV014 (HIGH): Container 'catalog' of Deployment 'catalog' should set 'securityContext.readOnlyRootFilesystem' to true
# KSV017 (HIGH): Container 'catalog' of Deployment 'catalog' should set 'securityContext.privileged' to false
# (버전에 따라 KSV118 "default security context" 등 항목·번호 표기가 조금 다를 수 있다)
```

`trivy config` 는 이미지가 아니라 **IaC 파일**(Kubernetes YAML, Dockerfile, Helm, Terraform 등)의 설정 오류를 검사합니다.
취약점 DB 가 아니라 검사 규칙 번들(trivy-checks)을 쓰며, 각 항목 아래에 어느 줄이 문제인지 표시됩니다.

**2) 매니페스트 고치기**

```yaml
# /opt/course/f13/manifests/deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: f13
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
      # hostPID: true 삭제                      ← KSV010
      securityContext:
        runAsNonRoot: true
        runAsUser: 101                          # 이미지의 nginx 사용자
        runAsGroup: 101
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: catalog
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:
          privileged: false                     # ← KSV017
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true          # ← KSV014
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
          mountPath: /tmp                       # nginx-unprivileged 는 pid·임시 파일을 /tmp 에 쓴다
      volumes:
      - name: tmp
        emptyDir: {}
```

HIGH 만 없애면 되지만, MEDIUM/LOW 항목(권한 상승, capability, seccomp, 리소스 제한)도 함께 넣는 편이 실제 운영에서 안전하고 다음 스캔에서도 깨끗합니다.
`readOnlyRootFilesystem: true` 를 넣으면 쓰기가 필요한 경로를 `emptyDir` 로 열어 줘야 컨테이너가 뜹니다.

**3) 다시 스캔하고 적용**

```bash
trivy config --severity HIGH,CRITICAL /opt/course/f13/manifests/ | tee /opt/course/f13/after.txt
# Failures: 0 (HIGH: 0, CRITICAL: 0)
trivy config --severity HIGH,CRITICAL --exit-code 1 /opt/course/f13/manifests/ >/dev/null && echo CLEAN
kubectl apply -f /opt/course/f13/manifests/deploy.yaml
kubectl -n f13 rollout status deploy catalog
```

## 검증

```bash
grep -E 'Failures' /opt/course/f13/before.txt /opt/course/f13/after.txt
kubectl -n f13 get pod -l app=catalog                                  # 1/1 Running
kubectl -n f13 exec deploy/catalog -- touch /etc/x 2>&1 | tail -1      # Read-only file system
kubectl -n f13 exec deploy/catalog -- wget -qO- localhost:8080 | head -4   # Welcome to nginx!
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `trivy config --severity HIGH,CRITICAL <dir>` — 이미지 스캔(`trivy image`)과 구분한다. 결과의 KSV 번호와 메시지가 고칠 필드를 그대로 알려 준다.
- **헷갈리는 지점**: Trivy 검사는 HIGH/CRITICAL 이 남아 있어도 기본 종료 코드가 0 입니다. CI 처럼 판정이 필요하면 `--exit-code 1` 을 줍니다. `readOnlyRootFilesystem` 만 켜고 `/tmp` 볼륨을 안 주면 Pod 가 `CrashLoopBackOff` 가 됩니다. Trivy 는 시험 허용 문서에 없으므로 `trivy config --help` 로 옵션을 확인합니다.

## 참고 문서

시험 중에는 Trivy 문서를 열 수 없으므로 `trivy config --help` 로 확인합니다.

- 검색어: `security context`, `pod security standards`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q14 →](../q14_kubesec_deployment_score/question.md)
