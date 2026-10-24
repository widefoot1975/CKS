# q15 — Falco rule for shells spawned in payment containers

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q15_falco_custom_rule_shell_output
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 `cks-c1-w1` 에서 Falco 가 서비스 `falco-modern-bpf`(드라이버 `modern_ebpf`)로 실행 중이다(없을 때만 falco.org 공식 apt 저장소에서 설치하므로 인터넷 필요). `/etc/falco/falco_rules.local.yaml` 은 주석만 있는 상태로 초기화되어 있다(원본은 워커의 `/opt/course/a15/backup/`).
namespace `payments` 와 `billing` 에 Deployment 가 몇 개 실행 중이다. Falco 는 다른 문항도 쓰므로 `cleanup.sh` 가 지우지 않는다.

## Task

Some workload in namespace `payments` keeps spawning shells. Falco runs on worker node
`cks-c1-w1`.

1. On `cks-c1-w1`, add a Falco rule named `Shell in payments container` to
   `/etc/falco/falco_rules.local.yaml` (do not edit `/etc/falco/falco_rules.yaml`) that
   triggers whenever a shell process (any program of Falco's default list `shell_binaries`)
   is started in a container of namespace `payments`. Use priority `WARNING` and exactly this
   output:

   ```
   %evt.time,%k8s.ns.name,%k8s.pod.name,%proc.name,%user.uid
   ```

2. Make Falco load the rule. Collect at least three alert lines produced by this rule and
   write them to `/opt/course/a15/alerts.log` on `cks-c1`.
3. Identify the Deployment that spawns the shells, scale it to `0` replicas, and write its
   name to `/opt/course/a15/deployment.txt`.

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

[↑ 문항 목록](../README.md) · [← q14](../q14_vap_permitted_registries_no_latest/question.md) · [q16 →](../q16_audit_policy_rules_apiserver/question.md)
