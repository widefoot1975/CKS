# q02 — Fix the kube-bench profiling finding on the API server · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The CIS benchmark tool `kube-bench` is installed on `cks-c1` (configuration in
> `/etc/kube-bench/cfg`).
>
> 1. Run `kube-bench` against the control-plane components only (target `master`) and save the
>    complete output to `/opt/course/d02/before.txt`.
> 2. Fix the failing check `Ensure that the --profiling argument is set to false` for the
>    **kube-apiserver** only. Do not change the controller manager or the scheduler.
> 3. When the API server is back, run the same `kube-bench` command again and save the output to
>    `/opt/course/d02/after.txt`. The API server profiling check must be `[PASS]`.

**해석**

`cks-c1` 에 CIS 벤치마크 도구 `kube-bench` 가 설치되어 있다(설정은 `/etc/kube-bench/cfg`).

1. 컨트롤 플레인 구성 요소만(target `master`) 대상으로 `kube-bench` 를 실행하고 전체 출력을 `/opt/course/d02/before.txt` 에 저장한다.
2. 실패한 항목 `Ensure that the --profiling argument is set to false` 를 **kube-apiserver** 에 대해서만 고친다.
   controller manager 와 scheduler 는 바꾸지 않는다.
3. API 서버가 다시 뜨면 같은 `kube-bench` 명령을 다시 실행해 `/opt/course/d02/after.txt` 에 저장한다. API 서버 profiling 항목이
   `[PASS]` 여야 한다.

## 모범 풀이

**1) 첫 실행**

```bash
sudo -i
kube-bench run --targets master \
  --config-dir /etc/kube-bench/cfg --config /etc/kube-bench/cfg/config.yaml > /opt/course/d02/before.txt
grep -n -i 'profiling' /opt/course/d02/before.txt
# [FAIL] 1.2.x Ensure that the --profiling argument is set to false (Automated)
# [FAIL] 1.3.x Ensure that the --profiling argument is set to false (Automated)   ← controller-manager
# [FAIL] 1.4.x Ensure that the --profiling argument is set to false (Automated)   ← scheduler
```

항목 번호는 kube-bench 가 고른 CIS 벤치마크 버전에 따라 다르므로 **제목과 섹션**으로 찾습니다. 섹션 1.2 가 API Server,
1.3 이 Controller Manager, 1.4 가 Scheduler 입니다. 같은 제목이 세 번 나오는 것이 이 문제의 함정이고, 고칠 것은 1.2 하나뿐입니다.
출력 아래쪽 `== Remediations master ==` 에 항목별 수정 방법이 그대로 적혀 있습니다.

kube-bench 가 클러스터 버전을 벤치마크에 매핑하지 못한다는 오류를 내면 `ls /etc/kube-bench/cfg` 로 가장 최신 `cis-1.*`
디렉터리를 골라 `--benchmark cis-1.xx` 를 붙입니다. 설정 디렉터리를 못 찾는다는 오류는 `--config-dir` 를 빠뜨렸을 때 납니다.

**2) API 서버 매니페스트 수정 — 백업 먼저**

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak   # manifests 디렉터리 밖에 백업
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --profiling=false            # true → false (줄이 없으면 추가: 기본값이 true)
    - --advertise-address=...
```

```bash
watch crictl ps --name kube-apiserver          # 새 컨테이너 ID 로 바뀌고 Running 이 될 때까지
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; echo API ready
```

kubelet 이 static Pod 매니페스트 변경을 감지해 API 서버를 다시 만듭니다. 1~2분 안에 안 뜨면 로그를 봅니다.

```bash
crictl ps -a --name kube-apiserver                       # Exited 반복이면 플래그 오타
ls /var/log/pods/ | grep kube-apiserver
tail -n 20 /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log
# 복구가 필요하면: cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

백업을 `/etc/kubernetes/manifests/` 안에 두면 kubelet 이 그 파일도 static Pod 로 띄우려 하므로 반드시 밖에 둡니다.

**3) 다시 실행**

```bash
kube-bench run --targets master \
  --config-dir /etc/kube-bench/cfg --config /etc/kube-bench/cfg/config.yaml > /opt/course/d02/after.txt
grep -n -i 'profiling' /opt/course/d02/after.txt
# [PASS] 1.2.x Ensure that the --profiling argument is set to false (Automated)
# [FAIL] 1.3.x ...   ← 문제에서 건드리지 말라고 한 controller-manager
# [FAIL] 1.4.x ...   ← scheduler
```

## 검증

```bash
ps -ef | grep [k]ube-apiserver | tr ' ' '\n' | grep profiling       # --profiling=false
kubectl -n kube-system get pod -l component=kube-apiserver          # Running
grep -c '\[PASS\]' /opt/course/d02/before.txt /opt/course/d02/after.txt   # after 가 1 많다
grep '\] 1\.2\..*profiling' /opt/course/d02/after.txt               # [PASS] 1.2.x ...
grep -- '--profiling' /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/manifests/kube-scheduler.yaml || echo "둘 다 그대로"
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: kube-bench 는 `[FAIL]` 아래 `Remediations` 에 고칠 파일과 플래그를 알려 준다. static Pod 수정은 백업(매니페스트 디렉터리 밖) → 편집 → `crictl ps` / `/var/log/pods` 로 확인.
- **헷갈리는 지점**: `--profiling` 의 기본값은 `true` 라서 kubeadm 매니페스트에 줄이 없어도 FAIL 입니다. 같은 제목의 항목이 apiserver·controller-manager·scheduler 에 하나씩 있으니 섹션 번호를 확인합니다.

## 참고 문서

시험 중에는 kube-bench 문서를 열 수 없으므로 `kube-bench run --help`, `kube-bench --help` 로 확인합니다.

- 검색어: `kube-apiserver`, `static pod`
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q03 →](../q03_verify_kubectl_sha512/question.md)
