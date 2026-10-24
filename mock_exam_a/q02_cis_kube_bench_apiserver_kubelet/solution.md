# q02 — Fix kube-bench findings on the API server and the kubelet · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> A CIS benchmark run is required on cluster `cks-c1`. Use `kube-bench` (already installed on
> both nodes).
>
> 1. On `cks-c1`, run the `master` target of `kube-bench` and save the complete output to
>    `/opt/course/a02/master-before.txt`.
> 2. Fix these failing kube-apiserver checks: profiling must be disabled, and the
>    authorization mode must not contain `AlwaysAllow` and must be exactly `Node,RBAC`.
> 3. On worker node `cks-c1-w1`, run the `node` target and fix these failing kubelet checks in
>    the kubelet configuration file (not with command-line flags): anonymous authentication
>    must be disabled and the authorization mode must be `Webhook`.
> 4. Run both targets again. Save the output of the `master` run to
>    `/opt/course/a02/master-after.txt` and of the `node` run to
>    `/opt/course/a02/node-after.txt`, both on `cks-c1`. The four checks above must be `[PASS]`.
> 5. Both nodes must be `Ready` and all `kube-system` Pods must be running when you finish.

**해석**

클러스터 `cks-c1` 에 CIS 벤치마크 점검이 필요하다. 두 노드에 설치된 `kube-bench` 를 쓴다.

1. `cks-c1` 에서 kube-bench 의 `master` 타깃을 실행하고 전체 출력을 `/opt/course/a02/master-before.txt` 에 저장한다.
2. kube-apiserver 의 실패 항목을 고친다. profiling 은 꺼야 하고, 인가 모드에는 `AlwaysAllow` 가 없어야 하며 정확히 `Node,RBAC` 여야 한다.
3. 워커 `cks-c1-w1` 에서 `node` 타깃을 실행하고 kubelet 실패 항목을 **설정 파일에서**(플래그 말고) 고친다. 익명 인증은 꺼야 하고 인가 모드는 `Webhook` 이어야 한다.
4. 두 타깃을 다시 실행해 `master` 결과는 `/opt/course/a02/master-after.txt`, `node` 결과는 `/opt/course/a02/node-after.txt` 에 (둘 다 `cks-c1` 에) 저장한다. 위 네 항목이 `[PASS]` 여야 한다.
5. 끝났을 때 두 노드는 `Ready`, `kube-system` 의 모든 Pod 는 실행 중이어야 한다.

## 모범 풀이

**1) 첫 실행 — FAIL 항목 찾기**

```bash
kube-bench run --targets master > /opt/course/a02/master-before.txt
grep -E '^\[FAIL\]' /opt/course/a02/master-before.txt | grep -Ei 'profiling|authorization-mode'
# [FAIL] 1.2.7 Ensure that the --authorization-mode argument is not set to AlwaysAllow (Automated)
# [FAIL] 1.2.15 Ensure that the --profiling argument is set to false (Automated)
```

항목 번호는 kube-bench 가 고른 CIS 벤치마크 버전마다 다르므로 **설명 문장으로 찾습니다**. kube-bench 가
`unable to determine benchmark version` 처럼 클러스터 버전을 매핑하지 못하면 `ls /etc/kube-bench/cfg` 로 가장 새 벤치마크를 보고
`--benchmark cis-1.10` 처럼 직접 지정합니다. 각 FAIL 아래 `== Remediations master ==` 절에 고치는 방법이 그대로 적혀 있습니다.

**2) kube-apiserver — 백업 → 수정 → 재기동 확인**

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak   # manifests 디렉터리 밖에 백업!
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --authorization-mode=Node,RBAC      # AlwaysAllow 제거
    - --profiling=false                   # true → false
```

```bash
watch crictl ps --name kube-apiserver          # 컨테이너 ID 가 바뀌고 Running 이 될 때까지 (30~60초)
kubectl get --raw=/readyz                      # ok
# 안 뜨면: 원인 확인 후 백업으로 복구
ls /var/log/pods/ | grep kube-apiserver
tail -n 20 /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log
crictl ps -a --name kube-apiserver; crictl logs <container-id>
# cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

백업을 `/etc/kubernetes/manifests/` 안에 두면 kubelet 이 그 파일도 static Pod 로 띄우려 해서 apiserver 가 두 개 뜨거나 충돌합니다.
`AlwaysAllow` 가 뒤에 붙어 있으면 Node·RBAC 이 "의견 없음" 을 낸 **모든 요청을 허용**하므로, 익명 사용자까지 사실상 cluster-admin 입니다.
겉보기에는 `Node,RBAC` 가 있어서 놓치기 쉽습니다.

**3) 워커 kubelet — 설정 파일 수정**

```bash
ssh cks-c1-w1
sudo -i
kube-bench run --targets node | grep -E '^\[FAIL\]' | grep -Ei 'anonymous|authorization'
# [FAIL] 4.2.1 Ensure that the --anonymous-auth argument is set to false (Automated)
# [FAIL] 4.2.2 Ensure that the --authorization-mode argument is not set to AlwaysAllow (Automated)
ps -ef | grep [k]ubelet | tr ' ' '\n' | grep -E -- '--config|--anonymous|--authorization'   # 플래그가 설정 파일을 덮어쓰지 않는지
cp /var/lib/kubelet/config.yaml /root/kubelet-config.yaml.bak
vim /var/lib/kubelet/config.yaml
```

```yaml
authentication:
  anonymous:
    enabled: false        # true → false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook           # AlwaysAllow → Webhook
```

```bash
systemctl restart kubelet
systemctl status kubelet --no-pager | head -5         # active (running)
journalctl -u kubelet -n 20 --no-pager                 # 설정 파싱 오류가 없는지
exit; exit
```

kubelet 은 플래그가 설정 파일보다 우선합니다. 그래서 먼저 `--anonymous-auth` 같은 플래그가 kubelet 명령줄(또는
`/var/lib/kubelet/kubeadm-flags.env`, systemd drop-in)에 없는지 확인합니다. 문제는 **설정 파일** 수정을 요구합니다.

| 위치 | 대상 | 바꾸는 법 | 반영 |
|---|---|---|---|
| `/etc/kubernetes/manifests/kube-apiserver.yaml` | apiserver 플래그 | 파일 수정 | kubelet 이 자동 재생성 |
| `/var/lib/kubelet/config.yaml` | kubelet 설정 | 파일 수정 | `systemctl restart kubelet` 필요 |
| `/var/lib/kubelet/kubeadm-flags.env` | kubelet 플래그 | 파일 수정 | 재시작 필요, 설정 파일보다 우선 |

**4) 재실행 결과 저장**

```bash
kube-bench run --targets master > /opt/course/a02/master-after.txt
ssh cks-c1-w1 sudo kube-bench run --targets node > /opt/course/a02/node-after.txt
grep -Ei 'profiling|authorization-mode' /opt/course/a02/master-after.txt | grep -E '^\[(PASS|FAIL)\]'
grep -Ei 'anonymous-auth|authorization-mode' /opt/course/a02/node-after.txt | grep -E '^\[(PASS|FAIL)\]'
```

## 검증

```bash
grep -E '^\[PASS\].*(profiling|AlwaysAllow|Node|RBAC)' /opt/course/a02/master-after.txt   # 모두 PASS
grep -E '^\[PASS\].*(anonymous-auth|authorization-mode)' /opt/course/a02/node-after.txt   # 둘 다 PASS
pgrep -af kube-apiserver | tr ' ' '\n' | grep -E 'profiling|authorization-mode'
# --authorization-mode=Node,RBAC
# --profiling=false
W1=$(kubectl get node cks-c1-w1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
curl -sk https://$W1:10250/pods; echo                        # Unauthorized (익명 차단)
kubectl get nodes                                            # 둘 다 Ready
kubectl -n kube-system get pod                               # 모두 Running
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: apiserver 는 static Pod 매니페스트 → 저장하면 자동 재시작. kubelet 은 `/var/lib/kubelet/config.yaml` → `systemctl restart kubelet`. 백업은 manifests 디렉터리 **밖**에.
- **헷갈리는 지점**: kube-bench 번호(1.2.x, 4.2.x)는 벤치마크 버전에 따라 바뀌므로 문구로 찾습니다. kubelet 은 플래그가 설정 파일보다 우선하므로 파일만 고치고 플래그를 남겨 두면 계속 FAIL 입니다. 인가 모드 순서와 상관없이 `AlwaysAllow` 가 하나라도 있으면 사실상 인가가 꺼집니다.

## 참고 문서

kube-bench 문서는 시험 중 열 수 없으므로 `kube-bench run --help`, `kube-bench --help` 와 출력의 Remediations 절을 씁니다.

- 검색어: `kube-apiserver`, `kubelet authentication authorization`, `kubelet config file`
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/
- https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q03 →](../q03_ingress_tls_ssl_redirect/question.md)
