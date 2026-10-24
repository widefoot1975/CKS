# q04 — Certificate user via a CSR with a least-privilege Role

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q04_csr_user_least_privilege_role
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `team-ana` 에는 Deployment `ana-app`(replicas 1)과 Secret `ana-db` 가 있다. 사용자 `dev-ana` 의 키·CSR·인증서·kubeconfig 와 CertificateSigningRequest `dev-ana`, Role·RoleBinding 은 아직 없다. `/opt/course/a04/` 는 비어 있다.

## Task

Developer `dev-ana` needs access to namespace `team-ana` with a client certificate.

1. Create an RSA `2048` private key `/opt/course/a04/dev-ana.key` and a certificate signing
   request `/opt/course/a04/dev-ana.csr` with common name `dev-ana` and organization
   `dev-team`.
2. Create a Kubernetes CertificateSigningRequest `dev-ana` for it that uses signer
   `kubernetes.io/kube-apiserver-client`, usage `client auth` and is valid for `24` hours.
   Approve it and save the issued certificate to `/opt/course/a04/dev-ana.crt`.
3. Create the kubeconfig `/opt/course/a04/dev-ana.kubeconfig` with embedded certificates,
   a context `dev-ana@kubernetes` for user `dev-ana` with default namespace `team-ana`, set as
   current context. It must point to the same API server as the admin kubeconfig.
4. Create a Role `ana-dev` and a RoleBinding `ana-dev` in `team-ana` for user `dev-ana` so
   that she can get, list and watch Pods, get and list Deployments, and change the replica
   count of Deployments with `kubectl scale`. She must not be able to change any other field
   of a Deployment, nor access anything else.
5. Scale Deployment `ana-app` to `2` replicas using her kubeconfig.
6. Using her kubeconfig, answer these with `kubectl auth can-i` and write the answers
   (`yes`/`no`, one per line, in this order) to `/opt/course/a04/can-i.txt`:
   `list pods`, `delete pods`, `update deployments`, `patch deployments` (subresource
   `scale`), `get secrets`, `list pods` in namespace `default`.

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

[↑ 문항 목록](../README.md) · [← q03](../q03_ingress_tls_ssl_redirect/question.md) · [q05 →](../q05_serviceaccount_automount_projected_token/question.md)
