# q13 — Configure the ImagePolicyWebhook admission plugin

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Supply Chain Security (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q13_imagepolicywebhook_admission_config
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `cks-c1` 의 `/etc/kubernetes/policywebhook/` 에 미완성 `admission-config.yaml`, 미완성 `kubeconfig.yaml`, 인증서(`ca.crt`, `apiserver-client.crt`, `apiserver-client.key`)가 있다.
`image-checker.local` 백엔드는 존재하지 않는다(이름 해석도 안 된다). kube-apiserver 원본 매니페스트는 `/opt/course/c13/backup/kube-apiserver.yaml` 에 백업되어 있다.
**문제를 마치면 새 Pod 가 하나도 만들어지지 않는 상태가 되므로, 확인 후 반드시 `cleanup.sh` 를 실행한다**(원본 매니페스트를 복구하고 API 서버가 돌아올 때까지 기다린다). `cks-c1` 에 `openssl` 이 필요하다.

## Task

The cluster must only run images approved by an external image scanner reachable at
`https://image-checker.local:8443/check`. Configure the `ImagePolicyWebhook` admission plugin on
the kube-apiserver of `cks-c1`. All configuration files are in `/etc/kubernetes/policywebhook/`.

1. Complete `/etc/kubernetes/policywebhook/admission-config.yaml`: use the kubeconfig file
   `/etc/kubernetes/policywebhook/kubeconfig.yaml`, cache allowed responses for `100` seconds and
   denied responses for `50` seconds, use a retry backoff of `500` milliseconds, and **deny** Pods
   when the backend cannot be reached.
2. Complete `/etc/kubernetes/policywebhook/kubeconfig.yaml` so that the backend server is
   `https://image-checker.local:8443/check`, verified with `ca.crt`, and the API server
   authenticates with `apiserver-client.crt` / `apiserver-client.key` from the same directory.
3. Enable the `ImagePolicyWebhook` admission plugin (keep the plugins that are already enabled) and
   point the kube-apiserver to the admission configuration file. Make sure the kube-apiserver
   can read the files.
4. The kube-apiserver must be running again. Try
   `kubectl run c13-test --image=nginx:1.27-alpine` and write the complete error message to
   `/opt/course/c13/denied.txt`. Leave the plugin enabled.

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

[↑ 문항 목록](../README.md) · [← q12](../q12_dockerfile_distroless_nonroot_build/question.md) · [q14 →](../q14_trivy_config_misconfig_fix/question.md)
