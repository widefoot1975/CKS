# q06 — Re-enable the NodeRestriction admission plugin and prove it

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q06_noderestriction_admission
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 kube-apiserver 의 admission 플러그인 설정이 바뀌어 `NodeRestriction` 이 꺼져 있다. 원본 매니페스트는 `/opt/course/a06/backup/` 에 있다.
`/opt/course/a06/w1-kubelet.kubeconfig` 는 워커 `cks-c1-w1` 의 kubelet 클라이언트 인증서(`system:node:cks-c1-w1`)로 API 서버에 접속하는 kubeconfig 다(인증서는 워커의 `/var/lib/kubelet/pki/kubelet-client-current.pem` 사본).

## Task

A compromised worker node must not be able to modify other nodes. The kubeconfig
`/opt/course/a06/w1-kubelet.kubeconfig` authenticates as the kubelet of `cks-c1-w1`.

1. Show the problem: using that kubeconfig, add the label `a06-before=pwned` to node
   `cks-c1`. Write the command output to `/opt/course/a06/before.txt`. Then remove the label
   again with the admin kubeconfig.
2. Make sure the kube-apiserver runs with the `NodeRestriction` admission plugin enabled.
   Keep the other admission plugins that are currently enabled.
3. Using the kubelet kubeconfig again, try each of the following and write the output
   (stdout and stderr) of all three commands to `/opt/course/a06/after.txt`:
   a. add label `a06-after=pwned` to node `cks-c1` (must be forbidden)
   b. add label `node-restriction.kubernetes.io/zone=evil` to node `cks-c1-w1` (must be forbidden)
   c. add label `a06-self=ok` to node `cks-c1-w1` (must succeed)

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

[↑ 문항 목록](../README.md) · [← q05](../q05_serviceaccount_automount_projected_token/question.md) · [q07 →](../q07_apparmor_profile_deployment/question.md)
