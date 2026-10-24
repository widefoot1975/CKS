# q15 — Stop a Pod that Falco reports spawning shells · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Falco runs on worker node `cks-c1-w1` as the systemd service `falco-modern-bpf`. The security
> team added the rule `Shell spawned in container`, and it keeps firing for one workload in
> namespace `garnet` or `jet`.
>
> 1. Using the Falco alerts on `cks-c1-w1`, find the Pod that spawns shells. Write its namespace
>    and Pod name, separated by one space (for example `team1 web-5d8f9c-abcde`), to
>    `/opt/course/d15/pod.txt` on `cks-c1`.
> 2. Scale the Deployment that owns this Pod to `0` replicas. Do not delete the Deployment and do
>    not change any other workload.
> 3. Confirm that the rule stops firing for that workload.

**해석**

워커 노드 `cks-c1-w1` 에서 Falco 가 systemd 서비스 `falco-modern-bpf` 로 돈다. 보안팀이 규칙 `Shell spawned in container` 를
추가했고, namespace `garnet` 또는 `jet` 의 워크로드 하나 때문에 계속 경보가 난다.

1. `cks-c1-w1` 의 Falco 경보로 셸을 띄우는 Pod 를 찾는다. namespace 와 Pod 이름을 공백 하나로 구분해(예: `team1 web-5d8f9c-abcde`)
   `cks-c1` 의 `/opt/course/d15/pod.txt` 에 쓴다.
2. 이 Pod 를 소유한 Deployment 를 replicas `0` 으로 줄인다. Deployment 를 지우거나 다른 워크로드를 바꾸지 않는다.
3. 그 워크로드에 대한 경보가 멈췄는지 확인한다.

## 모범 풀이

**1) 경보에서 Pod 찾기**

```bash
ssh cks-c1-w1
sudo -i
systemctl status falco-modern-bpf --no-pager | head -3          # active (running)
journalctl -u falco-modern-bpf --since "10 min ago" --no-pager | grep 'Shell spawned' | tail -3
# ... Warning Shell spawned in container (ns=garnet pod=report-gen-6c9f7b8d4-x2kqp container=3f1c2a9b8e7d
#     cmdline=sh -c date > /tmp/last-run user=root)
cat /etc/falco/rules.d/d15-shell.yaml                            # 규칙 조건과 output 형식 확인
exit; exit
```

Falco 는 기본 설정에서 경보를 stdout(→ journald)과 syslog 로 냅니다. 출력에 Pod 이름이 없고 컨테이너 ID 만 있다면
워커에서 `crictl ps --id <ID>` / `crictl inspect <ID> | grep -E 'io.kubernetes.pod.(name|namespace)'` 로 Pod 를 찾습니다.
경보는 계속 쌓이므로 `journalctl -f -u falco-modern-bpf | grep 'Shell spawned'` 로 지금도 나오는지 보는 것이 확실합니다.

```bash
echo "garnet report-gen-6c9f7b8d4-x2kqp" > /opt/course/d15/pod.txt     # cks-c1 에서, 실제 Pod 이름으로
```

**2) 소유 Deployment 축소**

```bash
alias k=kubectl
k -n garnet get pod report-gen-6c9f7b8d4-x2kqp -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}{"\n"}'
# ReplicaSet/report-gen-6c9f7b8d4        ← ReplicaSet 의 owner 가 Deployment report-gen
k -n garnet get rs report-gen-6c9f7b8d4 -o jsonpath='{.metadata.ownerReferences[0].name}{"\n"}'   # report-gen
k -n garnet scale deploy report-gen --replicas=0
k -n garnet get deploy
```

Pod 만 지우면 ReplicaSet 이 같은 템플릿으로 새 Pod 를 만들어 경보가 다시 납니다. 그래서 소유자(Deployment)를 0 으로 줄입니다.
조사(포렌식)가 필요하면 지우기 전에 `k -n garnet logs`, `k -n garnet get pod -o yaml` 을 남겨 둡니다.

**3) 경보가 멈췄는지 확인**

```bash
ssh cks-c1-w1 'sudo journalctl -u falco-modern-bpf --since "1 min ago" --no-pager | grep "Shell spawned" | grep -c "ns=garnet" '
# 0
```

## 검증

```bash
cat /opt/course/d15/pod.txt                                   # garnet report-gen-...
k -n garnet get deploy report-gen -o jsonpath='{.spec.replicas}{"\n"}'     # 0
k get deploy -n garnet; k get deploy -n jet                   # 나머지는 그대로 1/1
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: Falco 경보는 `journalctl -u falco-modern-bpf` (또는 `/var/log/syslog`). Pod → `ownerReferences` → ReplicaSet → Deployment 로 올라가 소유자를 멈춘다.
- **헷갈리는 지점**: 서비스 이름은 드라이버마다 다릅니다(`falco-modern-bpf`, `falco-kmod`, `falco-bpf`). 기본 규칙 `Terminal shell in container` 는 TTY 가 있는 셸(`kubectl exec -it`)에서만 나고, 이 문제처럼 스크립트가 띄우는 셸은 별도 규칙이 있어야 잡힙니다. 규칙 수정은 `falco_rules.yaml` 이 아니라 `falco_rules.local.yaml` 이나 `rules.d/` 에 합니다.

## 참고 문서

- 검색어: `falco rules`, `falco outputs`
- https://falco.org/docs/concepts/rules/
- https://falco.org/docs/concepts/outputs/
- https://kubernetes.io/docs/concepts/overview/working-with-objects/owners-dependents/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q16 →](../q16_audit_enable_given_policy/question.md)
