# q13 — Fix manifests with kube-linter and kubesec

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Supply Chain Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q13_kubelinter_kubesec_fix_manifests
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/b13/manifests/` 에 Deployment 매니페스트 `catalog.yaml`(`nginx:latest`, 80 포트)과 `worker.yaml`(busybox, 리소스 일부만 설정)이 있고, 빈 namespace `catalog` 가 있다. 아직 아무것도 apply 되지 않았다.
`kube-linter` v0.7.2 와 `kubesec` v2.14.2 가 없으면 setup 이 `/usr/local/bin` 에 설치하므로 인터넷이 필요하다(cleanup 은 지우지 않음).

## Task

The manifests in `/opt/course/b13/manifests/` must pass a security review before they are
deployed to namespace `catalog`.

1. Run `kube-linter` on the directory `/opt/course/b13/manifests/` with **only** these checks:
   `no-read-only-root-fs`, `run-as-non-root`, `unset-cpu-requirements`,
   `unset-memory-requirements` and `latest-tag`. Save the output to
   `/opt/course/b13/lint-before.txt`.
2. Fix both manifests so that this exact kube-linter run reports no findings. Rules:
   - In `catalog.yaml` use the image `nginxinc/nginx-unprivileged:1.27-alpine` with container port
     `8080`; the nginx server must still work with a read-only root filesystem.
   - Keep the image and the command of `worker.yaml`.
   - Containers must run with a numeric UID greater than `10000`, must not allow privilege
     escalation and must drop all capabilities.
   - Set CPU and memory requests and limits on every container.
   Save the output of the final run to `/opt/course/b13/lint-after.txt`.
3. Scan `catalog.yaml` with `kubesec` and write only its score (a number) to
   `/opt/course/b13/kubesec-score.txt`. The score must be at least `7`.
4. Apply both manifests. All Pods in namespace `catalog` must be `Running` and Ready.

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

[↑ 문항 목록](../README.md) · [← q12](../q12_sbom_bom_trivy_sbom/question.md) · [q14 →](../q14_vap_params_configmap_registries/question.md)
