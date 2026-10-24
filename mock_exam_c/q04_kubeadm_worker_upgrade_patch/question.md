# q04 — Upgrade the worker node with kubeadm

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q04_kubeadm_worker_upgrade_patch
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/c04/versions-before.txt` 에 컨트롤 플레인과 워커의 kubeadm·kubelet 버전이 기록되어 있고, namespace `upg` 에 Deployment `canary`(emptyDir 사용)와
워커에 고정된 단독 Pod `scratch` 가 있다. setup 은 버전을 낮추지 않으므로 **실습 클러스터의 워커가 이미 컨트롤 플레인과 같은 버전이면 패키지 설치 단계는 "이미 최신" 으로 끝난다**.
그래도 drain → 업그레이드 절차 → uncordon 과 기록은 똑같이 수행한다(버전 차이를 직접 만들려면 워커를 한 단계 낮은 버전으로 구성해 둔다).
워커에서 `pkgs.k8s.io` 로 인터넷 연결이 필요하다. 정리할 때 버전은 되돌리지 않는다.

## Task

Node `cks-c1-w1` must run the same Kubernetes patch version as the control plane `cks-c1`.

1. Determine the exact version of `kubeadm` and `kubelet` on the control plane node `cks-c1`.
2. Upgrade `kubeadm`, `kubelet` and `kubectl` on worker node `cks-c1-w1` (`ssh cks-c1-w1`, `sudo -i`)
   to exactly that version using the official `pkgs.k8s.io` apt repository, and run the kubeadm
   node upgrade.
3. Drain `cks-c1-w1` before the kubelet is upgraded. The standalone Pod `upg/scratch` may be
   deleted. Mark the three packages as held again when you are done.
4. Restart the kubelet and make `cks-c1-w1` schedulable again. Both replicas of Deployment
   `upg/canary` must be `Running`.
5. Write the output of `kubectl get nodes` to `/opt/course/c04/nodes-after.txt` on `cks-c1`.

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

[↑ 문항 목록](../README.md) · [← q03](../q03_ingress_tls_fix_secret_host/question.md) · [q05 →](../q05_rbac_dangerous_verbs_escalate_bind/question.md)
