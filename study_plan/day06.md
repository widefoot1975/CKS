# 6일차 (D-5) — 격리와 암호화 (etcd 암호화 · gVisor · user namespace · mTLS)

[← 5일차](day05.md) · [계획 전체](README.md) · [7일차 →](day07.md)

## 오늘의 목표

- EncryptionConfiguration 을 apiserver 에 붙이고 **기존 Secret 을 다시 써서** 암호화합니다.
- RuntimeClass, `hostUsers: false`, Istio `PeerAuthentication` 으로 격리 수준을 높이는 법을 비교합니다.

## 시간표

| 시간 | 할 일 |
|---|---|
| 0:00 – 0:15 | [cheatsheet.md](../cheatsheet.md) §5 뒷부분 (EncryptionConfiguration, RuntimeClass, user namespaces, Istio·Cilium) |
| 0:15 – 0:40 | 아래 문제 4개 풀기 |
| 0:40 – 0:52 | `solution.md` 와 대조, 오답 원인 기록 |
| 0:52 – 1:00 | `## Record` 에 기록하고 `python3 scripts/update_progress.py` 실행 |

## 풀 문제

| 문제 | 도메인 | 주제 | 배점 | 목표 | 결과 |
|---|---|---|---|---|---|
| E10 | Microservice | identity 에서 aescbc 로 암호화 전환 | 7 | 7분 | [Q](../mock_exam_e/q10_encryption_config_identity_to_aescbc/question.md) · [S](../mock_exam_e/q10_encryption_config_identity_to_aescbc/solution.md) ☐ |
| D11 | Microservice | RuntimeClass 로 gVisor 파드 | 6 | 6분 | [Q](../mock_exam_d/q11_runtimeclass_gvisor_pod/question.md) · [S](../mock_exam_d/q11_runtimeclass_gvisor_pod/solution.md) ☐ |
| F11 | Microservice | user namespace 로 Deployment 실행 | 6 | 6분 | [Q](../mock_exam_f/q11_user_namespaces_hostusers_false/question.md) · [S](../mock_exam_f/q11_user_namespaces_hostusers_false/solution.md) ☐ |
| E11 | Microservice | Istio PeerAuthentication STRICT | 6 | 6분 | [Q](../mock_exam_e/q11_istio_peerauthentication_strict_basic/question.md) · [S](../mock_exam_e/q11_istio_peerauthentication_strict_basic/solution.md) ☐ |

합계 25점, 목표 25분.

## 꼭 잡을 것

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources: [secrets]
  providers:
  - aescbc: { keys: [{ name: key1, secret: <head -c 32 /dev/urandom | base64> }] }
  - identity: {}                     # 맨 앞 provider 로 쓰고, 나머지는 읽기용
```

```bash
kubectl get secrets -A -o json | kubectl replace -f -     # 기존 Secret 재암호화
kubectl exec p -- dmesg | head -3                         # gVisor 면 gVisor 부팅 메시지
kubectl exec p -- cat /proc/self/uid_map                  # 0 0 4294967295 가 아니면 user namespace
```

- `--encryption-provider-config` 도 새 파일이므로 volumeMounts·volumes 가 필요합니다(1일차와 같은 절차).
- `identity` 를 맨 앞에 두면 암호화되지 않습니다. 순서가 곧 의미입니다.
- Istio 사이드카는 **파드를 다시 만들어야** 붙습니다. 라벨만 붙이고 `rollout restart` 를 빠뜨리기 쉽습니다.

## 여유가 있으면

- 심화 [A10 Secret 암호화와 기존 데이터 재작성](../mock_exam_a/q10_etcd_encryption_at_rest_rewrite/question.md)
- 심화 [C11 Cilium WireGuard 암호화](../mock_exam_c/q11_cilium_wireguard_encryption/question.md)
