# 1일차 (D-10) — 시험 형식, kube-apiserver 다루기

[← 계획 전체](README.md) · [2일차 →](day02.md)

## 오늘의 목표

- 시험이 어떻게 진행되는지(문제마다 `ssh`, 노드는 한 번 더 `ssh`, 120분, 67점) 머리에 넣습니다.
- **kube-apiserver·kubelet 설정을 고치고, 다시 뜨는지 확인하고, 안 뜨면 원인을 찾는 손버릇**을 들입니다. 이후 9일 동안 여러 도메인에서 같은 절차가 반복됩니다.

## 시간표

| 시간 | 할 일 |
|---|---|
| 0:00 – 0:15 | 루트 [README.md](../README.md) `출제 형태`·`실습 환경 준비`, [cheatsheet.md](../cheatsheet.md) §0 ~ §1 |
| 0:15 – 0:39 | 아래 문제 4개 풀기 |
| 0:39 – 0:51 | `solution.md` 와 대조, 오답 원인 기록 |
| 0:51 – 1:00 | `## Record` 에 기록하고 `python3 scripts/update_progress.py` 실행 |

## 풀 문제

| 문제 | 도메인 | 주제 | 배점 | 목표 | 결과 |
|---|---|---|---|---|---|
| D02 | Cluster Setup | kube-bench 로 apiserver profiling 끄기 | 5 | 5분 | [Q](../mock_exam_d/q02_kube_bench_apiserver_profiling/question.md) · [S](../mock_exam_d/q02_kube_bench_apiserver_profiling/solution.md) ☐ |
| E02 | Cluster Setup | kubelet 익명 접근 끄기 | 5 | 5분 | [Q](../mock_exam_e/q02_kubelet_anonymous_auth_disable/question.md) · [S](../mock_exam_e/q02_kubelet_anonymous_auth_disable/solution.md) ☐ |
| D06 | Cluster Hardening | system:anonymous 바인딩 지우기 | 5 | 5분 | [Q](../mock_exam_d/q06_anonymous_rbac_binding_remove/question.md) · [S](../mock_exam_d/q06_anonymous_rbac_binding_remove/solution.md) ☐ |
| D16 | Runtime Security | 주어진 정책으로 감사 로그 켜기 | 7 | 9분 | [Q](../mock_exam_d/q16_audit_enable_given_policy/question.md) · [S](../mock_exam_d/q16_audit_enable_given_policy/solution.md) ☐ |

합계 22점, 목표 24분.

## 꼭 잡을 것

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak   # manifests 밖에 백업
vim /etc/kubernetes/manifests/kube-apiserver.yaml
watch crictl ps | grep kube-apiserver               # 사라졌다가 새 ID 로 돌아오면 성공
crictl ps -a | grep kube-apiserver ; crictl logs <id>
journalctl -u kubelet --since '5 min ago' | grep -i apiserver
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
```

- 감사 로그처럼 **새 파일을 쓰는 플래그**는 플래그 + `volumeMounts` + `volumes(hostPath)` 세 곳을 다 고쳐야 apiserver 가 뜹니다.
- 백업을 `/etc/kubernetes/manifests/` 안에 두면 kubelet 이 그것도 정적 파드로 띄우려고 합니다.
- kubelet 은 `/var/lib/kubelet/config.yaml` 을 고친 뒤 `systemctl restart kubelet`. 워커에서 하는 일이니 `ssh cks-c1-w1` 부터.

## 여유가 있으면

- 심화 [A02 kube-bench 로 apiserver·kubelet 함께 고치기](../mock_exam_a/q02_cis_kube_bench_apiserver_kubelet/question.md)
- 심화 [B06 익명 접근을 헬스 경로로만 제한](../mock_exam_b/q06_anonymous_auth_health_endpoints_only/question.md)
