# q15 — Falco rule for shells spawned in payment containers · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Some workload in namespace `payments` keeps spawning shells. Falco runs on worker node
> `cks-c1-w1`.
>
> 1. On `cks-c1-w1`, add a Falco rule named `Shell in payments container` to
>    `/etc/falco/falco_rules.local.yaml` (do not edit `/etc/falco/falco_rules.yaml`) that
>    triggers whenever a shell process (any program of Falco's default list `shell_binaries`)
>    is started in a container of namespace `payments`. Use priority `WARNING` and exactly this
>    output:
>
>    ```
>    %evt.time,%k8s.ns.name,%k8s.pod.name,%proc.name,%user.uid
>    ```
>
> 2. Make Falco load the rule. Collect at least three alert lines produced by this rule and
>    write them to `/opt/course/a15/alerts.log` on `cks-c1`.
> 3. Identify the Deployment that spawns the shells, scale it to `0` replicas, and write its
>    name to `/opt/course/a15/deployment.txt`.

**해석**

namespace `payments` 의 어떤 워크로드가 계속 셸을 띄운다. Falco 는 워커 `cks-c1-w1` 에서 돌고 있다.

1. `cks-c1-w1` 의 `/etc/falco/falco_rules.local.yaml` 에(`/etc/falco/falco_rules.yaml` 은 수정하지 않는다) 이름이 `Shell in payments container` 인
   규칙을 추가한다. `payments` namespace 의 컨테이너에서 셸 프로세스(Falco 기본 목록 `shell_binaries` 의 프로그램)가 시작될 때마다 발생해야 한다.
   우선순위는 `WARNING`, 출력은 위 형식 그대로.
2. Falco 가 규칙을 읽게 한다. 이 규칙이 만든 경고를 세 줄 이상 모아 `cks-c1` 의 `/opt/course/a15/alerts.log` 에 쓴다.
3. 셸을 띄우는 Deployment 를 찾아 레플리카 0 으로 줄이고, 이름을 `/opt/course/a15/deployment.txt` 에 쓴다.

## 모범 풀이

**1) 규칙 작성 — 로컬 파일에**

```bash
ssh cks-c1-w1
sudo -i
grep -n -A3 -- '- list: shell_binaries' /etc/falco/falco_rules.yaml      # [ash, bash, csh, ksh, sh, tcsh, zsh, dash]
grep -n -A2 -- '- macro: spawned_process' /etc/falco/falco_rules.yaml   # evt.type in (execve, execveat) and evt.dir=<
vim /etc/falco/falco_rules.local.yaml
```

```yaml
- rule: Shell in payments container
  desc: A shell was started inside a container of namespace payments
  condition: >
    spawned_process
    and container
    and k8s.ns.name = "payments"
    and proc.name in (shell_binaries)
  output: "%evt.time,%k8s.ns.name,%k8s.pod.name,%proc.name,%user.uid"
  priority: WARNING
  tags: [cks, shell]
```

`falco_rules.yaml` 은 패키지 업그레이드나 `falcoctl` 의 규칙 갱신 때 **덮어써지므로** 사용자 규칙은 `falco_rules.local.yaml`(또는
`/etc/falco/rules.d/`)에 둡니다. 로컬 파일은 기본 규칙 파일 **뒤에** 로드되므로 `spawned_process`, `container` 매크로와
`shell_binaries` 목록을 그대로 쓸 수 있습니다. 출력 문자열에 `,` 와 `%` 가 있으므로 YAML 에서 따옴표로 감쌉니다.

**2) 문법 확인 → 재시작 → 경고 수집**

```bash
falco -V /etc/falco/falco_rules.yaml -V /etc/falco/falco_rules.local.yaml     # 로컬 파일만 검증하면 매크로를 못 찾는다
systemctl restart falco-modern-bpf
systemctl status falco-modern-bpf --no-pager | head -3                        # active (running)
sleep 40
journalctl -u falco-modern-bpf --since "2 min ago" --no-pager | grep ',payments,' | tail -5
# … falco[812]: 10:41:02.511920349: Warning 10:41:02.511920349,payments,payments-worker-6b7d9c-x2k4p,sh,0
exit; exit
```

```bash
# cks-c1 에서
ssh cks-c1-w1 "sudo journalctl -u falco-modern-bpf --since '5 min ago' --no-pager | grep ',payments,'" > /opt/course/a15/alerts.log
wc -l /opt/course/a15/alerts.log           # 3 이상
```

Falco 는 규칙 파일을 기동할 때 읽으므로 수정 후 재시작(또는 `SIGHUP`, 설정에 따라 자동 리로드)이 필요합니다. 규칙에 문법 오류가 있으면
서비스가 **시작에 실패**해 모든 탐지가 멈추므로 `systemctl status` 로 꼭 확인합니다. 출력 앞에 붙는 `시각: Warning` 은 Falco 가
자동으로 붙이는 머리말이고, 버전·설정(`append_output` 등)에 따라 뒤에 컨테이너 필드가 덧붙을 수도 있습니다.

| 필드 | 의미 |
|---|---|
| `%evt.time` | 이벤트 시각 |
| `%k8s.ns.name`, `%k8s.pod.name` | 컨테이너 런타임 라벨에서 얻은 namespace·Pod 이름 (런타임 소켓 연결 실패 시 `<NA>`) |
| `%proc.name` | 실행된 프로세스 이름(`sh`) |
| `%user.uid` | 실행 사용자 UID (컨테이너 기준) |

**3) Deployment 찾기 → 0 으로**

```bash
cut -d, -f3 /opt/course/a15/alerts.log | sort -u           # payments-worker-6b7d9c-x2k4p
kubectl -n payments get pod payments-worker-6b7d9c-x2k4p -o jsonpath='{.metadata.ownerReferences[0].name}{"\n"}'   # ReplicaSet 이름
kubectl -n payments get rs payments-worker-6b7d9c -o jsonpath='{.metadata.ownerReferences[0].name}{"\n"}'          # payments-worker
kubectl -n payments scale deploy payments-worker --replicas=0
echo payments-worker > /opt/course/a15/deployment.txt
```

`billing` namespace 의 `billing-worker` 도 똑같이 셸을 띄우지만 조건의 `k8s.ns.name = "payments"` 때문에 경고가 나오지 않습니다.
`payments-web` 은 셸을 띄우지 않으므로 그대로 둡니다.

## 검증

```bash
ssh cks-c1-w1 sudo grep -A8 'Shell in payments container' /etc/falco/falco_rules.local.yaml
ssh cks-c1-w1 systemctl is-active falco-modern-bpf                  # active
grep -c ',payments,.*,sh,' /opt/course/a15/alerts.log                # 3 이상
grep -c billing /opt/course/a15/alerts.log                          # 0
kubectl -n payments get deploy                                       # payments-worker 0/0, payments-web 1/1
cat /opt/course/a15/deployment.txt                                   # payments-worker
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 규칙 = `rule`/`desc`/`condition`/`output`/`priority`. 사용자 규칙은 `falco_rules.local.yaml`. `spawned_process and container and k8s.ns.name = "x" and proc.name in (shell_binaries)`. 수정 후 `systemctl restart falco-modern-bpf` → `journalctl -u falco-modern-bpf`.
- **헷갈리는 지점**: 기본 규칙 `Terminal shell in container` 는 TTY 가 있는 셸만 잡으므로 `kubectl exec -it` 가 아닌 스크립트 셸은 놓칩니다. 우선순위 키워드는 `WARNING`(대소문자 무관), 출력의 머리말 `Warning` 은 Falco 가 붙입니다. Pod 이름 → ReplicaSet → Deployment 로 소유자를 따라갑니다.

## 참고 문서

- 검색어: `falco rules`, `falco default macros`, `falco supported fields`
- https://falco.org/docs/concepts/rules/
- https://falco.org/docs/reference/rules/supported-fields/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q16 →](../q16_audit_policy_rules_apiserver/question.md)
