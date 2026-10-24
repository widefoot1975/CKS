# q11 — Run a Pod in gVisor with a RuntimeClass

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q11_runtimeclass_gvisor_pod
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 노드 `cks-c1-w1` 에 gVisor(`runsc`)가 설치되어 있고, containerd 에 `runsc` 라는 런타임 핸들러가 등록되어 있다. 컨트롤 플레인 `cks-c1` 에는 없다.
`runsc` 가 없으면 setup 이 gVisor apt 저장소로 설치하고 containerd 를 재시작하므로 인터넷이 필요하고 몇 분 걸릴 수 있다. cleanup 은 gVisor 를 지우지 않는다.
namespace `onyx` 는 비어 있고 RuntimeClass `gvisor` 는 아직 없다.

## Task

Worker node `cks-c1-w1` has the gVisor runtime installed; containerd exposes it as the runtime
handler `runsc`. The control-plane node does not have it.

1. Create a RuntimeClass `gvisor` that uses the handler `runsc`.
2. Create a Pod `sandboxed` in namespace `onyx` with image `nginx:1.27-alpine` that runs with
   RuntimeClass `gvisor` on node `cks-c1-w1`.
3. Write the output of `dmesg` run inside Pod `sandboxed` to `/opt/course/d11/dmesg.txt`.

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

[↑ 문항 목록](../README.md) · [← q10](../q10_secret_volume_readonly/question.md) · [q12 →](../q12_dockerfile_nonroot_pinned_tag/question.md)
