# q15 — Investigate existing Falco alerts

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q15_falco_investigate_existing_alerts
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 `cks-c1-w1` 에서 Falco 가 systemd 서비스 `falco-modern-bpf` 로 돌고 있고, namespace `retail`(Deployment `cache`, `storefront`)과 `logistics`(Deployment `tracker`, `router`)의 Pod 가 모두 워커에서 실행 중이다. 그중 일부가 수상한 행동을 반복해 Falco 경고가 이미 쌓여 있다.
Falco 가 없으면 setup 이 공식 apt 저장소로 설치(드라이버 `modern_ebpf`)하므로 인터넷이 필요하고 몇 분 걸린다(Falco 는 cleanup 이 지우지 않는다). 원래의 `/etc/falco/falco_rules.local.yaml` 은 워커의 `/opt/course/b15/backup/` 에 백업되고 cleanup 이 되돌린다.

## Task

Falco runs on worker node `cks-c1-w1` as the systemd service `falco-modern-bpf` and has already
raised alerts. Ignore alerts for namespaces `kube-system` and `default` and alerts caused by your
own `kubectl exec` or debugging sessions.

1. Use the Falco alerts of the last 15 minutes to identify every Pod that triggered an alert with
   priority `Warning` or higher. Write them to `/opt/course/b15/offenders.txt` on `cks-c1`, one per
   line, as `<namespace>/<pod-name>`.
2. Stop the offending workloads so that no Pod of them is running and none is recreated. Do not
   touch the other workloads.
3. Raise the priority of the Falco rule `Read sensitive file untrusted` to `CRITICAL` without
   editing `/etc/falco/falco_rules.yaml`. Restart Falco and prove that the rule now fires with
   priority `Critical`: copy one such new alert line to `/opt/course/b15/critical.txt` on
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

[↑ 문항 목록](../README.md) · [← q14](../q14_vap_params_configmap_registries/question.md) · [q16 →](../q16_audit_log_investigation/question.md)
