# q10 — Switch encryption at rest from identity to aescbc

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q10_encryption_config_identity_to_aescbc
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 kube-apiserver 는 `--encryption-provider-config=/etc/kubernetes/enc/enc.yaml` 로 실행 중이고(볼륨 마운트 포함), 이 파일의 providers 순서가
`identity` → `aescbc`(키 `key1`)라서 Secret 이 etcd 에 **평문**으로 저장된다. namespace `vault` 에 Secret `db-pass` 와 `api-key` 가 있다.
원본 kube-apiserver 매니페스트는 `/opt/course/e10/backup/` 에 백업되어 있고, `cleanup.sh` 가 Secret 을 평문으로 되돌린 뒤 원본을 복구한다.

## Task

Secrets in this cluster are stored unencrypted although an encryption configuration exists.

1. Edit `/etc/kubernetes/enc/enc.yaml` so that new Secrets are written encrypted with the
   `aescbc` provider and key `key1`, while Secrets that are still stored unencrypted remain
   readable. Do not change the key.
2. Make kube-apiserver use the changed configuration. kube-apiserver must be running again
   afterwards.
3. Rewrite all existing Secrets in namespace `vault` so that they are stored encrypted.
4. Read Secret `db-pass` in namespace `vault` directly from etcd and write the prefix of the
   stored value (format `k8s:enc:<provider>:v1:<key name>`) to `/opt/course/e10/prefix.txt`.

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

[↑ 문항 목록](../README.md) · [← q09](../q09_securitycontext_drop_caps_nonprivileged/question.md) · [q11 →](../q11_istio_peerauthentication_strict_basic/question.md)
