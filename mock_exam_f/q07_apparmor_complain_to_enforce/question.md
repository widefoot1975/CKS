# q07 — Switch an AppArmor profile from complain to enforce

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q07_apparmor_complain_to_enforce
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 노드 `cks-c1-w1` 에 AppArmor 프로필 파일 `/etc/apparmor.d/k8s-f07-readonly` 가 있고, 프로필 `k8s-f07-readonly` 는 **complain 모드**로 커널에 로드되어 있다. namespace `f07` 은 비어 있고 `/opt/course/f07/` 도 비어 있다.
워커 노드에 AppArmor 가 켜져 있어야 한다(Ubuntu 기본값).

## Task

The AppArmor profile `k8s-f07-readonly` on worker node `cks-c1-w1` is supposed to prevent
containers from writing to their filesystem, but it does not block anything yet.

1. On `cks-c1-w1`, find the mode in which profile `k8s-f07-readonly` is loaded and write the mode
   (one word) to `/opt/course/f07/mode-before.txt` on `cks-c1`.
2. Put the profile into enforce mode on `cks-c1-w1`. It must still be in enforce mode when the
   profile is loaded again from `/etc/apparmor.d/` (for example after a reboot).
3. Create a Pod `ro-pod` in namespace `f07` with image `busybox:1.36` and command
   `sleep 86400` that runs on node `cks-c1-w1` and uses the AppArmor profile `k8s-f07-readonly`
   for its container. Use the `securityContext` field, not an annotation.
4. In Pod `ro-pod`, run `touch /tmp/test` and write the error message to
   `/opt/course/f07/touch.txt`.

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

[↑ 문항 목록](../README.md) · [← q06](../q06_csr_approve_user_kubeconfig/question.md) · [q08 →](../q08_host_setuid_nologin_shell/question.md)
