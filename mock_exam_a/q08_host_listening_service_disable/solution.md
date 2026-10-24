# q08 — Find and remove a disguised listening service on the worker · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> An unknown program on worker node `cks-c1-w1` listens on TCP port `20494`. It is not needed.
>
> 1. Find the process listening on TCP port `20494` on `cks-c1-w1` and the systemd unit that
>    starts it. Write the result to `/opt/course/a08/answer.txt` on `cks-c1` in exactly this
>    format:
>
>    ```
>    port: 20494
>    unit: <name of the systemd unit, e.g. foo.service>
>    binary: <absolute path of the program in the unit's ExecStart>
>    ```
>
> 2. Stop the service and make sure it cannot start again, also not after a reboot.
> 3. Delete the unit file and the program file from the node, and reload systemd.
> 4. Nothing may listen on TCP port `20494` on `cks-c1-w1` afterwards.

**해석**

워커 `cks-c1-w1` 에서 정체를 모르는 프로그램이 TCP `20494` 를 열고 있다. 필요 없는 프로그램이다.

1. `cks-c1-w1` 에서 TCP `20494` 를 여는 프로세스와 그것을 띄우는 systemd 유닛을 찾아, `cks-c1` 의 `/opt/course/a08/answer.txt` 에 위 형식 그대로 쓴다
   (`unit:` 은 유닛 이름, `binary:` 는 유닛 ExecStart 에 있는 프로그램의 절대 경로).
2. 서비스를 멈추고 재부팅 후에도 다시 시작되지 않게 한다.
3. 유닛 파일과 프로그램 파일을 노드에서 지우고 systemd 를 다시 읽힌다.
4. 이후 `cks-c1-w1` 의 TCP `20494` 에서는 아무것도 listen 하지 않아야 한다.

## 모범 풀이

**1) 포트 → PID → 유닛**

```bash
ssh cks-c1-w1
sudo -i
ss -tlnp | grep 20494
# LISTEN 0 5 0.0.0.0:20494 0.0.0.0:* users:(("legacy-agent",pid=48211,fd=3))
PID=48211
systemctl status $PID --no-pager | head -3          # ● sys-telemetry.service - System telemetry collector
cat /proc/$PID/cgroup                                # 0::/system.slice/sys-telemetry.service
systemctl cat sys-telemetry.service                  # # /etc/systemd/system/sys-telemetry.service ... ExecStart=/usr/local/sbin/legacy-agent ...
ls -l /proc/$PID/exe                                 # 프로그램(또는 스크립트면 인터프리터) 경로
```

`ss -p` 는 root 여야 프로세스 정보를 보여 줍니다(`sudo -i` 필수). `ss` 가 없으면 `netstat -tlnp`, `lsof -i :20494`, `fuser 20494/tcp` 를 씁니다.
프로세스 이름(`legacy-agent`)과 유닛 이름(`sys-telemetry.service`)이 다르므로 **PID 로 유닛을 역추적**해야 합니다.
`systemctl status <PID>` 가 PID 가 속한 유닛을 바로 알려 줍니다. 프로그램이 스크립트면 `/proc/<PID>/exe` 는 python3 같은
인터프리터를 가리키므로, 문제대로 유닛 파일의 `ExecStart` 경로를 적습니다.

```bash
# cks-c1 에서 (워커 셸을 빠져나온 뒤)
cat > /opt/course/a08/answer.txt <<'EOF'
port: 20494
unit: sys-telemetry.service
binary: /usr/local/sbin/legacy-agent
EOF
```

**2) · 3) 멈추고, 끄고, 지우기 — 순서가 중요**

```bash
ssh cks-c1-w1
sudo -i
systemctl disable --now sys-telemetry.service        # stop + 부팅 시 시작 링크 제거
rm -f /etc/systemd/system/sys-telemetry.service /usr/local/sbin/legacy-agent
systemctl daemon-reload
systemctl reset-failed sys-telemetry.service 2>/dev/null || true
systemctl mask sys-telemetry.service                 # (선택) 같은 이름의 유닛이 다시 생겨도 시작 불가
```

| 조치 | 효과 | 혼자 하면 부족한 이유 |
|---|---|---|
| `kill <PID>` | 프로세스 종료 | 유닛에 `Restart=always` → 2초 뒤 다시 뜬다 |
| `systemctl stop` | 지금 멈춤 | 재부팅하면 다시 시작 (enabled) |
| `systemctl disable` | 부팅 시 시작 안 함 | 지금 도는 프로세스는 그대로 |
| `disable --now` + 파일 삭제 + `daemon-reload` | 완전 제거 | – |
| `mask` | `/dev/null` 링크로 시작 자체를 막음 | 유닛 파일을 지우기 전에 하면 "unit file exists" 로 실패할 수 있음 |

`kill` 로 끝내면 `Restart=always` 때문에 곧 다시 살아납니다. 파일을 먼저 지우고 `disable` 하면 systemd 가 유닛을 못 찾아
`multi-user.target.wants/` 의 심볼릭 링크가 남을 수 있으므로 **disable → 삭제 → daemon-reload** 순서로 합니다.

## 검증

```bash
ssh cks-c1-w1 sudo ss -tlnp | grep 20494 || echo "20494 closed"     # 20494 closed
ssh cks-c1-w1 systemctl is-enabled sys-telemetry.service            # not-found (또는 masked)
ssh cks-c1-w1 ls /etc/systemd/system/multi-user.target.wants/ | grep telemetry || echo "no wants link"
ssh cks-c1-w1 ls -l /usr/local/sbin/legacy-agent                    # No such file or directory
cat /opt/course/a08/answer.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `ss -tlnp` → PID → `systemctl status <PID>` (또는 `/proc/<PID>/cgroup`) → `systemctl cat <unit>` 으로 ExecStart 확인 → `disable --now` → 파일 삭제 → `daemon-reload`.
- **헷갈리는 지점**: 프로세스 이름·유닛 이름·포트가 서로 달라 이름으로 grep 하면 못 찾습니다. kill 만 하면 `Restart=` 정책으로 되살아납니다. 패키지로 설치된 서비스라면 파일 삭제 대신 `apt purge` 가 정석입니다.

## 참고 문서

systemd/ss 문서는 시험 중 열 수 없으므로 `systemctl --help`, `ss --help`, `man systemctl` 을 씁니다.

- 검색어: `securing a cluster`, `cis benchmark minimize host services`
- https://kubernetes.io/docs/tasks/administer-cluster/securing-a-cluster/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q09 →](../q09_psa_baseline_enforce_restricted_warn/question.md)
