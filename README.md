# CKS 모의시험 오답 노트

[CKS (Certified Kubernetes Security Specialist)](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) 준비 과정에서 푼 모의시험을 **회차별 → 문제별**로 정리하는 저장소입니다. 형식은 [CKA 저장소](https://github.com/widefoot1975/CKA), [CKAD 저장소](https://github.com/widefoot1975/CKAD)와 같습니다.

- 시험 형식: 실습형(performance-based), **120분**, 합격선 **67%**
- 응시 조건: **CKA 합격자만** 응시할 수 있습니다
- 시험 환경: **Kubernetes v1.35** (LF 시험 페이지 기준. 새 마이너 릴리스 후 4~8주 안에 따라 올라갑니다)
- 커리큘럼: [CNCF 공식 curriculum](https://github.com/cncf/curriculum) — **`CKS_Curriculum v1.34.pdf`** 기준 (2026-10 현재 최신 CKS 문서)

> 공개 저장소입니다. 실제 시험 문제 원문은 옮기지 않고, 요구사항을 직접 정리한 표현으로만 기록합니다.

시험장에서 쓸 명령은 [cheatsheet.md](cheatsheet.md) 에, 시험 전 10일 동안 하루 1시간씩 푸는 계획은 [study_plan/](study_plan/README.md) 에 모았습니다.

## 출제 범위와 트렌드

공식 커리큘럼의 도메인과 비중입니다. CKA·CKAD와 달리 **한 도메인이 30%를 넘지 않고 고르게 퍼져 있어서**, 약한 도메인 하나가 그대로 불합격으로 이어집니다.

| 도메인 | 비중 | 세부 항목 |
|---|---|---|
| **Cluster Setup** | 15% | NetworkPolicy 로 클러스터 접근 제한 / **CIS benchmark**(kube-bench)로 etcd·kubelet·kube-apiserver 점검 / Ingress **TLS** / 노드 메타데이터·엔드포인트 보호 / 플랫폼 **바이너리 검증** |
| **Cluster Hardening** | 15% | **RBAC** 최소화 / ServiceAccount 주의(기본 SA 끄기, 새 SA 권한 최소화) / Kubernetes **API 접근 제한** / 취약점 대응을 위한 **업그레이드** |
| **System Hardening** | 10% | 호스트 OS 공격면 줄이기 / 최소 권한 IAM / 외부 네트워크 접근 최소화 / **AppArmor·seccomp** |
| **Minimize Microservice Vulnerabilities** | **20%** | **Pod Security Standards** / **Secret 관리**(etcd 암호화) / 격리(멀티 테넌시, **샌드박스 컨테이너** gVisor) / **Pod 간 암호화**(Cilium, Istio) |
| **Supply Chain Security** | **20%** | 베이스 이미지 최소화 / 공급망 이해(**SBOM**, CI/CD, 저장소) / 공급망 보호(허용 레지스트리, 서명·검증) / 정적 분석(**Kubesec, KubeLinter**, Trivy) |
| **Monitoring, Logging and Runtime Security** | **20%** | 행위 분석(**Falco**) / 위협 탐지 / 공격 단계와 행위자 식별 / 런타임 **불변성** / **감사 로그(audit)** |

### 2026년 기준으로 알아 둘 변화

커리큘럼 문서는 v1.34 그대로지만 쿠버네티스와 도구가 바뀌었습니다. 2023~2024년 자료의 풀이를 그대로 따라 하면 여기서 막힙니다.

| 변화 | 시점 | 이 저장소에서 연습하는 곳 |
|---|---|---|
| **AppArmor 는 `securityContext.appArmorProfile` 필드**로 — `container.apparmor.security.beta.kubernetes.io/` 주석은 deprecated | v1.30 GA | AppArmor 문항 (A07, C07, D07, F07) |
| **ValidatingAdmissionPolicy GA** — 웹훅 서버 없이 CEL 로 허용 레지스트리·보안 규칙 강제 | v1.30 | A14, B14, C09, E13 |
| **MutatingAdmissionPolicy GA**, **user namespaces GA** — 단, 시험 환경 v1.35 에서는 user namespaces 가 beta(기본 켜짐) | v1.36 (2026-04) | B11, F11 |
| **Structured AuthenticationConfiguration** — anonymous 를 `/livez`·`/readyz`·`/healthz` 에만 허용 | v1.34 GA (anonymous 조건은 v1.32 beta) | B06 |
| KMS v2 GA, KMS v1 deprecated — 실습은 `aescbc`/`secretbox` 로 하고 원리는 같다 | v1.29 | A10, E10 |
| PodSecurityPolicy 제거 → **Pod Security Admission 라벨** | v1.25 | A09, D09, F09 |
| SA 토큰 Secret 자동 생성 없음 — `kubectl create token`, projected token, 레거시 토큰 정리 | v1.24~ | A05, B05, E05 |
| **Endpoints API deprecated** — 검증은 EndpointSlice 로 | v1.33 | Service·Ingress 문항 |
| **Ingress NGINX 은퇴**(이후 보안 패치 없음). 그래도 CKS 열람 문서에는 ingress-nginx 문서가 남아 있어 시험의 Ingress TLS 는 여전히 이 컨트롤러 기준 | 2026-03 | A03, C03, E03, F03 |
| **Trivy v0.69.4 악성 릴리스**(CVE-2026-33634) — 보안 도구 자체가 공급망 공격 대상. 이 저장소의 setup 은 Trivy 를 **v0.69.3 으로 고정** | 2026-03 | Trivy 문항 전부 |
| Falco 기본 드라이버 `modern_ebpf` (서비스 `falco-modern-bpf`), 사용자 규칙은 `falco_rules.local.yaml`·`rules.d` | Falco 0.38~ | A15, B15, C15, D15, E15, F15 |
| Kubernetes Dashboard 프로젝트 보관(archived) — "노출된 대시보드" 대신 일반 관리 UI 로 출제 | 2026 | C06 |

### 열람 가능한 문서

LF [허용 리소스](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed) 기준 CKS 는 다음만 열 수 있습니다.

- kubernetes.io/docs, kubernetes.io/blog
- falco.org/docs, kubernetes-sigs.github.io/bom, etcd.io/docs
- kubernetes.github.io/ingress-nginx, docs.cilium.io, istio.io/latest/docs
- 문제의 Quick Reference 상자에 링크된 문서, 시험 VM 의 `/usr/share` 문서

**Trivy, kubesec, KubeLinter, AppArmor, gVisor 문서는 목록에 없습니다.** 이 도구들은 `--help` 와 `man` 으로 옵션을 찾는 연습을 해 두세요. 각 문항의 `참고 문서` 도 이 목록 안에서만 적었습니다.

### 출제 형태

- 전 문항이 실습형입니다. 보통 15~20문항이 나옵니다.
- 문제마다 지정된 호스트로 `ssh` 해서 풉니다. 노드 파일이나 `systemctl` 작업은 그 클러스터의 노드로 다시 `ssh` 하고 `sudo -i` 합니다. 지정 호스트가 아닌 곳에서 작업하면 정답을 만들어도 0점이고, 다음 문제로 가기 전에 `exit` 로 베이스 터미널에 돌아옵니다.
- CKS 는 **kube-apiserver 정적 파드 매니페스트를 고치는 문항**이 여러 개 나옵니다. 한 번 잘못 고치면 그 클러스터의 다른 문항까지 못 풀게 되므로 **고치기 전에 백업**하고, 돌아오지 않으면 `crictl ps -a`, `/var/log/pods/kube-system_kube-apiserver-*` 로 원인을 봅니다.

이 저장소의 `question.md` 메타 표 `Host` 행은 이 형식을 따릅니다. 모든 문항이 `ssh cks-c1` 을 쓰며, `cks-c1` 은 **컨트롤 플레인 노드**, 워커는 `cks-c1-w1` 입니다. 연습 랩에서는 자기 클러스터의 컨트롤 플레인과 워커로 읽으면 됩니다.

### 실습 환경 준비

CKS 문항은 노드와 컨트롤 플레인을 직접 고치므로 **kind·minikube 로는 대부분 재현되지 않습니다.** 아래를 갖춘 VM 두 대짜리 kubeadm 클러스터를 권합니다.

- kubeadm v1.35 이상, 컨트롤 플레인 1대(`cks-c1`) + 워커 1대(`cks-c1-w1`), containerd + `crictl`
- CNI 는 **Cilium**(helm 설치) — NetworkPolicy·CiliumNetworkPolicy·WireGuard 암호화 문항에 필요
- 워커에 AppArmor 가 켜진 Ubuntu 22.04/24.04
- `setup.sh` 는 **컨트롤 플레인에서 root 로**(`sudo bash setup.sh`) 실행합니다. 워커 쪽 준비(AppArmor 프로필, 더미 서비스, Falco 설치 등)는 스크립트가 privileged 파드 + `nsenter` 로 대신합니다
- 필요한 도구는 setup 이 없을 때만 버전을 고정해 설치합니다: Trivy v0.69.3, kubesec, kube-linter, bom, kube-bench, Falco(워커, apt), gVisor `runsc`(워커), istioctl, ingress-nginx(NodePort)
- 인터넷 연결(이미지, 도구, 공식 체크섬 다운로드)

**kube-apiserver·kubelet 설정을 바꾸는 문항은 setup 이 원본을 `/opt/course/<문항>/backup/` 에 저장하고 cleanup 이 되돌립니다.** 공용 구성요소(ingress-nginx, Falco, Istio, gVisor, 도구 바이너리)는 여러 문항이 같이 쓰므로 `cleanup.sh` 가 지우지 않습니다.

### 시간 예산

120분에 100점이므로 **1점당 1.2분**이 실제 배분입니다. 이 저장소는 여기에 맞춰 문항마다 `목표` 시간을 넣어 두었습니다.

| 구분 | 배분 | 이유 |
|---|---|---|
| 일반 문항 | 배점 × **1분** | 설정을 바꾸고 검증하는 작업 |
| Monitoring·Logging·Runtime Security | 배점 × **1.33분** | Falco 출력·감사 로그를 읽고 범인을 좁히는 시간이 더 든다 |
| 합계 | **106분** | 남는 14분은 호스트 이동(`ssh`/`exit`), kube-apiserver 재시작 대기, 마지막 검증용 |

kube-apiserver 를 고치는 문항은 재시작에 1~2분이 걸립니다. **그동안 손을 놓지 말고 다음 문항의 `question.md` 를 읽어 두는 것**이 시간을 버는 방법입니다.

풀고 나면 `question.md` 맨 아래 `## Record` 표에 걸린 시간과 점수를 적고 `python3 scripts/update_progress.py` 를 실행하세요. 회차 README의 `실제`·`결과` 칸이 채워집니다.

## 디렉터리 구조

```
.
├── README.md                   # 이 파일 — 출제 트렌드, 진행 현황, 도메인별 자신감, 반복 오답
├── cheatsheet.md               # 시험장에서 쓸 명령과 빈출 절차
├── study_plan/                 # 시험 전 10일 학습 계획 (하루 1시간)
├── scripts/
│   └── update_progress.py      # question.md 의 풀이 기록으로 README 진행 표를 채운다
├── .gitignore
├── mock_exam_a/                # 모의고사 A — 17문항 100점 (심화)
│   ├── README.md               # 회차 요약: 문항 표, 도메인별 실점, 회고
│   └── q01_… ~ q17_…/
│       ├── question.md         # [영문] 문제 (Setup 안내만 한글) + 내 풀이 기록
│       ├── solution.md         # [한글] 해석 + 풀이
│       ├── setup.sh            # 문제 상황을 만드는 스크립트
│       └── cleanup.sh          # 실습 후 정리 스크립트
├── mock_exam_b/                # 모의고사 B — 17문항 100점 (심화)
├── mock_exam_c/                # 모의고사 C — 17문항 100점 (심화)
├── mock_exam_d/                # 모의고사 D — 17문항 100점 (기본)
├── mock_exam_e/                # 모의고사 E — 17문항 100점 (기본)
└── mock_exam_f/                # 모의고사 F — 17문항 100점 (기본)
```

**모의고사는 난이도가 다른 두 묶음입니다.** **D·E·F(기본)** 는 한 문제에 한 가지 개념만 묻고 단계가 2~4개로 짧아, 처음 풀거나 시험 직전 감을 잡을 때 씁니다. **A·B·C(심화)** 는 한 문제에 여러 단계와 함정(예: 새 설정 파일을 kube-apiserver 파드에 마운트하지 않음, 기존 Secret 재암호화 누락)이 섞여 있어 실력 점검용입니다. 권장 순서는 D → E → F → A → B → C 입니다.

**모든 세트는 각각 독립된 전 범위 모의고사입니다.** 여섯 세트 모두 공식 도메인 비중(15/15/10/20/20/20)을 그대로 지키고, 문항 배치도 같습니다.

| 문항 | 도메인 | 배점 |
|---|---|---|
| q01–q03 | Cluster Setup | 5 · 5 · 5 |
| q04–q06 | Cluster Hardening | 5 · 5 · 5 |
| q07–q08 | System Hardening | 5 · 5 |
| q09–q11 | Minimize Microservice Vulnerabilities | 7 · 7 · 6 |
| q12–q14 | Supply Chain Security | 7 · 7 · 6 |
| q15–q17 | Monitoring, Logging and Runtime Security | 7 · 7 · 6 |

## 문제와 풀이를 파일로 나누는 이유

문제 폴더에 `README.md`를 두지 않습니다. GitHub는 폴더를 열면 README를 자동으로 펼치기 때문에, 그 안에 답이 있으면 볼 때마다 스포일러가 됩니다.

| 파일 | 언어 | 내용 |
|---|---|---|
| `question.md` | **영문** | 메타 표 → Setup(스크립트 실행 안내, 한글) → 문제(`## Task`) → 내가 입력한 명령(`## My attempt`) → 풀이 기록(`## Record`) |
| `solution.md` | **한글** | 문제 해석(원문 + 해석) → 모범 풀이 → 검증 → 오답 원인 → 참고 문서 |
| `setup.sh` / `cleanup.sh` | — | 문제 상황 만들기 / 실습 후 정리. Setup 명령은 이 스크립트에만 있습니다 |

**문제를 영문으로 쓰는 이유는 실제 시험이 영문이기 때문입니다.** `solution.md` 맨 앞에 **원문과 한글 해석**을 두었으니, 풀이를 보기 전에 내가 영문을 제대로 읽었는지 먼저 대조하세요.

## 푸는 순서

1. 회차 `README.md` 의 문항 표에서 문제를 고릅니다.
2. `question.md` **만** 엽니다. `## Setup` 의 안내대로 `sudo bash setup.sh` 를 실행해 문제 상황을 만듭니다.
3. 메타 표의 `Host` 로 `ssh` 해서 직접 풀고, 입력한 명령을 `## My attempt` 에 그대로 붙입니다. **틀린 명령도 지우지 마세요.**
4. `solution.md` 를 엽니다. 한글 해석으로 문제를 제대로 읽었는지 먼저 확인하고, 그다음 모범 풀이와 비교합니다. 틀렸으면 `## 오답 원인 / 배운 점` 을 채웁니다.
5. `question.md` 맨 아래 `## Record` 표에 한 줄을 적습니다(날짜, 걸린 분, 얻은 점수). 다시 풀 때마다 한 줄씩 늘리며, 첫 줄이 모의고사 점수이고 그 아래는 복습입니다.
6. `python3 scripts/update_progress.py` 를 실행하면 회차 README의 `실제`·`결과`·도메인별 실점과 아래 진행 현황·도메인별 손실이 채워집니다. **결과는 `## Record` 에만 적고 README 표는 손으로 고치지 않습니다.**
7. `sudo bash cleanup.sh` 로 정리하고(특히 kube-apiserver 를 고친 문항), 페이지 맨 아래 링크로 다음 문제로 넘어갑니다.

## 새 회차 / 문제 추가하기

```bash
mkdir -p mock_exam_g/q01_<주제_스네이크케이스>
# question.md (영문, 맨 아래 ## Record 표 포함), solution.md (한글), setup.sh, cleanup.sh 를 만들고
# mock_exam_g/README.md 문항 표에 한 줄 추가 (scripts/update_progress.py 의 SETS 에도 g 추가)
```

> `.gitignore` 에 `*.key`, `*.crt`, `*.tar`, `kubeconfig` 등을 넣어 두었습니다. 공개 저장소이므로 CSR 문항에서 만든 개인 키, kubeconfig, 이미지 아카이브가 실수로 올라가지 않게 막습니다.

## 진행 현황

`응시일`·`실제 소요`·`점수`·`합격` 은 `scripts/update_progress.py` 가 각 문제의 `## Record` 첫 줄로 채웁니다. `회고` 만 손으로 체크합니다.

| 회차 | 문항 | 배점 | 목표 시간 | 응시일 | 실제 소요 | 점수 | 합격(67) | 회고 |
|---|---|---|---|---|---|---|---|---|
| [mock_exam_a](mock_exam_a/) | 17 | 100 | 106분 |  |  | / 100 | ☐ | ☐ |
| [mock_exam_b](mock_exam_b/) | 17 | 100 | 106분 |  |  | / 100 | ☐ | ☐ |
| [mock_exam_c](mock_exam_c/) | 17 | 100 | 106분 |  |  | / 100 | ☐ | ☐ |
| [mock_exam_d](mock_exam_d/) (기본) | 17 | 100 | 106분 |  |  | / 100 | ☐ | ☐ |
| [mock_exam_e](mock_exam_e/) (기본) | 17 | 100 | 106분 |  |  | / 100 | ☐ | ☐ |
| [mock_exam_f](mock_exam_f/) (기본) | 17 | 100 | 106분 |  |  | / 100 | ☐ | ☐ |

## 도메인별 자신감

도메인별 **손실 점수**(A~F 칸)는 `scripts/update_progress.py` 가 채웁니다. `자신감` 과 `약점 메모` 만 손으로 적고, 이것으로 공부 시간을 어디에 쓸지 결정합니다.

| 도메인 | 비중 | A | B | C | D | E | F | 자신감 | 약점 메모 |
|---|---|---|---|---|---|---|---|---|---|
| Cluster Setup | 15% |  |  |  |  |  |  | ☐☐☐☐☐ |  |
| Cluster Hardening | 15% |  |  |  |  |  |  | ☐☐☐☐☐ |  |
| System Hardening | 10% |  |  |  |  |  |  | ☐☐☐☐☐ |  |
| Minimize Microservice Vulnerabilities | 20% |  |  |  |  |  |  | ☐☐☐☐☐ |  |
| Supply Chain Security | 20% |  |  |  |  |  |  | ☐☐☐☐☐ |  |
| Monitoring, Logging and Runtime Security | 20% |  |  |  |  |  |  | ☐☐☐☐☐ |  |

## 반복 오답 목록

같은 주제를 두 번 이상 틀리면 여기에 올립니다. 시험 전날 이 표만 봅니다.

| 주제 | 틀린 횟수 | 관련 문제 | 해결했나 |
|---|---|---|---|
|  |  |  | ☐ |
