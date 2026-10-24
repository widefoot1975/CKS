# q12 — Generate SBOMs and scan them for vulnerabilities · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The image `docker.io/library/nginx:1.27.5` is about to be approved for production. Produce
> SBOMs for it and check them for vulnerabilities. Write all files to `/opt/course/b12/`.
>
> 1. Use `bom` to generate an SBOM of the image `docker.io/library/nginx:1.27.5` in SPDX JSON
>    format, including the operating system packages of the image, and save it as
>    `/opt/course/b12/nginx.spdx.json`.
> 2. Using the SPDX SBOM, find the version of the Debian package `libc6` and write only the version
>    string to `/opt/course/b12/libc6-version.txt`.
> 3. Use `trivy` to generate an SBOM of the same image in CycloneDX format and save it as
>    `/opt/course/b12/nginx.cdx.json`.
> 4. Scan the CycloneDX SBOM (not the image) with `trivy` for vulnerabilities of severity `HIGH`
>    and `CRITICAL`. Write the unique vulnerability IDs, sorted, one per line, to
>    `/opt/course/b12/cves.txt`.

**해석**

이미지 `docker.io/library/nginx:1.27.5` 를 운영 승인하기 전에 SBOM 을 만들고 취약점을 확인한다. 모든 파일은 `/opt/course/b12/` 에 쓴다.

1. `bom` 으로 이미지의 OS 패키지까지 포함한 SPDX JSON SBOM 을 만들어 `/opt/course/b12/nginx.spdx.json` 에 저장한다.
2. SPDX SBOM 에서 Debian 패키지 `libc6` 의 버전을 찾아 버전 문자열만 `/opt/course/b12/libc6-version.txt` 에 쓴다.
3. `trivy` 로 같은 이미지의 CycloneDX SBOM 을 만들어 `/opt/course/b12/nginx.cdx.json` 에 저장한다.
4. 이미지가 아니라 CycloneDX SBOM 을 `trivy` 로 스캔해 `HIGH`·`CRITICAL` 취약점 ID 를 중복 없이 정렬해 한 줄씩 `/opt/course/b12/cves.txt` 에 쓴다.

## 모범 풀이

**1) bom 으로 SPDX JSON**

```bash
bom version | head -3
bom generate --help | grep -E -- '--image|--format|--output|analyze'
bom generate --image docker.io/library/nginx:1.27.5 --analyze-images --format json \
  --output /opt/course/b12/nginx.spdx.json
jq -r '.spdxVersion, (.packages | length)' /opt/course/b12/nginx.spdx.json
# SPDX-2.3
# 1xx
```

> 함정 1: `--analyze-images`(`-a`)를 빼면 bom 은 이미지와 레이어(tar)만 패키지로 기록하고 **레이어 안의 OS 패키지(dpkg)** 는 분석하지
> 않습니다. 그러면 2번에서 `libc6` 가 보이지 않습니다. `--format` 기본값은 `tag-value` 라서 JSON 이 필요하면 `--format json` 을 줍니다.

bom 은 Docker 데몬 없이 레지스트리에서 직접 이미지를 받습니다(go-containerregistry). 쿠버네티스 SIG Release 가 만든 도구라 문서
(kubernetes-sigs.github.io/bom)가 시험 허용 목록에 있습니다.

**2) libc6 버전**

```bash
jq -r '.packages[] | select(.name=="libc6") | .versionInfo' /opt/course/b12/nginx.spdx.json | sort -u | tee /opt/course/b12/libc6-version.txt
# 2.36-9+deb12u10       (이미지 빌드 시점에 따라 다름)
```

SPDX 패키지 항목은 `name`, `versionInfo`, `externalRefs`(purl: `pkg:deb/debian/libc6@2.36-9+deb12u10?arch=amd64&distro=debian-12`) 를 가집니다.
jq 가 없으면 `grep -A3 '"name": "libc6"' nginx.spdx.json` 으로도 찾을 수 있습니다.

**3) trivy 로 CycloneDX**

```bash
trivy --version                                    # Version: 0.69.3
trivy image --format cyclonedx --output /opt/course/b12/nginx.cdx.json docker.io/library/nginx:1.27.5
jq -r '.bomFormat, .specVersion, (.components | length)' /opt/course/b12/nginx.cdx.json
# CycloneDX
# 1.6
# 1xx
```

`--format cyclonedx` 는 기본적으로 **패키지 목록만** 담습니다(취약점을 함께 넣으려면 `--scanners vuln`). `--format spdx-json` 을 주면 trivy 로도
SPDX 를 만들 수 있습니다.

**4) SBOM 스캔**

```bash
trivy sbom --severity HIGH,CRITICAL --format json /opt/course/b12/nginx.cdx.json \
  | jq -r '.Results[]?.Vulnerabilities[]?.VulnerabilityID' | sort -u > /opt/course/b12/cves.txt
wc -l /opt/course/b12/cves.txt
head /opt/course/b12/cves.txt
# CVE-2023-xxxx ...
```

> 함정 2: 처음 실행할 때 trivy 는 취약점 DB 를 내려받습니다(`--skip-db-update` 를 처음부터 주면 DB 가 없어 실패). `Vulnerabilities` 가 없는
> Result 가 있으므로 jq 에서 `[]?` 로 null 을 건너뜁니다. 같은 CVE 가 여러 패키지에 걸리면 중복되므로 `sort -u`.

| 명령 | 입력 | 하는 일 |
|---|---|---|
| `bom generate --image X -a --format json` | 이미지 | SPDX SBOM 생성 |
| `trivy image --format cyclonedx` | 이미지 | CycloneDX SBOM 생성 |
| `trivy image --severity ...` | 이미지 | 이미지를 직접 스캔 |
| `trivy sbom <file>` | SPDX/CycloneDX 파일 | SBOM 의 패키지(purl) 로 취약점 조회 — 이미지 다시 받지 않음 |

`trivy sbom` 은 SBOM 의 purl 과 OS 정보로 판단하므로, OS(distro) 정보가 없는 SBOM 을 넣으면 OS 패키지 취약점이 빠질 수 있습니다. bom 의 SPDX
로도 `trivy sbom /opt/course/b12/nginx.spdx.json` 을 돌려 결과를 비교해 보면 차이를 확인할 수 있습니다.

## 검증

```bash
ls -l /opt/course/b12/
jq -e '.spdxVersion' /opt/course/b12/nginx.spdx.json
jq -e '.bomFormat=="CycloneDX"' /opt/course/b12/nginx.cdx.json
cat /opt/course/b12/libc6-version.txt
jq -r '.components[] | select(.name=="libc6") | .version' /opt/course/b12/nginx.cdx.json      # 2번과 같은 값
diff <(sort -u /opt/course/b12/cves.txt) /opt/course/b12/cves.txt && echo sorted-unique
trivy image --severity HIGH,CRITICAL -q docker.io/library/nginx:1.27.5 | grep -c CVE         # 이미지 스캔과 대략 일치
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `bom generate --image <img> -a --format json -o <file>`, `trivy image --format cyclonedx -o <file> <img>`, `trivy sbom --severity HIGH,CRITICAL <file>`.
- **헷갈리는 지점**: SPDX(리눅스 재단, bom 기본) 와 CycloneDX(OWASP) 는 서로 다른 SBOM 형식입니다. 버전 문자열은 Debian 의 `epoch:upstream-revision` 형식 그대로(예: `2.36-9+deb12u10`) 씁니다. Trivy 는 허용 문서가 아니므로 `trivy sbom --help`, `trivy image --help` 로 플래그를 확인합니다. Trivy 버전은 0.69.3 을 고정해서 씁니다(0.69.4 는 악성 릴리스).

## 참고 문서

- 검색어: `bom generate`, `sbom`, `spdx`
- https://kubernetes-sigs.github.io/bom/
- https://kubernetes.io/docs/concepts/containers/images/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q13 →](../q13_kubelinter_kubesec_fix_manifests/question.md)
