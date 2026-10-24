# 4일차 (D-7) — System Hardening (AppArmor · seccomp · 호스트)

[← 3일차](day03.md) · [계획 전체](README.md) · [5일차 →](day05.md)

## 오늘의 목표

- AppArmor 프로필을 **워커에 로드**하고 `securityContext.appArmorProfile` 필드로 적용합니다(주석 방식은 deprecated).
- 호스트에서 열린 포트·불필요한 패키지·사용자를 찾아 없애는 명령을 익힙니다.

## 시간표

| 시간 | 할 일 |
|---|---|
| 0:00 – 0:15 | [cheatsheet.md](../cheatsheet.md) §4 System Hardening, 루트 README 의 AppArmor 행 |
| 0:15 – 0:40 | 아래 문제 5개 풀기 |
| 0:40 – 0:52 | `solution.md` 와 대조, 오답 원인 기록 |
| 0:52 – 1:00 | `## Record` 에 기록하고 `python3 scripts/update_progress.py` 실행 |

## 풀 문제

| 문제 | 도메인 | 주제 | 배점 | 목표 | 결과 |
|---|---|---|---|---|---|
| D07 | System Hardening | AppArmor 프로필 로드하고 파드에 적용 | 5 | 5분 | [Q](../mock_exam_d/q07_apparmor_load_apply_pod/question.md) · [S](../mock_exam_d/q07_apparmor_load_apply_pod/solution.md) ☐ |
| F07 | System Hardening | AppArmor complain 을 enforce 로 | 5 | 5분 | [Q](../mock_exam_f/q07_apparmor_complain_to_enforce/question.md) · [S](../mock_exam_f/q07_apparmor_complain_to_enforce/solution.md) ☐ |
| E07 | System Hardening | Deployment 에 RuntimeDefault seccomp | 5 | 5분 | [Q](../mock_exam_e/q07_seccomp_runtimedefault_deployment/question.md) · [S](../mock_exam_e/q07_seccomp_runtimedefault_deployment/solution.md) ☐ |
| D08 | System Hardening | 워커에서 열린 서비스 끄기 | 5 | 5분 | [Q](../mock_exam_d/q08_disable_listening_service_worker/question.md) · [S](../mock_exam_d/q08_disable_listening_service_worker/solution.md) ☐ |
| E08 | System Hardening | 노드에서 불필요한 패키지와 사용자 제거 | 5 | 5분 | [Q](../mock_exam_e/q08_remove_package_and_user_host/question.md) · [S](../mock_exam_e/q08_remove_package_and_user_host/solution.md) ☐ |

합계 25점, 목표 25분.

## 꼭 잡을 것

```bash
ssh cks-c1-w1 ; sudo -i
apparmor_parser -q /etc/apparmor.d/<profile> ; aa-status | grep <name> ; aa-enforce /etc/apparmor.d/<profile>
ss -tlpn | grep <port> ; systemctl disable --now <svc> ; systemctl mask <svc>
apt-get purge -y <pkg> ; userdel -r <user>
```

```yaml
securityContext:
  seccompProfile: { type: RuntimeDefault }
  appArmorProfile: { type: Localhost, localhostProfile: k8s-deny-write }   # 파일명이 아니라 프로필 이름
```

- 프로필은 **파드가 뜰 노드**에 로드되어 있어야 합니다. 없으면 파드가 `Blocked`/`CreateContainerError` 로 멈춥니다.
- `localhostProfile` 이름은 `aa-status` 에 보이는 프로필 이름(파일 안의 `profile <이름>`)입니다.
- seccomp `Localhost` 경로는 `/var/lib/kubelet/seccomp/` 기준 상대 경로입니다.

## 여유가 있으면

- 심화 [A07 Localhost AppArmor 로 Deployment 가두기](../mock_exam_a/q07_apparmor_profile_deployment/question.md)
- 심화 [B07 기록용 seccomp 프로필을 차단용으로](../mock_exam_b/q07_seccomp_localhost_profile_audit_to_errno/question.md)
