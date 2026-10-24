# q13 — Scan workload images with Trivy and stop the CRITICAL ones · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The security team does not allow images with known `CRITICAL` vulnerabilities in namespace
> `kobra`.
>
> 1. Using `trivy`, scan every image used by the Pods in namespace `kobra` (all containers,
>    including init containers) for vulnerabilities of severity `CRITICAL`.
> 2. Write every image that has at least one `CRITICAL` vulnerability, one per line, sorted
>    alphabetically, exactly as written in the Pod spec, to
>    `/opt/course/a13/critical-images.txt`.
> 3. Stop every workload that uses such an image: scale Deployments to `0` replicas (do not
>    delete them) and delete standalone Pods. Workloads whose images have no `CRITICAL`
>    vulnerability must keep running.

**해석**

보안팀은 namespace `kobra` 에 `CRITICAL` 취약점이 알려진 이미지를 허용하지 않는다.

1. `trivy` 로 `kobra` 의 Pod 가 쓰는 모든 이미지(init 컨테이너 포함 모든 컨테이너)를 `CRITICAL` 심각도로 스캔한다.
2. `CRITICAL` 취약점이 하나라도 있는 이미지를 Pod spec 에 적힌 그대로, 알파벳 순으로 한 줄씩 `/opt/course/a13/critical-images.txt` 에 쓴다.
3. 그런 이미지를 쓰는 워크로드를 모두 멈춘다. Deployment 는 지우지 말고 레플리카 0 으로, 단독 Pod 는 삭제한다.
   `CRITICAL` 이 없는 이미지의 워크로드는 계속 돌아야 한다.

## 모범 풀이

**1) 이미지 목록 — init 컨테이너까지**

```bash
kubectl -n kobra get pod -o jsonpath='{range .items[*]}{range .spec.initContainers[*]}{.image}{"\n"}{end}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' \
  | sort -u | tee /tmp/a13-images.txt
# busybox:1.36.1
# httpd:2.4.39
# nginx:1.19.0
# python:3.7.0-slim
# registry.k8s.io/pause:3.10
```

`kubectl get pod -o wide` 나 `.spec.containers[*].image` 만 보면 init 컨테이너 이미지(`python:3.7.0-slim`)를 놓칩니다. 누가 어떤 이미지를
쓰는지도 같이 봐 둡니다.

```bash
kubectl -n kobra get pod -o custom-columns='POD:.metadata.name,OWNER:.metadata.ownerReferences[0].kind,INIT:.spec.initContainers[*].image,IMAGES:.spec.containers[*].image'
```

**2) Trivy 스캔**

```bash
trivy --version                                     # Version: 0.69.3
for i in $(cat /tmp/a13-images.txt); do
  n=$(trivy image --quiet --severity CRITICAL --format json "$i" | jq '[.Results[]?.Vulnerabilities[]?] | length')
  echo "$n $i"
done
# 0   busybox:1.36.1
# 12  httpd:2.4.39               (숫자는 DB 날짜에 따라 다름)
# 30  nginx:1.19.0
# 25  python:3.7.0-slim
# 0   registry.k8s.io/pause:3.10
```

jq 가 없으면 이미지마다 `trivy image --severity CRITICAL -q <이미지> | grep Total` 로 봅니다. 첫 실행은 DB 를 받느라 시간이 걸리고,
이후에는 `~/.cache/trivy` 캐시를 씁니다. DB 가 한 번도 없는데 `--skip-db-update` 를 주면 실패합니다. `--exit-code 1` 은 취약점이 있을
때뿐 아니라 이미지를 못 받아도 0 이 아닌 값을 돌려주므로 판정에는 개수를 직접 세는 편이 안전합니다.
busybox·pause 처럼 패키지 DB 가 없는 이미지는 Trivy 가 OS 를 감지하지 못해 0 으로 나옵니다(취약점이 없다는 증명은 아니지만, 문제 기준으로는 "CRITICAL 없음").

```bash
printf '%s\n' httpd:2.4.39 nginx:1.19.0 python:3.7.0-slim | sort > /opt/course/a13/critical-images.txt
```

**3) 워크로드 멈추기 — 소유자를 보고 처리**

```bash
kubectl -n kobra get deploy -o custom-columns='NAME:.metadata.name,INIT:.spec.template.spec.initContainers[*].image,IMAGES:.spec.template.spec.containers[*].image'
# kobra-web      <none>              busybox:1.36.1
# kobra-api      <none>              nginx:1.19.0          ← 멈춤
# kobra-report   python:3.7.0-slim   busybox:1.36.1        ← init 때문에 멈춤
# kobra-pause    <none>              registry.k8s.io/pause:3.10
kubectl -n kobra scale deploy kobra-api kobra-report --replicas=0
kubectl -n kobra delete pod kobra-debug          # httpd:2.4.39, ownerReferences 없음 = 단독 Pod
```

Deployment 가 만든 Pod 를 `kubectl delete pod` 로 지우면 ReplicaSet 이 바로 새 Pod 를 만듭니다. 문제는 Deployment 를 **0 으로 scale** 하라고 했습니다.
`kobra-report` 는 메인 컨테이너가 안전한 busybox 지만 init 컨테이너가 취약 이미지라서 대상입니다.

## 검증

```bash
cat /opt/course/a13/critical-images.txt          # httpd:2.4.39 / nginx:1.19.0 / python:3.7.0-slim
kubectl -n kobra get deploy                       # kobra-api 0/0, kobra-report 0/0, kobra-web 1/1, kobra-pause 1/1
kubectl -n kobra get pod                          # kobra-web-…, kobra-pause-… 만
kubectl -n kobra get pod -o jsonpath='{range .items[*]}{.spec.initContainers[*].image} {.spec.containers[*].image}{"\n"}{end}' | grep -E 'nginx:1.19|httpd|python' || echo "clean"
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 이미지 수집(`initContainers` + `containers`) → `trivy image --severity CRITICAL -q` → 소유자 확인 → Deployment 는 scale 0, 단독 Pod 는 delete.
- **헷갈리는 지점**: Trivy 결과는 DB 갱신에 따라 바뀌므로 시험에서는 그 시점의 결과가 정답입니다. 컨트롤러 소유 Pod 를 지우면 되살아납니다. 결과 파일에는 Pod spec 에 적힌 이미지 문자열을 그대로 씁니다(`docker.io/library/` 를 붙이지 않음).

## 참고 문서

Trivy 문서는 시험 중 열 수 없으므로 `trivy image --help` 를 씁니다.

- 검색어: `images`, `kubectl jsonpath`, `list all container images running in a cluster`
- https://kubernetes.io/docs/tasks/access-application-cluster/list-all-running-container-images/
- https://kubernetes.io/docs/reference/kubectl/jsonpath/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q14 →](../q14_vap_permitted_registries_no_latest/question.md)
