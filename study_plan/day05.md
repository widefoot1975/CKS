# 5일차 (D-6) — Pod Security · securityContext · Secret

[← 4일차](day04.md) · [계획 전체](README.md) · [6일차 →](day06.md)

## 오늘의 목표

- Pod Security Admission 라벨(enforce·warn·audit)의 차이와 `--dry-run=server` 로 위반 파드를 미리 보는 법을 익힙니다.
- Secret 을 파일로, 읽기 전용으로 넘기고 etcd 에 어떻게 저장되는지 직접 봅니다.

## 시간표

| 시간 | 할 일 |
|---|---|
| 0:00 – 0:15 | [cheatsheet.md](../cheatsheet.md) §5 Minimize Microservice Vulnerabilities 앞부분 (PSA, restricted 4종, etcdctl) |
| 0:15 – 0:43 | 아래 문제 4개 풀기 |
| 0:43 – 0:55 | `solution.md` 와 대조, 오답 원인 기록 |
| 0:55 – 1:00 | `## Record` 에 기록하고 `python3 scripts/update_progress.py` 실행 |

## 풀 문제

| 문제 | 도메인 | 주제 | 배점 | 목표 | 결과 |
|---|---|---|---|---|---|
| D09 | Microservice | restricted 강제하고 파드 고치기 | 7 | 7분 | [Q](../mock_exam_d/q09_psa_restricted_label_fix_pod/question.md) · [S](../mock_exam_d/q09_psa_restricted_label_fix_pod/solution.md) ☐ |
| E09 | Microservice | privileged 컨테이너의 capability 버리기 | 7 | 7분 | [Q](../mock_exam_e/q09_securitycontext_drop_caps_nonprivileged/question.md) · [S](../mock_exam_e/q09_securitycontext_drop_caps_nonprivileged/solution.md) ☐ |
| D10 | Microservice | Secret 을 읽기 전용 볼륨으로 | 7 | 7분 | [Q](../mock_exam_d/q10_secret_volume_readonly/question.md) · [S](../mock_exam_d/q10_secret_volume_readonly/solution.md) ☐ |
| F10 | Microservice | etcd 에서 Secret 직접 읽기 | 7 | 7분 | [Q](../mock_exam_f/q10_etcdctl_read_secret_plaintext/question.md) · [S](../mock_exam_f/q10_etcdctl_read_secret_plaintext/solution.md) ☐ |

합계 28점, 목표 28분.

## 꼭 잡을 것

```bash
kubectl label ns team pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.35
kubectl label --dry-run=server --overwrite ns team pod-security.kubernetes.io/enforce=restricted
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt --key=/etc/kubernetes/pki/apiserver-etcd-client.key \
  get /registry/secrets/<ns>/<name> | hexdump -C | head
```

- restricted 4종: `runAsNonRoot: true`(+숫자 UID), `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`. 뒤의 둘은 **컨테이너 수준에만** 있습니다.
- `enforce` 는 거부, `warn` 은 kubectl 경고, `audit` 은 감사 로그에만 남깁니다. 거부된 파드는 ReplicaSet 이벤트에 보입니다.
- 암호화하지 않은 etcd 에는 Secret 값이 **평문 그대로**(base64 도 아님) 보입니다.

## 여유가 있으면

- 심화 [A09 baseline 강제와 restricted 경고](../mock_exam_a/q09_psa_baseline_enforce_restricted_warn/question.md)
- 심화 [B10 Secret 파일 마운트와 resourceNames](../mock_exam_b/q10_secret_file_mount_resource_names/question.md)
