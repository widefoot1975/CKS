# q14 — Raise a Pod's kubesec score

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Supply Chain Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q14_kubesec_score_fix_pod
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/d14/pod.yaml` 에 `privileged: true` 인 Pod `agent` 매니페스트가 있고(아직 만들지 않음), namespace `beryl` 은 비어 있다.
`kubesec` v2.14.2 가 없으면 setup 이 `/usr/local/bin` 에 설치한다(GitHub 로 인터넷 연결 필요). cleanup 은 kubesec 을 지우지 않는다.

## Task

The manifest `/opt/course/d14/pod.yaml` must pass a static security review with `kubesec`
before it may be deployed.

1. Scan the manifest with `kubesec scan` and write only the numeric score to
   `/opt/course/d14/before.txt`.
2. Edit `/opt/course/d14/pod.yaml` in place: remove the privileged mode and, in the
   container's `securityContext`, set `readOnlyRootFilesystem: true`, `runAsNonRoot: true`,
   `runAsUser: 10001`, `allowPrivilegeEscalation: false` and drop all capabilities. Add
   resource requests `cpu: 50m`, `memory: 32Mi` and limits `cpu: 100m`, `memory: 64Mi`.
3. Scan again and write only the score to `/opt/course/d14/after.txt`. The score must be at
   least `6` with no critical findings. Then create the Pod from the file; it must be
   `Running` in namespace `beryl`.

## My attempt

```bash

```

## Record

<!-- One row per attempt. Score = points earned (0 … Points). The first row is the mock exam itself; later rows are reviews. -->

| Date | Time (min) | Score | Note |
|---|---|---|---|
|  |  |  |  |

---

Solution → **[solution.md](solution.md)**

[↑ 문항 목록](../README.md) · [← q13](../q13_trivy_image_critical_count/question.md) · [q15 →](../q15_falco_shell_alert_delete_pod/question.md)
