# q11 — Enable Cilium WireGuard transparent encryption

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q11_cilium_wireguard_encryption
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

setup 은 Cilium 이 Helm 릴리스 `kube-system/cilium` 으로 설치되어 있는지 확인하고(아니면 멈춘다), 현재 릴리스 정보와 values 를 `/opt/course/c11/before.txt` 에 기록한다.
클러스터는 바꾸지 않는다. `helm` 이 필요하고, 차트를 받기 위해 `helm.cilium.io` 로 인터넷 연결이 필요하며, 노드 커널이 WireGuard 를 지원해야 한다(5.6 이상).
**정리할 때 암호화 설정은 되돌리지 않는다**(켜 두어도 다른 문제에 영향이 없다. 되돌리는 방법은 풀이에 있다).

## Task

Pod-to-Pod traffic between the nodes of the cluster must be encrypted. The CNI Cilium was
installed with Helm as release `cilium` in namespace `kube-system`.

1. Enable Cilium transparent encryption with type `wireguard` by upgrading the Helm release
   `cilium`. Keep all values that are currently set and keep the currently installed chart
   version.
2. Make sure that every Cilium agent Pod runs with the new configuration and is Ready.
3. Write the line containing `Encryption` from `cilium-dbg status` of the Cilium agent running on
   node `cks-c1-w1` to `/opt/course/c11/encryption.txt`.
4. Write the full output of `cilium-dbg encrypt status` of the same agent to
   `/opt/course/c11/encrypt-status.txt`.

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

[↑ 문항 목록](../README.md) · [← q10](../q10_secret_leak_hunt_env_annotations/question.md) · [q12 →](../q12_dockerfile_distroless_nonroot_build/question.md)
