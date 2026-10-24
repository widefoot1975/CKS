# q02 — Fix the kube-bench profiling finding on the API server

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q02_kube_bench_apiserver_profiling
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 kube-apiserver 매니페스트에 `--profiling=true` 가 들어가 있고, 원본은 `/opt/course/d02/backup/kube-apiserver.yaml` 에 백업되어 있다.
`kube-bench` v0.10.4 가 없으면 `/usr/local/bin/kube-bench` 와 설정 디렉터리 `/etc/kube-bench/cfg` 로 설치한다(GitHub 로 인터넷 연결 필요). cleanup 은 매니페스트를 원래대로 되돌리지만 kube-bench 는 지우지 않는다.

## Task

The CIS benchmark tool `kube-bench` is installed on `cks-c1` (configuration in
`/etc/kube-bench/cfg`).

1. Run `kube-bench` against the control-plane components only (target `master`) and save the
   complete output to `/opt/course/d02/before.txt`.
2. Fix the failing check `Ensure that the --profiling argument is set to false` for the
   **kube-apiserver** only. Do not change the controller manager or the scheduler.
3. When the API server is back, run the same `kube-bench` command again and save the output to
   `/opt/course/d02/after.txt`. The API server profiling check must be `[PASS]`.

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

[↑ 문항 목록](../README.md) · [← q01](../q01_networkpolicy_default_deny_ingress/question.md) · [q03 →](../q03_verify_kubectl_sha512/question.md)
