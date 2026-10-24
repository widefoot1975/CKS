# q08 — Remove a setuid bit and a login shell on a node

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | System Hardening (10%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q08_host_setuid_nologin_shell
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 노드 `cks-c1-w1` 의 `/usr/local/bin/` 에 실행 파일 두 개가 있고 그중 하나에 setuid 비트가 붙어 있다. 서비스 계정용 로컬 사용자 `svc-backup` 은 로그인 셸이 `/bin/bash` 로 되어 있다. `cks-c1` 의 `/opt/course/f08/` 는 비어 있다.

## Task

A security scan of worker node `cks-c1-w1` found a privilege escalation path and a service user
that can log in interactively.

1. On `cks-c1-w1`, find every regular file below `/usr/local/bin/` that has the setuid bit set and
   write the full path(s), one per line, to `/opt/course/f08/suid.txt` on `cks-c1`.
2. Remove the setuid bit from those files. Do not delete them and do not change any other
   permission bits.
3. The local user `svc-backup` on `cks-c1-w1` must not be able to get an interactive shell. Set its
   login shell to `/usr/sbin/nologin`. Do not delete the user.
4. Write the `/etc/passwd` entry of `svc-backup` on `cks-c1-w1` to `/opt/course/f08/passwd.txt` on
   `cks-c1`.

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

[↑ 문항 목록](../README.md) · [← q07](../q07_apparmor_complain_to_enforce/question.md) · [q09 →](../q09_psa_dry_run_find_violators/question.md)
