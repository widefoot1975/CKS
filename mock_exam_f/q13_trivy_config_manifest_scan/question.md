# q13 — Fix Trivy misconfiguration findings in a manifest

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Supply Chain Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q13_trivy_config_manifest_scan
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/f13/manifests/deploy.yaml` 에 Deployment `catalog`(namespace `f13`) 매니페스트가 있고 아직 클러스터에는 적용되지 않았다. namespace `f13` 은 비어 있다.
Trivy 가 없으면 setup 이 **v0.69.3** 을 설치한다(v0.69.4 는 악성 릴리스였으므로 쓰지 않는다). 설치와 첫 스캔 때 검사 규칙 번들을 받으므로 인터넷 연결이 필요하다. Trivy 는 공용 도구라 정리할 때 지우지 않는다.

## Task

Before Deployment `catalog` goes live, its manifest must pass a misconfiguration scan.

1. Scan the directory `/opt/course/f13/manifests/` with `trivy config`, reporting only `HIGH` and
   `CRITICAL` findings, and write the output to `/opt/course/f13/before.txt`.
2. Edit `/opt/course/f13/manifests/deploy.yaml` in place so that the same scan reports no `HIGH`
   or `CRITICAL` findings. Keep the Deployment name, namespace, image and container port. The
   container needs a writable `/tmp`.
3. Run the scan again, write the output to `/opt/course/f13/after.txt`, then apply the manifest.
   The Pod of `catalog` must be `Running` and Ready.

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

[↑ 문항 목록](../README.md) · [← q12](../q12_image_digest_pinning/question.md) · [q14 →](../q14_kubesec_deployment_score/question.md)
