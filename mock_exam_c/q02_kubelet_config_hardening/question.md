# q02 — Harden the worker kubelet configuration

| Item | Value |
|---|---|
| Exam | mock_exam_c |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q02_kubelet_config_hardening
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 `cks-c1-w1` 의 `/var/lib/kubelet/config.yaml` 은 익명 접근 허용(`anonymous.enabled: true`), webhook 인증 끔, `authorization.mode: AlwaysAllow`,
`readOnlyPort: 10255`, `rotateCertificates: false` 로 바뀌어 있고 kubelet 이 이 설정으로 다시 시작되어 있다. 원본은 워커의 `/opt/course/c02/backup/config.yaml` 에 있다.
지금은 `cks-c1` 에서 `curl -sk https://<워커 IP>:10250/pods` 가 인증 없이 Pod 목록을 돌려준다.

## Task

The kubelet on worker node `cks-c1-w1` was reconfigured insecurely. Work on `cks-c1-w1`
(`ssh cks-c1-w1`, then `sudo -i`) and change only the kubelet config file
`/var/lib/kubelet/config.yaml`; do not add kubelet command-line flags.

1. Disable anonymous authentication and enable webhook authentication. Keep the existing
   `x509.clientCAFile`.
2. Set the authorization mode to `Webhook`.
3. Disable the read-only port (`10255`).
4. Enable client certificate rotation.
5. Do **not** set `protectKernelDefaults`.
6. Restart the kubelet. Node `cks-c1-w1` must be `Ready` again and `kubectl logs` / `kubectl exec`
   to Pods on that node must keep working.
7. On `cks-c1`, write two lines to `/opt/course/c02/check.txt`:
   - line 1: the HTTP status code of an unauthenticated `curl -sk https://<InternalIP of cks-c1-w1>:10250/pods`
   - line 2: `open` or `closed` — whether TCP port `10255` on `cks-c1-w1` still answers

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

[↑ 문항 목록](../README.md) · [← q01](../q01_networkpolicy_ingress_controller_only/question.md) · [q03 →](../q03_ingress_tls_fix_secret_host/question.md)
