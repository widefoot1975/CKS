# q08 — Find and remove a disguised listening service on the worker

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | System Hardening (10%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q08_host_listening_service_disable
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 `cks-c1-w1` 에서는 systemd 서비스 하나가 TCP `20494` 포트를 열고 있다(워커에 `python3` 또는 OpenBSD `nc` 가 필요하다). 서비스 이름은 포트나 프로그램 이름과 다르게 지어져 있다. `/opt/course/a08/` 는 `cks-c1` 에 비어 있다.

## Task

An unknown program on worker node `cks-c1-w1` listens on TCP port `20494`. It is not needed.

1. Find the process listening on TCP port `20494` on `cks-c1-w1` and the systemd unit that
   starts it. Write the result to `/opt/course/a08/answer.txt` on `cks-c1` in exactly this
   format:

   ```
   port: 20494
   unit: <name of the systemd unit, e.g. foo.service>
   binary: <absolute path of the program in the unit's ExecStart>
   ```

2. Stop the service and make sure it cannot start again, also not after a reboot.
3. Delete the unit file and the program file from the node, and reload systemd.
4. Nothing may listen on TCP port `20494` on `cks-c1-w1` afterwards.

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

[↑ 문항 목록](../README.md) · [← q07](../q07_apparmor_profile_deployment/question.md) · [q09 →](../q09_psa_baseline_enforce_restricted_warn/question.md)
