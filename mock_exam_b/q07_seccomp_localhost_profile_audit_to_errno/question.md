# q07 — Turn a logging seccomp profile into a blocking one

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q07_seccomp_localhost_profile_audit_to_errno
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `cks-c1` 의 `/opt/course/b07/` 에 seccomp 프로필 `no-chmod.json`(chmod 계열 syscall 을 `SCMP_ACT_LOG` 로 기록만 함)과 Pod 매니페스트 `pod.yaml`(Pod `chmod-test`, 컨테이너 `app`·`helper`, 워커에 고정, securityContext 없음)이 있다. namespace `forge` 는 비어 있고, 워커 `cks-c1-w1` 의 `/var/lib/kubelet/seccomp/profiles/` 에는 `no-chmod.json` 이 없다.

## Task

The security team drafted the seccomp profile `/opt/course/b07/no-chmod.json` on `cks-c1`. It
currently only logs the syscalls it lists.

1. Change the profile so that the syscalls `chmod`, `fchmod`, `fchmodat` and `fchmodat2` fail
   with an error, while every other syscall stays allowed. Install the profile on worker node
   `cks-c1-w1` as `/var/lib/kubelet/seccomp/profiles/no-chmod.json`.
2. Edit `/opt/course/b07/pod.yaml`: the Pod must use the seccomp profile `RuntimeDefault` for all
   containers by default, and container `app` must use the profile from step 1 instead. Create the
   Pod in namespace `forge`.
3. In both containers run `touch /tmp/f && chmod 600 /tmp/f`. Write the complete output
   (stdout and stderr) of the command in container `app` to `/opt/course/b07/app-chmod.txt`. The
   command must fail in `app` and succeed in `helper`.

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

[↑ 문항 목록](../README.md) · [← q06](../q06_anonymous_auth_health_endpoints_only/question.md) · [q08 →](../q08_host_users_groups_sshd/question.md)
