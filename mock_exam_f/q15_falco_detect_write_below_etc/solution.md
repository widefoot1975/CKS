# q15 — Falco rule for writes below /etc · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Containers in namespace `f15` must not modify files below `/etc`. Use Falco on worker node
> `cks-c1-w1` to find out which Pod does it.
>
> 1. On `cks-c1-w1`, add a Falco rule named `Write below etc in f15` to
>    `/etc/falco/falco_rules.local.yaml`. It must fire when a process in a container of namespace
>    `f15` opens a file below `/etc/` for writing. Use priority `ERROR` and an output that contains,
>    in this order, `%evt.time`, `%k8s.ns.name`, `%k8s.pod.name`, `%proc.name` and `%fd.name`. Do
>    not modify `/etc/falco/falco_rules.yaml`.
> 2. Make sure Falco has loaded the rule without errors.
> 3. Write at least three alert lines produced by this rule to `/opt/course/f15/alerts.log` on
>    `cks-c1`.
> 4. Write the name of the Pod that triggers the rule to `/opt/course/f15/pod.txt` and scale the
>    Deployment that owns it to `0` replicas.

**해석**

namespace `f15` 의 컨테이너는 `/etc` 아래 파일을 바꾸면 안 된다. 워커 노드 `cks-c1-w1` 의 Falco 로 어느 Pod 가 그러는지 찾는다.

1. `cks-c1-w1` 의 `/etc/falco/falco_rules.local.yaml` 에 규칙 `Write below etc in f15` 를 추가한다. namespace `f15` 의 컨테이너 안 프로세스가
   `/etc/` 아래 파일을 쓰기용으로 열면 발생해야 한다. priority 는 `ERROR`, output 에는 `%evt.time`, `%k8s.ns.name`, `%k8s.pod.name`, `%proc.name`,
   `%fd.name` 을 이 순서로 넣는다. `/etc/falco/falco_rules.yaml` 은 고치지 않는다.
2. Falco 가 오류 없이 규칙을 읽었는지 확인한다.
3. 이 규칙이 만든 경고를 세 줄 이상 `cks-c1` 의 `/opt/course/f15/alerts.log` 에 쓴다.
4. 규칙을 일으키는 Pod 이름을 `/opt/course/f15/pod.txt` 에 쓰고, 그 Pod 를 가진 Deployment 를 레플리카 `0` 으로 줄인다.

## 모범 풀이

**1) 규칙 작성 (워커에서)**

```bash
ssh cks-c1-w1
sudo -i
systemctl is-active falco-modern-bpf        # active
grep -n 'macro: open_write' -A3 /etc/falco/falco_rules.yaml    # 기본 매크로 참고 (고치지 않음)
```

```yaml
# /etc/falco/falco_rules.local.yaml 에 추가
- rule: Write below etc in f15
  desc: A process in a container of namespace f15 opened a file below /etc for writing
  condition: >
    evt.type in (open, openat, openat2) and evt.is_open_write = true
    and fd.typechar = 'f' and fd.num >= 0
    and fd.name startswith /etc/
    and container.id != host
    and k8s.ns.name = "f15"
  output: "%evt.time %k8s.ns.name %k8s.pod.name %proc.name %fd.name"
  priority: ERROR
  tags: [filesystem, cks]
```

조건의 앞 줄은 기본 규칙의 `open_write` 매크로와 같은 내용이고(`open_write and container and ...` 로 써도 됨), `container.id != host` 가
호스트 프로세스를 걸러 냅니다. 규칙은 반드시 **local 파일**에 둡니다. `falco_rules.yaml` 은 패키지를 올릴 때 덮어써집니다.

| 필드 | 의미 |
|---|---|
| `evt.is_open_write` | `O_WRONLY`/`O_RDWR` 등 쓰기 플래그로 열었는지 |
| `fd.name` | 연 파일의 전체 경로 (컨테이너 안 경로) |
| `container.id != host` | 컨테이너 안에서 일어난 이벤트만 |
| `k8s.ns.name`, `k8s.pod.name` | 컨테이너 런타임 라벨에서 얻은 namespace·Pod 이름 |

**2) 규칙 로드 확인 (워커에서)**

```bash
falco -V /etc/falco/falco_rules.local.yaml         # 문법 검사 (오류가 있으면 줄 번호와 함께 출력)
systemctl restart falco-modern-bpf
journalctl -u falco-modern-bpf -n 30 --no-pager | grep -iE 'error|loading rules'
# Loading rules from: /etc/falco/falco_rules.yaml
# Loading rules from: /etc/falco/falco_rules.local.yaml       ← 오류 줄이 없어야 한다
```

Falco 는 기본 설정(`watch_config_files: true`)에서 규칙 파일이 바뀌면 스스로 다시 읽지만, 재시작하면 오류를 바로 확인할 수 있습니다.

**3) 경고 수집 (`cks-c1` 에서)**

```bash
sleep 30
ssh cks-c1-w1 sudo journalctl -u falco-modern-bpf --since '-5min' --no-pager \
  | grep 'Error' | grep ' f15 ' | tail -5 > /opt/course/f15/alerts.log
cat /opt/course/f15/alerts.log
# ... falco[1234]: 10:21:03.481207523: Error 10:21:03.481207523 f15 config-writer-6d9c8b7f5-x2k4p sh /etc/f15-app.conf
```

기본 설정에서 경고는 `stdout_output` 으로 나가고 systemd 가 journal 에 남깁니다. `file_output` 을 켜 둔 환경이라면 그 파일에서 찾아도 됩니다.

**4) 원인 Pod 처리**

```bash
POD=$(awk '{for(i=1;i<=NF;i++) if($i=="f15") {print $(i+1); exit}}' /opt/course/f15/alerts.log)
echo $POD > /opt/course/f15/pod.txt
kubectl -n f15 get pod $POD -o jsonpath='{.metadata.ownerReferences[0].name}{"\n"}'   # config-writer-6d9c8b7f5 (ReplicaSet)
kubectl -n f15 scale deploy config-writer --replicas=0
```

Pod 를 지우기만 하면 ReplicaSet 이 새로 만들므로 Deployment 를 0 으로 줄입니다. `config-reader` 는 `/etc` 를 읽기만 하므로 규칙에 걸리지 않습니다.

## 검증

```bash
ssh cks-c1-w1 sudo grep -A8 'Write below etc in f15' /etc/falco/falco_rules.local.yaml
ssh cks-c1-w1 sudo systemctl is-active falco-modern-bpf                     # active
wc -l < /opt/course/f15/alerts.log                                          # 3 이상
kubectl -n f15 get deploy                                                   # config-writer 0/0, config-reader 1/1
cat /opt/course/f15/pod.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 커스텀 규칙은 `/etc/falco/falco_rules.local.yaml`(또는 `rules.d/`), 검사는 `falco -V`, 확인은 `journalctl -u falco-modern-bpf`. 원인 Pod 는 컨트롤러(Deployment)를 줄여야 다시 안 생긴다.
- **헷갈리는 지점**: `fd.name` 은 컨테이너 안에서 본 경로라 호스트의 `/etc` 와 다릅니다. output 의 필드 순서까지 채점될 수 있으므로 문제 그대로 씁니다. YAML 의 `condition: >` 아래 줄은 들여쓰기를 맞춰야 하고, 문자열 비교 값에 공백·특수문자가 있으면 따옴표로 감쌉니다.

## 참고 문서

- 검색어: `falco rules`, `falco supported fields`, `falco default macros`
- https://falco.org/docs/concepts/rules/
- https://falco.org/docs/reference/rules/supported-fields/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q16 →](../q16_audit_policy_secrets_metadata/question.md)
