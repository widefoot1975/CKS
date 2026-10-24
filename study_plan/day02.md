# 2일차 (D-9) — Cluster Setup (NetworkPolicy · Ingress TLS · 바이너리 검증)

[← 1일차](day01.md) · [계획 전체](README.md) · [3일차 →](day03.md)

## 오늘의 목표

- 기본 거부 + 필요한 것만 여는 NetworkPolicy 를 5분 안에 씁니다. 메타데이터(169.254.169.254) 차단도 같은 틀입니다.
- TLS Secret → Ingress `tls` → `curl --resolve` 확인 순서와 sha512 비교를 손에 익힙니다.

## 시간표

| 시간 | 할 일 |
|---|---|
| 0:00 – 0:15 | [cheatsheet.md](../cheatsheet.md) §2 Cluster Setup |
| 0:15 – 0:40 | 아래 문제 5개 풀기 |
| 0:40 – 0:52 | `solution.md` 와 대조, 오답 원인 기록 |
| 0:52 – 1:00 | `## Record` 에 기록하고 `python3 scripts/update_progress.py` 실행 |

## 풀 문제

| 문제 | 도메인 | 주제 | 배점 | 목표 | 결과 |
|---|---|---|---|---|---|
| D01 | Cluster Setup | 기본 거부 ingress 와 허용 클라이언트 하나 | 5 | 5분 | [Q](../mock_exam_d/q01_networkpolicy_default_deny_ingress/question.md) · [S](../mock_exam_d/q01_networkpolicy_default_deny_ingress/solution.md) ☐ |
| E01 | Cluster Setup | 한 네임스페이스에서만 ingress 허용 | 5 | 5분 | [Q](../mock_exam_e/q01_networkpolicy_allow_from_namespace/question.md) · [S](../mock_exam_e/q01_networkpolicy_allow_from_namespace/solution.md) ☐ |
| F01 | Cluster Setup | 클라우드 메타데이터로 가는 egress 차단 | 5 | 5분 | [Q](../mock_exam_f/q01_networkpolicy_block_metadata_egress/question.md) · [S](../mock_exam_f/q01_networkpolicy_block_metadata_egress/solution.md) ☐ |
| E03 | Cluster Setup | 자체 서명 인증서로 Ingress TLS | 5 | 5분 | [Q](../mock_exam_e/q03_ingress_tls_basic/question.md) · [S](../mock_exam_e/q03_ingress_tls_basic/solution.md) ☐ |
| D03 | Cluster Setup | kubectl 바이너리 SHA-512 검증 | 5 | 5분 | [Q](../mock_exam_d/q03_verify_kubectl_sha512/question.md) · [S](../mock_exam_d/q03_verify_kubectl_sha512/solution.md) ☐ |

합계 25점, 목표 25분.

## 꼭 잡을 것

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 -keyout tls.key -out tls.crt \
  -subj '/CN=shop.example.com' -addext 'subjectAltName=DNS:shop.example.com'
kubectl create secret tls web-tls --cert=tls.crt --key=tls.key -n ns
curl -kv --resolve shop.example.com:<port>:<nodeIP> https://shop.example.com:<port>/
echo "$(curl -sL https://dl.k8s.io/v1.35.0/bin/linux/amd64/kubectl.sha512)  kubectl" | sha512sum -c
```

- `namespaceSelector` 는 `kubernetes.io/metadata.name` 라벨로 고르면 라벨을 따로 붙일 필요가 없습니다.
- egress 를 막으면 DNS(53 UDP·TCP)를 따로 열어야 이름 풀이가 됩니다.
- 메타데이터 차단: `ipBlock: {cidr: 0.0.0.0/0, except: [169.254.169.254/32]}`.
- 바이너리 검증은 **클러스터와 같은 버전**의 체크섬으로 합니다. `kubectl version` 으로 버전부터 확인합니다.

## 여유가 있으면

- 심화 [A01 기본 거부에 DNS·API·외부 egress 만 열기](../mock_exam_a/q01_networkpolicy_default_deny_dns_metadata/question.md)
- 심화 [B03 플랫폼 바이너리와 apiserver 이미지 검증](../mock_exam_b/q03_verify_platform_binaries_sha512/question.md)
