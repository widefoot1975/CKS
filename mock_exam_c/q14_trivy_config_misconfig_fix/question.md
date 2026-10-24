# q14 — Fix misconfigurations reported by trivy config

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Supply Chain Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q14_trivy_config_misconfig_fix
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/c14/` 에 `Dockerfile`, `app.sh`, `k8s/deploy.yaml`(Deployment `report`, 아직 적용 안 됨)이 있고 namespace `reports` 는 비어 있다.
Trivy 가 없으면 setup 이 **v0.69.3** 을 `/usr/local/bin` 에 설치한다. 검사 규칙 번들을 받기 위해 `ghcr.io`/`mirror.gcr.io` 로 인터넷 연결이 필요하다. Trivy 는 정리할 때 지우지 않는다.

## Task

The directory `/opt/course/c14/` contains a `Dockerfile` and the Kubernetes manifest
`k8s/deploy.yaml`. Use Trivy's misconfiguration scanner on the whole directory.

1. Write the number of `HIGH` and `CRITICAL` misconfigurations Trivy reports for the directory
   (both files together) to `/opt/course/c14/before.txt` (just the number).
2. Fix the `Dockerfile` so that Trivy reports no `HIGH` or `CRITICAL` misconfiguration. The image
   must still be based on Ubuntu (use tag `24.04`) and still install `curl`.
3. Fix `k8s/deploy.yaml` so that Trivy reports no `HIGH` or `CRITICAL` misconfiguration. Use image
   `nginxinc/nginx-unprivileged:1.27-alpine` (listens on port `8080`). Do not use host namespaces,
   host paths or privileged mode. Give the container CPU and memory requests and limits.
4. Apply `k8s/deploy.yaml`. Deployment `report` in namespace `reports` must have all replicas
   Ready.
5. Write the new number of `HIGH` and `CRITICAL` misconfigurations to `/opt/course/c14/after.txt`.

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

[↑ 문항 목록](../README.md) · [← q13](../q13_imagepolicywebhook_admission_config/question.md) · [q15 →](../q15_falco_macro_list_append_exceptions/question.md)
