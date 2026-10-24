# q09 — Enforce tenant Pod security with a ValidatingAdmissionPolicy

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q09_vap_tenant_pod_security
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `tenant-a`(라벨 `tenant=true`)와 `tenant-b`(라벨 없음)가 있고, `/opt/course/c09/tests/` 에 테스트용 Pod 매니페스트 6개가 있다.
ValidatingAdmissionPolicy 는 아직 없다.

## Task

Namespaces labeled `tenant=true` host untrusted tenants. Without using Pod Security Admission,
enforce the following rules for Pods in those namespaces with a ValidatingAdmissionPolicy named
`tenant-pod-security` and a ValidatingAdmissionPolicyBinding named `tenant-pod-security-binding`.

1. Reject a Pod if any of the following is true:
   - any container is `privileged: true`
   - the Pod uses a `hostPath` volume
   - the Pod sets `hostNetwork`, `hostPID` or `hostIPC` to `true`
   - any container would not run with `runAsNonRoot: true` — the value may come from the Pod's
     `securityContext` or from the container's `securityContext`; a container value overrides
     the Pod value
2. "Container" means regular containers, init containers **and** ephemeral containers. Adding an
   ephemeral container to a running Pod (`kubectl debug`) must be checked too.
3. The policy must apply to `CREATE` and `UPDATE` only, fail closed, and the binding must only
   select namespaces labeled `tenant=true` and use the validation action `Deny`.
4. Create each manifest in `/opt/course/c09/tests/` in namespace `tenant-a` and write one line per
   file to `/opt/course/c09/results.txt` in the form `<file name>: allowed` or `<file name>: denied`,
   sorted by file name. Then run
   `kubectl -n tenant-a debug ok --image=busybox:1.36 --profile=sysadmin -- true` and append a
   line `debug-sysadmin: allowed` or `debug-sysadmin: denied`.

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

[↑ 문항 목록](../README.md) · [← q08](../q08_host_kernel_modules_blacklist/question.md) · [q10 →](../q10_secret_leak_hunt_env_annotations/question.md)
