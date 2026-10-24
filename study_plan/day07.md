# 7일차 (D-4) — Supply Chain (이미지 최소화 · Trivy · 정적 분석 · 허용 레지스트리)

[← 6일차](day06.md) · [계획 전체](README.md) · [8일차 →](day08.md)

## 오늘의 목표

- Dockerfile 을 고쳐 공격면을 줄이고, Trivy·kubesec 결과로 확인합니다.
- ValidatingAdmissionPolicy 로 허용 레지스트리를 강제합니다. 웹훅 없이 CEL 로 끝납니다.

## 시간표

| 시간 | 할 일 |
|---|---|
| 0:00 – 0:15 | [cheatsheet.md](../cheatsheet.md) §6 Supply Chain Security, 루트 README 의 Trivy 행과 `열람 가능한 문서` |
| 0:15 – 0:42 | 아래 문제 4개 풀기 |
| 0:42 – 0:54 | `solution.md` 와 대조, 오답 원인 기록 |
| 0:54 – 1:00 | `## Record` 에 기록하고 `python3 scripts/update_progress.py` 실행 |

## 풀 문제

| 문제 | 도메인 | 주제 | 배점 | 목표 | 결과 |
|---|---|---|---|---|---|
| D12 | Supply Chain | Dockerfile 베이스 이미지 고정과 non-root | 7 | 7분 | [Q](../mock_exam_d/q12_dockerfile_nonroot_pinned_tag/question.md) · [S](../mock_exam_d/q12_dockerfile_nonroot_pinned_tag/solution.md) ☐ |
| D13 | Supply Chain | Trivy 로 CRITICAL 개수 세기 | 7 | 7분 | [Q](../mock_exam_d/q13_trivy_image_critical_count/question.md) · [S](../mock_exam_d/q13_trivy_image_critical_count/solution.md) ☐ |
| D14 | Supply Chain | 파드의 kubesec 점수 올리기 | 6 | 6분 | [Q](../mock_exam_d/q14_kubesec_score_fix_pod/question.md) · [S](../mock_exam_d/q14_kubesec_score_fix_pod/solution.md) ☐ |
| E13 | Supply Chain | VAP 로 신뢰하지 않는 레지스트리 거부 | 7 | 7분 | [Q](../mock_exam_e/q13_vap_deny_untrusted_registry/question.md) · [S](../mock_exam_e/q13_vap_deny_untrusted_registry/solution.md) ☐ |

합계 27점, 목표 27분.

## 꼭 잡을 것

```bash
trivy image --severity CRITICAL -q nginx:1.19
trivy image --severity HIGH,CRITICAL --format json -o out.json img
kubesec scan pod.yaml | jq '.[0].score, .[0].scoring.critical'
kubectl get pods -n ns -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'
```

- Trivy·kubesec·KubeLinter 문서는 시험에서 열 수 없습니다. 오늘 `trivy image --help`, `kubesec scan --help` 를 직접 읽어 둡니다.
- Dockerfile: 태그 고정, 멀티 스테이지, 최종 스테이지에 셸·패키지 관리자 없음, `USER` 는 숫자, Secret 을 `ENV` 로 넣지 않기.
- VAP 는 Policy 만으로는 아무 일도 하지 않습니다. **Binding 의 `validationActions: [Deny]`** 까지 만들어야 거부됩니다. initContainers 도 검사 대상에 넣습니다.

## 여유가 있으면

- 심화 [A14 허용 레지스트리와 태그 고정 VAP](../mock_exam_a/q14_vap_permitted_registries_no_latest/question.md)
- 심화 [C13 ImagePolicyWebhook admission 설정](../mock_exam_c/q13_imagepolicywebhook_admission_config/question.md)
