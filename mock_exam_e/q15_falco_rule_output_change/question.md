# q15 — Change the output of a Falco rule with an override

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q15_falco_rule_output_change
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 노드 `cks-c1-w1` 에서 Falco 가 서비스 `falco-modern-bpf`(드라이버 `modern_ebpf`)로 실행 중이고, `/etc/falco/falco_rules.local.yaml` 에는 이 문제용 규칙이 없다
(원본은 워커의 `/opt/course/e15/backup/` 에 백업). namespace `frontdesk` 에 `cks-c1-w1` 에 고정된 파드 `shell-target`(nginx)이 있다.
Falco 가 없으면 setup 이 falco.org 공식 apt 저장소로 설치하므로 인터넷 연결이 필요하다(수 분). Falco 는 공용 구성요소라 `cleanup.sh` 가 지우지 않고 로컬 규칙 파일만 되돌린다.

## Task

The SOC wants a shorter, fixed format for alerts of the Falco rule
`Terminal shell in container` on worker node `cks-c1-w1`.

1. Without editing `/etc/falco/falco_rules.yaml`, replace the output of the existing rule
   `Terminal shell in container` with exactly:
   `SHELL ns=%k8s.ns.name pod=%k8s.pod.name container=%container.name uid=%user.uid cmd=%proc.cmdline`.
   Do not change the rule's condition or priority.
2. Make Falco load the change.
3. Open an interactive shell in Pod `shell-target` in namespace `frontdesk`
   (`kubectl exec -it … -- sh`) and exit it. Copy the resulting Falco alert line(s) to
   `/opt/course/e15/alerts.log` on `cks-c1`.

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

[↑ 문항 목록](../README.md) · [← q14](../q14_kubelinter_fix_findings/question.md) · [q16 →](../q16_audit_log_who_deleted/question.md)
