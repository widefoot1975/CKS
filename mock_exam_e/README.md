# mock_exam_e

| 항목 | 내용 |
|---|---|
| 출처 | 자체 출제 (CKS 커리큘럼 v1.34 비중 반영, 시험 환경 v1.35) |
| 성격 | 기본 — 한 문제에 한 가지 개념만 묻고 단계가 2~4개로 짧습니다 |
| 응시일 |  |
| 제한 시간 | 120분 (목표 시간 합계 106분, 여유 14분) |
| 실제 소요 |  |
| 점수 | / 100 (합격선 67) |

문제는 영문(`question.md`), 풀이는 한글(`solution.md`)입니다. `solution.md` 맨 앞에 한글 해석이 있으니, 풀이를 보기 전에 영문을 제대로 읽었는지 먼저 대조하세요.

각 문제는 `## Setup` 의 `setup.sh` 로 상황을 만든 뒤, 메타 표의 `Host` 로 `ssh` 해서 풉니다. 실제 시험에서는 지정 호스트가 아닌 곳에서 작업하면 0점이고, 문제를 마치면 `exit` 로 베이스 터미널에 돌아온 뒤 다음 문제의 호스트로 들어갑니다.

## 문항

`목표`는 배점에 비례해 배분한 **시간 예산**입니다 (일반 문항 배점×1분, Monitoring·Runtime Security 배점×1.33분). 걸린 시간과 점수는 각 `question.md` 맨 아래 `## Record` 에만 적고 `python3 scripts/update_progress.py` 를 실행하세요. 이 표의 `실제`·`결과` 와 아래 도메인별 실점이 채워집니다.

| # | 문제 | 도메인 | 배점 | 목표 | 실제 | 결과 | 링크 |
|---|---|---|---|---|---|---|---|
| 01 | Allow ingress only from one namespace | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q01_networkpolicy_allow_from_namespace/question.md) · [S](q01_networkpolicy_allow_from_namespace/solution.md) |
| 02 | Disable anonymous access to the kubelet API | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q02_kubelet_anonymous_auth_disable/question.md) · [S](q02_kubelet_anonymous_auth_disable/solution.md) |
| 03 | Add TLS to an Ingress with a self-signed certificate | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q03_ingress_tls_basic/question.md) · [S](q03_ingress_tls_basic/solution.md) |
| 04 | Read-only ClusterRole for a user, checked with can-i | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q04_clusterrole_readonly_user_can_i/question.md) · [S](q04_clusterrole_readonly_user_can_i/solution.md) |
| 05 | Short-lived ServiceAccount token with a custom audience | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q05_create_token_duration_audience/question.md) · [S](q05_create_token_duration_audience/solution.md) |
| 06 | Block Pod egress to the Kubernetes API | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q06_networkpolicy_block_apiserver_egress/question.md) · [S](q06_networkpolicy_block_apiserver_egress/solution.md) |
| 07 | Run a Deployment with the RuntimeDefault seccomp profile | System Hardening | 5 | 5분 |  | ☐ | [Q](q07_seccomp_runtimedefault_deployment/question.md) · [S](q07_seccomp_runtimedefault_deployment/solution.md) |
| 08 | Remove an unneeded package and user from a node | System Hardening | 5 | 5분 |  | ☐ | [Q](q08_remove_package_and_user_host/question.md) · [S](q08_remove_package_and_user_host/solution.md) |
| 09 | Drop capabilities from a privileged container | Microservice | 7 | 7분 |  | ☐ | [Q](q09_securitycontext_drop_caps_nonprivileged/question.md) · [S](q09_securitycontext_drop_caps_nonprivileged/solution.md) |
| 10 | Switch encryption at rest from identity to aescbc | Microservice | 7 | 7분 |  | ☐ | [Q](q10_encryption_config_identity_to_aescbc/question.md) · [S](q10_encryption_config_identity_to_aescbc/solution.md) |
| 11 | Enforce mTLS STRICT with Istio PeerAuthentication | Microservice | 6 | 6분 |  | ☐ | [Q](q11_istio_peerauthentication_strict_basic/question.md) · [S](q11_istio_peerauthentication_strict_basic/solution.md) |
| 12 | Generate an SPDX SBOM with bom | Supply Chain | 7 | 7분 |  | ☐ | [Q](q12_bom_generate_spdx_sbom/question.md) · [S](q12_bom_generate_spdx_sbom/solution.md) |
| 13 | Deny Pods from untrusted registries with ValidatingAdmissionPolicy | Supply Chain | 7 | 7분 |  | ☐ | [Q](q13_vap_deny_untrusted_registry/question.md) · [S](q13_vap_deny_untrusted_registry/solution.md) |
| 14 | Fix KubeLinter findings in a Deployment manifest | Supply Chain | 6 | 6분 |  | ☐ | [Q](q14_kubelinter_fix_findings/question.md) · [S](q14_kubelinter_fix_findings/solution.md) |
| 15 | Change the output of a Falco rule with an override | Runtime Security | 7 | 9분 |  | ☐ | [Q](q15_falco_rule_output_change/question.md) · [S](q15_falco_rule_output_change/solution.md) |
| 16 | Find who deleted a ConfigMap in the audit log | Runtime Security | 7 | 9분 |  | ☐ | [Q](q16_audit_log_who_deleted/question.md) · [S](q16_audit_log_who_deleted/solution.md) |
| 17 | Find the container running as root with crictl | Runtime Security | 6 | 8분 |  | ☐ | [Q](q17_crictl_find_root_container/question.md) · [S](q17_crictl_find_root_container/solution.md) |
|  | **합계** |  | **100** | **106분** |  |  |  |

## 도메인별 실점

| 도메인 | 비중 | 배점 합 | 목표 시간 | 획득 | 손실 |
|---|---|---|---|---|---|
| Cluster Setup | 15% | 15 | 15분 |  |  |
| Cluster Hardening | 15% | 15 | 15분 |  |  |
| System Hardening | 10% | 10 | 10분 |  |  |
| Minimize Microservice Vulnerabilities | 20% | 20 | 20분 |  |  |
| Supply Chain Security | 20% | 20 | 20분 |  |  |
| Monitoring, Logging and Runtime Security | 20% | 20 | 26분 |  |  |

## 회고

**잘한 것**

-

**놓친 것**

-

**시간을 많이 쓴 문항** (목표 대비 초과)

-

**다음 회차까지 할 것**

- [ ]
