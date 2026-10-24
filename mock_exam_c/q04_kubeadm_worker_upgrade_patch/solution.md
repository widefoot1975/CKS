# q04 — Upgrade the worker node with kubeadm · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Node `cks-c1-w1` must run the same Kubernetes patch version as the control plane `cks-c1`.
>
> 1. Determine the exact version of `kubeadm` and `kubelet` on the control plane node `cks-c1`.
> 2. Upgrade `kubeadm`, `kubelet` and `kubectl` on worker node `cks-c1-w1` (`ssh cks-c1-w1`, `sudo -i`)
>    to exactly that version using the official `pkgs.k8s.io` apt repository, and run the kubeadm
>    node upgrade.
> 3. Drain `cks-c1-w1` before the kubelet is upgraded. The standalone Pod `upg/scratch` may be
>    deleted. Mark the three packages as held again when you are done.
> 4. Restart the kubelet and make `cks-c1-w1` schedulable again. Both replicas of Deployment
>    `upg/canary` must be `Running`.
> 5. Write the output of `kubectl get nodes` to `/opt/course/c04/nodes-after.txt` on `cks-c1`.

**해석**

노드 `cks-c1-w1` 은 컨트롤 플레인 `cks-c1` 과 같은 패치 버전이어야 한다.

1. 컨트롤 플레인 `cks-c1` 의 `kubeadm`·`kubelet` 정확한 버전을 확인한다.
2. 워커 `cks-c1-w1` 에서 공식 `pkgs.k8s.io` apt 저장소로 `kubeadm`·`kubelet`·`kubectl` 을 그 버전으로 올리고 kubeadm 노드 업그레이드를 실행한다.
3. kubelet 을 올리기 전에 `cks-c1-w1` 을 drain 한다. 단독 Pod `upg/scratch` 는 지워져도 된다. 끝나면 세 패키지를 다시 hold 한다.
4. kubelet 을 재시작하고 노드를 다시 스케줄 가능하게 한다. `upg/canary` 의 두 레플리카가 `Running` 이어야 한다.
5. `cks-c1` 에서 `kubectl get nodes` 출력을 `/opt/course/c04/nodes-after.txt` 에 쓴다.

## 모범 풀이

**1) 목표 버전 확인 (cks-c1)**

```bash
kubeadm version -o short          # v1.35.2  (예시)
kubelet --version                 # Kubernetes v1.35.2
kubectl get nodes                 # VERSION 열 = 각 노드의 kubelet 버전
```

**2) 워커에서 kubeadm 업그레이드 → `kubeadm upgrade node`**

```bash
ssh cks-c1-w1
sudo -i
cat /etc/apt/sources.list.d/kubernetes.list
# deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /
```

pkgs.k8s.io 는 **마이너 버전마다 저장소가 따로**입니다. 워커가 한 마이너 낮다면 경로의 `v1.34` 를 `v1.35` 로 바꿔야 새 버전이 보입니다.

```bash
sed -i 's#/v1\.[0-9]*/deb/#/v1.35/deb/#' /etc/apt/sources.list.d/kubernetes.list
# 키가 없거나 만료되었으면 같은 마이너 경로에서 다시 받는다
# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
apt-get update
apt-cache madison kubeadm | head -3          # 1.35.2-1.1 ...

apt-mark unhold kubeadm
apt-get install -y kubeadm='1.35.2-1.1'
apt-mark hold kubeadm
kubeadm version -o short                     # v1.35.2

kubeadm upgrade node                         # 워커: kubelet 설정(/var/lib/kubelet/config.yaml) 갱신
```

**3) drain (cks-c1 에서)**

```bash
kubectl drain cks-c1-w1 --ignore-daemonsets --delete-emptydir-data --force
```

| 옵션 | 없으면 |
|---|---|
| `--ignore-daemonsets` | Cilium 등 DaemonSet Pod 때문에 거부 |
| `--delete-emptydir-data` | emptyDir 를 쓰는 `canary` Pod 때문에 거부(데이터가 사라진다는 경고) |
| `--force` | 컨트롤러가 없는 단독 Pod `scratch` 때문에 거부 — 이 Pod 는 다시 만들어지지 않는다 |

**4) kubelet·kubectl 업그레이드와 재시작 (워커)**

```bash
apt-mark unhold kubelet kubectl
apt-get install -y kubelet='1.35.2-1.1' kubectl='1.35.2-1.1'
apt-mark hold kubelet kubectl
systemctl daemon-reload
systemctl restart kubelet
apt-mark showhold                            # kubeadm kubectl kubelet
exit; exit
```

**5) uncordon 과 기록 (cks-c1)**

```bash
kubectl uncordon cks-c1-w1
kubectl get nodes | tee /opt/course/c04/nodes-after.txt
# NAME        STATUS   ROLES           AGE   VERSION
# cks-c1      Ready    control-plane   ...   v1.35.2
# cks-c1-w1   Ready    <none>          ...   v1.35.2
kubectl -n upg rollout status deploy canary
```

drain 동안 `canary` Pod 는 Pending 이 됩니다. 컨트롤 플레인에 `node-role.kubernetes.io/control-plane:NoSchedule` taint 가 있어서
갈 곳이 없기 때문이고, uncordon 하면 다시 워커에 배치됩니다.

버전 정책(버전 skew): kubelet 은 kube-apiserver 보다 **새로우면 안 되고**, 최대 3 마이너까지 낮을 수 있습니다. 그래서 항상 컨트롤
플레인을 먼저 올리고 워커를 나중에, 마이너는 한 단계씩 올립니다. 보안 패치(CVE 수정) 반영이 이 문제의 목적입니다.

## 검증

```bash
kubectl get node cks-c1-w1 -o jsonpath='{.status.nodeInfo.kubeletVersion}{"\n"}'   # 컨트롤 플레인과 같은 값
kubectl get node cks-c1-w1 -o jsonpath='{.spec.unschedulable}{"\n"}'                # 빈 값
kubectl -n upg get pod -o wide                                                      # canary 2개 Running, scratch 없음
ssh cks-c1-w1 'apt-mark showhold; kubeadm version -o short'
cat /opt/course/c04/nodes-after.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 워커 순서 = repo 마이너 맞추기 → kubeadm(unhold/install/hold) → `kubeadm upgrade node` → drain → kubelet·kubectl → `daemon-reload` + `restart kubelet` → uncordon.
- **헷갈리는 지점**: 워커에서는 `kubeadm upgrade apply` 가 아니라 `kubeadm upgrade node` 입니다. `apt-mark hold` 를 풀지 않으면 설치가 "held packages" 로 거부되고, 저장소 마이너를 안 바꾸면 `madison` 에 새 버전이 안 나옵니다. drain 은 컨트롤 플레인(kubectl 이 있는 곳)에서 실행합니다.

## 참고 문서

- 검색어: `upgrading kubeadm clusters`, `upgrade linux nodes`, `version skew policy`, `changing the kubernetes package repository`
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/
- https://kubernetes.io/releases/version-skew-policy/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q05 →](../q05_rbac_dangerous_verbs_escalate_bind/question.md)
