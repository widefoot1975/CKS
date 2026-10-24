# q12 — Generate SBOMs and scan them for vulnerabilities

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q12_sbom_bom_trivy_sbom
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `cks-c1` 에 `bom` v0.6.0 과 `trivy` v0.69.3 이 있고(없으면 setup 이 `/usr/local/bin` 에 설치, cleanup 은 지우지 않음) `/opt/course/b12/` 는 비어 있다. 두 도구가 이미지와 Trivy 취약점 DB 를 내려받으므로 인터넷이 필요하다.
Trivy v0.69.4 는 악성 릴리스(CVE-2026-33634)이므로 절대 설치하지 말고, `trivy --version` 이 `0.69.3` 인지 확인한다.

## Task

The image `docker.io/library/nginx:1.27.5` is about to be approved for production. Produce
SBOMs for it and check them for vulnerabilities. Write all files to `/opt/course/b12/`.

1. Use `bom` to generate an SBOM of the image `docker.io/library/nginx:1.27.5` in SPDX JSON
   format, including the operating system packages of the image, and save it as
   `/opt/course/b12/nginx.spdx.json`.
2. Using the SPDX SBOM, find the version of the Debian package `libc6` and write only the version
   string to `/opt/course/b12/libc6-version.txt`.
3. Use `trivy` to generate an SBOM of the same image in CycloneDX format and save it as
   `/opt/course/b12/nginx.cdx.json`.
4. Scan the CycloneDX SBOM (not the image) with `trivy` for vulnerabilities of severity `HIGH`
   and `CRITICAL`. Write the unique vulnerability IDs, sorted, one per line, to
   `/opt/course/b12/cves.txt`.

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

[↑ 문항 목록](../README.md) · [← q11](../q11_user_namespaces_hostusers_false/question.md) · [q13 →](../q13_kubelinter_kubesec_fix_manifests/question.md)
