# q09 — Find Pod Security baseline violators with a dry run

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q09_psa_dry_run_find_violators
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `legacy` 에 Pod Security 라벨이 없고, 단독 Pod 다섯 개(`web`, `debug-priv`, `host-net`, `log-reader`, `cap-add`)가 `Running` 이다. `/opt/course/f09/` 는 비어 있다.

## Task

Namespace `legacy` will start enforcing the Pod Security Standard `baseline`. Before that,
existing Pods that would violate it must be found and removed.

1. Without changing the namespace yet, use a server-side dry run to find out which existing Pods in
   namespace `legacy` violate the `baseline` level. Write their names, one per line and sorted
   alphabetically, to `/opt/course/f09/violators.txt`.
2. Delete exactly these Pods.
3. Label namespace `legacy` so that it enforces `baseline`, pinned to version `v1.35`.
4. Try to create a Pod `priv-test` in namespace `legacy` with image `busybox:1.36` and
   `securityContext.privileged: true`, and write the rejection message to
   `/opt/course/f09/rejected.txt`.

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

[↑ 문항 목록](../README.md) · [← q08](../q08_host_setuid_nologin_shell/question.md) · [q10 →](../q10_etcdctl_read_secret_plaintext/question.md)
