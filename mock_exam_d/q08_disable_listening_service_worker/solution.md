# q08 — Disable a listening service on the worker node · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> A security scan reported that worker node `cks-c1-w1` listens on TCP port `20800`. Nobody needs
> this service.
>
> 1. On `cks-c1-w1`, find the systemd unit whose process listens on TCP port `20800`. Write the
>    unit name (for example `foo.service`) to `/opt/course/d08/unit.txt` on `cks-c1`.
> 2. Stop the unit and make sure it is not started again at boot.
> 3. Delete the executable that the unit starts (its `ExecStart` file). Nothing may listen on
>    TCP port `20800` afterwards.

**해석**

보안 스캔에서 워커 노드 `cks-c1-w1` 가 TCP `20800` 포트를 열고 있다고 나왔다. 이 서비스는 아무도 쓰지 않는다.

1. `cks-c1-w1` 에서 TCP `20800` 을 열고 있는 프로세스의 systemd 유닛을 찾아 유닛 이름(예: `foo.service`)을 `cks-c1` 의
   `/opt/course/d08/unit.txt` 에 쓴다.
2. 유닛을 멈추고 부팅할 때 다시 시작되지 않게 한다.
3. 유닛이 실행하는 실행 파일(`ExecStart` 의 파일)을 삭제한다. 그 뒤에는 TCP `20800` 을 아무것도 열고 있으면 안 된다.

## 모범 풀이

**1) 포트 → PID → 유닛**

```bash
ssh cks-c1-w1
sudo -i
ss -ltnp | grep 20800
# LISTEN 0  5  0.0.0.0:20800  0.0.0.0:*  users:(("python3",pid=41234,fd=3))
systemctl status 41234 | head -3
# ● pkgcache-sync.service - Package cache sync agent
#      Loaded: loaded (/etc/systemd/system/pkgcache-sync.service; enabled; ...)
cat /proc/41234/cgroup                     # 0::/system.slice/pkgcache-sync.service  ← 같은 답
systemctl cat pkgcache-sync.service        # ExecStart=/usr/local/bin/pkgcache-sync, Restart=always
```

`ss` 의 `-p` 는 root 일 때만 프로세스를 보여 줍니다. 프로세스 이름(`python3`)만으로는 어떤 서비스인지 알 수 없으니
`systemctl status <PID>` 나 `/proc/<PID>/cgroup` 으로 유닛을 확인합니다. `ss` 가 없으면 `netstat -tlnp`, `lsof -i :20800` 도 됩니다.

**2) 중지와 비활성화**

```bash
systemctl disable --now pkgcache-sync.service      # stop + disable 한 번에
systemctl is-enabled pkgcache-sync.service         # disabled
systemctl is-active pkgcache-sync.service          # inactive
exit; exit
echo pkgcache-sync.service > /opt/course/d08/unit.txt     # cks-c1 에서
```

| 명령 | 지금 멈춤 | 부팅 시 시작 안 함 | 다른 유닛·수동으로도 시작 불가 |
|---|---|---|---|
| `kill <PID>` | 잠깐 (`Restart=always` 라 바로 되살아남) | X | X |
| `systemctl stop` | O | X | X |
| `systemctl disable` | X | O | X |
| `systemctl disable --now` | O | O | X |
| `systemctl mask --now` | O | O | O |

`Restart=always` 유닛은 프로세스를 `kill` 해도 systemd 가 다시 띄웁니다. 반드시 systemd 로 멈춥니다.

**3) 실행 파일 삭제**

```bash
ssh cks-c1-w1
sudo -i
rm -f /usr/local/bin/pkgcache-sync
ss -ltn | grep 20800 || echo "20800 closed"
```

유닛 파일까지 지우려면 `rm /etc/systemd/system/pkgcache-sync.service && systemctl daemon-reload` 를 추가합니다. 패키지로 설치된
서비스라면 `dpkg -S <파일>` 로 패키지를 찾아 `apt purge` 하는 것이 정석입니다.

## 검증

```bash
ssh cks-c1-w1 'sudo systemctl is-enabled pkgcache-sync.service; sudo systemctl is-active pkgcache-sync.service'   # disabled / inactive
ssh cks-c1-w1 'sudo ss -ltn | grep -c 20800'           # 0
ssh cks-c1-w1 'ls /usr/local/bin/pkgcache-sync'         # No such file or directory
cat /opt/course/d08/unit.txt                            # pkgcache-sync.service
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `ss -ltnp | grep <port>` → `systemctl status <PID>` → `systemctl disable --now <unit>` (필요하면 `mask`).
- **헷갈리는 지점**: `disable` 만 하면 지금 돌고 있는 프로세스는 그대로이고, `stop` 만 하면 재부팅 후 다시 뜹니다. `0.0.0.0` 은 모든 인터페이스, `127.0.0.1` 은 로컬에서만 접속 가능하다는 뜻이라 스캔 결과를 해석할 때 구분합니다.

## 참고 문서

시험 중에는 systemd 문서를 열 수 없으므로 `man systemctl`, `systemctl --help`, `ss --help` 로 확인합니다.

- 검색어: `securing a cluster`, `ports and protocols`
- https://kubernetes.io/docs/tasks/administer-cluster/securing-a-cluster/
- https://kubernetes.io/docs/reference/networking/ports-and-protocols/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q09 →](../q09_psa_restricted_label_fix_pod/question.md)
