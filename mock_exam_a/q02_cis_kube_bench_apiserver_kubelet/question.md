# q02 — Fix kube-bench findings on the API server and the kubelet

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q02_cis_kube_bench_apiserver_kubelet
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 두 노드에 `kube-bench` v0.10.4 가 설치되어 있다(없을 때만 GitHub 릴리스 .deb 를 받으므로 인터넷 필요). kube-apiserver 에는 `--profiling=true` 와 `--authorization-mode=Node,RBAC,AlwaysAllow` 가 걸려 있고, 워커 `cks-c1-w1` 의 kubelet 설정 파일은 익명 인증 허용 + `AlwaysAllow` 인가로 바뀌어 있다.
원본 매니페스트와 kubelet 설정은 각 노드의 `/opt/course/a02/backup/` 에 있고, `cleanup.sh` 가 되돌린다.

## Task

A CIS benchmark run is required on cluster `cks-c1`. Use `kube-bench` (already installed on
both nodes).

1. On `cks-c1`, run the `master` target of `kube-bench` and save the complete output to
   `/opt/course/a02/master-before.txt`.
2. Fix these failing kube-apiserver checks: profiling must be disabled, and the
   authorization mode must not contain `AlwaysAllow` and must be exactly `Node,RBAC`.
3. On worker node `cks-c1-w1`, run the `node` target and fix these failing kubelet checks in
   the kubelet configuration file (not with command-line flags): anonymous authentication
   must be disabled and the authorization mode must be `Webhook`.
4. Run both targets again. Save the output of the `master` run to
   `/opt/course/a02/master-after.txt` and of the `node` run to
   `/opt/course/a02/node-after.txt`, both on `cks-c1`. The four checks above must be `[PASS]`.
5. Both nodes must be `Ready` and all `kube-system` Pods must be running when you finish.

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

[↑ 문항 목록](../README.md) · [← q01](../q01_networkpolicy_default_deny_dns_metadata/question.md) · [q03 →](../q03_ingress_tls_ssl_redirect/question.md)
