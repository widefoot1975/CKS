# q07 — AppArmor and seccomp in a multi-container Pod

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q07_apparmor_seccomp_multicontainer
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `guard` 에는 Pod Security `enforce=baseline` 라벨이 붙어 있고, `cks-c1` 의 `/opt/course/c07/dual.yaml` 에 Pod `dual` 매니페스트가 있지만 Pod 는 없다
(그대로 apply 하면 거부된다). AppArmor 프로필 파일은 워커 `cks-c1-w1` 의 `/opt/course/c07/k8s-deny-write` 에 있고(같은 내용이 `cks-c1` 에도 있다) **아직 로드되어 있지 않다**.
워커에 AppArmor 가 켜져 있어야 한다(Ubuntu 기본).

## Task

Pod `dual` in namespace `guard` runs two containers, `app` and `sidecar`. Its manifest is
`/opt/course/c07/dual.yaml`. Do not change the labels of namespace `guard`.

1. On worker node `cks-c1-w1`, load the AppArmor profile from file `/opt/course/c07/k8s-deny-write`
   in enforce mode.
2. Edit `/opt/course/c07/dual.yaml` so that:
   - the Pod runs on node `cks-c1-w1`
   - the seccomp profile `RuntimeDefault` is set once at Pod level and applies to **both**
     containers (no container may override it)
   - container `app` is confined by the AppArmor profile you loaded, container `sidecar` uses the
     container runtime's default AppArmor profile
   - AppArmor is configured with `securityContext` fields only (no annotations)
3. Create the Pod from the edited file. Both containers must be running.
4. Write two lines to `/opt/course/c07/check.txt`: line 1 is the content of
   `/proc/1/attr/current` inside container `app`, line 2 the same for container `sidecar`.

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

[↑ 문항 목록](../README.md) · [← q06](../q06_exposed_admin_ui_lockdown/question.md) · [q08 →](../q08_host_kernel_modules_blacklist/question.md)
