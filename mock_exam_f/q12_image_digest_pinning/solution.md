# q12 — Pin container images by digest · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Image tags are mutable. Deployment `api` in namespace `f12` must keep running exactly the image
> content it runs now, even if someone pushes a new image under the same tag.
>
> 1. Find the image digest that each running container of Deployment `api` actually uses and write
>    one line per container in the form `<container-name> <imageID>` (as reported in the Pod status)
>    to `/opt/course/f12/digests.txt`.
> 2. Change Deployment `api` so that both containers reference their image by digest only, in the
>    form `docker.io/library/<name>@sha256:<digest>` (no tag), using the digests from step 1.
> 3. Wait until the rollout is complete. All Pods of `api` must be `Running` and Ready.

**해석**

이미지 태그는 바뀔 수 있다. namespace `f12` 의 Deployment `api` 는 누군가 같은 태그로 새 이미지를 올려도 지금 돌고 있는 이미지 내용 그대로를 계속 써야 한다.

1. Deployment `api` 의 각 컨테이너가 실제로 쓰는 이미지 다이제스트를 찾아, 컨테이너마다 한 줄씩 `<컨테이너 이름> <imageID>`(Pod status 에 보이는 값)
   형식으로 `/opt/course/f12/digests.txt` 에 쓴다.
2. Deployment `api` 의 두 컨테이너가 1 단계의 다이제스트로 이미지를 참조하게 바꾼다. 형식은 `docker.io/library/<이름>@sha256:<다이제스트>` 이고 태그는 붙이지 않는다.
3. 롤아웃이 끝날 때까지 기다린다. `api` 의 모든 Pod 가 `Running`·Ready 여야 한다.

## 모범 풀이

**1) 실행 중인 이미지의 다이제스트 — Pod status 의 `imageID`**

```bash
alias k=kubectl
k -n f12 get pod -l app=api -o jsonpath='{range .items[0].status.containerStatuses[*]}{.name} {.imageID}{"\n"}{end}' \
  | tee /opt/course/f12/digests.txt
# sidecar docker.io/library/busybox@sha256:<64자리 16진수>
# web docker.io/library/nginx@sha256:<64자리 16진수>
```

`spec.containers[].image` 는 **요청한 이름**(태그)이고, `status.containerStatuses[].imageID` 는 런타임이 실제로 받은 이미지의
**레지스트리 다이제스트**입니다. 태그로 받은 multi-arch 이미지라면 이 값은 manifest list(index)의 다이제스트라서 노드 아키텍처와
상관없이 그대로 쓸 수 있습니다. `containerStatuses` 순서는 spec 순서와 다를 수 있으니 이름으로 짝을 맞춥니다.

같은 값을 노드에서 보려면 `crictl images --digests`, `crictl inspecti nginx:1.27-alpine | grep -A2 repoDigests` 를 씁니다.

**2) 다이제스트로 바꾸기**

```bash
WEB=$(awk '$1=="web"{print $2}' /opt/course/f12/digests.txt)
SIDE=$(awk '$1=="sidecar"{print $2}' /opt/course/f12/digests.txt)
echo $WEB $SIDE
k -n f12 set image deploy/api web=$WEB sidecar=$SIDE
```

`imageID` 가 이미 `docker.io/library/<이름>@sha256:...` 형식이라 그대로 넣으면 됩니다. `nginx:1.27-alpine@sha256:...` 처럼 태그와
다이제스트를 함께 쓰는 것도 문법상 허용되지만 이때도 다이제스트만 사용되므로, 이 문제는 태그 없이 쓰라고 했습니다.

| 참조 형식 | 고정 여부 |
|---|---|
| `nginx:1.27-alpine` | 태그 — 같은 이름으로 다른 내용이 올라올 수 있음 |
| `nginx:latest` / `nginx` | 가장 나쁨 — 매번 바뀜 |
| `docker.io/library/nginx@sha256:...` | 내용 주소 — 바이트가 같아야만 받음 |

**3) 롤아웃 확인**

```bash
k -n f12 rollout status deploy api
k -n f12 get pod -l app=api
```

## 검증

```bash
k -n f12 get deploy api -o jsonpath='{range .spec.template.spec.containers[*]}{.name} {.image}{"\n"}{end}'
# web docker.io/library/nginx@sha256:...
# sidecar docker.io/library/busybox@sha256:...
k -n f12 get pod -l app=api -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[*].imageID}{"\n"}{end}'
diff <(sort /opt/course/f12/digests.txt) \
     <(k -n f12 get pod -l app=api -o jsonpath='{range .items[0].status.containerStatuses[*]}{.name} {.imageID}{"\n"}{end}' | sort) && echo SAME
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 실제 다이제스트 = `kubectl get pod -o jsonpath='{.status.containerStatuses[*].imageID}'`. 고정 = `kubectl set image deploy/<d> <container>=<repo>@sha256:<digest>`.
- **헷갈리는 지점**: `crictl images` 의 `IMAGE ID` 열은 이미지 **config** 의 ID 라서 레지스트리 다이제스트가 아닙니다(`--digests` 를 줘야 레지스트리 다이제스트가 나옴). 다이제스트 고정은 내용을 고정할 뿐 취약점을 없애지 않으므로, 스캔과 주기적인 갱신이 함께 필요합니다.

## 참고 문서

- 검색어: `images digest`, `image pull policy`
- https://kubernetes.io/docs/concepts/containers/images/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_set/kubectl_set_image/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q13 →](../q13_trivy_config_manifest_scan/question.md)
