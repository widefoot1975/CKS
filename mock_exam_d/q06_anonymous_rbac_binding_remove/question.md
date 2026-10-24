# q06 — Remove an anonymous RBAC binding

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Cluster Hardening (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q06_anonymous_rbac_binding_remove
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 어떤 ClusterRoleBinding 이 익명 사용자 `system:anonymous` 에 ClusterRole `view` 를 주고 있어서, 인증서 없이 `curl -k` 로 API 서버에 요청해도 Pod 목록이 보인다.
API 서버가 `--anonymous-auth=false` 로 설정된 클러스터라면 setup 이 경고를 출력한다(그 경우 익명 요청 자체가 401 이라 이 문제를 재현할 수 없다).

## Task

Someone made the cluster readable without credentials. Do not disable anonymous authentication on
the API server (its health endpoints are used by probes); fix the authorization instead.

1. Send an anonymous request (no client certificate, no token) to
   `https://<API server address>:6443/api/v1/namespaces/default/pods` and write only the HTTP
   status code to `/opt/course/d06/before.txt`.
2. Find the ClusterRoleBinding that grants ClusterRole `view` to `system:anonymous`, write its
   name to `/opt/course/d06/binding.txt` and delete it. Do not delete the kubeadm default
   bindings `system:public-info-viewer` and `kubeadm:bootstrap-signer-clusterinfo`.
3. Send the same anonymous request again and write the HTTP status code to
   `/opt/course/d06/after.txt`.

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

[↑ 문항 목록](../README.md) · [← q05](../q05_sa_automount_false/question.md) · [q07 →](../q07_apparmor_load_apply_pod/question.md)
