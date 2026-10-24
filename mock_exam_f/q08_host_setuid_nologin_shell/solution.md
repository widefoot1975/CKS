# q08 — Remove a setuid bit and a login shell on a node · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> A security scan of worker node `cks-c1-w1` found a privilege escalation path and a service user
> that can log in interactively.
>
> 1. On `cks-c1-w1`, find every regular file below `/usr/local/bin/` that has the setuid bit set and
>    write the full path(s), one per line, to `/opt/course/f08/suid.txt` on `cks-c1`.
> 2. Remove the setuid bit from those files. Do not delete them and do not change any other
>    permission bits.
> 3. The local user `svc-backup` on `cks-c1-w1` must not be able to get an interactive shell. Set its
>    login shell to `/usr/sbin/nologin`. Do not delete the user.
> 4. Write the `/etc/passwd` entry of `svc-backup` on `cks-c1-w1` to `/opt/course/f08/passwd.txt` on
>    `cks-c1`.

**해석**

워커 노드 `cks-c1-w1` 의 보안 점검에서 권한 상승 경로 하나와 대화형 로그인이 가능한 서비스 사용자가 발견되었다.

1. `cks-c1-w1` 에서 `/usr/local/bin/` 아래 setuid 비트가 있는 일반 파일을 모두 찾아, 전체 경로를 한 줄에 하나씩 `cks-c1` 의 `/opt/course/f08/suid.txt` 에 쓴다.
2. 그 파일들에서 setuid 비트를 없앤다. 파일을 지우거나 다른 권한 비트를 바꾸지 않는다.
3. `cks-c1-w1` 의 로컬 사용자 `svc-backup` 이 대화형 셸을 얻지 못하게 로그인 셸을 `/usr/sbin/nologin` 으로 바꾼다. 사용자는 지우지 않는다.
4. `cks-c1-w1` 에서 `svc-backup` 의 `/etc/passwd` 항목을 `cks-c1` 의 `/opt/course/f08/passwd.txt` 에 쓴다.

## 모범 풀이

**1) setuid 파일 찾기**

```bash
ssh cks-c1-w1
sudo -i
find /usr/local/bin -type f -perm -4000 -exec ls -l {} \;
# -rwsr-xr-x 1 root root 204264 ... /usr/local/bin/f08-find
```

`-perm -4000` 은 "setuid 비트가 **포함된**" 파일입니다(`-perm 4000` 은 권한이 정확히 4000 인 것만 찾으므로 틀림). setgid 까지 보려면
`-perm /6000` 을 씁니다. 소유자가 root 인 setuid `find` 는 `f08-find . -exec /bin/sh -p \; -quit` 로 누구나 root 셸을 얻는 고전적인 경로입니다.

`cks-c1` 에 기록합니다(`exit` 로 돌아오거나, `cks-c1` 에서 ssh 로 바로 실행).

```bash
ssh cks-c1-w1 sudo find /usr/local/bin -type f -perm -4000 > /opt/course/f08/suid.txt
cat /opt/course/f08/suid.txt          # /usr/local/bin/f08-find
```

**2) setuid 비트만 제거 (워커에서)**

```bash
chmod u-s /usr/local/bin/f08-find
stat -c '%a %A %n' /usr/local/bin/f08-find      # 755 -rwxr-xr-x /usr/local/bin/f08-find
```

`chmod 755` 로 숫자를 다시 쓰면 원래 권한을 정확히 알아야 하지만, `u-s` 는 setuid 비트만 뺍니다.

**3) 로그인 셸을 nologin 으로 (워커에서)**

```bash
getent passwd svc-backup           # svc-backup:x:1001:1001::/home/svc-backup:/bin/bash
usermod -s /usr/sbin/nologin svc-backup        # chsh -s /usr/sbin/nologin svc-backup 도 같음
su - svc-backup                    # This account is currently not available.
```

`nologin` 은 메시지를 출력하고 0 이 아닌 코드로 끝나므로 SSH·`su` 로 셸을 얻을 수 없습니다. 계정 잠금(`usermod -L`)은 비밀번호만 막고
SSH 키 로그인은 막지 못하므로 셸 변경과는 다른 조치입니다.

**4) passwd 항목 기록**

```bash
ssh cks-c1-w1 getent passwd svc-backup > /opt/course/f08/passwd.txt
cat /opt/course/f08/passwd.txt     # svc-backup:x:1001:1001::/home/svc-backup:/usr/sbin/nologin
```

## 검증

```bash
ssh cks-c1-w1 sudo find /usr/local/bin -type f -perm /6000     # 출력 없음
ssh cks-c1-w1 ls -l /usr/local/bin/                            # 두 파일 모두 남아 있음, -rwxr-xr-x
ssh cks-c1-w1 getent passwd svc-backup | cut -d: -f7           # /usr/sbin/nologin
cat /opt/course/f08/suid.txt /opt/course/f08/passwd.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `find <dir> -type f -perm -4000` → `chmod u-s <파일>`. 셸 제거는 `usermod -s /usr/sbin/nologin <user>`.
- **헷갈리는 지점**: `/usr/bin/passwd`, `/usr/bin/sudo` 같은 배포판 기본 setuid 파일은 정상이므로 문제 범위(`/usr/local/bin`) 밖은 건드리지 않습니다. 노드 작업은 반드시 문제에서 지정한 노드에서 하고, 결과 파일은 지정한 호스트(`cks-c1`)에 씁니다.

## 참고 문서

시험 중에는 리눅스 문서를 열 수 없으므로 `find --help`, `usermod --help`, `man chmod` 로 확인합니다.

- 검색어: `securing a cluster`, `node hardening`
- https://kubernetes.io/docs/tasks/administer-cluster/securing-a-cluster/
- https://kubernetes.io/docs/concepts/security/security-checklist/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q09 →](../q09_psa_dry_run_find_violators/question.md)
