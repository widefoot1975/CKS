# q10 — Mount a Secret as a file and restrict access by resourceNames

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q10_secret_file_mount_resource_names
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `pay` 에 Secret `db-cred`(`username`, `password`), Secret `stripe-key`, ServiceAccount `api`, Deployment `api`(SA `api`, `db-cred` 의 `password` 를 환경 변수 `DB_PASSWORD` 로 받음)가 있다. SA `api` 에는 아무 권한도 없다.
etcd 저장 암호화(EncryptionConfiguration)는 설정되어 있지 않다고 가정한다. 호스트에 `etcdctl` 이 없으면 etcd Pod 안의 `etcdctl` 을 쓴다.

## Task

Deployment `api` in namespace `pay` reads its database password from an environment variable.

1. Change Deployment `api` so that the container no longer has the environment variable
   `DB_PASSWORD`. Instead, mount Secret `db-cred` as a volume at `/etc/db` (read-only), with file
   permissions `0400` for all files of the volume.
2. Make Secret `db-cred` immutable without changing its data.
3. Create a Role `db-cred-reader` and a RoleBinding `db-cred-reader` in namespace `pay` so that
   ServiceAccount `api` can `get` the Secret `db-cred` and nothing else. Write the answers
   (`yes`/`no`) of `kubectl auth can-i` for these three checks as ServiceAccount `api`, one per
   line in this order, to `/opt/course/b10/can-i.txt`:
   `get secret/db-cred`, `get secret/stripe-key`, `list secrets` (all in namespace `pay`).
4. Read the stored entry of Secret `db-cred` directly from etcd and write the raw output as a hex dump
   (`hexdump -C`) to `/opt/course/b10/etcd-db-cred.txt`.

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

[↑ 문항 목록](../README.md) · [← q09](../q09_istio_peerauthentication_strict/question.md) · [q11 →](../q11_user_namespaces_hostusers_false/question.md)
