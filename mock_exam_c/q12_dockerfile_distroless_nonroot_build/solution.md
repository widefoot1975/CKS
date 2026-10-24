# q12 — Build a distroless non-root Go image · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The Go web service in `/opt/course/c12/app/` is packaged in a large image that runs as root.
> Do not change `main.go` or `go.mod`.
>
> 1. Rewrite `/opt/course/c12/app/Dockerfile` as a multi-stage build:
>    - build stage named `build` from `docker.io/library/golang:1.26-alpine` that compiles a
>      statically linked binary (`CGO_ENABLED=0`)
>    - final stage from `gcr.io/distroless/static-debian12:nonroot` that contains only the binary
>    - the final image runs as numeric user and group `65532:65532` and starts the binary with an
>      exec-form `ENTRYPOINT`
> 2. Build the image with `podman` and tag it `c12-app:v2`. The image must be smaller than 20 MB.
> 3. Save the image as a docker-archive to `/opt/course/c12/c12-app-v2.tar`.
> 4. Scan the archive with Trivy for `HIGH` and `CRITICAL` vulnerabilities. There must be none.
>    Write the Trivy table output to `/opt/course/c12/trivy.txt`.
> 5. Run the image as container `c12-test` with host port `18080` mapped to container port `8080`,
>    write the response of `curl -s http://localhost:18080/` to `/opt/course/c12/curl.txt`, then
>    remove the container.

**해석**

`/opt/course/c12/app/` 의 Go 웹 서비스가 root 로 실행되는 큰 이미지로 패키징되어 있다. `main.go`, `go.mod` 는 고치지 않는다.

1. `/opt/course/c12/app/Dockerfile` 을 멀티 스테이지로 다시 쓴다.
   - 빌드 단계 이름은 `build`, 베이스 `docker.io/library/golang:1.26-alpine`, 정적 링크 바이너리(`CGO_ENABLED=0`)를 컴파일
   - 최종 단계는 `gcr.io/distroless/static-debian12:nonroot`, 바이너리만 포함
   - 최종 이미지는 숫자 사용자·그룹 `65532:65532` 로 실행되고 exec 형식 `ENTRYPOINT` 로 바이너리를 시작
2. `podman` 으로 빌드해 `c12-app:v2` 태그를 붙인다. 이미지는 20 MB 미만이어야 한다.
3. docker-archive 로 `/opt/course/c12/c12-app-v2.tar` 에 저장한다.
4. 아카이브를 Trivy 로 `HIGH`·`CRITICAL` 취약점 검사한다. 하나도 없어야 한다. Trivy 표 출력을 `/opt/course/c12/trivy.txt` 에 쓴다.
5. 컨테이너 `c12-test` 로 실행(호스트 18080 → 컨테이너 8080)하고 `curl -s http://localhost:18080/` 응답을 `/opt/course/c12/curl.txt` 에 쓴 뒤 컨테이너를 지운다.

## 모범 풀이

**1) 기존 Dockerfile 의 문제**

```bash
cat /opt/course/c12/app/Dockerfile
# FROM golang:1.24                 ← 컴파일러·셸·apt 가 다 든 수백 MB 이미지, 짧은 이름
# WORKDIR /src
# COPY . .
# RUN go build -o /usr/local/bin/app .
# EXPOSE 8080
# CMD /usr/local/bin/app           ← 셸 형식 (distroless 에는 /bin/sh 가 없음), USER 없음 = root
```

**2) 멀티 스테이지 Dockerfile**

```dockerfile
FROM docker.io/library/golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/app .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app"]
```

| 결정 | 이유 |
|---|---|
| `CGO_ENABLED=0` | `static` distroless 에는 libc 가 없음. 동적 링크 바이너리는 `exec /app: no such file or directory` 로 실패 |
| `static-debian12:nonroot` | 셸·패키지 관리자 없음, 기본 사용자 nonroot(65532). 공격 표면과 CVE 대상 패키지가 거의 없음 |
| `USER 65532:65532` (숫자) | 쿠버네티스 `runAsNonRoot: true` 는 이름(`nonroot`)으로는 root 여부를 확인할 수 없어 거부함 → 숫자로 명시 |
| exec 형식 `ENTRYPOINT ["/app"]` | 셸 형식은 `/bin/sh -c` 가 필요 — distroless 에 셸이 없음. 신호(SIGTERM)도 앱이 직접 받음 |
| `-trimpath -ldflags="-s -w"` | 빌드 경로·디버그 심볼 제거로 크기 감소 |
| 정확한 이미지 이름 | podman short-name 해석 프롬프트/오인 방지 |

**3) 빌드 · 크기 확인 · 저장**

```bash
cd /opt/course/c12/app
podman build -t c12-app:v2 .
podman image inspect c12-app:v2 --format '{{.Size}}'            # 예: 8–10 MB (바이트 단위 숫자)
podman images c12-app
podman save -o /opt/course/c12/c12-app-v2.tar c12-app:v2        # 기본 형식 docker-archive
```

**4) Trivy 검사 (아카이브 입력)**

```bash
trivy --version                                                  # Version: 0.69.3
trivy image --input /opt/course/c12/c12-app-v2.tar --severity HIGH,CRITICAL | tee /opt/course/c12/trivy.txt
trivy image --input /opt/course/c12/c12-app-v2.tar --severity HIGH,CRITICAL --exit-code 1 -q >/dev/null && echo CLEAN
```

Trivy 는 OS 패키지뿐 아니라 Go 바이너리에 박힌 **Go 표준 라이브러리 버전**도 검사합니다. 지원이 끝난 Go 마이너(예: 1.24)로 빌드하면
OS 패키지가 없어도 `stdlib` HIGH 가 잡힐 수 있어서, 지원 중인 `1.26` 의 최신 패치 이미지로 빌드합니다. 그래도 잡히면 `podman pull`
로 최신 패치를 받아 다시 빌드합니다. `--input` 은 레지스트리나 데몬 없이 tar 를 직접 검사합니다.

**5) 실행 확인**

```bash
podman run -d --name c12-test -p 18080:8080 c12-app:v2
curl -s http://localhost:18080/ | tee /opt/course/c12/curl.txt     # c12 app ok
podman exec c12-test id 2>&1 | head -1                             # 셸·id 바이너리 없음 → 실행 실패 (정상)
podman inspect c12-test --format '{{.Config.User}}'               # 65532:65532
podman rm -f c12-test
```

## 검증

```bash
grep -E '^FROM|^USER|^ENTRYPOINT' /opt/course/c12/app/Dockerfile
podman image inspect c12-app:v2 --format '{{.Size}} {{.Config.User}} {{.Config.Entrypoint}}'   # < 20000000, 65532:65532, [/app]
tar -tf /opt/course/c12/c12-app-v2.tar | grep manifest.json
trivy image --input /opt/course/c12/c12-app-v2.tar --severity HIGH,CRITICAL --exit-code 1 -q >/dev/null; echo rc=$?   # rc=0
cat /opt/course/c12/trivy.txt                                       # 표에 HIGH/CRITICAL 행이 없어야 한다
cat /opt/course/c12/curl.txt
podman ps -a --filter name=c12-test                                # 없음
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 빌드 단계(컴파일러) / 실행 단계(바이너리만) 분리, `CGO_ENABLED=0` + `static` distroless, `USER 65532:65532`, exec 형식 `ENTRYPOINT`.
- **헷갈리는 지점**: distroless 는 셸이 없어서 `RUN`, 셸 형식 `CMD`, `podman exec ... sh` 가 모두 안 됩니다(디버깅은 `:debug` 태그). `static` 대신 `base` 변형은 glibc 가 있어 cgo 바이너리도 돌지만 더 큽니다. Trivy 버전은 고정해서 씁니다(v0.69.4 악성 릴리스 사례).

## 참고 문서

시험 중에는 podman·Trivy 문서를 열 수 없으므로 `podman build --help`, `trivy image --help` 로 확인합니다.

- 검색어: `images`, `security context runAsNonRoot`, `pod security standards`
- https://kubernetes.io/docs/concepts/containers/images/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q13 →](../q13_imagepolicywebhook_admission_config/question.md)
