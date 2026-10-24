# q11 — Run an untrusted workload in a gVisor RuntimeClass

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q11_runtimeclass_gvisor_sandbox
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 `cks-c1-w1` 에는 gVisor(`runsc`)가 설치되어 있고 containerd 에 런타임 핸들러 `runsc` 가 등록되어 있다(없을 때만 gVisor apt 저장소에서 설치하므로 인터넷 필요). 워커에는 라벨 `sandbox.cks.io/gvisor=true` 가 있다.
namespace `sandbox` 에는 일반 runc 로 도는 Deployment `untrusted-render`(nginx, replicas 2)가 있고, RuntimeClass 는 없다. gVisor 와 containerd 설정은 다른 문항도 쓰므로 `cleanup.sh` 가 지우지 않는다.

## Task

Deployment `untrusted-render` in namespace `sandbox` processes untrusted input and must run
in a gVisor sandbox. The container runtime on `cks-c1-w1` has a handler named `runsc`.

1. Create a RuntimeClass `gvisor` for this handler. Using the RuntimeClass itself (not the
   Deployment), make sure Pods that use it are only scheduled to nodes labeled
   `sandbox.cks.io/gvisor=true`.
2. Change Deployment `untrusted-render` to use RuntimeClass `gvisor`. Both replicas must be
   `Running`.
3. Write the output of `dmesg` executed in one of its containers to
   `/opt/course/a11/dmesg.txt`, and the name of the node that Pod runs on to
   `/opt/course/a11/node.txt`.

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

[↑ 문항 목록](../README.md) · [← q10](../q10_etcd_encryption_at_rest_rewrite/question.md) · [q12 →](../q12_dockerfile_minimize_kubesec/question.md)
