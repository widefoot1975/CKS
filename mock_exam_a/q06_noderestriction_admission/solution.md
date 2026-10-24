# q06 — Re-enable the NodeRestriction admission plugin and prove it · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> A compromised worker node must not be able to modify other nodes. The kubeconfig
> `/opt/course/a06/w1-kubelet.kubeconfig` authenticates as the kubelet of `cks-c1-w1`.
>
> 1. Show the problem: using that kubeconfig, add the label `a06-before=pwned` to node
>    `cks-c1`. Write the command output to `/opt/course/a06/before.txt`. Then remove the label
>    again with the admin kubeconfig.
> 2. Make sure the kube-apiserver runs with the `NodeRestriction` admission plugin enabled.
>    Keep the other admission plugins that are currently enabled.
> 3. Using the kubelet kubeconfig again, try each of the following and write the output
>    (stdout and stderr) of all three commands to `/opt/course/a06/after.txt`:
>    a. add label `a06-after=pwned` to node `cks-c1` (must be forbidden)
>    b. add label `node-restriction.kubernetes.io/zone=evil` to node `cks-c1-w1` (must be forbidden)
>    c. add label `a06-self=ok` to node `cks-c1-w1` (must succeed)

**해석**

탈취된 워커 노드가 다른 노드를 수정할 수 없어야 한다. kubeconfig `/opt/course/a06/w1-kubelet.kubeconfig` 는 `cks-c1-w1` 의 kubelet 으로 인증한다.

1. 문제를 보여 준다. 이 kubeconfig 로 노드 `cks-c1` 에 라벨 `a06-before=pwned` 를 붙이고 출력을 `/opt/course/a06/before.txt` 에 쓴다.
   그런 다음 admin kubeconfig 로 라벨을 다시 지운다.
2. kube-apiserver 가 `NodeRestriction` admission 플러그인을 켠 상태로 돌게 한다. 지금 켜져 있는 다른 플러그인은 유지한다.
3. 다시 kubelet kubeconfig 로 아래 세 가지를 시도하고, 세 명령의 출력(표준출력과 표준에러)을 모두 `/opt/course/a06/after.txt` 에 쓴다.
   a. 노드 `cks-c1` 에 `a06-after=pwned` 라벨 (거부되어야 함)
   b. 노드 `cks-c1-w1` 에 `node-restriction.kubernetes.io/zone=evil` 라벨 (거부되어야 함)
   c. 노드 `cks-c1-w1` 에 `a06-self=ok` 라벨 (성공해야 함)

## 모범 풀이

**1) 구멍 확인**

```bash
KK=/opt/course/a06/w1-kubelet.kubeconfig
kubectl --kubeconfig=$KK auth whoami                    # system:node:cks-c1-w1, 그룹 system:nodes
kubectl --kubeconfig=$KK label node cks-c1 a06-before=pwned > /opt/course/a06/before.txt 2>&1
cat /opt/course/a06/before.txt                          # node/cks-c1 labeled  ← 다른 노드를 바꿀 수 있다!
kubectl label node cks-c1 a06-before-
```

Node authorizer 는 kubelet 이 동작하는 데 필요한 **종류**의 요청(노드 갱신, 자기 Pod 의 Secret 읽기 등)을 허용합니다.
"자기 노드 객체만" 이라는 제한은 admission 단계의 `NodeRestriction` 이 담당하므로, 이것이 꺼지면 한 노드의 kubelet 인증서로
다른 노드의 라벨·taint 를 바꿔 워크로드를 끌어올 수 있습니다.

**2) apiserver 플래그 — enable 과 disable 을 둘 다 본다**

```bash
grep -n admission-plugins /etc/kubernetes/manifests/kube-apiserver.yaml
#    - --disable-admission-plugins=NodeRestriction
#    - --enable-admission-plugins=NamespaceLifecycle,ServiceAccount
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --enable-admission-plugins=NamespaceLifecycle,ServiceAccount,NodeRestriction
    # --disable-admission-plugins=NodeRestriction  ← 이 줄은 삭제
```

```bash
watch crictl ps --name kube-apiserver        # 새 컨테이너가 Running
kubectl get --raw=/readyz; echo              # ok
# 안 뜨면 원인 확인
tail -n 5 /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log
#   ... plugins [NodeRestriction] appear in both --enable-admission-plugins and --disable-admission-plugins
# 복구: cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

enable 목록에만 추가하고 disable 줄을 남기면 apiserver 가 **기동 시 검증 오류로 죽습니다**. 같은 플러그인이 두 목록에 있으면 안 됩니다.
`NamespaceLifecycle`, `ServiceAccount` 는 원래 기본으로 켜지는 플러그인이라 지워도 동작은 같지만, 문제는 기존 값을 유지하라고 했습니다.
`NodeRestriction` 은 **기본으로 켜지지 않으므로**(kubeadm 이 명시적으로 넣음) enable 목록에 꼭 있어야 합니다.

**3) 다시 시도**

```bash
KK=/opt/course/a06/w1-kubelet.kubeconfig
{
  kubectl --kubeconfig=$KK label node cks-c1 a06-after=pwned
  kubectl --kubeconfig=$KK label node cks-c1-w1 node-restriction.kubernetes.io/zone=evil
  kubectl --kubeconfig=$KK label node cks-c1-w1 a06-self=ok
} > /opt/course/a06/after.txt 2>&1
cat /opt/course/a06/after.txt
# Error from server (Forbidden): nodes "cks-c1" is forbidden: node "cks-c1-w1" is not allowed to modify node "cks-c1"
# Error from server (Forbidden): nodes "cks-c1-w1" is forbidden: is not allowed to modify labels: node-restriction.kubernetes.io/zone
# node/cks-c1-w1 labeled
```

| 요청 (kubelet 신원) | NodeRestriction 꺼짐 | 켜짐 |
|---|---|---|
| 다른 노드 라벨·taint 수정 | 허용 | 거부 |
| 자기 노드에 `node-restriction.kubernetes.io/*` 라벨 | 허용 | 거부 |
| 자기 노드에 일반 라벨 | 허용 | 허용 |
| 다른 노드에 바인딩된 Pod 수정·삭제, 미러 Pod 생성 | 허용 | 거부 |

`node-restriction.kubernetes.io/` 접두사 라벨은 관리자만 붙일 수 있으므로, 민감한 워크로드를 특정 노드에 고정할 때 이 접두사의 라벨을
nodeSelector 로 쓰면 탈취된 kubelet 이 스스로를 그 노드로 위장할 수 없습니다.

## 검증

```bash
pgrep -af kube-apiserver | tr ' ' '\n' | grep admission-plugins   # --enable-admission-plugins=...,NodeRestriction (disable 없음)
grep -c Forbidden /opt/course/a06/after.txt                        # 2
grep 'labeled' /opt/course/a06/after.txt                           # node/cks-c1-w1 labeled
kubectl get node cks-c1 --show-labels | grep -c a06                # 0
kubectl get nodes                                                  # 둘 다 Ready
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: Node authorizer(`--authorization-mode=Node,RBAC`) + `NodeRestriction` admission 은 한 쌍이다. 하나만 있으면 kubelet 이 다른 노드를 건드릴 수 있다.
- **헷갈리는 지점**: 플래그는 `--enable-admission-plugins` 와 `--disable-admission-plugins` 를 **함께** 봐야 합니다. 같은 이름이 양쪽에 있으면 apiserver 가 뜨지 않습니다. `kubectl --as system:node:cks-c1-w1` 로 흉내 낼 때는 `--as-group system:nodes` 도 줘야 Node authorizer 가 노드로 인식합니다.

## 참고 문서

- 검색어: `NodeRestriction`, `node authorization`, `admission controllers`
- https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/
- https://kubernetes.io/docs/reference/access-authn-authz/node/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q07 →](../q07_apparmor_profile_deployment/question.md)
