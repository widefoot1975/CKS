# q02 — Disable anonymous access to the kubelet API

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q02_kubelet_anonymous_auth_disable
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 노드 `cks-c1-w1` 의 kubelet 설정 `/var/lib/kubelet/config.yaml` 이 `authentication.anonymous.enabled: true`, `authorization.mode: AlwaysAllow` 로
바뀌어 있어서, 인증서 없이 `curl -sk https://<워커 IP>:10250/pods` 를 호출해도 파드 목록 JSON 이 나온다. 원본은 워커의 `/opt/course/e02/backup/config.yaml` 에 백업되어 있다.

## Task

The kubelet on worker node `cks-c1-w1` answers API requests from anyone.

1. On worker node `cks-c1-w1`, change the kubelet configuration so that anonymous requests
   are rejected and requests are authorized by the API server (`Webhook` mode). Apply the
   change.
2. On `cks-c1`, run `curl -sk -o /dev/null -w '%{http_code}' https://<cks-c1-w1 InternalIP>:10250/pods`
   and write the HTTP status code to `/opt/course/e02/status.txt`.
3. `kubectl logs` and `kubectl exec` for Pods on `cks-c1-w1` must keep working, and the node
   must be `Ready`.

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

[↑ 문항 목록](../README.md) · [← q01](../q01_networkpolicy_allow_from_namespace/question.md) · [q03 →](../q03_ingress_tls_basic/question.md)
