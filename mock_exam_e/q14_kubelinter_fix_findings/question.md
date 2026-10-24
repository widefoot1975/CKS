# q14 — Fix KubeLinter findings in a Deployment manifest

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Supply Chain Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q14_kubelinter_fix_findings
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/e14/catalog.yaml` 에 Deployment `catalog`(namespace `lint`, 이미지 `nginx:latest`, `privileged: true`) 매니페스트가 있고, 아직 클러스터에 적용되지 않았다.
namespace `lint` 는 비어 있다. `kube-linter` v0.7.2 가 없으면 setup 이 `/usr/local/bin` 에 설치하므로 인터넷 연결이 필요하다. 이 바이너리는 공용 도구라 `cleanup.sh` 가 지우지 않는다.

## Task

Manifest `/opt/course/e14/catalog.yaml` must pass a KubeLinter review before it is deployed.
Use exactly these checks: `latest-tag`, `privileged-container`, `run-as-non-root`,
`no-read-only-root-fs` (and no default checks).

1. Lint the manifest with only these four checks and save the complete output to
   `/opt/course/e14/before.txt`.
2. Fix `/opt/course/e14/catalog.yaml` in place: use image
   `nginxinc/nginx-unprivileged:1.27-alpine` with container port `8080`, remove the
   privileged mode, run as non-root with UID `101`, make the root filesystem read-only and
   mount an `emptyDir` volume at `/tmp` so that nginx can start.
3. Run the same lint command again; it must exit with code `0`. Save its output to
   `/opt/course/e14/after.txt`. Then apply the manifest; the Pod must be `Running`.

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

[↑ 문항 목록](../README.md) · [← q13](../q13_vap_deny_untrusted_registry/question.md) · [q15 →](../q15_falco_rule_output_change/question.md)
