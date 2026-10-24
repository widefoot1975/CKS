# q15 — Investigate existing Falco alerts · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Falco runs on worker node `cks-c1-w1` as the systemd service `falco-modern-bpf` and has already
> raised alerts. Ignore alerts for namespaces `kube-system` and `default` and alerts caused by your
> own `kubectl exec` or debugging sessions.
>
> 1. Use the Falco alerts of the last 15 minutes to identify every Pod that triggered an alert with
>    priority `Warning` or higher. Write them to `/opt/course/b15/offenders.txt` on `cks-c1`, one per
>    line, as `<namespace>/<pod-name>`.
> 2. Stop the offending workloads so that no Pod of them is running and none is recreated. Do not
>    touch the other workloads.
> 3. Raise the priority of the Falco rule `Read sensitive file untrusted` to `CRITICAL` without
>    editing `/etc/falco/falco_rules.yaml`. Restart Falco and prove that the rule now fires with
>    priority `Critical`: copy one such new alert line to `/opt/course/b15/critical.txt` on
>    `cks-c1`.

**해석**

워커 `cks-c1-w1` 에서 Falco 가 systemd 서비스 `falco-modern-bpf` 로 돌고 있고 이미 경고를 냈다. `kube-system`, `default` 네임스페이스의 경고와
직접 한 `kubectl exec`·디버깅으로 생긴 경고는 무시한다.

1. 최근 15분의 Falco 경고에서 우선순위 `Warning` 이상을 일으킨 Pod 를 모두 찾아 `<namespace>/<pod-name>` 형식으로 한 줄씩 `cks-c1` 의
   `/opt/course/b15/offenders.txt` 에 쓴다.
2. 문제의 워크로드를 멈춰 그 Pod 가 하나도 돌지 않고 다시 생기지도 않게 한다. 다른 워크로드는 건드리지 않는다.
3. `/etc/falco/falco_rules.yaml` 을 고치지 않고 규칙 `Read sensitive file untrusted` 의 우선순위를 `CRITICAL` 로 올린다. Falco 를 재시작하고
   이 규칙이 `Critical` 로 울리는 새 경고 한 줄을 `cks-c1` 의 `/opt/course/b15/critical.txt` 에 복사한다.

## 모범 풀이

**1) 경고 읽기 (워커)**

```bash
ssh cks-c1-w1
sudo -i
systemctl status falco-modern-bpf --no-pager | head -5
journalctl -u falco-modern-bpf --since "15 min ago" --no-pager \
  | grep -E ': (Emergency|Alert|Critical|Error|Warning) ' \
  | sed -E 's/^.*: (Emergency|Alert|Critical|Error|Warning) /\1 /' | cut -c1-220 | sort | uniq -c | sort -rn | head
#  45 Warning Sensitive file opened for reading by non-trusted program (file=/etc/shadow ... process=cat ... container_id=5c1f0a9b2e3d container_name=cache ...)
#  45 Critical Executing binary not part of base image (proc_exe=/tmp/ls ... container_id=9e8d7c6b5a41 container_name=tracker ...)
#  ...
```

Falco 우선순위는 높은 것부터 `Emergency > Alert > Critical > Error > Warning > Notice > Informational > Debug` 입니다. "Warning 이상"이면
위 다섯 단계를 모두 봅니다. 출력 형식은 버전마다 조금 다르지만 `container_id=<12자리>` 는 항상 있습니다(새 버전은 `k8s_pod_name=`,
`k8s_ns_name=` 도 붙습니다).

**2) container_id → Pod 매핑**

```bash
journalctl -u falco-modern-bpf --since "15 min ago" --no-pager \
  | grep -E ': (Emergency|Alert|Critical|Error|Warning) ' | grep -o 'container_id=[0-9a-f]*' | sort -u
# container_id=5c1f0a9b2e3d
# container_id=9e8d7c6b5a41
for id in 5c1f0a9b2e3d 9e8d7c6b5a41; do
  crictl inspect $id | jq -r '.status.labels | "\(.["io.kubernetes.pod.namespace"])/\(.["io.kubernetes.pod.name"])"'
done
# retail/cache-6c9d...-x7k2p
# logistics/tracker-5f7b...-q9w4z
```

`crictl inspect` 는 12자리 축약 ID 도 받습니다. `crictl ps --id <id>` 의 POD 열, `crictl inspectp <podID>` 로도 같은 정보를 얻습니다.
`container_id=host` 인 경고는 컨테이너가 아니라 호스트 프로세스입니다.

```bash
exit; exit
cat > /opt/course/b15/offenders.txt <<'EOF'
retail/cache-6c9d...-x7k2p
logistics/tracker-5f7b...-q9w4z
EOF
```

**3) 워크로드 멈추기 — Pod 만 지우면 다시 생긴다**

```bash
kubectl -n retail get pod cache-6c9d...-x7k2p -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}{"\n"}'
# ReplicaSet/cache-6c9d...
kubectl -n retail scale deploy cache --replicas=0
kubectl -n logistics scale deploy tracker --replicas=0
kubectl get pod -n retail; kubectl get pod -n logistics      # storefront, router 만 남음
```

> 함정: `kubectl delete pod` 만 하면 ReplicaSet 이 즉시 새 Pod 를 만들어 경고가 계속 납니다. 소유자(Deployment)를 0 으로 줄이거나 지웁니다.

**4) 우선순위 오버라이드 — 로컬 규칙 파일에**

```bash
ssh cks-c1-w1
sudo -i
grep -n -A3 'rule: Read sensitive file untrusted' /etc/falco/falco_rules.yaml | head     # priority: WARNING
cat >> /etc/falco/falco_rules.local.yaml <<'EOF'

- rule: Read sensitive file untrusted
  priority: CRITICAL
  override:
    priority: replace
EOF
falco --dry-run -c /etc/falco/falco.yaml 2>&1 | tail -3     # 규칙 문법 확인(버전에 따라 -V/--validate 사용)
systemctl restart falco-modern-bpf
systemctl is-active falco-modern-bpf
```

> 함정: `/etc/falco/falco_rules.yaml` 은 패키지(또는 falcoctl 규칙 업데이트)가 덮어쓰는 파일입니다. 사용자 변경은 그 **뒤에 로드되는**
> `falco_rules.local.yaml`(또는 `/etc/falco/rules.d/`)에 둡니다. 같은 이름의 규칙을 다시 정의할 때는 `override:` 로 바꿀 필드와 방식
> (`replace`/`append`)을 적습니다. 옛 문법 `append: true` 는 condition 덧붙이기용이라 priority 변경에는 맞지 않습니다.

```bash
# 새 경고 만들기: 워커에서 /etc/shadow 를 읽는 짧은 Pod
kubectl run shadow-test -n retail --restart=Never --image=nginx:1.27-alpine \
  --overrides='{"spec":{"nodeName":"cks-c1-w1"}}' --command -- sh -c 'cat /etc/shadow >/dev/null; sleep 5'
ssh cks-c1-w1 "sudo journalctl -u falco-modern-bpf --since '2 min ago' --no-pager | grep -m1 'Critical Sensitive file opened'" \
  > /opt/course/b15/critical.txt
cat /opt/course/b15/critical.txt
# ... Critical Sensitive file opened for reading by non-trusted program (file=/etc/shadow ... container_name=shadow-test ...)
kubectl -n retail delete pod shadow-test
```

## 검증

```bash
cat /opt/course/b15/offenders.txt
kubectl -n retail get deploy; kubectl -n logistics get deploy      # cache, tracker 는 0/0, 나머지 1/1
ssh cks-c1-w1 'sudo tail -6 /etc/falco/falco_rules.local.yaml'
ssh cks-c1-w1 'sudo systemctl is-active falco-modern-bpf'
grep -c Critical /opt/course/b15/critical.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `journalctl -u falco-modern-bpf --since ...` → `container_id` → `crictl inspect <id>` 의 `io.kubernetes.pod.namespace/name` 라벨 → 소유 워크로드를 scale 0. 규칙 변경은 `falco_rules.local.yaml` + `override: {priority: replace}`.
- **헷갈리는 지점**: Falco 서비스 이름은 드라이버별로 다릅니다(`falco-modern-bpf`, `falco-kmod`, `falco-bpf`). Falco 를 DaemonSet 으로 돌리는 환경이면 로그는 `kubectl -n falco logs ds/falco` 입니다. 경고를 일으킨 바이너리(`/tmp/ls`)는 이미지에 없던 파일이라 "Drop and execute new binary in container" 가 CRITICAL 로 울립니다.

## 참고 문서

- 검색어: `falco rules`, `falco override rules`, `falco outputs`, `crictl`
- https://falco.org/docs/concepts/rules/
- https://falco.org/docs/
- https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q16 →](../q16_audit_log_investigation/question.md)
