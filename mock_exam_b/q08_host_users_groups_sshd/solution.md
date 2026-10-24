# q08 — Harden host users, groups, sshd and setuid files · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> A temporary operations account and some leftovers from an old maintenance job were found on
> worker node `cks-c1-w1`. Perform all changes on `cks-c1-w1`.
>
> 1. User `ops-tmp` must keep existing, but must no longer be a member of the groups `sudo` and
>    `docker`. Lock the user's password and set its login shell to `/usr/sbin/nologin`.
> 2. sshd must not allow root login and must not allow password authentication. Put your settings in
>    the file `/etc/ssh/sshd_config.d/00-cks-hardening.conf`. The **effective** sshd configuration
>    (`sshd -T`) must show `permitrootlogin no` and `passwordauthentication no`. Apply the change
>    without rebooting the node.
> 3. Find every file in `/usr/local/bin/` that has the setuid bit set. Remove the setuid bit (do not
>    delete the files) and write the full paths, one per line, to `/opt/course/b08/setuid.txt` on
>    `cks-c1`.

**해석**

워커 `cks-c1-w1` 에서 임시 운영 계정과 예전 유지보수 작업의 흔적이 발견됐다. 모든 변경은 `cks-c1-w1` 에서 한다.

1. 사용자 `ops-tmp` 는 남겨 두되 `sudo`, `docker` 그룹에서 빼고, 비밀번호를 잠그고, 로그인 셸을 `/usr/sbin/nologin` 으로 바꾼다.
2. sshd 는 root 로그인과 비밀번호 인증을 허용하지 않아야 한다. 설정은 `/etc/ssh/sshd_config.d/00-cks-hardening.conf` 에 넣는다.
   **실제 적용된** 설정(`sshd -T`)에 `permitrootlogin no`, `passwordauthentication no` 가 보여야 한다. 재부팅 없이 적용한다.
3. `/usr/local/bin/` 에서 setuid 비트가 있는 파일을 모두 찾아 setuid 비트만 없애고(파일은 지우지 않음), 전체 경로를 한 줄씩
   `cks-c1` 의 `/opt/course/b08/setuid.txt` 에 쓴다.

## 모범 풀이

**1) 사용자와 그룹**

```bash
ssh cks-c1-w1
sudo -i
id ops-tmp                                   # uid=... groups=...,27(sudo),...(docker)
gpasswd -d ops-tmp sudo
gpasswd -d ops-tmp docker
usermod -L -s /usr/sbin/nologin ops-tmp      # -L: 비밀번호 잠금(해시 앞에 !), -s: 셸
id ops-tmp                                   # sudo, docker 없음
passwd -S ops-tmp                            # ops-tmp L ...   (L = locked)
getent passwd ops-tmp                        # ...:/usr/sbin/nologin
```

`docker` 그룹은 `/var/run/docker.sock` 에 접근할 수 있어 사실상 root 와 같습니다(`docker run -v /:/host --privileged`). `sudo` 그룹과
함께 반드시 빼야 하는 이유입니다. `usermod -G <목록>` 으로 보조 그룹을 통째로 다시 지정하는 방법도 있지만 다른 그룹까지 빠질 수 있어
`gpasswd -d` 가 안전합니다. 비밀번호 잠금은 키 기반 로그인까지 막지는 않으므로 셸을 nologin 으로 바꾸는 것까지 함께 합니다.

**2) sshd — 먼저 읽힌 값이 이긴다**

```bash
ls /etc/ssh/sshd_config.d/
# 50-legacy.conf  (클라우드 이미지라면 50-cloud-init.conf 도)
cat /etc/ssh/sshd_config.d/50-legacy.conf
# PermitRootLogin yes
# PasswordAuthentication yes
grep -n Include /etc/ssh/sshd_config
# 12:Include /etc/ssh/sshd_config.d/*.conf      ← 파일 맨 위쪽에서 포함
```

> 함정: sshd 는 대부분의 키워드에 대해 **처음 읽은 값**을 씁니다(나중 값이 덮어쓰지 않음). drop-in 은 파일 이름의 사전순으로 읽히므로
> `99-hardening.conf` 를 만들면 먼저 읽힌 `50-legacy.conf` 의 `yes` 가 그대로 적용됩니다. 그래서 과제의 파일 이름이 `00-` 입니다.

```bash
cat > /etc/ssh/sshd_config.d/00-cks-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
sshd -t && echo syntax-ok                                  # 문법 오류가 있으면 reload 하지 않는다
sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication)'
# permitrootlogin no
# passwordauthentication no
systemctl reload ssh || systemctl reload sshd               # Ubuntu 는 ssh, RHEL 계열은 sshd
```

50-legacy.conf 를 지우거나 값을 고쳐도 되지만, 과제는 00 파일에 설정을 두라고 했으므로 00 파일이 핵심입니다. 지금 연결된 ssh 세션은
reload 해도 끊기지 않습니다. 새 터미널에서 키로 다시 접속되는지 확인하고 나서 기존 세션을 닫는 습관을 들입니다.

**3) setuid 파일**

```bash
find /usr/local/bin -perm -4000 -type f -exec ls -l {} \;
# -rwsr-xr-x 1 root root ... /usr/local/bin/netdiag
chmod u-s /usr/local/bin/netdiag
find /usr/local/bin -perm -4000 -type f                      # 출력 없음
exit; exit
mkdir -p /opt/course/b08
echo /usr/local/bin/netdiag > /opt/course/b08/setuid.txt     # cks-c1 에서
```

`-perm -4000` 은 "setuid 비트를 포함", `-perm /6000` 은 "setuid 또는 setgid". `/6000` 으로 찾으면 setgid 만 있는
`report-mail`(`-rwxr-sr-x`)도 걸리는데, 과제는 setuid 만 묻으므로 목록에 넣지 않습니다. `netdiag` 는 `find` 의 복사본이라 setuid 가 붙으면
`netdiag . -exec /bin/sh -p \; -quit` 로 누구나 root 셸을 얻습니다.

| 비트 | 숫자 | `ls -l` 표시 | 의미 |
|---|---|---|---|
| setuid | 4000 | `-rwsr-xr-x` (사용자 x 자리가 `s`) | 파일 소유자 권한으로 실행 |
| setgid | 2000 | `-rwxr-sr-x` (그룹 x 자리가 `s`) | 파일 그룹 권한으로 실행 |
| sticky | 1000 | `drwxrwxrwt` (기타 x 자리가 `t`) | 디렉터리에서 본인 파일만 삭제 가능 |

## 검증

```bash
ssh cks-c1-w1 'id ops-tmp; sudo passwd -S ops-tmp; getent passwd ops-tmp'
ssh cks-c1-w1 'sudo sshd -T | grep -Ei "^(permitrootlogin|passwordauthentication)"'
ssh cks-c1-w1 'sudo find /usr/local/bin -perm -4000 -type f | wc -l'          # 0
ssh cks-c1-w1 'ls -l /usr/local/bin/netdiag'                                    # -rwxr-xr-x (파일은 남아 있음)
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@cks-c1-w1   # Permission denied (publickey)
cat /opt/course/b08/setuid.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `gpasswd -d <user> <group>`, `usermod -L -s /usr/sbin/nologin <user>`, `sshd -T` 로 실제 값 확인, `find <dir> -perm -4000`, `chmod u-s`.
- **헷갈리는 지점**: sshd 는 "첫 값 우선"이라 drop-in 은 앞 번호가 이깁니다(systemd·sysctl 의 "나중 값 우선"과 반대). `sshd -t` 는 문법 검사, `sshd -T` 는 최종 적용값 출력입니다. `PermitRootLogin prohibit-password` 는 키 로그인은 허용하므로 `no` 와 다릅니다.

## 참고 문서

허용 문서에 sshd·리눅스 계정 관리 문서는 없으므로 `man sshd_config`, `usermod --help`, `gpasswd --help`, `find --help` 로 확인합니다.

- 검색어: `security checklist`, `hardening nodes`
- https://kubernetes.io/docs/concepts/security/security-checklist/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q09 →](../q09_istio_peerauthentication_strict/question.md)
