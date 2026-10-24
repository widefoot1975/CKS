# q11 — Run a Deployment in a user namespace

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q11_user_namespaces_hostusers_false
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `tenant` 에 Deployment `sandbox`(replicas 1, busybox, 컨테이너 안에서 root 로 `sleep` 실행, `hostNetwork: true`, 워커 `cks-c1-w1` 에 고정)가 있다.
user namespace 를 쓰려면 워커가 Linux 6.3 이상, containerd 2.0 이상(runc 1.2 이상)이어야 한다. setup 이 노드의 커널·런타임 버전을 출력하고 조건이 안 되면 경고한다.

## Task

Deployment `sandbox` in namespace `tenant` runs its container as root. Root inside the container
must not be root on the node.

1. Change Deployment `sandbox` so that its Pod runs in its own user namespace instead of the host
   user namespace. Make any other change that is required for the Pod to be accepted, but keep the
   image, the command and the node placement. The Pod must be `Running`.
2. Write the content of `/proc/self/uid_map` as seen inside the container to
   `/opt/course/b11/uid_map.txt`.
3. On `cks-c1-w1`, find the UID with which the container's `sleep` process runs on the host and
   write only that number to `/opt/course/b11/host-uid.txt` on `cks-c1`.

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

[↑ 문항 목록](../README.md) · [← q10](../q10_secret_file_mount_resource_names/question.md) · [q12 →](../q12_sbom_bom_trivy_sbom/question.md)
