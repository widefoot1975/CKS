# q12 — Harden a Dockerfile and raise a Deployment's kubesec score · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The image and manifest of application `a12-app` violate several supply chain rules.
>
> 1. Rewrite `/opt/course/a12/app/Dockerfile` as a multi-stage build:
>    - build stage `docker.io/library/golang:1.24-alpine`, building a static binary
>      (`CGO_ENABLED=0`) from `main.go`
>    - final stage `scratch` that contains only the binary
>    - no `ENV` or `ARG` with the API token, and no `curl` or `wget` in the final image
>    - the final image runs as user and group `65532` (numeric)
> 2. Build it with `podman` as `localhost/a12-app:v2`.
> 3. Run `kubesec scan` on `/opt/course/a12/deploy.yaml` and note the score. Then fix the
>    manifest so that the scan reports no critical findings and a score of at least `7`:
>    remove privileged mode and host networking, use image `localhost/a12-app:v2`, read
>    `API_TOKEN` from key `token` of Secret `a12-api` instead of a literal value, use
>    ServiceAccount `a12-app`, run as non-root user `65532` with a read-only root filesystem,
>    no privilege escalation and all capabilities dropped, and set CPU and memory requests
>    and limits. Do not apply the manifest.
> 4. Write the scores to `/opt/course/a12/kubesec.txt` in the form `before: <n>` and
>    `after: <n>` (two lines).

**해석**

애플리케이션 `a12-app` 의 이미지와 매니페스트가 공급망 규칙을 여러 개 어기고 있다.

1. `/opt/course/a12/app/Dockerfile` 을 멀티 스테이지 빌드로 다시 쓴다.
   - 빌드 스테이지 `docker.io/library/golang:1.24-alpine` 에서 `main.go` 로 정적 바이너리(`CGO_ENABLED=0`)를 빌드
   - 최종 스테이지 `scratch` 에는 바이너리만
   - API 토큰을 담은 `ENV`·`ARG` 금지, 최종 이미지에 `curl`·`wget` 금지
   - 최종 이미지는 사용자·그룹 `65532`(숫자)로 실행
2. `podman` 으로 `localhost/a12-app:v2` 로 빌드한다.
3. `/opt/course/a12/deploy.yaml` 에 `kubesec scan` 을 실행해 점수를 적어 둔다. 그다음 critical 항목이 없고 점수가 7 이상이 되도록 매니페스트를 고친다.
   privileged 와 host 네트워크 제거, 이미지 `localhost/a12-app:v2`, `API_TOKEN` 은 리터럴 대신 Secret `a12-api` 의 키 `token` 에서 읽기,
   ServiceAccount `a12-app`, UID `65532` 비 root + 읽기 전용 루트 파일시스템 + 권한 상승 금지 + capability 전부 제거, CPU·메모리 requests 와 limits.
   매니페스트는 적용하지 않는다.
4. 점수를 `before: <n>`, `after: <n>` 두 줄로 `/opt/course/a12/kubesec.txt` 에 쓴다.

## 모범 풀이

**1) 원래 Dockerfile 의 문제**

```bash
cat /opt/course/a12/app/Dockerfile
# FROM docker.io/library/golang:latest              ← 태그 고정 안 됨, 컴파일러가 든 거대한 이미지가 그대로 런타임
# ENV API_TOKEN=tok-a12-9f8e7d                      ← 비밀이 이미지 설정·history 에 영구히 남음
# RUN apt-get update && apt-get install -y curl wget  ← 공격 도구
# (USER 없음)                                        ← root 로 실행
```

**2) 멀티 스테이지로 다시 쓰기**

```dockerfile
# build stage
FROM docker.io/library/golang:1.24-alpine AS build
WORKDIR /src
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/app main.go

# final stage
FROM scratch
COPY --from=build /out/app /usr/local/bin/app
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/app"]
```

```bash
cd /opt/course/a12/app
podman build -t localhost/a12-app:v2 .
podman image inspect localhost/a12-app:v2 --format '{{.Config.User}} {{.Config.Env}}'   # 65532:65532 [PATH=...]  (토큰 없음)
podman history localhost/a12-app:v2 | grep -i token || echo "no token in history"
CID=$(podman create localhost/a12-app:v2); podman export $CID | tar -t; podman rm $CID    # usr/local/bin/app 과 빈 디렉터리 몇 개뿐 (셸·curl·wget 없음)
podman images localhost/a12-app                                                         # 수 MB
```

| 규칙 | 왜 |
|---|---|
| 멀티 스테이지 | 컴파일러·소스·빌드 캐시가 최종 이미지에 남지 않음 → 크기·CVE·공격면 감소 |
| 태그 고정(`1.24-alpine`, `3.20`) | `latest` 는 빌드할 때마다 내용이 바뀌어 재현 불가. 더 엄격하게는 `@sha256:` 다이제스트 |
| `CGO_ENABLED=0` | libc 에 링크되지 않은 정적 바이너리 → distroless/scratch 에서도 실행 |
| 비밀을 ENV/ARG 에 두지 않음 | `podman inspect`, `podman history` 로 누구나 읽음. 런타임에 Secret 으로 주입 |
| 숫자 `USER` | `scratch` 에는 `/etc/passwd` 가 없어 이름으로는 사용자를 찾을 수 없고, `runAsNonRoot: true` 일 때 kubelet 도 이름(`USER app`)으로는 비 root 인지 판단하지 못함 |
| `scratch` 최종 이미지 | 셸·패키지 관리자·`wget`(alpine 의 busybox 에도 들어 있음)이 아예 없음. 정적 바이너리라서 가능 |

빌드 스테이지에 ENV 를 넣어도 최종 스테이지에는 안 넘어가지만, 빌드 스테이지 이미지가 캐시·레지스트리에 남으면 같은 문제가
생기므로 아예 넣지 않습니다.

**3) kubesec — 고치기 전 점수**

```bash
kubesec scan /opt/course/a12/deploy.yaml | tee /tmp/a12-before.json | head -30
jq '.[0].score' /tmp/a12-before.json            # 음수 (예: -39)
jq -r '.[0].scoring.critical[]?.id' /tmp/a12-before.json
# Privileged
# HostNetwork
```

**매니페스트 수정**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: a12-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: a12-app
  template:
    metadata:
      labels:
        app: a12-app
    spec:
      serviceAccountName: a12-app            # hostNetwork: true 삭제
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
      containers:
      - name: app
        image: localhost/a12-app:v2
        env:
        - name: API_TOKEN
          valueFrom:
            secretKeyRef:
              name: a12-api
              key: token
        securityContext:                     # privileged: true 삭제
          runAsNonRoot: true
          runAsUser: 65532
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
          limits:
            cpu: 200m
            memory: 64Mi
```

```bash
kubesec scan /opt/course/a12/deploy.yaml | tee /tmp/a12-after.json | jq '.[0] | {score, critical: .scoring.critical}'
# { "score": 10 이상, "critical": null 또는 [] }
printf 'before: %s\nafter: %s\n' "$(jq '.[0].score' /tmp/a12-before.json)" "$(jq '.[0].score' /tmp/a12-after.json)" > /opt/course/a12/kubesec.txt
cat /opt/course/a12/kubesec.txt
```

kubesec 은 critical 항목(privileged, hostNetwork/hostPID/hostIPC, `SYS_ADMIN` 추가 등)이 하나라도 있으면 점수를 크게 깎고, 좋은 설정마다
점수를 더합니다(예: `readOnlyRootFilesystem`, `runAsNonRoot`, `runAsUser` > 10000, `capabilities.drop`, requests/limits 각각,
`serviceAccountName`). UID 를 10000 이하로 주면 `runAsUser` 가점을 못 받습니다. jq 가 없으면 `kubesec scan … | grep '"score"'` 로 봅니다.

## 검증

```bash
cat /opt/course/a12/kubesec.txt                                                   # before: -NN / after: 7 이상
kubesec scan /opt/course/a12/deploy.yaml | jq '.[0].scoring.critical | length'    # 0 (또는 null)
grep -nE 'privileged|hostNetwork|value: tok' /opt/course/a12/deploy.yaml || echo "clean"
grep -cE '^FROM' /opt/course/a12/app/Dockerfile                                   # 2
grep -nE 'latest|ENV|ARG|curl|wget' /opt/course/a12/app/Dockerfile || echo "clean"
podman image inspect localhost/a12-app:v2 --format '{{.Config.User}}'             # 65532:65532
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 빌드 스테이지(`AS build`) → `COPY --from=build` → 최소 베이스 → 숫자 `USER`. 비밀은 이미지가 아니라 Secret(`secretKeyRef`)으로.
- **헷갈리는 지점**: `ENV` 를 나중 레이어에서 지워도 history 에 남습니다. kubesec 점수는 critical 이 하나라도 있으면 음수가 되므로 먼저 critical 을 없애고 가점 항목을 채웁니다. `readOnlyRootFilesystem` 을 켜면 앱이 쓰는 경로에 emptyDir 이 필요할 수 있습니다(이 앱은 쓰지 않음).

## 참고 문서

kubesec·podman 문서는 시험 중 열 수 없으므로 `kubesec scan --help`, `podman build --help` 를 씁니다.

- 검색어: `security context`, `secrets environment variables`, `images`
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/configuration/secret/
- https://kubernetes.io/docs/concepts/containers/images/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q13 →](../q13_trivy_scan_delete_critical/question.md)
