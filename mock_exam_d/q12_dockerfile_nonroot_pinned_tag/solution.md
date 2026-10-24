# q12 — Pin the base image and run as non-root in a Dockerfile · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The image built from `/opt/course/d12/app/Dockerfile` uses a moving base image tag and runs as
> root.
>
> 1. Edit the Dockerfile: use the base image `docker.io/library/alpine:3.20` instead of the
>    `latest` tag, and make the container run as the non-root user with UID `10001` and GID
>    `10001` (numeric). Do not change other instructions.
> 2. Using `podman`, build the image with tag `d12-app:v1` from `/opt/course/d12/app/`.
> 3. Run `podman run --rm d12-app:v1` and write its output to `/opt/course/d12/run.txt`.

**해석**

`/opt/course/d12/app/Dockerfile` 로 만든 이미지는 바뀌는 베이스 이미지 태그를 쓰고 root 로 실행된다.

1. Dockerfile 을 고친다. `latest` 태그 대신 베이스 이미지 `docker.io/library/alpine:3.20` 을 쓰고, 컨테이너가 UID `10001`,
   GID `10001`(숫자)의 non-root 사용자로 실행되게 한다. 다른 명령은 바꾸지 않는다.
2. `podman` 으로 `/opt/course/d12/app/` 에서 태그 `d12-app:v1` 로 이미지를 빌드한다.
3. `podman run --rm d12-app:v1` 을 실행해 출력을 `/opt/course/d12/run.txt` 에 쓴다.

## 모범 풀이

**1) Dockerfile 수정**

```bash
cat /opt/course/d12/app/Dockerfile
# FROM docker.io/library/alpine:latest
# COPY app.sh /app/app.sh
# RUN chmod 0755 /app/app.sh
# USER root
# CMD ["/app/app.sh"]
vi /opt/course/d12/app/Dockerfile
```

```dockerfile
FROM docker.io/library/alpine:3.20
COPY app.sh /app/app.sh
RUN chmod 0755 /app/app.sh
USER 10001:10001
CMD ["/app/app.sh"]
```

`USER` 는 **마지막으로 나온 값**이 실행 사용자입니다. `USER root` 를 남긴 채 위에 `USER 10001` 을 추가하면 여전히 root 입니다.
숫자 UID 는 `/etc/passwd` 에 없어도 쓸 수 있고, 쿠버네티스의 `runAsNonRoot: true` 는 이미지 USER 가 **숫자**여야 non-root 인지
판단할 수 있으므로(`USER app` 처럼 이름이면 `CreateContainerConfigError`) 숫자로 적는 것이 좋습니다.
`chmod` 는 root 단계에서 끝났고 `0755` 라 UID 10001 도 실행할 수 있습니다.

| 태그 방식 | 재현성 | 비고 |
|---|---|---|
| `alpine` / `alpine:latest` | X | 빌드할 때마다 다른 이미지가 될 수 있다 |
| `alpine:3.20` | 보통 | 패치 버전은 계속 바뀐다 (3.20.x) |
| `alpine:3.20@sha256:...` | O | digest 고정, 가장 엄격 |

**2) 빌드**

```bash
podman build -t d12-app:v1 /opt/course/d12/app
podman image inspect d12-app:v1 --format '{{.Config.User}}'    # 10001:10001
```

**3) 실행**

```bash
podman run --rm d12-app:v1 > /opt/course/d12/run.txt
cat /opt/course/d12/run.txt         # app running as uid=10001 gid=10001
```

## 검증

```bash
grep -E '^(FROM|USER)' /opt/course/d12/app/Dockerfile      # FROM ...alpine:3.20 / USER 10001:10001 (한 번만)
podman images d12-app                                      # localhost/d12-app  v1
podman image inspect d12-app:v1 --format '{{.Config.User}}'
cat /opt/course/d12/run.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `FROM` 은 고정 태그(가능하면 digest), 마지막 `USER` 는 숫자 UID:GID.
- **헷갈리는 지점**: Dockerfile 의 `USER` 는 그 뒤의 `RUN` 에도 적용되므로 패키지 설치 같은 root 작업은 `USER` 앞에 둡니다. 쿠버네티스 `securityContext.runAsUser` 는 이미지 USER 를 덮어쓰지만, 이미지 자체를 non-root 로 만들어 두는 것이 공급망 쪽 방어입니다.

## 참고 문서

시험 중에는 podman/Dockerfile 문서를 열 수 없으므로 `podman build --help`, `podman image inspect --help` 로 확인합니다.

- 검색어: `images`, `image pull policy`, `security context runAsNonRoot`
- https://kubernetes.io/docs/concepts/containers/images/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q13 →](../q13_trivy_image_critical_count/question.md)
