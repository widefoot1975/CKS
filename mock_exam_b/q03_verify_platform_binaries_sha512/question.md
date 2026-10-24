# q03 — Verify platform binaries and the kube-apiserver image

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q03_verify_platform_binaries_sha512
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/b03/bin/` 에 클러스터 버전과 같은 `kubectl`, `kubelet`, `kube-apiserver`(linux/amd64) 바이너리가 있고, `/opt/course/b03/sha512/` 에 dl.k8s.io 에서 받은 공식 `<이름>.sha512` 파일이 있다. 바이너리 중 일부는 setup 이 변조해 두었다.
dl.k8s.io 에서 약 250MB 를 받으므로 인터넷이 필요하다.

## Task

Someone copied Kubernetes binaries for the cluster's version into `/opt/course/b03/bin/`. The
official SHA512 checksums published by the Kubernetes project are in `/opt/course/b03/sha512/`
(one file `<binary>.sha512` per binary).

1. Verify every binary in `/opt/course/b03/bin/` against its official SHA512 checksum. Write the
   names of all binaries that do **not** match to `/opt/course/b03/mismatch.txt`, one per line,
   and delete those binaries. Keep the binaries that match.
2. Find the image digest of the container image that the running `kube-apiserver` Pod on
   `cks-c1` actually uses (the `sha256:` value the container runtime reports for the running
   container). Write only that `sha256:...` value to `/opt/course/b03/apiserver-digest.txt`.
3. Confirm with `crictl` that the same digest belongs to the image tag in the kube-apiserver
   manifest, and write that image reference (`registry/repository:tag`) to
   `/opt/course/b03/apiserver-image.txt`.

## My attempt

```bash

```

## Record

<!-- One row per attempt. Score = points earned (0 … Points). The first row is the mock exam itself; later rows are reviews. -->

| Date | Time (min) | Score | Note |
|---|---|---|---|
|  |  |  |  |

---

Solution → **[solution.md](solution.md)**

[↑ 문항 목록](../README.md) · [← q02](../q02_cis_etcd_kubelet_file_permissions/question.md) · [q04 →](../q04_rbac_find_excessive_bindings/question.md)
