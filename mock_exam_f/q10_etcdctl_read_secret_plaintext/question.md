# q10 — Read a Secret directly from etcd

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q10_etcdctl_read_secret_plaintext
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `vault-demo` 에 Secret `db-cred`(키 `username`, `password`)가 있고, kube-apiserver 에는 저장 암호화(`--encryption-provider-config`)가 설정되어 있지 않다. `/opt/course/f10/` 는 비어 있다.
`etcdctl` 이 없으면 setup 이 클러스터의 etcd 와 같은 버전을 GitHub 릴리스에서 받아 `/usr/local/bin` 에 설치하므로 인터넷 연결이 필요하다(실패해도 etcd 파드 안의 `etcdctl` 로 풀 수 있다). etcdctl 은 공용 도구라 정리할 때 지우지 않는다.

## Task

The security team wants to know whether Secrets are readable by anyone who gets access to the etcd
data.

1. On `cks-c1`, use `etcdctl` with the etcd client TLS certificates under `/etc/kubernetes/pki/`
   to read the etcd key of Secret `db-cred` in namespace `vault-demo`. Write the value of the key
   exactly as returned by etcd (no decoding) to `/opt/course/f10/etcd-raw.txt`.
2. Find the value of the data field `password` inside that raw output and write it, exactly as it
   appears in etcd, to `/opt/course/f10/password.txt`.
3. Write `PLAINTEXT` to `/opt/course/f10/result.txt` if the password can be read from the etcd
   data without any key, otherwise write `ENCRYPTED`.

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

[↑ 문항 목록](../README.md) · [← q09](../q09_psa_dry_run_find_violators/question.md) · [q11 →](../q11_user_namespaces_hostusers_false/question.md)
