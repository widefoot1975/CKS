# q11 — Run a Deployment in a user namespace

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q11_user_namespaces_hostusers_false
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `f11` 에 Deployment `isolated`(busybox, 컨테이너 `sleeper`, replicas 1)가 `Running` 이고, 컨테이너 안의 root(UID 0)는 노드의 root 와 같다. `/opt/course/f11/` 는 비어 있다.
user namespace 를 쓰려면 노드가 Linux 커널 6.3 이상, containerd 2.0 이상(runc 1.2 이상)이어야 한다. v1.33 부터 기능 게이트 `UserNamespacesSupport` 는 기본으로 켜져 있다.

## Task

The process in Deployment `isolated` runs as root. If it escapes the container it must not be root
on the node.

1. Change Deployment `isolated` in namespace `f11` so that its Pods run in their own user namespace
   instead of the host user namespace. Do not change the image, the command or the user inside the
   container.
2. When the new Pod is `Running`, write the content of `/proc/self/uid_map` as seen inside the
   container to `/opt/course/f11/uid_map.txt`.
3. On the node where the Pod runs, find the host UID of the container's `sleep` process and write
   only the number to `/opt/course/f11/host_uid.txt` on `cks-c1`.

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

[↑ 문항 목록](../README.md) · [← q10](../q10_etcdctl_read_secret_plaintext/question.md) · [q12 →](../q12_image_digest_pinning/question.md)
