# q14 — Raise the kubesec score of a Deployment

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Supply Chain Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q14_kubesec_deployment_score
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/f14/deploy.yaml` 에 Deployment `billing`(namespace `f14`) 매니페스트가 있고 아직 적용되지 않았다. namespace `f14` 은 비어 있다.
`kubesec` v2.14.2 가 없으면 setup 이 GitHub 릴리스에서 `/usr/local/bin` 에 설치하므로 인터넷 연결이 필요하다. kubesec 은 공용 도구라 정리할 때 지우지 않는다.

## Task

The manifest of Deployment `billing` must reach a kubesec score of at least `7` before it may be
deployed.

1. Run `kubesec scan` on `/opt/course/f14/deploy.yaml` and write only the score (a number) to
   `/opt/course/f14/before.txt`.
2. Edit `/opt/course/f14/deploy.yaml` in place so that kubesec reports no critical findings and a
   score of at least `7`. Keep the Deployment name, namespace, image and container port. The
   container needs a writable `/tmp`.
3. Write the new score to `/opt/course/f14/after.txt`, then apply the manifest. The Pod of
   `billing` must be `Running` and Ready.

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

[↑ 문항 목록](../README.md) · [← q13](../q13_trivy_config_manifest_scan/question.md) · [q15 →](../q15_falco_detect_write_below_etc/question.md)
