# q02 — Fix CIS file permission findings with kube-bench · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> A CIS benchmark run on the control plane node `cks-c1` reports permission problems on
> configuration files.
>
> 1. Run `kube-bench` against the control plane components (`master` target) and write every
>    `[FAIL]` line of section `1.1` to `/opt/course/f02/before.txt`.
> 2. Fix the findings that concern file permissions: the four static Pod manifests in
>    `/etc/kubernetes/manifests/` must have permissions `600` and the etcd data directory must have
>    permissions `700`. Do not change file contents or ownership.
> 3. Run `kube-bench` again and write the `[PASS]` lines of the checks for the four manifest files and
>    the etcd data directory permissions to `/opt/course/f02/after.txt`.

**해석**

컨트롤 플레인 노드 `cks-c1` 에서 CIS 벤치마크를 돌리면 설정 파일 권한 문제가 보고된다.

1. 컨트롤 플레인 구성요소(`master` 타깃)에 대해 `kube-bench` 를 실행하고, `1.1` 절의 `[FAIL]` 줄을 모두 `/opt/course/f02/before.txt` 에 쓴다.
2. 파일 권한에 관한 항목을 고친다. `/etc/kubernetes/manifests/` 의 static Pod 매니페스트 네 개는 `600`, etcd 데이터 디렉터리는 `700` 이어야 한다.
   파일 내용이나 소유자는 바꾸지 않는다.
3. `kube-bench` 를 다시 실행하고, 매니페스트 네 개와 etcd 데이터 디렉터리 권한 항목의 `[PASS]` 줄을 `/opt/course/f02/after.txt` 에 쓴다.

## 모범 풀이

**1) 처음 실행 — FAIL 확인**

```bash
sudo -i
kube-bench run --targets master | grep '^\[FAIL\] 1\.1\.' | tee /opt/course/f02/before.txt
# [FAIL] 1.1.1 Ensure that the API server pod specification file permissions are set to 600 or more restrictive (Automated)
# [FAIL] 1.1.3 Ensure that the controller manager pod specification file permissions are set to 600 or more restrictive (Automated)
# [FAIL] 1.1.5 Ensure that the scheduler pod specification file permissions are set to 600 or more restrictive (Automated)
# [FAIL] 1.1.7 Ensure that the etcd pod specification file permissions are set to 600 or more restrictive (Automated)
# [FAIL] 1.1.11 Ensure that the etcd data directory permissions are set to 700 or more restrictive (Automated)
# [FAIL] 1.1.12 Ensure that the etcd data directory ownership is set to etcd:etcd (Automated)
```

쿠버네티스 버전을 벤치마크에 매핑하지 못한다는 오류가 나면 `ls /etc/kube-bench/cfg/` 로 있는 벤치마크를 보고
`kube-bench run --targets master --benchmark cis-1.10` 처럼 직접 지정합니다. 각 FAIL 아래 `== Remediations master ==` 절에
고치는 명령(`chmod 600 ...`)이 그대로 적혀 있으므로 시험에서도 출력부터 읽습니다.

**2) 권한 고치기**

```bash
ls -l /etc/kubernetes/manifests/          # -rw-r--r-- (644) 네 개
grep -- --data-dir /etc/kubernetes/manifests/etcd.yaml   # --data-dir=/var/lib/etcd
chmod 600 /etc/kubernetes/manifests/*.yaml
chmod 700 /var/lib/etcd
stat -c '%a %U:%G %n' /etc/kubernetes/manifests/*.yaml /var/lib/etcd
# 600 root:root /etc/kubernetes/manifests/etcd.yaml
# ...
# 700 root:root /var/lib/etcd
```

권한만 바꾸면 kubelet 은 static Pod 를 다시 만들지 않습니다(파일 내용이 그대로라서). 그래서 이 작업은 컨트롤 플레인에 영향이 없습니다.
데이터 디렉터리는 매니페스트의 `--data-dir` 값으로 확인합니다. 클러스터마다 경로가 다를 수 있습니다.

| 항목 | 대상 | 기대값 |
|---|---|---|
| 1.1.1 / 1.1.3 / 1.1.5 / 1.1.7 | `kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`, `etcd.yaml` | `600` 이하 |
| 1.1.2 / 1.1.4 / 1.1.6 / 1.1.8 | 같은 파일의 소유자 | `root:root` |
| 1.1.11 | etcd 데이터 디렉터리 권한 | `700` 이하 |
| 1.1.12 | etcd 데이터 디렉터리 소유자 | `etcd:etcd` |

**3) 다시 실행 — PASS 확인**

```bash
kube-bench run --targets master | grep -E '^\[PASS\] 1\.1\.(1|3|5|7|11) ' | tee /opt/course/f02/after.txt
# [PASS] 1.1.1 Ensure that the API server pod specification file permissions are set to 600 or more restrictive (Automated)
# [PASS] 1.1.3 ...
# [PASS] 1.1.5 ...
# [PASS] 1.1.7 ...
# [PASS] 1.1.11 Ensure that the etcd data directory permissions are set to 700 or more restrictive (Automated)
```

1.1.12(소유자 `etcd:etcd`)는 kubeadm 노드에 `etcd` 사용자가 없어 원래 FAIL 입니다. 문제에서 소유자는 바꾸지 말라고 했으므로 남겨 둡니다.

## 검증

```bash
stat -c '%a %n' /etc/kubernetes/manifests/*.yaml /var/lib/etcd      # 600 ×4, 700
kube-bench run --targets master --check 1.1.1,1.1.3,1.1.5,1.1.7,1.1.11 | grep -E '^\[(PASS|FAIL)\]'
kubectl get --raw=/readyz; echo                                      # ok
cat /opt/course/f02/before.txt /opt/course/f02/after.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: static Pod 매니페스트 `600 root:root`, etcd 데이터 디렉터리 `700`. kube-bench 출력의 Remediation 절이 정답 명령이다.
- **헷갈리는 지점**: `--targets` 값은 `master`, `node`, `etcd`, `controlplane`, `policies` 입니다. 파일 권한 항목(1.1.x)은 `master` 타깃에 있고, `--check 1.1.1,1.1.11` 처럼 특정 항목만 다시 돌릴 수 있습니다. `[WARN]` 은 수동 확인 항목입니다. 문제에서 바꾸라고 한 것만 바꾸고, `chmod -R` 로 데이터 디렉터리 안의 파일까지 건드리지 않습니다.

## 참고 문서

시험 중에는 kube-bench 문서를 열 수 없으므로 `kube-bench run --help` 로 플래그를 확인합니다.

- 검색어: `securing a cluster`, `kubeadm static pod`
- https://kubernetes.io/docs/tasks/administer-cluster/securing-a-cluster/
- https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q03 →](../q03_ingress_tls_wrong_secret_name/question.md)
