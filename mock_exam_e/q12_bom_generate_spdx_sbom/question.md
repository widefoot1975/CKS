# q12 — Generate an SPDX SBOM with bom

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Supply Chain Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q12_bom_generate_spdx_sbom
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `cks-c1` 에 `bom` v0.6.0 이 `/usr/local/bin/bom` 으로 있고(없으면 setup 이 설치하므로 인터넷 연결 필요), `/opt/course/e12/` 는 비어 있다.
`bom` 은 이미지를 `registry.k8s.io` 에서 직접 받으므로 실습 중에도 인터넷 연결이 필요하다. `bom` 바이너리는 공용 도구라 `cleanup.sh` 가 지우지 않는다.

## Task

The security team wants a Software Bill of Materials for the image
`registry.k8s.io/pause:3.10`.

1. Using `bom`, generate an SPDX SBOM of the image `registry.k8s.io/pause:3.10` in SPDX
   tag-value format and save it as `/opt/course/e12/pause.spdx`.
2. Generate the same SBOM in SPDX JSON format and save it as `/opt/course/e12/pause.spdx.json`.
3. Write the SPDX specification version used by these documents (the value of the
   `SPDXVersion` field, e.g. `SPDX-X.Y`) to `/opt/course/e12/spdx-version.txt`.

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

[↑ 문항 목록](../README.md) · [← q11](../q11_istio_peerauthentication_strict_basic/question.md) · [q13 →](../q13_vap_deny_untrusted_registry/question.md)
