# q15 — Falco rule for writes below /etc

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q15_falco_detect_write_below_etc
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 노드 `cks-c1-w1` 에서 Falco 가 서비스 `falco-modern-bpf`(드라이버 `modern_ebpf`)로 돌고 있고, `/etc/falco/falco_rules.local.yaml` 에는 이 문제용 규칙이 없다(원본은 같은 디렉터리에 `.f15.bak` 로 백업). namespace `f15` 에 Deployment 두 개(`config-writer`, `config-reader`)가 워커에서 돌고 있다. `/opt/course/f15/` 는 비어 있다.
Falco 가 없으면 setup 이 falco.org 공식 apt 저장소로 워커에 설치하므로(수 분 걸림) 인터넷 연결이 필요하다. Falco 는 공용 도구라 정리할 때 지우지 않는다.

## Task

Containers in namespace `f15` must not modify files below `/etc`. Use Falco on worker node
`cks-c1-w1` to find out which Pod does it.

1. On `cks-c1-w1`, add a Falco rule named `Write below etc in f15` to
   `/etc/falco/falco_rules.local.yaml`. It must fire when a process in a container of namespace
   `f15` opens a file below `/etc/` for writing. Use priority `ERROR` and an output that contains,
   in this order, `%evt.time`, `%k8s.ns.name`, `%k8s.pod.name`, `%proc.name` and `%fd.name`. Do
   not modify `/etc/falco/falco_rules.yaml`.
2. Make sure Falco has loaded the rule without errors.
3. Write at least three alert lines produced by this rule to `/opt/course/f15/alerts.log` on
   `cks-c1`.
4. Write the name of the Pod that triggers the rule to `/opt/course/f15/pod.txt` and scale the
   Deployment that owns it to `0` replicas.

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

[↑ 문항 목록](../README.md) · [← q14](../q14_kubesec_deployment_score/question.md) · [q16 →](../q16_audit_policy_secrets_metadata/question.md)
