# q01 — Allow ingress only from the Ingress controller and restrict egress

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
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_c/q01_networkpolicy_ingress_controller_only
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `shop` 에 Deployment `web`(nginx, 라벨 `app=web`), Service `web`, Ingress `web`(host `shop.cks.local`), 테스트용 Pod `tester` 가 있고,
namespace `default` 에 Pod `outsider` 가 있다. NetworkPolicy 는 하나도 없어서 어디서든 `web` 에 직접 닿는다.
ingress-nginx(`controller-v1.12.1`, baremetal NodePort)가 없으면 setup 이 설치하므로 GitHub·registry.k8s.io 로 인터넷 연결이 필요하다.
ingress-nginx 는 다른 문제에서도 쓰므로 정리할 때 지우지 않는다.

## Task

Namespace `shop` runs Deployment `web` (Pod label `app=web`, container port `80`). It is published
through Service `web` and Ingress `web` (host `shop.cks.local`, IngressClass `nginx`). Today every
Pod in the cluster can reach the `web` Pods directly, and Pods in `shop` can connect anywhere.

1. Create a NetworkPolicy `web-from-ingress` in namespace `shop`. Pods with label `app=web` must
   accept ingress only on TCP port `80`, and only from Pods labeled
   `app.kubernetes.io/name=ingress-nginx` **and** `app.kubernetes.io/component=controller` that run in
   namespace `ingress-nginx`. A Pod with the same labels in any other namespace must not be allowed.
2. Create a NetworkPolicy `shop-egress` in namespace `shop` that selects all Pods in the namespace
   and allows egress only to:
   - the CoreDNS Pods (`k8s-app=kube-dns` in namespace `kube-system`) on UDP and TCP port `53`
   - any IP address on TCP ports `80` and `443`, except `169.254.169.254/32`

   All other egress, including the kubelet port `10250` on the nodes, must be denied.
3. Write three lines to `/opt/course/c01/result.txt`:
   - line 1: the HTTP status code returned by the Ingress for host `shop.cks.local`, requested from
     `cks-c1` through the HTTP NodePort of Service `ingress-nginx/ingress-nginx-controller` on the
     InternalIP of node `cks-c1-w1`
   - line 2: `open` or `blocked` — `curl -m 3 http://web.shop.svc.cluster.local` from Pod `default/outsider`
   - line 3: `open` or `blocked` — `curl -k -m 3 https://<InternalIP of cks-c1-w1>:10250/healthz` from Pod `shop/tester`

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

[↑ 문항 목록](../README.md) · [q02 →](../q02_kubelet_config_hardening/question.md)
