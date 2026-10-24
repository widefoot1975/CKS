# q15 — Stop a Pod that Falco reports spawning shells

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q15_falco_shell_alert_delete_pod
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 노드 `cks-c1-w1` 에서 Falco(서비스 `falco-modern-bpf`, 드라이버 `modern_ebpf`)가 돌고, 보안팀 규칙 `Shell spawned in container` 가 `/etc/falco/rules.d/d15-shell.yaml` 에 들어가 있다.
namespace `garnet`, `jet` 에 Deployment 몇 개가 도는데 그중 하나가 주기적으로 셸을 띄운다. Falco 가 없으면 setup 이 공식 apt 저장소로 설치하므로 인터넷이 필요하고 몇 분 걸릴 수 있다. cleanup 은 규칙 파일만 지우고 Falco 는 남겨 둔다.

## Task

Falco runs on worker node `cks-c1-w1` as the systemd service `falco-modern-bpf`. The security
team added the rule `Shell spawned in container`, and it keeps firing for one workload in
namespace `garnet` or `jet`.

1. Using the Falco alerts on `cks-c1-w1`, find the Pod that spawns shells. Write its namespace
   and Pod name, separated by one space (for example `team1 web-5d8f9c-abcde`), to
   `/opt/course/d15/pod.txt` on `cks-c1`.
2. Scale the Deployment that owns this Pod to `0` replicas. Do not delete the Deployment and do
   not change any other workload.
3. Confirm that the rule stops firing for that workload.

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

[↑ 문항 목록](../README.md) · [← q14](../q14_kubesec_score_fix_pod/question.md) · [q16 →](../q16_audit_enable_given_policy/question.md)
