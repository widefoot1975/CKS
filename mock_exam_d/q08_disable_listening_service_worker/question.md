# q08 — Disable a listening service on the worker node

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | System Hardening (10%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q08_disable_listening_service_worker
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 노드 `cks-c1-w1` 에서 어떤 systemd 서비스가 TCP `20800` 을 모든 주소(`0.0.0.0`)에서 열고 있다. 서비스 이름은 직접 찾는다.
워커 노드에 `python3` 가 있어야 한다(Ubuntu 기본 설치에 포함). 없으면 setup 이 `NO_PYTHON3` 을 출력한다.

## Task

A security scan reported that worker node `cks-c1-w1` listens on TCP port `20800`. Nobody needs
this service.

1. On `cks-c1-w1`, find the systemd unit whose process listens on TCP port `20800`. Write the
   unit name (for example `foo.service`) to `/opt/course/d08/unit.txt` on `cks-c1`.
2. Stop the unit and make sure it is not started again at boot.
3. Delete the executable that the unit starts (its `ExecStart` file). Nothing may listen on
   TCP port `20800` afterwards.

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

[↑ 문항 목록](../README.md) · [← q07](../q07_apparmor_load_apply_pod/question.md) · [q09 →](../q09_psa_restricted_label_fix_pod/question.md)
