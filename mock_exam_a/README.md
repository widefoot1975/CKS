# mock_exam_a

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

공용 구성요소(ingress-nginx, Falco, gVisor, kube-bench·kubesec·Trivy 같은 도구)는 여러 문항이 같이 쓰므로 `cleanup.sh` 가 지우지 않습니다. kube-apiserver 매니페스트나 kubelet 설정을 바꾸는 문항(q02, q06, q10, q16)은 다음 문항으로 넘어가기 전에 반드시 `cleanup.sh` 로 원래대로 되돌리세요.

## 문항

`목표`는 배점에 비례해 배분한 **시간 예산**입니다 (일반 문항 배점×1분, Monitoring·Runtime Security 배점×1.33분). 걸린 시간과 점수는 각 `question.md` 맨 아래 `## Record` 에만 적고 `python3 scripts/update_progress.py` 를 실행하세요. 이 표의 `실제`·`결과` 와 아래 도메인별 실점이 채워집니다.

| # | 문제 | 도메인 | 배점 | 목표 | 실제 | 결과 | 링크 |
|---|---|---|---|---|---|---|---|
| 01 | Default-deny a namespace and open only DNS, API and external egress | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q01_networkpolicy_default_deny_dns_metadata/question.md) · [S](q01_networkpolicy_default_deny_dns_metadata/solution.md) |
| 02 | Fix kube-bench findings on the API server and the kubelet | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q02_cis_kube_bench_apiserver_kubelet/question.md) · [S](q02_cis_kube_bench_apiserver_kubelet/solution.md) |
| 03 | TLS Ingress with a SAN certificate and a forced HTTPS redirect | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q03_ingress_tls_ssl_redirect/question.md) · [S](q03_ingress_tls_ssl_redirect/solution.md) |
| 04 | Certificate user via a CSR with a least-privilege Role | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q04_csr_user_least_privilege_role/question.md) · [S](q04_csr_user_least_privilege_role/solution.md) |
| 05 | Lock down ServiceAccount tokens and use an audience-bound projected token | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q05_serviceaccount_automount_projected_token/question.md) · [S](q05_serviceaccount_automount_projected_token/solution.md) |
| 06 | Re-enable the NodeRestriction admission plugin and prove it | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q06_noderestriction_admission/question.md) · [S](q06_noderestriction_admission/solution.md) |
| 07 | Confine a Deployment with a Localhost AppArmor profile | System Hardening | 5 | 5분 |  | ☐ | [Q](q07_apparmor_profile_deployment/question.md) · [S](q07_apparmor_profile_deployment/solution.md) |
| 08 | Find and remove a disguised listening service on the worker | System Hardening | 5 | 5분 |  | ☐ | [Q](q08_host_listening_service_disable/question.md) · [S](q08_host_listening_service_disable/solution.md) |
| 09 | Enforce Pod Security baseline while warning on restricted | Microservice | 7 | 7분 |  | ☐ | [Q](q09_psa_baseline_enforce_restricted_warn/question.md) · [S](q09_psa_baseline_enforce_restricted_warn/solution.md) |
| 10 | Encrypt Secrets at rest and rewrite the existing data | Microservice | 7 | 7분 |  | ☐ | [Q](q10_etcd_encryption_at_rest_rewrite/question.md) · [S](q10_etcd_encryption_at_rest_rewrite/solution.md) |
| 11 | Run an untrusted workload in a gVisor RuntimeClass | Microservice | 6 | 6분 |  | ☐ | [Q](q11_runtimeclass_gvisor_sandbox/question.md) · [S](q11_runtimeclass_gvisor_sandbox/solution.md) |
| 12 | Harden a Dockerfile and raise a Deployment's kubesec score | Supply Chain | 7 | 7분 |  | ☐ | [Q](q12_dockerfile_minimize_kubesec/question.md) · [S](q12_dockerfile_minimize_kubesec/solution.md) |
| 13 | Scan workload images with Trivy and stop the CRITICAL ones | Supply Chain | 7 | 7분 |  | ☐ | [Q](q13_trivy_scan_delete_critical/question.md) · [S](q13_trivy_scan_delete_critical/solution.md) |
| 14 | ValidatingAdmissionPolicy for trusted registries and pinned tags | Supply Chain | 6 | 6분 |  | ☐ | [Q](q14_vap_permitted_registries_no_latest/question.md) · [S](q14_vap_permitted_registries_no_latest/solution.md) |
| 15 | Falco rule for shells spawned in payment containers | Runtime Security | 7 | 9분 |  | ☐ | [Q](q15_falco_custom_rule_shell_output/question.md) · [S](q15_falco_custom_rule_shell_output/solution.md) |
| 16 | Audit policy with ordered rules and log rotation | Runtime Security | 7 | 9분 |  | ☐ | [Q](q16_audit_policy_rules_apiserver/question.md) · [S](q16_audit_policy_rules_apiserver/solution.md) |
| 17 | Immutable Pods with read-only root filesystems | Runtime Security | 6 | 8분 |  | ☐ | [Q](q17_immutable_readonly_rootfs_emptydir/question.md) · [S](q17_immutable_readonly_rootfs_emptydir/solution.md) |
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
