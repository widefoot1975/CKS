# q14 — ValidatingAdmissionPolicy with ConfigMap parameters

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Supply Chain Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q14_vap_params_configmap_registries
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `policy-config` 에 ConfigMap `registry-allowlist`(키 `registries` = `registry.k8s.io/,docker.io/library/`)가 있고, 라벨 없는 빈 namespace `team-red`, `team-blue` 가 있다. `/opt/course/b14/bad-init.yaml` 에 initContainer 가 있는 테스트용 Pod 매니페스트가 있다. ValidatingAdmissionPolicy 는 아직 없다.

## Task

Only images from approved registries may run in selected namespaces. The list of approved
registry prefixes is maintained in the ConfigMap `registry-allowlist` in namespace
`policy-config` (key `registries`, comma-separated).

1. Create a ValidatingAdmissionPolicy `allowed-registries` that uses ConfigMaps as parameters
   and checks Pods on `CREATE` and `UPDATE`: every image of `containers` and `initContainers` must
   start with one of the prefixes from the parameter's `registries` key. Use a
   `messageExpression` whose message contains the rejected image(s).
2. Create a ValidatingAdmissionPolicyBinding `allowed-registries-binding` that uses the
   ConfigMap `registry-allowlist` in namespace `policy-config` as parameter, applies only to
   namespaces labeled `registry-check=enforced`, uses the validation actions `Deny` and `Audit`,
   and denies requests if the parameter cannot be found.
3. Label namespace `team-red` with `registry-check=enforced`.
4. In namespace `team-red`: create Pod `ok` with image `docker.io/library/nginx:1.27-alpine`
   (must succeed), try to create Pod `short` with image `nginx:1.27-alpine` and apply
   `/opt/course/b14/bad-init.yaml` (both must be denied). Write both error messages to
   `/opt/course/b14/denied.txt`. In namespace `team-blue`, Pod `free` with image
   `nginx:1.27-alpine` must be created successfully.

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

[↑ 문항 목록](../README.md) · [← q13](../q13_kubelinter_kubesec_fix_manifests/question.md) · [q15 →](../q15_falco_investigate_existing_alerts/question.md)
