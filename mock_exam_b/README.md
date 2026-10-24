# mock_exam_b

| 항목 | 내용 |
|---|---|
| 출처 | 자체 출제 (CKS 커리큘럼 v1.34 비중 반영, 시험 환경 v1.35) |
| 성격 | 심화 — 한 문제에 여러 개념과 단계가 섞이고, 문제마다 함정이 하나 이상 숨어 있습니다 |
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
| 01 | L7 HTTP policy with CiliumNetworkPolicy | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q01_ciliumnetworkpolicy_l7_http/question.md) · [S](q01_ciliumnetworkpolicy_l7_http/solution.md) |
| 02 | Fix kube-bench findings for etcd and the worker kubelet | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q02_cis_etcd_kubelet_file_permissions/question.md) · [S](q02_cis_etcd_kubelet_file_permissions/solution.md) |
| 03 | Verify platform binaries and the kube-apiserver image | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q03_verify_platform_binaries_sha512/question.md) · [S](q03_verify_platform_binaries_sha512/solution.md) |
| 04 | Find and replace excessive RBAC bindings | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q04_rbac_find_excessive_bindings/question.md) · [S](q04_rbac_find_excessive_bindings/solution.md) |
| 05 | Clean up legacy ServiceAccount token Secrets | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q05_sa_legacy_token_cleanup/question.md) · [S](q05_sa_legacy_token_cleanup/solution.md) |
| 06 | Allow anonymous access only to health endpoints | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q06_anonymous_auth_health_endpoints_only/question.md) · [S](q06_anonymous_auth_health_endpoints_only/solution.md) |
| 07 | Turn a logging seccomp profile into a blocking one | System Hardening | 5 | 5분 |  | ☐ | [Q](q07_seccomp_localhost_profile_audit_to_errno/question.md) · [S](q07_seccomp_localhost_profile_audit_to_errno/solution.md) |
| 08 | Harden host users, groups, sshd and setuid files | System Hardening | 5 | 5분 |  | ☐ | [Q](q08_host_users_groups_sshd/question.md) · [S](q08_host_users_groups_sshd/solution.md) |
| 09 | Enforce Istio mTLS with PeerAuthentication STRICT | Microservice | 7 | 7분 |  | ☐ | [Q](q09_istio_peerauthentication_strict/question.md) · [S](q09_istio_peerauthentication_strict/solution.md) |
| 10 | Mount a Secret as a file and restrict access by resourceNames | Microservice | 7 | 7분 |  | ☐ | [Q](q10_secret_file_mount_resource_names/question.md) · [S](q10_secret_file_mount_resource_names/solution.md) |
| 11 | Run a Deployment in a user namespace | Microservice | 6 | 6분 |  | ☐ | [Q](q11_user_namespaces_hostusers_false/question.md) · [S](q11_user_namespaces_hostusers_false/solution.md) |
| 12 | Generate SBOMs and scan them for vulnerabilities | Supply Chain | 7 | 7분 |  | ☐ | [Q](q12_sbom_bom_trivy_sbom/question.md) · [S](q12_sbom_bom_trivy_sbom/solution.md) |
| 13 | Fix manifests with kube-linter and kubesec | Supply Chain | 7 | 7분 |  | ☐ | [Q](q13_kubelinter_kubesec_fix_manifests/question.md) · [S](q13_kubelinter_kubesec_fix_manifests/solution.md) |
| 14 | ValidatingAdmissionPolicy with ConfigMap parameters | Supply Chain | 6 | 6분 |  | ☐ | [Q](q14_vap_params_configmap_registries/question.md) · [S](q14_vap_params_configmap_registries/solution.md) |
| 15 | Investigate existing Falco alerts | Runtime Security | 7 | 9분 |  | ☐ | [Q](q15_falco_investigate_existing_alerts/question.md) · [S](q15_falco_investigate_existing_alerts/solution.md) |
| 16 | Investigate the audit log and reduce its noise | Runtime Security | 7 | 9분 |  | ☐ | [Q](q16_audit_log_investigation/question.md) · [S](q16_audit_log_investigation/solution.md) |
| 17 | Trace a malicious process from the node to its Pod | Runtime Security | 6 | 8분 |  | ☐ | [Q](q17_crictl_find_malicious_process/question.md) · [S](q17_crictl_find_malicious_process/solution.md) |
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
