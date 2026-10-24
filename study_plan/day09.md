# 9일차 (D-2) — 시간 재고 푸는 미니 모의고사

[← 8일차](day08.md) · [계획 전체](README.md) · [10일차 →](day10.md)

## 오늘의 목표

실제 시험의 **절반에 조금 못 미치는 분량**(43점, 47분)을 타이머를 켜고 한 번에 풉니다. 아직 풀지 않은 `mock_exam_f` 문제로 골랐고, 여섯 도메인이 모두 들어 있습니다. 오늘 보는 것은 실력보다 **시간 배분과 문제를 넘기는 판단**입니다.

## 규칙

- 타이머 **47분**. 중간에 `solution.md`, 이 저장소의 다른 파일, 검색은 보지 않습니다. 시험처럼 kubernetes.io 와 CKS 허용 문서(falco.org 등)만 봅니다. Trivy·kubesec 은 `--help` 로 찾습니다.
- 문제마다 지정된 호스트로 `ssh` → 풀기 → 확인 → `exit`. 워커 작업은 `ssh cks-c1-w1` 로 한 번 더 들어갑니다.
- **3분 안에 실마리가 안 보이면 표시하고 다음 문제**로 넘어갑니다. 끝까지 돌고 나서 표시한 문제로 돌아옵니다.
- 순서는 자유입니다. 시험에서처럼 배점이 크고 자신 있는 문제부터 풉니다.

## 환경 준비 (타이머 켜기 전)

7문제의 환경을 한 클러스터에 **한꺼번에** 만들어 두고 시작합니다. 각 문제 페이지의 Setup 섹션과 같은 스크립트입니다. 저장소를 `cks-c1` 의 `~/CKS` 에 받아 두었다고 가정합니다(다른 곳이면 첫 줄만 바꿉니다).

```bash
cd ~/CKS
sudo bash mock_exam_f/q15_falco_detect_write_below_etc/setup.sh   # 1. 워커에 Falco 가 없으면 설치가 가장 오래 걸리므로 먼저
sudo bash mock_exam_f/q03_ingress_tls_wrong_secret_name/setup.sh   # 2. ingress-nginx 가 없으면 설치
sudo bash mock_exam_f/q05_sa_default_automount_off_dedicated_sa/setup.sh
sudo bash mock_exam_f/q09_psa_dry_run_find_violators/setup.sh
sudo bash mock_exam_f/q13_trivy_config_manifest_scan/setup.sh
sudo bash mock_exam_f/q14_kubesec_deployment_score/setup.sh
sudo bash mock_exam_f/q17_delete_privileged_writable_pods/setup.sh
clear                            # 설정 출력에 답의 실마리가 보이므로 지운다
```

일곱 문제는 서로 다른 네임스페이스(`f15`, `shop`, `hr`, `legacy`, `f13`, `f14`, `f17`)와 결과 디렉터리(`/opt/course/<문제>`)를 쓰고, **kube-apiserver 를 고치는 문제가 없어서** 순서를 바꿔도 서로 영향을 주지 않습니다. F15 와 F03 을 먼저 두는 것은 Falco 와 Ingress 컨트롤러가 준비될 시간을 벌기 위해서입니다.

채점까지 끝나면 정리합니다.

```bash
cd ~/CKS
for q in mock_exam_f/q15_falco_detect_write_below_etc mock_exam_f/q03_ingress_tls_wrong_secret_name mock_exam_f/q05_sa_default_automount_off_dedicated_sa mock_exam_f/q09_psa_dry_run_find_violators \
         mock_exam_f/q13_trivy_config_manifest_scan mock_exam_f/q14_kubesec_deployment_score mock_exam_f/q17_delete_privileged_writable_pods; do
  sudo bash $q/cleanup.sh
done
```

## 시간표

| 시간 | 할 일 |
|---|---|
| 0:00 – 0:47 | 아래 7문제 풀기 (타이머) |
| 0:47 – 1:00 | 채점: 각 `solution.md` 의 검증 단계로 맞았는지 확인하고 점수를 적습니다 |

풀이를 꼼꼼히 비교하는 것은 내일 오답 복습 시간에 합니다.

## 문제

| 문제 | 도메인 | 주제 | 배점 | 목표 | 결과 |
|---|---|---|---|---|---|
| F15 | Runtime Security | /etc 아래 쓰기를 잡는 Falco 규칙 | 7 | 9분 | [Q](../mock_exam_f/q15_falco_detect_write_below_etc/question.md) · [S](../mock_exam_f/q15_falco_detect_write_below_etc/solution.md) ☐ |
| F17 | Runtime Security | privileged·쓰기 가능한 파드 지우기 | 6 | 8분 | [Q](../mock_exam_f/q17_delete_privileged_writable_pods/question.md) · [S](../mock_exam_f/q17_delete_privileged_writable_pods/solution.md) ☐ |
| F09 | Microservice | dry-run 으로 baseline 위반 파드 찾기 | 7 | 7분 | [Q](../mock_exam_f/q09_psa_dry_run_find_violators/question.md) · [S](../mock_exam_f/q09_psa_dry_run_find_violators/solution.md) ☐ |
| F13 | Supply Chain | trivy config 오설정 고치기 | 7 | 7분 | [Q](../mock_exam_f/q13_trivy_config_manifest_scan/question.md) · [S](../mock_exam_f/q13_trivy_config_manifest_scan/solution.md) ☐ |
| F14 | Supply Chain | Deployment 의 kubesec 점수 올리기 | 6 | 6분 | [Q](../mock_exam_f/q14_kubesec_deployment_score/question.md) · [S](../mock_exam_f/q14_kubesec_deployment_score/solution.md) ☐ |
| F03 | Cluster Setup | 엉뚱한 인증서를 내는 Ingress 고치기 | 5 | 5분 | [Q](../mock_exam_f/q03_ingress_tls_wrong_secret_name/question.md) · [S](../mock_exam_f/q03_ingress_tls_wrong_secret_name/solution.md) ☐ |
| F05 | Cluster Hardening | default SA 토큰 자동 마운트 끄기 | 5 | 5분 | [Q](../mock_exam_f/q05_sa_default_automount_off_dedicated_sa/question.md) · [S](../mock_exam_f/q05_sa_default_automount_off_dedicated_sa/solution.md) ☐ |

합계 **43점**, 목표 **47분**.

## 결과 기록

| 항목 | 값 |
|---|---|
| 걸린 시간 | 분 |
| 점수 | / 43 |
| 환산 (÷ 0.43) | / 100 — 67 이상이면 합격선 |
| 표시하고 넘긴 문제 | |
| 목표 시간을 가장 많이 넘긴 문제 | |

**목표 시간을 가장 많이 넘긴 문제가 내일 복습할 주제입니다.** 시험장에서도 같은 유형은 뒤로 미룹니다.
