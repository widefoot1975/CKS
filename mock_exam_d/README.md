# mock_exam_d

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

실습 클러스터는 kubeadm 2노드(컨트롤 플레인 `cks-c1`, 워커 `cks-c1-w1`, CNI Cilium, containerd)입니다. 스크립트는 모두 `cks-c1` 에서 root 로(`sudo bash setup.sh`) 실행하고, 워커 노드 작업이 필요하면 스크립트가 알아서 워커에 반영합니다. kube-bench·Trivy·kubesec·Falco·gVisor 처럼 여러 문제가 같이 쓰는 도구는 setup 이 없을 때만 고정 버전으로 설치하고(인터넷 필요), cleanup 은 지우지 않습니다.

## 문항

`목표`는 배점에 비례해 배분한 **시간 예산**입니다 (일반 문항 배점×1분, Monitoring·Runtime Security 배점×1.33분). 걸린 시간과 점수는 각 `question.md` 맨 아래 `## Record` 에만 적고 `python3 scripts/update_progress.py` 를 실행하세요. 이 표의 `실제`·`결과` 와 아래 도메인별 실점이 채워집니다.

| # | 문제 | 도메인 | 배점 | 목표 | 실제 | 결과 | 링크 |
|---|---|---|---|---|---|---|---|
| 01 | Default-deny ingress with one allowed client | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q01_networkpolicy_default_deny_ingress/question.md) · [S](q01_networkpolicy_default_deny_ingress/solution.md) |
| 02 | Fix the kube-bench profiling finding on the API server | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q02_kube_bench_apiserver_profiling/question.md) · [S](q02_kube_bench_apiserver_profiling/solution.md) |
| 03 | Verify a kubectl binary against its official SHA-512 | Cluster Setup | 5 | 5분 |  | ☐ | [Q](q03_verify_kubectl_sha512/question.md) · [S](q03_verify_kubectl_sha512/solution.md) |
| 04 | Least-privilege Role for a ServiceAccount | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q04_role_rolebinding_sa_least_privilege/question.md) · [S](q04_role_rolebinding_sa_least_privilege/solution.md) |
| 05 | Stop mounting the ServiceAccount token | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q05_sa_automount_false/question.md) · [S](q05_sa_automount_false/solution.md) |
| 06 | Remove an anonymous RBAC binding | Cluster Hardening | 5 | 5분 |  | ☐ | [Q](q06_anonymous_rbac_binding_remove/question.md) · [S](q06_anonymous_rbac_binding_remove/solution.md) |
| 07 | Load an AppArmor profile and apply it to a Pod | System Hardening | 5 | 5분 |  | ☐ | [Q](q07_apparmor_load_apply_pod/question.md) · [S](q07_apparmor_load_apply_pod/solution.md) |
| 08 | Disable a listening service on the worker node | System Hardening | 5 | 5분 |  | ☐ | [Q](q08_disable_listening_service_worker/question.md) · [S](q08_disable_listening_service_worker/solution.md) |
| 09 | Enforce Pod Security restricted and fix a Pod | Microservice | 7 | 7분 |  | ☐ | [Q](q09_psa_restricted_label_fix_pod/question.md) · [S](q09_psa_restricted_label_fix_pod/solution.md) |
| 10 | Mount a Secret as a read-only volume | Microservice | 7 | 7분 |  | ☐ | [Q](q10_secret_volume_readonly/question.md) · [S](q10_secret_volume_readonly/solution.md) |
| 11 | Run a Pod in gVisor with a RuntimeClass | Microservice | 6 | 6분 |  | ☐ | [Q](q11_runtimeclass_gvisor_pod/question.md) · [S](q11_runtimeclass_gvisor_pod/solution.md) |
| 12 | Pin the base image and run as non-root in a Dockerfile | Supply Chain | 7 | 7분 |  | ☐ | [Q](q12_dockerfile_nonroot_pinned_tag/question.md) · [S](q12_dockerfile_nonroot_pinned_tag/solution.md) |
| 13 | Count CRITICAL vulnerabilities with Trivy | Supply Chain | 7 | 7분 |  | ☐ | [Q](q13_trivy_image_critical_count/question.md) · [S](q13_trivy_image_critical_count/solution.md) |
| 14 | Raise a Pod's kubesec score | Supply Chain | 6 | 6분 |  | ☐ | [Q](q14_kubesec_score_fix_pod/question.md) · [S](q14_kubesec_score_fix_pod/solution.md) |
| 15 | Stop a Pod that Falco reports spawning shells | Runtime Security | 7 | 9분 |  | ☐ | [Q](q15_falco_shell_alert_delete_pod/question.md) · [S](q15_falco_shell_alert_delete_pod/solution.md) |
| 16 | Enable API server auditing with a given policy | Runtime Security | 7 | 9분 |  | ☐ | [Q](q16_audit_enable_given_policy/question.md) · [S](q16_audit_enable_given_policy/solution.md) |
| 17 | Read-only root filesystem for an nginx Deployment | Runtime Security | 6 | 8분 |  | ☐ | [Q](q17_readonly_rootfs_pod/question.md) · [S](q17_readonly_rootfs_pod/solution.md) |
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
