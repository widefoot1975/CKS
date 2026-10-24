# q16 — Enable API server auditing with a given policy · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Auditing is not enabled on the API server of this cluster. The audit policy has already been
> written to `/etc/kubernetes/audit/d16-policy.yaml` on `cks-c1`. Do not change the policy.
>
> 1. Configure the kube-apiserver to use this policy and write the audit log to
>    `/var/log/kubernetes/audit/audit.log`, keeping at most `2` rotated log files, each at most
>    `10` MB.
> 2. When the API server is back, create a Secret `audit-probe` in namespace `default` with
>    `kubectl create secret generic audit-probe --from-literal=k=v` and read it once with
>    `kubectl get secret audit-probe`. Write all audit log lines that mention `audit-probe` to
>    `/opt/course/d16/probe.log`.

**해석**

이 클러스터의 API 서버는 감사(audit)를 하지 않는다. 감사 정책은 `cks-c1` 의 `/etc/kubernetes/audit/d16-policy.yaml` 에 이미 있다.
정책은 바꾸지 않는다.

1. kube-apiserver 가 이 정책을 쓰고 감사 로그를 `/var/log/kubernetes/audit/audit.log` 에 쓰도록 설정한다. 회전된 로그 파일은
   최대 `2` 개, 파일 하나는 최대 `10` MB 로 한다.
2. API 서버가 다시 뜨면 `kubectl create secret generic audit-probe --from-literal=k=v` 로 namespace `default` 에 Secret `audit-probe` 를
   만들고 `kubectl get secret audit-probe` 로 한 번 읽는다. `audit-probe` 가 들어 있는 감사 로그 줄을 모두 `/opt/course/d16/probe.log` 에 쓴다.

## 모범 풀이

**1) 정책 확인과 백업**

```bash
sudo -i
cat /etc/kubernetes/audit/d16-policy.yaml       # secrets/configmaps → Metadata, 나머지 None
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak
vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

**2) 플래그 + 볼륨 — 둘 다 필요**

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --audit-policy-file=/etc/kubernetes/audit/d16-policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxbackup=2
    - --audit-log-maxsize=10
    # ... 기존 플래그 ...
    volumeMounts:
    # ... 기존 mount ...
    - mountPath: /etc/kubernetes/audit/d16-policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes/audit/
      name: audit-log
  volumes:
  # ... 기존 volume ...
  - name: audit-policy
    hostPath:
      path: /etc/kubernetes/audit/d16-policy.yaml
      type: File
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit/
      type: DirectoryOrCreate
```

kube-apiserver 는 **컨테이너** 안에서 돌기 때문에 플래그의 경로는 컨테이너 안 경로입니다. kubeadm 매니페스트는
`/etc/kubernetes/pki` 등만 hostPath 로 마운트하므로, 정책 파일과 로그 디렉터리를 마운트하지 않으면 API 서버가
`open /etc/kubernetes/audit/d16-policy.yaml: no such file or directory` 로 바로 죽거나 로그가 컨테이너 안에만 쌓였다가 사라집니다.

| 플래그 | 뜻 |
|---|---|
| `--audit-policy-file` | 정책 파일 (없으면 감사 꺼짐) |
| `--audit-log-path` | 로그 파일 경로 (`-` 면 stdout) |
| `--audit-log-maxbackup` | 회전된 파일 보관 개수 |
| `--audit-log-maxsize` | 회전 기준 크기 (MB) |
| `--audit-log-maxage` | 보관 일수 |

**3) 재시작 지켜보기**

```bash
watch crictl ps --name kube-apiserver
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done; echo API ready
# 안 뜨면:
crictl ps -a --name kube-apiserver
tail -n 20 /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log
journalctl -u kubelet --since "5 min ago" | grep -i apiserver | tail     # 매니페스트 YAML 오류는 kubelet 로그에
# 복구: cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```

**4) 감사 이벤트 확인**

```bash
kubectl create secret generic audit-probe --from-literal=k=v
kubectl get secret audit-probe
grep audit-probe /var/log/kubernetes/audit/audit.log > /opt/course/d16/probe.log
wc -l /opt/course/d16/probe.log                       # 2 이상 (create, get)
grep -o '"verb":"[a-z]*"' /opt/course/d16/probe.log | sort | uniq -c
#   1 "verb":"create"
#   1 "verb":"get"
grep -c '"requestObject"' /opt/course/d16/probe.log   # 0 — Metadata 레벨이라 본문(Secret 값)은 기록되지 않는다
```

정책이 `omitStages: [RequestReceived]` 라서 요청마다 `ResponseComplete` 단계 한 줄씩 남습니다. Secret 을 `Request`·
`RequestResponse` 레벨로 기록하면 비밀 값이 감사 로그에 평문으로 남으므로 Secret 은 `Metadata` 가 원칙입니다.

## 검증

```bash
ps -ef | grep [k]ube-apiserver | tr ' ' '\n' | grep audit
# --audit-log-maxbackup=2 / --audit-log-maxsize=10 / --audit-log-path=... / --audit-policy-file=...
ls -l /var/log/kubernetes/audit/                      # audit.log
head -c 300 /opt/course/d16/probe.log; echo           # {"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata",...
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 감사 = 플래그 4개(`policy-file`, `log-path`, `maxbackup`/`maxsize`/`maxage`) + hostPath 볼륨 2개(정책 파일, 로그 디렉터리). 정책 규칙은 위에서부터 **처음 맞는 것**이 적용된다.
- **헷갈리는 지점**: 정책 파일만 바꾸고 API 서버를 재시작하지 않으면 반영되지 않습니다(static Pod 는 매니페스트가 바뀌어야 재시작). 정책 apiVersion 은 `audit.k8s.io/v1` 이고 `v1beta1` 은 제거되었습니다.

## 참고 문서

- 검색어: `auditing`, `audit policy`, `audit log backend`
- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q17 →](../q17_readonly_rootfs_pod/question.md)
