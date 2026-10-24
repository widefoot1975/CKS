# q08 — Harden host users, groups, sshd and setuid files

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | System Hardening (10%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q08_host_users_groups_sshd
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 `cks-c1-w1` 에는 비밀번호가 있고 `sudo`·`docker` 그룹에 속한 사용자 `ops-tmp`(셸 `/bin/bash`)가 있고, `/etc/ssh/sshd_config.d/50-legacy.conf` 가 root 로그인과 비밀번호 인증을 켠다. `/usr/local/bin/` 에는 setup 이 넣은 실행 파일 몇 개가 있다.
노드에 키 기반으로 ssh 하고 있다는 전제다(비밀번호로만 접속한다면 비밀번호 인증을 끄기 전에 키를 등록할 것).

## Task

A temporary operations account and some leftovers from an old maintenance job were found on
worker node `cks-c1-w1`. Perform all changes on `cks-c1-w1`.

1. User `ops-tmp` must keep existing, but must no longer be a member of the groups `sudo` and
   `docker`. Lock the user's password and set its login shell to `/usr/sbin/nologin`.
2. sshd must not allow root login and must not allow password authentication. Put your settings in
   the file `/etc/ssh/sshd_config.d/00-cks-hardening.conf`. The **effective** sshd configuration
   (`sshd -T`) must show `permitrootlogin no` and `passwordauthentication no`. Apply the change
   without rebooting the node.
3. Find every file in `/usr/local/bin/` that has the setuid bit set. Remove the setuid bit (do not
   delete the files) and write the full paths, one per line, to `/opt/course/b08/setuid.txt` on
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

[↑ 문항 목록](../README.md) · [← q07](../q07_seccomp_localhost_profile_audit_to_errno/question.md) · [q09 →](../q09_istio_peerauthentication_strict/question.md)
