# mock_exam_c

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

kube-apiserver 매니페스트를 고치는 문항(q13, q16, q17)은 setup 이 원본을 `/opt/course/<id>/backup/` 에 백업하고 cleanup 이 복구한 뒤 API 서버가 돌아올 때까지 기다립니다. 다음 문제로 넘어가기 전에 반드시 `cleanup.sh` 를 실행하세요.
공용 구성요소(ingress-nginx, Falco, Trivy)는 여러 문항이 같이 쓰므로 `cleanup.sh` 가 지우지 않습니다.

## 문항

`목표`는 배점에 비례해 배분한 **시간 예산**입니다 (일반 문항 배점×1분, Monitoring·Runtime Security 배점×1.33분). 걸린 시간과 점수는 각 `question.md` 맨 아래 `## Record` 에만 적고 `python3 scripts/update_progress.py` 를 실행하세요. 이 표의 `실제`·`결과` 와 아래 도메인별 실점이 채워집니다.

| # | 문제 | 도메인 | 배점 | 목표 | 실제 | 결과 | 링크 |
|---|---|---|---|---|---|---|---|
| 01 | Allow ingress only from the Ingress controller and restrict egress | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q01_networkpolicy_ingress_controller_only/question.md) · [S](q01_networkpolicy_ingress_controller_only/solution.md) |
| 02 | Harden the worker kubelet configuration | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q02_kubelet_config_hardening/question.md) · [S](q02_kubelet_config_hardening/solution.md) |
| 03 | Repair a broken TLS Ingress | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q03_ingress_tls_fix_secret_host/question.md) · [S](q03_ingress_tls_fix_secret_host/solution.md) |
| 04 | Upgrade the worker node with kubeadm | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q04_kubeadm_worker_upgrade_patch/question.md) · [S](q04_kubeadm_worker_upgrade_patch/solution.md) |
| 05 | Remove dangerous RBAC permissions in a tenant namespace | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q05_rbac_dangerous_verbs_escalate_bind/question.md) · [S](q05_rbac_dangerous_verbs_escalate_bind/solution.md) |
| 06 | Lock down an exposed admin UI | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q06_exposed_admin_ui_lockdown/question.md) · [S](q06_exposed_admin_ui_lockdown/solution.md) |
| 07 | AppArmor and seccomp in a multi-container Pod | System Hardening | 5 | 5분 |  | ☐ | [Q](q07_apparmor_seccomp_multicontainer/question.md) · [S](q07_apparmor_seccomp_multicontainer/solution.md) |
| 08 | Blacklist kernel modules and remove a telnet server | System Hardening | 5 | 5분 |  | ☐ | [Q](q08_host_kernel_modules_blacklist/question.md) · [S](q08_host_kernel_modules_blacklist/solution.md) |
| 09 | Enforce tenant Pod security with a ValidatingAdmissionPolicy | Microservice | 7 | 7분 |  | ☐ | [Q](q09_vap_tenant_pod_security/question.md) · [S](q09_vap_tenant_pod_security/solution.md) |
| 10 | Hunt down leaked secret values | Microservice | 7 | 7분 |  | ☐ | [Q](q10_secret_leak_hunt_env_annotations/question.md) · [S](q10_secret_leak_hunt_env_annotations/solution.md) |
| 11 | Enable Cilium WireGuard transparent encryption | Microservice | 6 | 6분 |  | ☐ | [Q](q11_cilium_wireguard_encryption/question.md) · [S](q11_cilium_wireguard_encryption/solution.md) |
| 12 | Build a distroless non-root Go image | Supply Chain | 7 | 7분 |  | ☐ | [Q](q12_dockerfile_distroless_nonroot_build/question.md) · [S](q12_dockerfile_distroless_nonroot_build/solution.md) |
| 13 | Configure the ImagePolicyWebhook admission plugin | Supply Chain | 7 | 7분 |  | ☐ | [Q](q13_imagepolicywebhook_admission_config/question.md) · [S](q13_imagepolicywebhook_admission_config/solution.md) |
| 14 | Fix misconfigurations reported by trivy config | Supply Chain | 6 | 6분 |  | ☐ | [Q](q14_trivy_config_misconfig_fix/question.md) · [S](q14_trivy_config_misconfig_fix/solution.md) |
| 15 | Falco list, macro and a namespace exception | Runtime Security | 7 | 9분 |  | ☐ | [Q](q15_falco_macro_list_append_exceptions/question.md) · [S](q15_falco_macro_list_append_exceptions/solution.md) |
| 16 | Audit impersonation and pods/exec | Runtime Security | 7 | 9분 |  | ☐ | [Q](q16_audit_impersonation_exec_levels/question.md) · [S](q16_audit_impersonation_exec_levels/solution.md) |
| 17 | Investigate a privileged hostPath Pod | Runtime Security | 6 | 8분 |  | ☐ | [Q](q17_incident_privileged_hostpath_pod/question.md) · [S](q17_incident_privileged_hostpath_pod/solution.md) |
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
