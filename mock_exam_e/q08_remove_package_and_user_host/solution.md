# q08 — Remove an unneeded package and user from a node · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Worker node `cks-c1-w1` runs an FTP server that nobody needs, and an old local account.
>
> 1. On `cks-c1-w1`, find the program listening on TCP port `21` and the Debian package that
>    installed it. Write the package name to `/opt/course/e08/package.txt` on `cks-c1`.
> 2. Remove that package from `cks-c1-w1` including its configuration files.
> 3. Delete the local user `legacy-ftp` on `cks-c1-w1` together with its home directory. No
>    process of this user may keep running.

**해석**

워커 노드 `cks-c1-w1` 에 아무도 쓰지 않는 FTP 서버와 오래된 로컬 계정이 있다.

1. `cks-c1-w1` 에서 TCP `21` 에서 대기하는 프로그램과 그것을 설치한 데비안 패키지를 찾는다. 패키지 이름을 `cks-c1` 의
   `/opt/course/e08/package.txt` 에 쓴다.
2. `cks-c1-w1` 에서 그 패키지를 설정 파일까지 포함해 제거한다.
3. `cks-c1-w1` 의 로컬 사용자 `legacy-ftp` 를 홈 디렉터리와 함께 삭제한다. 이 사용자의 프로세스가 남아 있으면 안 된다.

## 모범 풀이

**1) 포트 → 프로세스 → 바이너리 → 패키지**

```bash
ssh cks-c1-w1
sudo -i
ss -ltnp | grep -w 21
# LISTEN 0 32  *:21  *:*  users:(("vsftpd",pid=4321,fd=3))
readlink -f /proc/4321/exe          # /usr/sbin/vsftpd
dpkg -S /usr/sbin/vsftpd            # vsftpd: /usr/sbin/vsftpd
systemctl status vsftpd --no-pager | head -3
```

`ss -ltnp` 의 `-p` 는 root 여야 프로세스 이름이 보입니다(`netstat -ltnp`, `lsof -i :21` 도 같은 역할). 패키지 이름과 바이너리 이름이
다를 수 있으니 반드시 `dpkg -S <경로>` 로 확인합니다.

```bash
# cks-c1 에서 (워커에서 exit 한 뒤)
mkdir -p /opt/course/e08 && echo vsftpd > /opt/course/e08/package.txt
```

**2) 패키지 purge**

```bash
# cks-c1-w1, root
systemctl disable --now vsftpd
apt-get purge -y vsftpd             # remove + 설정 파일(/etc/vsftpd.conf) 삭제
apt-get autoremove -y               # 같이 들어온 의존 패키지 정리 (선택)
dpkg -l vsftpd | tail -1            # 출력 없음 또는 "un"/"pn" 상태
ss -ltn | grep -w 21 || echo "21 닫힘"
```

| 명령 | 바이너리 | `/etc` 설정 파일 | dpkg 상태 |
|---|---|---|---|
| `apt-get remove` | 삭제 | **남음** | `rc` |
| `apt-get purge` (= `remove --purge`) | 삭제 | 삭제 | 없음 |

**3) 사용자 삭제 — 프로세스부터 끝냅니다**

```bash
ps -u legacy-ftp -o pid,cmd          # sleep infinity 등
userdel -r legacy-ftp
# userdel: user legacy-ftp is currently used by process 5678   ← 프로세스가 있으면 거부
pkill -KILL -u legacy-ftp            # (systemd 유닛으로 떠 있다면 systemctl stop <유닛> 도 가능)
userdel -r legacy-ftp                # -r: 홈 디렉터리와 메일 스풀까지 삭제
id legacy-ftp                        # no such user
ls -d /home/legacy-ftp               # No such file or directory
```

`userdel -f` 로 강제 삭제할 수도 있지만 프로세스는 그대로 남아 "주인 없는 UID" 로 계속 돌기 때문에, 먼저 프로세스를 끝내는 것이 맞습니다.

## 검증

```bash
cat /opt/course/e08/package.txt                                  # vsftpd (cks-c1)
ssh cks-c1-w1 'dpkg -l | grep -w vsftpd; ls /etc/vsftpd.conf; ss -ltn | grep -w 21'   # 모두 아무것도 없음 / No such file
ssh cks-c1-w1 'id legacy-ftp; ps -u legacy-ftp; ls -d /home/legacy-ftp'                # no such user / 없음
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `ss -ltnp` → `/proc/<pid>/exe` → `dpkg -S` → `apt-get purge`. 사용자는 `pkill -u` 후 `userdel -r`.
- **헷갈리는 지점**: `remove` 는 설정 파일을 남깁니다(`dpkg -l` 에 `rc`). 서비스만 `stop` 하면 재부팅 때 다시 뜨고, `disable` 만 하면 다른 유닛이 의존해 올릴 수 있으니 필요 없는 것은 패키지째 지우는 것이 공격 표면을 줄이는 방법입니다. 답안 파일은 워커가 아니라 `cks-c1` 에 씁니다.

## 참고 문서

시험 중에는 `ss --help`, `man userdel`, `apt-get --help` 로 확인합니다.

- 검색어: `securing a cluster`, `node hardening`
- https://kubernetes.io/docs/tasks/administer-cluster/securing-a-cluster/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q09 →](../q09_securitycontext_drop_caps_nonprivileged/question.md)
