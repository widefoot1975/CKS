# q12 — Generate an SPDX SBOM with bom · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The security team wants a Software Bill of Materials for the image
> `registry.k8s.io/pause:3.10`.
>
> 1. Using `bom`, generate an SPDX SBOM of the image `registry.k8s.io/pause:3.10` in SPDX
>    tag-value format and save it as `/opt/course/e12/pause.spdx`.
> 2. Generate the same SBOM in SPDX JSON format and save it as `/opt/course/e12/pause.spdx.json`.
> 3. Write the SPDX specification version used by these documents (the value of the
>    `SPDXVersion` field, e.g. `SPDX-X.Y`) to `/opt/course/e12/spdx-version.txt`.

**해석**

보안 팀이 이미지 `registry.k8s.io/pause:3.10` 의 SBOM(소프트웨어 자재 명세서)을 원한다.

1. `bom` 으로 이미지 `registry.k8s.io/pause:3.10` 의 SPDX SBOM 을 SPDX tag-value 형식으로 만들어 `/opt/course/e12/pause.spdx` 에 저장한다.
2. 같은 SBOM 을 SPDX JSON 형식으로 만들어 `/opt/course/e12/pause.spdx.json` 에 저장한다.
3. 이 문서들이 쓰는 SPDX 사양 버전(`SPDXVersion` 필드 값, 예: `SPDX-X.Y`)을 `/opt/course/e12/spdx-version.txt` 에 쓴다.

## 모범 풀이

**1) tag-value (기본 형식)**

```bash
bom generate --help | grep -E -- '--image|--format|--output'     # (출력 요약)
#   -i, --image strings     list of images
#       --format string     format of the document (supports tag-value, json) (default "tag-value")
#   -o, --output string     path to the file where the document will be written (defaults to STDOUT)
bom generate --image registry.k8s.io/pause:3.10 --output /opt/course/e12/pause.spdx
head -12 /opt/course/e12/pause.spdx
# SPDXVersion: SPDX-2.3
# DataLicense: CC0-1.0
# SPDXID: SPDXRef-DOCUMENT
# DocumentName: ...
# DocumentNamespace: https://spdx.org/spdxdocs/k8s-releng-bom-...
# Creator: Tool: bom-v0.6.0
# ...
```

`--image` 는 레지스트리에서 이미지를 받아 이미지(멀티 아키텍처면 인덱스와 아키텍처별 이미지)와 레이어를 패키지로 기록합니다. 디렉터리를
분석할 때는 `--dirs`, 파일은 `--file` 을 씁니다.

**2) JSON**

```bash
bom generate --image registry.k8s.io/pause:3.10 --format json --output /opt/course/e12/pause.spdx.json
jq -r '.spdxVersion, .name, (.packages | length)' /opt/course/e12/pause.spdx.json
# SPDX-2.3
# ...
# <패키지 수>
```

**3) SPDX 버전**

```bash
awk -F': ' '/^SPDXVersion:/{print $2; exit}' /opt/course/e12/pause.spdx > /opt/course/e12/spdx-version.txt
cat /opt/course/e12/spdx-version.txt      # SPDX-2.3 (bom 버전에 따라 다를 수 있으니 파일에 적힌 값을 그대로 쓴다)
bom document outline /opt/course/e12/pause.spdx | head -20     # 패키지 트리를 사람이 읽기 좋게 출력
```

| 도구 | SBOM 생성 | 형식 |
|---|---|---|
| `bom generate` | 이미지·디렉터리·파일 | SPDX tag-value / SPDX JSON |
| `trivy image --format spdx-json` / `cyclonedx` | 이미지 | SPDX JSON / CycloneDX |
| `trivy sbom <파일>` | — (SBOM 을 입력으로 취약점 스캔) | SPDX·CycloneDX 읽기 |

## 검증

```bash
ls -l /opt/course/e12/
head -1 /opt/course/e12/pause.spdx                                  # SPDXVersion: SPDX-2.3
jq -e '.spdxVersion' /opt/course/e12/pause.spdx.json                # "SPDX-2.3" (유효한 JSON 이어야 함)
grep -c '^PackageName:' /opt/course/e12/pause.spdx                  # 1 이상
cat /opt/course/e12/spdx-version.txt                                # SPDX-2.3
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `bom generate --image <img> --output f.spdx` (tag-value 기본), JSON 은 `--format json`. 구조 보기는 `bom document outline f.spdx`.
- **헷갈리는 지점**: `--output` 을 빼면 SBOM 이 표준출력으로 나옵니다(리다이렉트해도 되지만 로그가 섞이지 않게 `--output` 권장). `bom` 문서(kubernetes-sigs.github.io/bom)는 시험에서 열 수 있지만 `--help` 가 더 빠릅니다. SPDX 는 Linux Foundation, CycloneDX 는 OWASP 표준입니다.

## 참고 문서

시험 중에는 `bom generate --help`, `bom document --help` 로 플래그를 확인합니다.

- 검색어: `bom generate image`, `spdx`
- https://kubernetes-sigs.github.io/bom/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q13 →](../q13_vap_deny_untrusted_registry/question.md)
