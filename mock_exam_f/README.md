# mock_exam_f

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

이 회차의 모든 문제는 `cks-c1`(컨트롤 플레인, 워커 `cks-c1-w1`) 에서 `sudo bash setup.sh` 로 준비합니다. ingress-nginx, Falco, Trivy, kubesec, kube-bench, etcdctl 같은 공용 구성요소는 setup 이 없을 때만 설치하고 `cleanup.sh` 는 지우지 않습니다.

## 문항

`목표`는 배점에 비례해 배분한 **시간 예산**입니다 (일반 문항 배점×1분, Monitoring·Runtime Security 배점×1.33분). 걸린 시간과 점수는 각 `question.md` 맨 아래 `## Record` 에만 적고 `python3 scripts/update_progress.py` 를 실행하세요. 이 표의 `실제`·`결과` 와 아래 도메인별 실점이 채워집니다.

| # | 문제 | 도메인 | 배점 | 목표 | 실제 | 결과 | 링크 |
|---|---|---|---|---|---|---|---|
| 01 | Block Pod egress to the cloud metadata endpoint | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q01_networkpolicy_block_metadata_egress/question.md) · [S](q01_networkpolicy_block_metadata_egress/solution.md) |
| 02 | Fix CIS file permission findings with kube-bench | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q02_cis_static_pod_manifest_permissions/question.md) · [S](q02_cis_static_pod_manifest_permissions/solution.md) |
| 03 | Fix an Ingress that serves the wrong TLS certificate | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q03_ingress_tls_wrong_secret_name/question.md) · [S](q03_ingress_tls_wrong_secret_name/solution.md) |
| 04 | Remove a wildcard rule from a Role | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q04_remove_wildcard_rbac_rule/question.md) · [S](q04_remove_wildcard_rbac_rule/solution.md) |
| 05 | Disable token automount on the default ServiceAccount | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q05_sa_default_automount_off_dedicated_sa/question.md) · [S](q05_sa_default_automount_off_dedicated_sa/solution.md) |
| 06 | Sign a user certificate with a CSR and build a kubeconfig | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q06_csr_approve_user_kubeconfig/question.md) · [S](q06_csr_approve_user_kubeconfig/solution.md) |
| 07 | Switch an AppArmor profile from complain to enforce | System Hardening | 5 | 5분 |  | ☐ | [Q](q07_apparmor_complain_to_enforce/question.md) · [S](q07_apparmor_complain_to_enforce/solution.md) |
| 08 | Remove a setuid bit and a login shell on a node | System Hardening | 5 | 5분 |  | ☐ | [Q](q08_host_setuid_nologin_shell/question.md) · [S](q08_host_setuid_nologin_shell/solution.md) |
| 09 | Find Pod Security baseline violators with a dry run | Microservice | 7 | 7분 |  | ☐ | [Q](q09_psa_dry_run_find_violators/question.md) · [S](q09_psa_dry_run_find_violators/solution.md) |
| 10 | Read a Secret directly from etcd | Microservice | 7 | 7분 |  | ☐ | [Q](q10_etcdctl_read_secret_plaintext/question.md) · [S](q10_etcdctl_read_secret_plaintext/solution.md) |
| 11 | Run a Deployment in a user namespace | Microservice | 6 | 6분 |  | ☐ | [Q](q11_user_namespaces_hostusers_false/question.md) · [S](q11_user_namespaces_hostusers_false/solution.md) |
| 12 | Pin container images by digest | Supply Chain | 7 | 7분 |  | ☐ | [Q](q12_image_digest_pinning/question.md) · [S](q12_image_digest_pinning/solution.md) |
| 13 | Fix Trivy misconfiguration findings in a manifest | Supply Chain | 7 | 7분 |  | ☐ | [Q](q13_trivy_config_manifest_scan/question.md) · [S](q13_trivy_config_manifest_scan/solution.md) |
| 14 | Raise the kubesec score of a Deployment | Supply Chain | 6 | 6분 |  | ☐ | [Q](q14_kubesec_deployment_score/question.md) · [S](q14_kubesec_deployment_score/solution.md) |
| 15 | Falco rule for writes below /etc | Runtime Security | 7 | 9분 |  | ☐ | [Q](q15_falco_detect_write_below_etc/question.md) · [S](q15_falco_detect_write_below_etc/solution.md) |
| 16 | Audit Secret access at Metadata level | Runtime Security | 7 | 9분 |  | ☐ | [Q](q16_audit_policy_secrets_metadata/question.md) · [S](q16_audit_policy_secrets_metadata/solution.md) |
| 17 | Delete privileged and writable Pods | Runtime Security | 6 | 8분 |  | ☐ | [Q](q17_delete_privileged_writable_pods/question.md) · [S](q17_delete_privileged_writable_pods/solution.md) |
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
