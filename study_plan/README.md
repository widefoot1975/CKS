# 시험 전 10일 학습 계획 (하루 1시간)

시험 10일 전부터 **하루 1시간씩** 이 저장소만으로 준비하는 계획입니다. 1일차가 D-10, 10일차가 시험 전날(D-1)입니다. 형식은 [CKA 저장소의 학습 계획](https://github.com/widefoot1975/CKA/tree/main/study_plan)과 같습니다.

> 예: 9월 26일에 시작하면 10월 5일이 10일차, 10월 6일이 시험일입니다.

## 계획을 세운 기준

- **여섯 세트를 전부 풀 수는 없습니다.** 102문항의 목표 시간만 더해도 636분이라 10시간을 넘습니다. 그래서 **기본 난이도(D·E·F)** 를 중심으로 약 40문항을 풀고, 심화(A·B·C)는 매일 `여유가 있으면` 항목으로만 둡니다.
- **1일차에 kube-apiserver 정적 파드를 고치는 손버릇부터 잡습니다.** CKS 는 감사 로그, etcd 암호화, admission 플러그인처럼 apiserver 를 고치는 문항이 여러 도메인에 흩어져 있고, 한 번 망가뜨리면 그 클러스터의 다른 문항까지 잃습니다.
- 그다음은 **커리큘럼 순서**(Cluster Setup → Cluster Hardening → System Hardening → Microservice → Supply Chain → Runtime Security)로 갑니다. 비중 20% 도메인 세 개에는 하루 이상씩 씁니다.
- **하루 1시간은 모두 같은 틀로 씁니다.** 읽기 15분, 문제 풀이 25~35분, 풀이 대조와 기록 10~15분입니다.
- **문제는 `question.md` 만 보고 손으로 풉니다.** 다 푼 뒤에 `solution.md` 를 열고, 한글 해석으로 영문을 제대로 읽었는지부터 확인합니다.
- `읽을 곳` 은 루트 [README.md](../README.md) 와 [cheatsheet.md](../cheatsheet.md) 의 절입니다.

## 일정표

| 일차 | D- | 주제 | 읽을 곳 | 풀 문제 | 배점 |
|---|---|---|---|---|---|
| [1일차](day01.md) | D-10 | 시험 형식, kube-apiserver 다루기 | README 출제 형태·실습 환경 · cheatsheet §0 ~ §1 | D02 · E02 · D06 · D16 | 22 |
| [2일차](day02.md) | D-9 | Cluster Setup (NetworkPolicy · Ingress TLS · 바이너리 검증) | cheatsheet §2 | D01 · E01 · F01 · E03 · D03 | 25 |
| [3일차](day03.md) | D-8 | Cluster Hardening (RBAC · ServiceAccount · CSR) | cheatsheet §3 | D04 · E04 · D05 · E05 · F06 | 25 |
| [4일차](day04.md) | D-7 | System Hardening (AppArmor · seccomp · 호스트) | cheatsheet §4 | D07 · F07 · E07 · D08 · E08 | 25 |
| [5일차](day05.md) | D-6 | Pod Security · securityContext · Secret | cheatsheet §5 앞부분 | D09 · E09 · D10 · F10 | 28 |
| [6일차](day06.md) | D-5 | 격리와 암호화 (etcd 암호화 · gVisor · user namespace · mTLS) | cheatsheet §5 뒷부분 | E10 · D11 · F11 · E11 | 25 |
| [7일차](day07.md) | D-4 | Supply Chain (이미지 최소화 · Trivy · 정적 분석 · 허용 레지스트리) | cheatsheet §6 | D12 · D13 · D14 · E13 | 27 |
| [8일차](day08.md) | D-3 | Runtime Security (Falco · 감사 로그 · crictl) | cheatsheet §7 | D15 · E15 · E16 · E17 | 27 |
| [9일차](day09.md) | D-2 | 시간 재고 푸는 미니 모의고사 | — | F15 · F17 · F09 · F13 · F14 · F03 · F05 | 43 |
| [10일차](day10.md) | D-1 | 오답 복습, 당일 준비 | README 2026 변화·열람 문서 · cheatsheet 전체 | 새 문제 없음 | — |

`D02` 는 `mock_exam_d` 의 q02 라는 뜻입니다.

## 시작 전에 확인할 것

- **VM 두 대짜리 kubeadm 클러스터가 있어야 합니다.** 컨트롤 플레인(`cks-c1`)과 워커(`cks-c1-w1`), CNI 는 Cilium, 워커는 AppArmor 가 켜진 Ubuntu 를 기준으로 합니다(루트 README `실습 환경 준비`). kind·minikube 로는 AppArmor·Falco·kube-apiserver 문항이 재현되지 않습니다.
- **스냅샷을 떠 두세요.** kube-apiserver 를 고치는 문항은 cleanup 이 원본을 되돌리지만, 연습 중에 apiserver 가 안 뜨면 VM 스냅샷으로 돌아가는 것이 가장 빠릅니다.
- **killer.sh 시뮬레이터**: CKS 를 등록하면 시뮬레이터 세션 2회가 함께 제공됩니다(세션마다 36시간 이용). CKS 시뮬레이터는 실제 시험보다 어렵기로 유명하니, 9일차 전후의 주말에 한 번 써 보고 점수에 너무 흔들리지 마세요.

## 매일 끝낼 때 기록할 것

1. 푼 문제의 `question.md` → `## My attempt` 에 입력한 명령 (틀린 것도 그대로)
2. 같은 `question.md` 맨 아래 `## Record` 에 날짜·걸린 분·점수 한 줄, 그리고 `python3 scripts/update_progress.py` 실행
3. 틀린 문제는 `solution.md` 의 `## 오답 원인 / 배운 점`
4. 같은 주제를 두 번 틀리면 저장소 루트 [README.md](../README.md) 의 **반복 오답 목록**에 추가 — 10일차에 이 표를 다시 봅니다.
5. kube-apiserver·kubelet 을 고친 문항은 **`sudo bash cleanup.sh` 까지** 하고 끝냅니다. 다음 날 다른 문항의 setup 이 바뀐 설정 위에서 돌지 않게 합니다.
