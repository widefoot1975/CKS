# q10 — Encrypt Secrets at rest and rewrite the existing data

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q10_etcd_encryption_at_rest_rewrite
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 kube-apiserver 에는 암호화 설정이 없고, namespace `finance` 에 Secret `db-creds` 가 etcd 에 평문으로 저장되어 있다. 원본 매니페스트는 `/opt/course/a10/backup/` 에 있다.
`cleanup.sh` 는 모든 Secret 을 평문으로 다시 쓴 뒤 매니페스트를 되돌린다(암호화된 채로 설정만 지우면 Secret 을 읽을 수 없게 되므로 반드시 `cleanup.sh` 로 정리한다). 호스트에 `hexdump` 가 있어야 한다.

## Task

Secrets of cluster `cks-c1` are stored unencrypted in etcd.

1. Create the encryption configuration `/etc/kubernetes/enc/enc.yaml` that encrypts
   resource `secrets` with the `aescbc` provider using one key named `key1` (a new random
   32-byte key), and can still read data that is not yet encrypted.
2. Configure the kube-apiserver to use this file. The kube-apiserver must be running and
   healthy afterwards.
3. Make sure that all Secrets that already exist in the cluster are stored encrypted.
4. Read the raw etcd value of Secret `db-creds` in namespace `finance` with `etcdctl` and
   write its `hexdump -C` output to `/opt/course/a10/etcd-db-creds.txt`.

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

[↑ 문항 목록](../README.md) · [← q09](../q09_psa_baseline_enforce_restricted_warn/question.md) · [q11 →](../q11_runtimeclass_gvisor_sandbox/question.md)
