# q15 — Falco list, macro and a namespace exception · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Containers must not run package managers at runtime, except in the CI namespace `build`. Work on
> worker node `cks-c1-w1` (`ssh cks-c1-w1`, `sudo -i`). Do not edit `/etc/falco/falco_rules.yaml`.
>
> 1. In `/etc/falco/falco_rules.local.yaml` create
>    - a list `cks_pkg_mgmt_binaries` with the items `apt`, `apt-get`, `dpkg`, `apk`, `dnf`, `yum`,
>      `pip`, `pip3`
>    - a macro `cks_pkg_mgmt_procs` that is true when the process name is in that list
>    - a rule `CKS Package Management In Container` that fires when such a process is spawned in a
>      container, with priority `ERROR` and an output that contains the fields `%k8s.ns.name`,
>      `%k8s.pod.name`, `%proc.cmdline` and `%user.uid`
> 2. Below the rule, in the same file, add a separate item that **appends** to the existing rule's
>    condition so that processes in namespace `build` do not trigger it. Do not change the original
>    rule item for this.
> 3. Configure Falco to additionally write its alerts to the file `/var/log/falco/c15-events.log`.
> 4. Restart Falco and make sure it loads the rules without errors. Then, from `cks-c1`, run
>    `kubectl -n web exec deploy/tools -- apk info` and `kubectl -n build exec deploy/tools -- apk info`.
> 5. Copy all lines of `/var/log/falco/c15-events.log` that belong to your rule to
>    `/opt/course/c15/alerts.log` on `cks-c1`.

**해석**

컨테이너는 실행 중에 패키지 관리자를 돌리면 안 된다. 단 CI namespace `build` 는 예외다. 워커 `cks-c1-w1` 에서 작업하고
`/etc/falco/falco_rules.yaml` 은 고치지 않는다.

1. `/etc/falco/falco_rules.local.yaml` 에 다음을 만든다.
   - 항목이 `apt`, `apt-get`, `dpkg`, `apk`, `dnf`, `yum`, `pip`, `pip3` 인 list `cks_pkg_mgmt_binaries`
   - 프로세스 이름이 그 list 에 있으면 참인 macro `cks_pkg_mgmt_procs`
   - 컨테이너 안에서 그런 프로세스가 생성되면 울리는 rule `CKS Package Management In Container`. priority `ERROR`, output 에 `%k8s.ns.name`,
     `%k8s.pod.name`, `%proc.cmdline`, `%user.uid` 포함
2. 같은 파일의 rule 아래에, 기존 rule 의 condition 에 **덧붙이는** 별도 항목을 추가해 namespace `build` 의 프로세스는 울리지 않게 한다.
   이를 위해 원래 rule 항목을 고치지 않는다.
3. Falco 가 알림을 `/var/log/falco/c15-events.log` 파일에도 쓰게 한다.
4. Falco 를 재시작하고 규칙이 오류 없이 로드되는지 확인한다. 그 뒤 `cks-c1` 에서 `web`·`build` 의 `tools` 에 `apk info` 를 실행한다.
5. `/var/log/falco/c15-events.log` 에서 이 rule 의 줄만 `cks-c1` 의 `/opt/course/c15/alerts.log` 로 복사한다.

## 모범 풀이

**1) 로컬 규칙 파일**

```bash
ssh cks-c1-w1
sudo -i
systemctl status falco-modern-bpf --no-pager | head -3
vi /etc/falco/falco_rules.local.yaml
```

```yaml
- list: cks_pkg_mgmt_binaries
  items: [apt, apt-get, dpkg, apk, dnf, yum, pip, pip3]

- macro: cks_pkg_mgmt_procs
  condition: proc.name in (cks_pkg_mgmt_binaries)

- rule: CKS Package Management In Container
  desc: A package manager was executed inside a container
  condition: spawned_process and container and cks_pkg_mgmt_procs
  output: "Package manager run in container (ns=%k8s.ns.name pod=%k8s.pod.name cmd=%proc.cmdline uid=%user.uid)"
  priority: ERROR
  tags: [cks, container, software_mgmt]

# build namespace 예외: 원래 rule 의 condition 뒤에 덧붙인다
- rule: CKS Package Management In Container
  condition: and not k8s.ns.name = build
  override:
    condition: append
```

| 요소 | 역할 |
|---|---|
| `list` | 값 목록. 다른 list·macro·rule 에서 이름으로 재사용 |
| `macro` | 재사용 가능한 condition 조각. `spawned_process`, `container` 도 `falco_rules.yaml` 에 있는 macro |
| `override: condition: append` | 같은 이름의 기존 rule 에 condition 을 이어 붙임. 결과는 `spawned_process and container and cks_pkg_mgmt_procs and not k8s.ns.name = build` |

`override` 는 Falco 0.36 부터의 방식이고, 예전의 `append: true` 는 deprecated 입니다. 덧붙이는 항목은 **원래 rule 보다 뒤에**
로드되어야 합니다(같은 파일이면 아래쪽, 다른 파일이면 나중에 읽히는 파일). 예외는 `exceptions:` 블록(`fields: [k8s.ns.name]`,
`values: [[build]]`)으로 쓸 수도 있습니다. `falco_rules.yaml` 은 패키지 업그레이드 때 덮어쓰이므로 사용자 규칙은 로컬 파일에 둡니다.

**2) 파일 출력**

```bash
vi /etc/falco/falco.yaml
```

```yaml
file_output:
  enabled: true
  keep_alive: false
  filename: /var/log/falco/c15-events.log
```

```bash
mkdir -p /var/log/falco          # 디렉터리가 없으면 Falco 가 파일을 열지 못한다
```

**3) 검증 후 재시작**

```bash
falco -V /etc/falco/falco_rules.yaml -V /etc/falco/falco_rules.local.yaml    # 문법·참조 확인 (macro 를 쓰므로 기본 규칙도 같이)
systemctl restart falco-modern-bpf
journalctl -u falco-modern-bpf -n 30 --no-pager | grep -iE 'error|loading rules'
# Loading rules from: /etc/falco/falco_rules.local.yaml  ... 오류 없음
exit; exit
```

**4) 발생시키기 (cks-c1)**

```bash
kubectl -n web exec deploy/tools -- apk info >/dev/null
kubectl -n build exec deploy/tools -- apk info >/dev/null
```

**5) 수집**

```bash
ssh cks-c1-w1 "sudo grep 'Package manager run in container' /var/log/falco/c15-events.log" | tee /opt/course/c15/alerts.log
# 2026-...: Error Package manager run in container (ns=web pod=tools-7d...-x cmd=apk info uid=0)
grep -c 'ns=build' /opt/course/c15/alerts.log      # 0
```

`build` 의 실행은 예외로 빠져서 한 줄도 없어야 합니다. 같은 알림은 `journalctl -u falco-modern-bpf` 에도 나옵니다(stdout/syslog 출력).

## 검증

```bash
ssh cks-c1-w1 'sudo grep -n -A3 "override" /etc/falco/falco_rules.local.yaml'
ssh cks-c1-w1 'sudo grep -A3 "^file_output" /etc/falco/falco.yaml'
ssh cks-c1-w1 'systemctl is-active falco-modern-bpf'                         # active
grep -c 'ns=web' /opt/course/c15/alerts.log                                  # 1 이상
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 사용자 규칙은 `/etc/falco/falco_rules.local.yaml`. 기존 rule 확장은 같은 이름 + `override: {condition: append}`. 바꾸고 나면 `systemctl restart falco-modern-bpf` 와 로그 확인.
- **헷갈리는 지점**: `append` 한 condition 은 `and ...` 로 시작해야 문법이 이어집니다. `proc.name` 은 최대 15자로 잘린 이름이라 긴 실행 파일 이름은 `proc.exepath` 등으로 봐야 합니다. `file_output` 디렉터리가 없으면 출력이 조용히 실패할 수 있습니다.

## 참고 문서

- 검색어: `falco rules list macro`, `falco override append`, `falco file output`
- https://falco.org/docs/concepts/rules/basic-elements/
- https://falco.org/docs/concepts/rules/overriding/
- https://falco.org/docs/concepts/rules/exceptions/
- https://falco.org/docs/concepts/outputs/channels/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q16 →](../q16_audit_impersonation_exec_levels/question.md)
