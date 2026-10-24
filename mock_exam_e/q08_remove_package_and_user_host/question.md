# q08 — Remove an unneeded package and user from a node

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | System Hardening (10%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q08_remove_package_and_user_host
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 노드 `cks-c1-w1`(Ubuntu/Debian 계열)에 어떤 FTP 서버 패키지가 설치되어 TCP `21` 에서 대기하고 있고, 로컬 사용자 `legacy-ftp`(홈 `/home/legacy-ftp`)가
있으며 이 사용자로 프로세스 하나가 돌고 있다. setup 이 워커에서 `apt-get` 으로 패키지를 설치하므로 워커에 인터넷 연결이 필요하다(수 분 걸릴 수 있음).

## Task

Worker node `cks-c1-w1` runs an FTP server that nobody needs, and an old local account.

1. On `cks-c1-w1`, find the program listening on TCP port `21` and the Debian package that
   installed it. Write the package name to `/opt/course/e08/package.txt` on `cks-c1`.
2. Remove that package from `cks-c1-w1` including its configuration files.
3. Delete the local user `legacy-ftp` on `cks-c1-w1` together with its home directory. No
   process of this user may keep running.

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

[↑ 문항 목록](../README.md) · [← q07](../q07_seccomp_runtimedefault_deployment/question.md) · [q09 →](../q09_securitycontext_drop_caps_nonprivileged/question.md)
