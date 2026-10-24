# q13 — Deny Pods from untrusted registries with ValidatingAdmissionPolicy

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q13_vap_deny_untrusted_registry
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `factory`(라벨 `registry-policy=trusted`)와 `playground`(라벨 없음)가 비어 있고, ValidatingAdmissionPolicy `trusted-registry-only` 와
그 바인딩은 없다. 지금은 어느 namespace 에서나 아무 이미지로 파드를 만들 수 있다.

## Task

Namespaces labeled `registry-policy=trusted` may only run images from `registry.k8s.io`.

1. Create a ValidatingAdmissionPolicy named `trusted-registry-only` that applies to `CREATE`
   and `UPDATE` of `pods` and rejects a Pod if any image in `spec.containers` does not start
   with `registry.k8s.io/`. Use the message `only images from registry.k8s.io are allowed`.
2. Create a ValidatingAdmissionPolicyBinding named `trusted-registry-only-binding` that
   enforces the policy (action `Deny`) only in namespaces labeled `registry-policy=trusted`.
3. Test it: Pod `ok` with image `registry.k8s.io/pause:3.10` in namespace `factory` must be
   created; Pod `bad` with image `nginx:1.27-alpine` in namespace `factory` must be
   rejected — write the full error message to `/opt/course/e13/denied.txt`. The same
   `nginx:1.27-alpine` Pod named `free` in namespace `playground` must still be created.

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

[↑ 문항 목록](../README.md) · [← q12](../q12_bom_generate_spdx_sbom/question.md) · [q14 →](../q14_kubelinter_fix_findings/question.md)
