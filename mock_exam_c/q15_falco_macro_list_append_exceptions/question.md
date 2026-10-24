# q15 — Falco list, macro and a namespace exception

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 9 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q15_falco_macro_list_append_exceptions
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 `cks-c1-w1` 에서 Falco(서비스 `falco-modern-bpf`)가 실행 중이고, namespace `web` 과 `build` 에 워커에 고정된 Deployment `tools`(alpine)가 하나씩 있다.
Falco 가 없으면 setup 이 공식 apt 저장소(`download.falco.org`)에서 설치하므로 워커에서 인터넷 연결이 필요하다. Falco 는 다른 문제에서도 쓰므로 정리할 때 지우지 않고,
setup 이 워커의 `/opt/course/c15/backup/` 에 백업해 둔 `falco.yaml`·`falco_rules.local.yaml` 을 cleanup 이 되돌린다.

## Task

Containers must not run package managers at runtime, except in the CI namespace `build`. Work on
worker node `cks-c1-w1` (`ssh cks-c1-w1`, `sudo -i`). Do not edit `/etc/falco/falco_rules.yaml`.

1. In `/etc/falco/falco_rules.local.yaml` create
   - a list `cks_pkg_mgmt_binaries` with the items `apt`, `apt-get`, `dpkg`, `apk`, `dnf`, `yum`,
     `pip`, `pip3`
   - a macro `cks_pkg_mgmt_procs` that is true when the process name is in that list
   - a rule `CKS Package Management In Container` that fires when such a process is spawned in a
     container, with priority `ERROR` and an output that contains the fields `%k8s.ns.name`,
     `%k8s.pod.name`, `%proc.cmdline` and `%user.uid`
2. Below the rule, in the same file, add a separate item that **appends** to the existing rule's
   condition so that processes in namespace `build` do not trigger it. Do not change the original
   rule item for this.
3. Configure Falco to additionally write its alerts to the file `/var/log/falco/c15-events.log`.
4. Restart Falco and make sure it loads the rules without errors. Then, from `cks-c1`, run
   `kubectl -n web exec deploy/tools -- apk info` and `kubectl -n build exec deploy/tools -- apk info`.
5. Copy all lines of `/var/log/falco/c15-events.log` that belong to your rule to
   `/opt/course/c15/alerts.log` on `cks-c1`.

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

[↑ 문항 목록](../README.md) · [← q14](../q14_trivy_config_misconfig_fix/question.md) · [q16 →](../q16_audit_impersonation_exec_levels/question.md)
