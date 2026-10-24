# q03 — Verify platform binaries and the kube-apiserver image · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Someone copied Kubernetes binaries for the cluster's version into `/opt/course/b03/bin/`. The
> official SHA512 checksums published by the Kubernetes project are in `/opt/course/b03/sha512/`
> (one file `<binary>.sha512` per binary).
>
> 1. Verify every binary in `/opt/course/b03/bin/` against its official SHA512 checksum. Write the
>    names of all binaries that do **not** match to `/opt/course/b03/mismatch.txt`, one per line,
>    and delete those binaries. Keep the binaries that match.
> 2. Find the image digest of the container image that the running `kube-apiserver` Pod on
>    `cks-c1` actually uses (the `sha256:` value the container runtime reports for the running
>    container). Write only that `sha256:...` value to `/opt/course/b03/apiserver-digest.txt`.
> 3. Confirm with `crictl` that the same digest belongs to the image tag in the kube-apiserver
>    manifest, and write that image reference (`registry/repository:tag`) to
>    `/opt/course/b03/apiserver-image.txt`.

**해석**

누군가 클러스터 버전의 쿠버네티스 바이너리를 `/opt/course/b03/bin/` 에 복사해 두었다. 공식 SHA512 체크섬은 `/opt/course/b03/sha512/` 에
바이너리마다 `<이름>.sha512` 로 있다.

1. 모든 바이너리를 공식 SHA512 와 대조해 **일치하지 않는** 이름을 한 줄에 하나씩 `/opt/course/b03/mismatch.txt` 에 쓰고 그 바이너리를
   지운다. 일치하는 것은 남긴다.
2. 실행 중인 `kube-apiserver` Pod 가 실제로 쓰는 이미지의 다이제스트(런타임이 보고하는 `sha256:` 값)만
   `/opt/course/b03/apiserver-digest.txt` 에 쓴다.
3. `crictl` 로 그 다이제스트가 매니페스트에 적힌 이미지 태그의 것인지 확인하고, 그 이미지 참조(`레지스트리/저장소:태그`)를
   `/opt/course/b03/apiserver-image.txt` 에 쓴다.

## 모범 풀이

**1) 체크섬 대조**

```bash
sudo -i
cd /opt/course/b03
cat sha512/kubectl.sha512
# 3f1c...e9a2            ← 해시만 있고 파일 이름이 없다
ls -l bin/
```

> 함정 1: dl.k8s.io 의 `.sha512` 파일에는 **해시값만** 들어 있습니다. 그래서 `sha512sum -c sha512/kubectl.sha512` 는
> `no properly formatted checksum lines found` 로 실패합니다. `"<해시>  <파일>"`(공백 **두 칸**) 형식을 만들어 넘깁니다.

```bash
for b in bin/*; do
  n=$(basename "$b")
  echo "$(cat sha512/$n.sha512)  $b" | sha512sum --check --quiet >/dev/null 2>&1 \
    && echo "OK       $n" || { echo "MISMATCH $n"; echo "$n" >> mismatch.txt; }
done
# MISMATCH kube-apiserver
# OK       kubectl
# MISMATCH kubelet
cat mismatch.txt
xargs -I{} rm -f bin/{} < mismatch.txt
ls bin/
```

직접 비교하는 방법도 같습니다.

```bash
sha512sum bin/kubelet | cut -d' ' -f1
cat sha512/kubelet.sha512
```

> 함정 2: `ls -l` 의 **크기가 같다고 같은 파일이 아닙니다.** setup 은 한 바이너리 끝에 바이트를 덧붙이고(크기 변화), 다른 하나는
> 중간의 1바이트만 덮어써서 크기가 그대로입니다. 반드시 해시로 비교합니다. 같은 이유로 `kubectl version --client` 출력이 맞아도
> 변조 여부는 알 수 없습니다.

**2) 실행 중인 kube-apiserver 이미지 다이제스트**

```bash
kubectl -n kube-system get pod kube-apiserver-cks-c1 \
  -o jsonpath='{.spec.containers[0].image}{"\n"}{.status.containerStatuses[0].imageID}{"\n"}'
# registry.k8s.io/kube-apiserver:v1.35.0
# registry.k8s.io/kube-apiserver@sha256:9a4b...
kubectl -n kube-system get pod kube-apiserver-cks-c1 -o jsonpath='{.status.containerStatuses[0].imageID}' \
  | sed 's/.*@//' > /opt/course/b03/apiserver-digest.txt
cat /opt/course/b03/apiserver-digest.txt          # sha256:9a4b...
```

`imageID` 는 런타임이 **풀(pull)할 때 레지스트리에서 받은 매니페스트(대개 멀티 아키텍처 인덱스)의 다이제스트**입니다. `crictl images` 의
`IMAGE ID` 열(로컬 이미지 config 의 sha256 앞 13자리)과는 다른 값이므로 섞어 쓰지 않습니다.

**3) crictl 로 태그와 다이제스트 대조**

```bash
grep 'image:' /etc/kubernetes/manifests/kube-apiserver.yaml     # image: registry.k8s.io/kube-apiserver:v1.35.0
crictl images --digests | grep kube-apiserver
# IMAGE                            TAG       DIGEST         IMAGE ID       SIZE
# registry.k8s.io/kube-apiserver   v1.35.0   9a4b1c2d3e4f5  aa11bb22cc33   ...
crictl inspecti registry.k8s.io/kube-apiserver:v1.35.0 | grep -A2 repoDigests
#   "repoDigests": [ "registry.k8s.io/kube-apiserver@sha256:9a4b..." ]
CID=$(crictl ps --name kube-apiserver -q)
crictl inspect "$CID" | grep -E '"image"|imageRef' | head
grep 'image:' /etc/kubernetes/manifests/kube-apiserver.yaml | awk '{print $2}' > /opt/course/b03/apiserver-image.txt
```

`repoDigests` 의 sha256 이 2) 의 값과 같으면 "매니페스트의 태그 → 실제 실행 중인 이미지" 가 같은 내용이라는 뜻입니다. 레지스트리의 현재 값과
비교하고 싶다면 레지스트리 API 로 같은 태그의 다이제스트를 볼 수 있습니다(시험장에서는 인터넷이 막혀 있을 수 있음).

```bash
curl -sIL -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json' \
  https://registry.k8s.io/v2/kube-apiserver/manifests/v1.35.0 | grep -i docker-content-digest
```

| 확인 대상 | 방법 | 비교 기준 |
|---|---|---|
| 노드에 놓인 바이너리 | `sha512sum` | dl.k8s.io 의 `<binary>.sha512` |
| 실행 중인 컨테이너 이미지 | Pod `status.containerStatuses[].imageID`, `crictl inspecti` 의 `repoDigests` | 레지스트리 태그의 다이제스트 |
| 매니페스트 고정 | `image: ...@sha256:<digest>` | 태그가 바뀌어도 같은 내용 보장 |

## 검증

```bash
cd /opt/course/b03
cat mismatch.txt; ls bin/
for b in bin/*; do n=$(basename $b); echo "$(cat sha512/$n.sha512)  $b" | sha512sum -c; done   # 남은 것은 모두 OK
cat apiserver-digest.txt apiserver-image.txt
crictl inspecti "$(cat apiserver-image.txt)" | grep -c "$(cat apiserver-digest.txt)"          # 1 이상
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `echo "$(cat X.sha512)  X" | sha512sum -c` (공백 두 칸). 다운로드 경로 `https://dl.k8s.io/release/<ver>/bin/linux/amd64/<binary>(.sha512)`.
- **헷갈리는 지점**: sha256 과 sha512 파일이 둘 다 배포됩니다(`sha256sum` 과 짝을 맞출 것). 이미지 쪽은 `imageID`·`repoDigests`(레지스트리 다이제스트)와 `IMAGE ID`(로컬 config 해시)가 다른 값입니다. 바이너리를 "지우라"는 지시는 일치하지 않는 것만이며, 일치하는 것까지 지우면 감점입니다.

## 참고 문서

- 검색어: `install kubectl linux validate binary`, `container images digest`, `crictl`
- https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
- https://kubernetes.io/docs/concepts/containers/images/
- https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q04 →](../q04_rbac_find_excessive_bindings/question.md)
