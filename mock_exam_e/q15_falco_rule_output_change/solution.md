# q15 — Change the output of a Falco rule with an override · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The SOC wants a shorter, fixed format for alerts of the Falco rule
> `Terminal shell in container` on worker node `cks-c1-w1`.
>
> 1. Without editing `/etc/falco/falco_rules.yaml`, replace the output of the existing rule
>    `Terminal shell in container` with exactly:
>    `SHELL ns=%k8s.ns.name pod=%k8s.pod.name container=%container.name uid=%user.uid cmd=%proc.cmdline`.
>    Do not change the rule's condition or priority.
> 2. Make Falco load the change.
> 3. Open an interactive shell in Pod `shell-target` in namespace `frontdesk`
>    (`kubectl exec -it … -- sh`) and exit it. Copy the resulting Falco alert line(s) to
>    `/opt/course/e15/alerts.log` on `cks-c1`.

**해석**

보안관제팀이 워커 노드 `cks-c1-w1` 에서 Falco 규칙 `Terminal shell in container` 의 경보를 더 짧은 고정 형식으로 받고 싶어 한다.

1. `/etc/falco/falco_rules.yaml` 을 고치지 않고, 기존 규칙 `Terminal shell in container` 의 output 을 정확히 위 문자열로 **교체**한다.
   규칙의 condition 과 priority 는 바꾸지 않는다.
2. Falco 가 변경을 읽게 한다.
3. namespace `frontdesk` 의 파드 `shell-target` 에 대화형 셸(`kubectl exec -it … -- sh`)을 열었다 닫고, 그 결과로 생긴 Falco 경보 줄을
   `cks-c1` 의 `/opt/course/e15/alerts.log` 에 복사한다.

## 모범 풀이

**1) 로컬 규칙 파일에 override**

```bash
ssh cks-c1-w1
sudo -i
grep -n -A3 'rule: Terminal shell in container' /etc/falco/falco_rules.yaml   # 원래 output·priority(NOTICE) 확인
grep -A6 '^rules_files:\|^rules_file:' /etc/falco/falco.yaml                 # falco_rules.yaml 다음에 falco_rules.local.yaml
vi /etc/falco/falco_rules.local.yaml
```

```yaml
- rule: Terminal shell in container
  output: SHELL ns=%k8s.ns.name pod=%k8s.pod.name container=%container.name uid=%user.uid cmd=%proc.cmdline
  override:
    output: replace
```

이미 있는 규칙과 **같은 이름**으로 `override:` 를 쓰면 지정한 키만 바뀌고 나머지(condition, priority, tags …)는 원래 규칙 그대로입니다.
`output` 은 `replace`(교체)와 `append`(뒤에 덧붙이기) 둘 다 됩니다. 로컬 파일은 기본 규칙 파일 **다음에** 로드되어야 override 할 대상이
있으므로 `falco.yaml` 의 `rules_files` 순서를 확인합니다. `falco_rules.yaml` 은 패키지 업그레이드 때 덮어써지므로 직접 고치지 않습니다.

예전 방식인 `append: true` 는 condition·output 을 **뒤에 덧붙이기만** 하므로 output 교체에는 쓸 수 없고, 같은 이름의 규칙을
`override` 없이 다시 정의하면 규칙 전체를 새로 써야 합니다(condition 까지 복사해야 함).

**2) 문법 확인 후 재시작**

```bash
falco -V /etc/falco/falco_rules.yaml -V /etc/falco/falco_rules.local.yaml     # 두 파일을 순서대로 검증 → OK
systemctl restart falco-modern-bpf
systemctl is-active falco-modern-bpf                                          # active
journalctl -u falco-modern-bpf -n 20 --no-pager | grep -i -E 'loading rules|error'
```

`falco.yaml` 의 `watch_config_files: true`(기본)면 규칙 파일 저장만으로도 다시 읽지만, 재시작하면 로드 오류를 바로 볼 수 있어 확실합니다.

**3) 경보 발생과 수집**

```bash
# cks-c1 (다른 터미널 또는 워커에서 exit 한 뒤)
kubectl -n frontdesk exec -it shell-target -- sh
/ # exit
```

```bash
# cks-c1-w1, root
journalctl -u falco-modern-bpf --since "5 min ago" --no-pager | grep 'SHELL ns='
# Oct 24 10:12:03 cks-c1-w1 falco[812]: 10:12:03.123456789: Notice SHELL ns=frontdesk pod=shell-target container=shell-target uid=0 cmd=sh
```

```bash
# cks-c1 에서 워커의 결과를 받아 저장
mkdir -p /opt/course/e15
ssh cks-c1-w1 "sudo journalctl -u falco-modern-bpf --since '15 min ago' --no-pager | grep 'SHELL ns='" > /opt/course/e15/alerts.log
cat /opt/course/e15/alerts.log
```

규칙 조건에 `proc.tty != 0` 이 있어 `-it`(TTY)로 연 셸만 잡힙니다. `kubectl exec shell-target -- sh -c id` 처럼 TTY 없이 실행하면 이 규칙은
울리지 않습니다. 출력 앞의 `시각: Notice` 는 Falco 가 붙이는 타임스탬프와 priority 입니다(Falco 버전·`append_output` 설정에 따라 뒤에 필드가 더 붙을 수 있음).

## 검증

```bash
ssh cks-c1-w1 'sudo grep -A4 "rule: Terminal shell in container" /etc/falco/falco_rules.local.yaml'
ssh cks-c1-w1 'sudo systemctl is-active falco-modern-bpf'            # active
ssh cks-c1-w1 'sudo md5sum -c /opt/course/e15/backup/falco_rules.yaml.md5'   # OK — 기본 규칙 파일은 setup 직후 그대로
grep -c 'SHELL ns=frontdesk pod=shell-target' /opt/course/e15/alerts.log   # 1 이상
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 기존 규칙 수정 = `falco_rules.local.yaml` 에 같은 `rule:` 이름 + 바꿀 키 + `override: {<키>: replace|append}`. 검증 `falco -V`, 적용 `systemctl restart falco-modern-bpf`, 확인 `journalctl -u falco-modern-bpf`.
- **헷갈리는 지점**: 규칙 이름은 대소문자·공백까지 정확히 같아야 override 됩니다(다르면 "새 규칙"으로 인식되어 condition 이 없다는 오류). `%k8s.pod.name` 같은 필드는 컨테이너 메타데이터가 있어야 채워지고, 없으면 `<NA>` 로 나옵니다. 경보는 Falco 가 도는 **워커**에서 보이고, 답안 파일은 `cks-c1` 에 씁니다.

## 참고 문서

- 검색어: `falco rules override`, `falco output fields`, `falco rules files`
- https://falco.org/docs/concepts/rules/overriding/
- https://falco.org/docs/concepts/rules/basic-elements/
- https://falco.org/docs/reference/rules/supported-fields/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q16 →](../q16_audit_log_who_deleted/question.md)
