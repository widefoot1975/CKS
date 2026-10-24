# q02 — Fix kube-bench findings for etcd and the worker kubelet

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q02_cis_etcd_kubelet_file_permissions
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `cks-c1` 의 etcd static pod 는 `--client-cert-auth=false` 로 떠 있고 `/var/lib/etcd` 권한은 `755` 다. 워커 `cks-c1-w1` 의 kubelet 은 `/var/lib/kubelet/config.yaml` 에 `readOnlyPort: 10255` 가 들어가 10255 포트(인증 없음)가 열려 있고 그 파일 권한은 `644` 다.
원본은 `cks-c1:/opt/course/b02/backup/etcd.yaml`, `cks-c1-w1:/opt/course/b02/backup/config.yaml` 에 있고 cleanup 이 되돌린다. kube-bench v0.10.4 가 없으면 두 노드에 설치하므로 인터넷이 필요하다(설치한 kube-bench 는 cleanup 이 지우지 않는다).

## Task

A CIS benchmark review found problems on the etcd member of control plane `cks-c1` and on the
kubelet of worker node `cks-c1-w1`. `kube-bench` is installed on both nodes.

1. On `cks-c1`, run `kube-bench run --targets master,etcd` and fix these findings:
   - etcd must require client certificate authentication (`--client-cert-auth=true`).
   - The etcd data directory must have permissions `700` or more restrictive.
2. On worker node `cks-c1-w1`, fix the kubelet: the read-only port must be disabled through
   `/var/lib/kubelet/config.yaml` (`readOnlyPort: 0`), and the file
   `/var/lib/kubelet/config.yaml` must have permissions `600`. Restart the kubelet.
3. Run kube-bench again and save on `cks-c1` the complete output of
   `kube-bench run --targets master,etcd` (run on `cks-c1`) to `/opt/course/b02/cp.txt` and of
   `kube-bench run --targets node` (run on `cks-c1-w1`) to `/opt/course/b02/node.txt`. The checks
   for the four items above must show `[PASS]`.
4. Both nodes must be `Ready`, the kube-apiserver must be healthy and nothing may listen on TCP
   port `10255` on `cks-c1-w1`.

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

[↑ 문항 목록](../README.md) · [← q01](../q01_ciliumnetworkpolicy_l7_http/question.md) · [q03 →](../q03_verify_platform_binaries_sha512/question.md)
