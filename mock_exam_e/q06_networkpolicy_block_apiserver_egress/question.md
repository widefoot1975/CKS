# q06 — Block Pod egress to the Kubernetes API

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q06_networkpolicy_block_apiserver_egress
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `sandbox` 에 curl 파드 `runner` 가 있고 NetworkPolicy 는 없다. 지금은 `runner` 에서
`curl -sk https://kubernetes.default.svc/version` 이 API 서버 버전 JSON 을 돌려준다. CNI 는 Cilium 이다.

## Task

Untrusted jobs run in namespace `sandbox`. They must not be able to talk to the Kubernetes
API server, but everything else must keep working.

1. Find the ClusterIP of Service `kubernetes` in namespace `default` and the InternalIP of
   the control-plane node `cks-c1`. Write them, one per line in this order, to
   `/opt/course/e06/apiserver-ips.txt`.
2. Create a NetworkPolicy named `deny-apiserver` in namespace `sandbox` that applies to all
   Pods and allows egress
   - to the cluster DNS Pods (label `k8s-app=kube-dns` in namespace `kube-system`) on UDP
     and TCP port `53`, and
   - to `0.0.0.0/0` except the two addresses from step 1 (as `/32`).
3. From Pod `runner`, run `curl -sk -m 5 https://kubernetes.default.svc/version` and write
   only the curl exit code to `/opt/course/e06/api-test.txt`.

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

[↑ 문항 목록](../README.md) · [← q05](../q05_create_token_duration_audience/question.md) · [q07 →](../q07_seccomp_runtimedefault_deployment/question.md)
