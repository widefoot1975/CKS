# 3일차 (D-8) — Cluster Hardening (RBAC · ServiceAccount · CSR)

[← 2일차](day02.md) · [계획 전체](README.md) · [4일차 →](day04.md)

## 오늘의 목표

- `kubectl auth can-i --as` 로 권한을 **만들기 전과 후에** 확인하는 습관을 들입니다.
- ServiceAccount 토큰을 쓰지 않는 파드에서 빼고, 필요한 곳에는 짧은 토큰을 주는 법을 익힙니다.

## 시간표

| 시간 | 할 일 |
|---|---|
| 0:00 – 0:15 | [cheatsheet.md](../cheatsheet.md) §3 Cluster Hardening |
| 0:15 – 0:40 | 아래 문제 5개 풀기 |
| 0:40 – 0:52 | `solution.md` 와 대조, 오답 원인 기록 |
| 0:52 – 1:00 | `## Record` 에 기록하고 `python3 scripts/update_progress.py` 실행 |

## 풀 문제

| 문제 | 도메인 | 주제 | 배점 | 목표 | 결과 |
|---|---|---|---|---|---|
| D04 | Cluster Hardening | ServiceAccount 용 최소 권한 Role | 5 | 5분 | [Q](../mock_exam_d/q04_role_rolebinding_sa_least_privilege/question.md) · [S](../mock_exam_d/q04_role_rolebinding_sa_least_privilege/solution.md) ☐ |
| E04 | Cluster Hardening | 사용자 읽기 전용 ClusterRole 과 can-i | 5 | 5분 | [Q](../mock_exam_e/q04_clusterrole_readonly_user_can_i/question.md) · [S](../mock_exam_e/q04_clusterrole_readonly_user_can_i/solution.md) ☐ |
| D05 | Cluster Hardening | ServiceAccount 토큰 마운트 끄기 | 5 | 5분 | [Q](../mock_exam_d/q05_sa_automount_false/question.md) · [S](../mock_exam_d/q05_sa_automount_false/solution.md) ☐ |
| E05 | Cluster Hardening | 짧은 수명·audience 지정 토큰 | 5 | 5분 | [Q](../mock_exam_e/q05_create_token_duration_audience/question.md) · [S](../mock_exam_e/q05_create_token_duration_audience/solution.md) ☐ |
| F06 | Cluster Hardening | CSR 로 사용자 인증서 서명하고 kubeconfig 만들기 | 5 | 5분 | [Q](../mock_exam_f/q06_csr_approve_user_kubeconfig/question.md) · [S](../mock_exam_f/q06_csr_approve_user_kubeconfig/solution.md) ☐ |

합계 25점, 목표 25분.

## 꼭 잡을 것

```bash
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n ns
kubectl create rolebinding pod-reader --role=pod-reader --serviceaccount=ns:app -n ns
kubectl auth can-i --list --as=system:serviceaccount:ns:app -n ns
kubectl create token app -n ns --duration=10m --audience=vault
kubectl patch sa default -n ns -p '{"automountServiceAccountToken":false}'
kubectl certificate approve dev-ana
kubectl get csr dev-ana -o jsonpath='{.status.certificate}' | base64 -d > ana.crt
```

- SA 를 `--as` 로 흉내 낼 때는 `system:serviceaccount:<ns>:<name>` 전체를 씁니다.
- `automountServiceAccountToken` 은 SA 와 파드 양쪽에 있고, **파드 값이 우선**합니다.
- CSR 의 `signerName` 은 `kubernetes.io/kube-apiserver-client`, `usages` 는 `client auth`. 사용자 이름은 인증서 CN, 그룹은 O 입니다.

## 여유가 있으면

- 심화 [A04 CSR 사용자와 최소 권한 Role](../mock_exam_a/q04_csr_user_least_privilege_role/question.md)
- 심화 [C05 테넌트의 위험한 RBAC 권한 제거](../mock_exam_c/q05_rbac_dangerous_verbs_escalate_bind/question.md)
