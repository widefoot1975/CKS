# q06 — Sign a user certificate with a CSR and build a kubeconfig

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q06_csr_approve_user_kubeconfig
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `/opt/course/f06/` 에 사용자 `jane` 의 개인 키 `jane.key` 와 인증서 서명 요청 `jane.csr`(CN `jane`)이 있다. namespace `dev` 에는 Pod `hello` 와, 사용자 `jane` 에게 Pod 조회를 허용하는 Role·RoleBinding 이 이미 있다. CertificateSigningRequest `jane` 은 아직 없다.

## Task

A new developer `jane` needs access to namespace `dev` with a client certificate signed by the
cluster CA.

1. Create a CertificateSigningRequest named `jane` from `/opt/course/f06/jane.csr`. Use the signer
   for kube-apiserver client certificates, the usage `client auth` and an expiration of `86400`
   seconds.
2. Approve the request and save the issued certificate (PEM) to `/opt/course/f06/jane.crt`.
3. Create the kubeconfig file `/opt/course/f06/jane.kubeconfig` with a cluster `kubernetes` (same
   API server URL and CA as the admin kubeconfig), a user `jane` using `jane.crt` and `jane.key`
   (embed all certificate data), and a context `jane@kubernetes` with default namespace `dev`.
   Make it the current context.
4. Run `kubectl --kubeconfig /opt/course/f06/jane.kubeconfig get pods` and write the output to
   `/opt/course/f06/pods.txt`.

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

[↑ 문항 목록](../README.md) · [← q05](../q05_sa_default_automount_off_dedicated_sa/question.md) · [q07 →](../q07_apparmor_complain_to_enforce/question.md)
