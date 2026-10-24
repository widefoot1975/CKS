# q10 — Mount a Secret as a read-only volume

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q10_secret_volume_readonly
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `topaz` 에 Secret `db-cred`(키 `username`, `password`)와 Deployment `app`(busybox, replicas 1)이 있다.
`app` 은 Secret 값을 환경 변수 `DB_USER`, `DB_PASSWORD` 로 받고 있어 `env` 나 `/proc/<pid>/environ` 으로 값이 보인다.

## Task

Deployment `app` in namespace `topaz` receives Secret `db-cred` as environment variables.
Environment variables leak easily (crash dumps, `env`, child processes), so switch to a file
mount.

1. Remove the environment variables `DB_USER` and `DB_PASSWORD` from the container of
   Deployment `app`.
2. Mount Secret `db-cred` as a volume named `db-cred` at `/etc/db-cred` in the container.
   The mount must be read-only and every file must have mode `0400`.
3. After the rollout, write the output of `ls -lL /etc/db-cred` from the running Pod to
   `/opt/course/d10/ls.txt`.

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

[↑ 문항 목록](../README.md) · [← q09](../q09_psa_restricted_label_fix_pod/question.md) · [q11 →](../q11_runtimeclass_gvisor_pod/question.md)
