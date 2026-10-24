# q08 — Blacklist kernel modules and remove a telnet server

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | System Hardening (10%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q08_host_kernel_modules_blacklist
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 `cks-c1-w1` 에는 커널 모듈 `dccp`, `sctp`, `rds`, `tipc` 중 커널이 제공하는 것들이 로드되어 있고(배포판 커널에 따라 일부는 없을 수 있다),
telnet 서버 패키지가 설치되어 있다. 패키지 설치를 위해 워커에서 apt 저장소로 인터넷 연결이 필요하다. `/opt/course/c08/` 는 비어 있다.

## Task

Worker node `cks-c1-w1` must not support rarely used network protocols and must not offer a
telnet server. Work on `cks-c1-w1` (`ssh cks-c1-w1`, `sudo -i`); write the answer files on `cks-c1`.

1. Find out which of the kernel modules `dccp`, `sctp`, `rds` and `tipc` are currently loaded on
   `cks-c1-w1`. Write their names, one per line and sorted, to `/opt/course/c08/loaded.txt`.
2. Create `/etc/modprobe.d/cks-blacklist.conf` on `cks-c1-w1` so that none of the four modules can
   be loaded anymore — neither automatically nor by an explicit `modprobe <module>`.
3. Unload every one of the four modules that is still loaded, without rebooting.
4. Find the installed Debian package that provides the telnet server daemon, purge it, and write
   the package name to `/opt/course/c08/removed-package.txt`.

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

[↑ 문항 목록](../README.md) · [← q07](../q07_apparmor_seccomp_multicontainer/question.md) · [q09 →](../q09_vap_tenant_pod_security/question.md)
