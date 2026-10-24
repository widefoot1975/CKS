# q02 — Fix kube-bench findings for etcd and the worker kubelet · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> A CIS benchmark review found problems on the etcd member of control plane `cks-c1` and on the
> kubelet of worker node `cks-c1-w1`. `kube-bench` is installed on both nodes.
>
> 1. On `cks-c1`, run `kube-bench run --targets master,etcd` and fix these findings:
>    - etcd must require client certificate authentication (`--client-cert-auth=true`).
>    - The etcd data directory must have permissions `700` or more restrictive.
> 2. On worker node `cks-c1-w1`, fix the kubelet: the read-only port must be disabled through
>    `/var/lib/kubelet/config.yaml` (`readOnlyPort: 0`), and the file
>    `/var/lib/kubelet/config.yaml` must have permissions `600`. Restart the kubelet.
> 3. Run kube-bench again and save on `cks-c1` the complete output of
>    `kube-bench run --targets master,etcd` (run on `cks-c1`) to `/opt/course/b02/cp.txt` and of
>    `kube-bench run --targets node` (run on `cks-c1-w1`) to `/opt/course/b02/node.txt`. The checks
>    for the four items above must show `[PASS]`.
> 4. Both nodes must be `Ready`, the kube-apiserver must be healthy and nothing may listen on TCP
>    port `10255` on `cks-c1-w1`.

**해석**

CIS 점검에서 컨트롤 플레인 `cks-c1` 의 etcd 와 워커 `cks-c1-w1` 의 kubelet 에 문제가 발견됐다. 두 노드에 kube-bench 가 있다.

1. `cks-c1` 에서 `kube-bench run --targets master,etcd` 를 돌리고 고친다. etcd 는 클라이언트 인증서 인증을 요구해야 하고
   (`--client-cert-auth=true`), etcd 데이터 디렉터리 권한은 `700` 이하여야 한다.
2. 워커에서 kubelet 의 read-only 포트를 `/var/lib/kubelet/config.yaml` 의 `readOnlyPort: 0` 으로 끄고, 그 파일 권한을 `600` 으로 한다.
   kubelet 을 재시작한다.
3. 다시 kube-bench 를 돌려 `cks-c1` 의 `/opt/course/b02/cp.txt`(master,etcd) 와 `/opt/course/b02/node.txt`(워커의 node) 에 전체 출력을
   저장한다. 위 네 항목은 `[PASS]` 여야 한다.
4. 두 노드 `Ready`, apiserver 정상, 워커의 10255 포트는 닫혀 있어야 한다.

## 모범 풀이

**1) 현재 상태 확인 (cks-c1)**

```bash
sudo -i
kube-bench run --targets master,etcd | grep -E '^\[(FAIL|WARN)\]' | grep -Ei 'etcd|client-cert'
# [FAIL] 1.1.11 Ensure that the etcd data directory permissions are set to 700 or more restrictive (Automated)
# [FAIL] 1.1.12 Ensure that the etcd data directory ownership is set to etcd:etcd (Automated)
# [FAIL] 2.2 Ensure that the --client-cert-auth argument is set to true (Automated)
```

번호는 kube-bench 가 고른 CIS 프로필(예: cis-1.10)마다 다를 수 있으니 **문구로** 찾습니다. kube-bench 가
`unable to determine benchmark version` 처럼 버전 매핑 오류를 내면 `kube-bench run --help` 의 `--benchmark` 로 최신 프로필
(`--benchmark cis-1.10` 등)을 직접 지정합니다.

> 함정 1: 데이터 디렉터리 권한(1.1.11)은 `etcd` 타깃이 아니라 **`master` 타깃(1.1.x, 컨트롤 플레인 파일)** 에 있습니다. `--targets etcd`
> 만 돌리면 이 FAIL 이 보이지 않습니다.

**2) etcd 고치기 — static pod 매니페스트**

```bash
cp /etc/kubernetes/manifests/etcd.yaml /root/etcd.yaml.bak          # 백업은 manifests 디렉터리 밖에!
grep -n 'cert-auth' /etc/kubernetes/manifests/etcd.yaml
#    - --client-cert-auth=false
#    - --peer-client-cert-auth=true
sed -i 's/- --client-cert-auth=false/- --client-cert-auth=true/' /etc/kubernetes/manifests/etcd.yaml
chmod 700 /var/lib/etcd
ls -ld /var/lib/etcd                                                 # drwx------ root root
```

> 함정 2: 백업을 `/etc/kubernetes/manifests/etcd.yaml.bak` 처럼 같은 디렉터리에 두면 kubelet 이 **두 번째 static pod** 로 읽으려 합니다
> (확장자가 무엇이든 디렉터리의 파일을 모두 매니페스트로 시도). 백업은 항상 다른 디렉터리에 둡니다.

kubelet 이 매니페스트 변경을 감지하면 etcd 컨테이너를 다시 만들고, 그동안 apiserver 는 etcd 에 연결하지 못해 잠시 응답하지 않습니다.

```bash
watch crictl ps --name 'etcd|kube-apiserver'          # etcd 의 CREATED 가 방금으로 바뀌는지
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; echo apiserver ok
# 안 뜨면: ls -t /var/log/pods/kube-system_etcd-cks-c1_*/etcd/ ; tail 로그 → 오타면 백업으로 복구
#          cp /root/etcd.yaml.bak /etc/kubernetes/manifests/etcd.yaml
```

데이터 디렉터리는 hostPath 로 마운트되므로 호스트에서 `chmod` 하면 바로 반영되고 etcd 재시작은 필요 없습니다. kubeadm 은 etcd 를 root 로
실행하므로 `etcd` 사용자가 없어 1.1.12(소유자 `etcd:etcd`)는 kubeadm 클러스터에서 보통 FAIL 로 남습니다. 이번 과제 범위가 아니고,
억지로 `chown` 할 대상 사용자도 없습니다.

**3) 워커 kubelet 고치기**

```bash
ssh cks-c1-w1
sudo -i
grep -n readOnlyPort /var/lib/kubelet/config.yaml              # readOnlyPort: 10255
sed -i 's/^readOnlyPort:.*/readOnlyPort: 0/' /var/lib/kubelet/config.yaml
chmod 600 /var/lib/kubelet/config.yaml
# 플래그가 설정 파일보다 우선하므로 오버라이드가 없는지 확인
grep -rn 'read-only-port' /etc/systemd/system/kubelet.service.d/ /var/lib/kubelet/kubeadm-flags.env /etc/default/kubelet 2>/dev/null
systemctl restart kubelet
systemctl is-active kubelet
ss -ltnp | grep -E ':10255|:10250'                             # 10250 만 남아야 한다
```

| 설정 위치 | 우선순위 | 비고 |
|---|---|---|
| kubelet 명령행 플래그(`--read-only-port`, `KUBELET_EXTRA_ARGS`) | 높음 | 설정 파일 값을 덮어쓴다(대부분 deprecated 경고) |
| `/var/lib/kubelet/config.yaml` (`KubeletConfiguration`) | 낮음 | `readOnlyPort` 생략 시 기본값 `0` |

read-only 포트(10255)는 **인증·인가 없이** `/pods`, `/metrics` 등을 노출하므로 꺼야 합니다. 인증되는 포트는 10250 입니다.

**4) 다시 점검하고 저장 (cks-c1 에서)**

```bash
exit; exit                                                          # cks-c1 로 돌아온다
sudo -i
kube-bench run --targets master,etcd > /opt/course/b02/cp.txt
ssh cks-c1-w1 sudo kube-bench run --targets node > /opt/course/b02/node.txt
grep -E 'client-cert-auth|data directory permissions' /opt/course/b02/cp.txt
# [PASS] 1.1.11 Ensure that the etcd data directory permissions are set to 700 or more restrictive
# [PASS] 2.2 Ensure that the --client-cert-auth argument is set to true
grep -E 'read-only-port|config.yaml configuration file is being used validate permissions' /opt/course/b02/node.txt
# [PASS] 4.1.9 If the kubelet config.yaml configuration file is being used validate permissions set to 600 or more restrictive
# [PASS] 4.2.4 Verify that the --read-only-port argument is set to 0
```

## 검증

```bash
kubectl get nodes                                             # 둘 다 Ready
kubectl get --raw='/readyz?verbose' | tail -2                 # readyz check passed
kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep client-cert
ssh cks-c1-w1 'sudo ss -ltn | grep 10255 || echo 10255 closed'
ssh cks-c1-w1 'sudo stat -c "%a %n" /var/lib/kubelet/config.yaml'   # 600
curl -s -m 3 http://<워커IP>:10255/pods || echo refused             # 연결 거부
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: static pod 고치기 = 백업(매니페스트 디렉터리 밖) → 편집 → `crictl ps`·`/var/log/pods` 로 재기동 확인 → `/readyz`. kubelet 고치기 = config.yaml 편집 → 플래그 오버라이드 확인 → `systemctl restart kubelet`.
- **헷갈리는 지점**: `--client-cert-auth` 와 `--peer-client-cert-auth` 는 다른 플래그입니다(`sed` 패턴이 둘 다 건드리지 않게). 파일 권한·소유자 점검은 kube-bench 의 1.1.x(컨트롤 플레인 파일)·4.1.x(워커 파일)에, 프로세스 인자 점검은 2.x(etcd)·4.2.x(kubelet)에 있습니다. `config.yaml` 은 600 으로 줄여도 root 로 도는 kubelet 이 읽을 수 있어 문제없습니다.

## 참고 문서

kube-bench 는 허용 문서가 아니므로 `kube-bench run --help` 로 `--targets`, `--check`, `--benchmark` 를 확인합니다.

- 검색어: `kubelet config file`, `kubelet authentication authorization`, `static pod`, `operating etcd`
- https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/
- https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/
- https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/
- https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
- https://etcd.io/docs/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q03 →](../q03_verify_platform_binaries_sha512/question.md)
