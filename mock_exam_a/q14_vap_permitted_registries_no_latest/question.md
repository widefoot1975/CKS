# q14 — ValidatingAdmissionPolicy for trusted registries and pinned tags

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Supply Chain Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q14_vap_permitted_registries_no_latest
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `orbit` 에는 라벨 `registry-policy=enforced` 가 있고 namespace `playground` 에는 없다. `/opt/course/a14/init-test.yaml` 에는 init 컨테이너가 있는 테스트용 Pod 매니페스트가 있다. ValidatingAdmissionPolicy·Binding 은 없다.

## Task

Only trusted, pinned images may be deployed into namespaces labeled
`registry-policy=enforced`. Implement this with a ValidatingAdmissionPolicy (no webhook).

1. Create a ValidatingAdmissionPolicy `trusted-registries` that checks `CREATE` and `UPDATE`
   of Pods and of Deployments (`apps/v1`). For every container and init container:
   - the image must start with `registry.k8s.io/` or `docker.io/library/`
     (message: `images must come from registry.k8s.io/ or docker.io/library/`)
   - the image must have an explicit tag that is not `latest`; references by digest
     (`@sha256:`) are also allowed (message: `images must use an explicit tag other than latest`)
2. Create a ValidatingAdmissionPolicyBinding `trusted-registries-binding` that rejects
   violating requests and applies only to namespaces labeled `registry-policy=enforced`.
3. Run the following commands and write their complete output (stdout and stderr) to
   `/opt/course/a14/tests.txt`. Only `t1` and `t6` may be accepted.

   ```bash
   kubectl -n orbit run t1 --image=docker.io/library/nginx:1.27-alpine --dry-run=server
   kubectl -n orbit run t2 --image=nginx:1.27-alpine --dry-run=server
   kubectl -n orbit run t3 --image=registry.k8s.io/pause --dry-run=server
   kubectl -n orbit create deploy t4 --image=docker.io/library/busybox:latest --dry-run=server
   kubectl -n orbit apply -f /opt/course/a14/init-test.yaml --dry-run=server
   kubectl -n playground run t6 --image=nginx:latest --dry-run=server
   ```

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

[↑ 문항 목록](../README.md) · [← q13](../q13_trivy_scan_delete_critical/question.md) · [q15 →](../q15_falco_custom_rule_shell_output/question.md)
