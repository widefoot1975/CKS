# 8일차 (D-3) — Runtime Security (Falco · 감사 로그 · crictl)

[← 7일차](day07.md) · [계획 전체](README.md) · [9일차 →](day09.md)

## 오늘의 목표

- Falco 경보에서 **컨테이너 ID → 파드 → 네임스페이스**로 좁혀 가는 순서를 몸에 붙입니다.
- 감사 로그를 `jq` 로 걸러 누가, 언제, 무엇을 했는지 답합니다.

## 시간표

| 시간 | 할 일 |
|---|---|
| 0:00 – 0:15 | [cheatsheet.md](../cheatsheet.md) §7 Monitoring, Logging and Runtime Security |
| 0:15 – 0:50 | 아래 문제 4개 풀기 |
| 0:50 – 0:57 | `solution.md` 와 대조, 오답 원인 기록 |
| 0:57 – 1:00 | `## Record` 에 기록하고 `python3 scripts/update_progress.py` 실행 |

## 풀 문제

| 문제 | 도메인 | 주제 | 배점 | 목표 | 결과 |
|---|---|---|---|---|---|
| D15 | Runtime Security | Falco 가 셸 실행을 알린 파드 멈추기 | 7 | 9분 | [Q](../mock_exam_d/q15_falco_shell_alert_delete_pod/question.md) · [S](../mock_exam_d/q15_falco_shell_alert_delete_pod/solution.md) ☐ |
| E15 | Runtime Security | override 로 Falco 규칙 출력 바꾸기 | 7 | 9분 | [Q](../mock_exam_e/q15_falco_rule_output_change/question.md) · [S](../mock_exam_e/q15_falco_rule_output_change/solution.md) ☐ |
| E16 | Runtime Security | 감사 로그에서 ConfigMap 지운 사람 찾기 | 7 | 9분 | [Q](../mock_exam_e/q16_audit_log_who_deleted/question.md) · [S](../mock_exam_e/q16_audit_log_who_deleted/solution.md) ☐ |
| E17 | Runtime Security | crictl 로 root 로 도는 컨테이너 찾기 | 6 | 8분 | [Q](../mock_exam_e/q17_crictl_find_root_container/question.md) · [S](../mock_exam_e/q17_crictl_find_root_container/solution.md) ☐ |

합계 27점, 목표 35분.

## 꼭 잡을 것

```bash
journalctl -u falco-modern-bpf --since '10 min ago' | grep -i shell
crictl ps --id <id> ; crictl inspect <id> | jq -r '.status.labels["io.kubernetes.pod.name"], .status.labels["io.kubernetes.pod.namespace"]'
vim /etc/falco/falco_rules.local.yaml ; systemctl restart falco-modern-bpf
jq -c 'select(.verb=="delete" and .objectRef.resource=="configmaps") | [.user.username, .objectRef.namespace, .objectRef.name, .requestReceivedTimestamp]' \
  /var/log/kubernetes/audit/audit.log
```

- Falco 의 기본 규칙 파일(`falco_rules.yaml`)은 고치지 않습니다. 새 규칙과 override 는 `falco_rules.local.yaml`(또는 `rules.d`)에 넣습니다.
- 규칙 출력 필드: `%evt.time`, `%k8s.ns.name`, `%k8s.pod.name`, `%container.id`, `%proc.name`, `%user.uid`.
- 감사 정책은 **위에서부터 처음 맞는 규칙 하나**만 적용됩니다. 넓은 규칙을 위에 두면 아래 규칙이 무시됩니다.

## 여유가 있으면

- 심화 [A15 payments 컨테이너의 셸을 잡는 Falco 규칙](../mock_exam_a/q15_falco_custom_rule_shell_output/question.md)
- 심화 [B16 감사 로그 조사와 소음 줄이기](../mock_exam_b/q16_audit_log_investigation/question.md)
