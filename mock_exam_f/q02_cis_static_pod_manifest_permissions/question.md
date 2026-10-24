# q02 — Fix CIS file permission findings with kube-bench

| Item | Value |
|---|---|
| Exam | mock_exam_f |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_f/q02_cis_static_pod_manifest_permissions
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 `cks-c1` 의 `/etc/kubernetes/manifests/*.yaml` 네 파일은 권한이 `644`, etcd 데이터 디렉터리(`/var/lib/etcd`)는 `755` 로 바뀌어 있다(kubeadm 기본값은 `600` / `700`). 원래 권한은 `/opt/course/f02/backup/perms.txt` 에 백업되어 있다.
`kube-bench` v0.10.4 가 없으면 setup 이 GitHub 릴리스의 `.deb` 로 설치하므로 인터넷 연결이 필요하다. kube-bench 는 공용 도구라 정리할 때 지우지 않는다.

## Task

A CIS benchmark run on the control plane node `cks-c1` reports permission problems on
configuration files.

1. Run `kube-bench` against the control plane components (`master` target) and write every
   `[FAIL]` line of section `1.1` to `/opt/course/f02/before.txt`.
2. Fix the findings that concern file permissions: the four static Pod manifests in
   `/etc/kubernetes/manifests/` must have permissions `600` and the etcd data directory must have
   permissions `700`. Do not change file contents or ownership.
3. Run `kube-bench` again and write the `[PASS]` lines of the checks for the four manifest files and
   the etcd data directory permissions to `/opt/course/f02/after.txt`.

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

[↑ 문항 목록](../README.md) · [← q01](../q01_networkpolicy_block_metadata_egress/question.md) · [q03 →](../q03_ingress_tls_wrong_secret_name/question.md)
