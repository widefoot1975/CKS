# q08 — Blacklist kernel modules and remove a telnet server · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Worker node `cks-c1-w1` must not support rarely used network protocols and must not offer a
> telnet server. Work on `cks-c1-w1` (`ssh cks-c1-w1`, `sudo -i`); write the answer files on `cks-c1`.
>
> 1. Find out which of the kernel modules `dccp`, `sctp`, `rds` and `tipc` are currently loaded on
>    `cks-c1-w1`. Write their names, one per line and sorted, to `/opt/course/c08/loaded.txt`.
> 2. Create `/etc/modprobe.d/cks-blacklist.conf` on `cks-c1-w1` so that none of the four modules can
>    be loaded anymore — neither automatically nor by an explicit `modprobe <module>`.
> 3. Unload every one of the four modules that is still loaded, without rebooting.
> 4. Find the installed Debian package that provides the telnet server daemon, purge it, and write
>    the package name to `/opt/course/c08/removed-package.txt`.

**해석**

워커 `cks-c1-w1` 은 잘 쓰지 않는 네트워크 프로토콜을 지원하지 않아야 하고 telnet 서버도 없어야 한다. 작업은
`cks-c1-w1` 에서(`ssh cks-c1-w1`, `sudo -i`) 하고, 답 파일은 `cks-c1` 에 쓴다.

1. 커널 모듈 `dccp`, `sctp`, `rds`, `tipc` 중 지금 로드된 것을 찾아 이름을 정렬해 한 줄씩 `/opt/course/c08/loaded.txt` 에 쓴다.
2. 네 모듈 모두 자동으로도, 명시적인 `modprobe <모듈>` 로도 로드되지 않게 `/etc/modprobe.d/cks-blacklist.conf` 를 만든다.
3. 아직 로드된 모듈을 재부팅 없이 내린다.
4. telnet 서버 데몬을 제공하는 설치된 데비안 패키지를 찾아 purge 하고 패키지 이름을 `/opt/course/c08/removed-package.txt` 에 쓴다.

## 모범 풀이

**1) 로드된 모듈 확인**

```bash
ssh cks-c1-w1
sudo -i
lsmod | awk '{print $1}' | grep -xE 'dccp|sctp|rds|tipc' | sort | tee /tmp/loaded.txt
# rds
# sctp
# tipc
lsmod | grep -E '^(dccp|sctp|rds|tipc)'     # 의존 모듈(dccp_ipv4, rds_tcp, udp_tunnel ...)도 함께 보인다
```

`grep -x` 로 줄 전체를 비교해야 `sctp_diag`, `rds_tcp` 같은 이름이 섞이지 않습니다.

**2) modprobe 설정**

```bash
cat <<'EOF' > /etc/modprobe.d/cks-blacklist.conf
# CKS: 사용하지 않는 프로토콜 모듈 차단
blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
EOF
```

| 지시어 | 막는 것 | 못 막는 것 |
|---|---|---|
| `blacklist <m>` | 별칭(alias)에 의한 **자동** 로드 (예: 소켓 생성 시 `net-pf-…`) | `modprobe <m>` 명시 로드, 다른 모듈의 의존성으로 끌려오는 로드 |
| `install <m> /bin/false` | `modprobe` 가 이 모듈을 넣으려 할 때마다 대신 `/bin/false` 실행 → 실패 | `insmod /path/x.ko` 직접 로드(이건 root 권한 문제) |

그래서 "명시적인 modprobe 도 안 되게" 라는 요구는 `install … /bin/false` 가 필요합니다(CIS 벤치마크의 권고도 같은 형식입니다).

**3) 언로드**

```bash
for m in dccp sctp rds tipc; do lsmod | grep -q "^$m " && modprobe -r $m; done
lsmod | grep -E '^(dccp|sctp|rds|tipc) ' || echo none-loaded
```

`modprobe -r` 은 의존 모듈도 함께 내립니다. `Module x is in use` 가 나오면 `lsmod` 의 `Used by` 열에서 먼저 내려야 할 모듈을
확인합니다(`rds_tcp` → `rds` 순). `remove` 경로는 `install` 지시어와 무관하므로 설정 파일을 만든 뒤에도 내릴 수 있습니다.

**4) telnet 서버 패키지 찾아 제거**

```bash
dpkg -l | grep -i telnet
# ii  inetutils-telnetd  2:2.5-3ubuntu4  amd64  telnet server
dpkg -S telnetd | head -3                 # 파일 → 패키지 확인
apt-get purge -y inetutils-telnetd
dpkg -l inetutils-telnetd | tail -1       # 'un' 또는 "no packages found"
ss -ltnp | grep ':23 ' || echo port-23-closed
exit; exit
```

`purge` 는 설정 파일까지 지웁니다(`remove` 는 `rc` 상태로 설정을 남김). 함께 설치된 inetd(`openbsd-inetd` 등)가 더 필요 없다면
`apt-get autoremove --purge` 로 정리할 수 있습니다.

**5) 답 파일 (cks-c1)**

```bash
printf 'rds\nsctp\ntipc\n' > /opt/course/c08/loaded.txt         # 1) 에서 확인한 실제 목록을 쓴다
echo inetutils-telnetd > /opt/course/c08/removed-package.txt
```

## 검증

```bash
ssh cks-c1-w1 'sudo modprobe -n -v sctp'          # install /bin/false
ssh cks-c1-w1 'sudo modprobe sctp; echo rc=$?'    # modprobe: ERROR ... rc=1
ssh cks-c1-w1 'lsmod | grep -E "^(dccp|sctp|rds|tipc) " || echo none'
ssh cks-c1-w1 'dpkg -l | grep -i telnetd || echo removed'
cat /opt/course/c08/loaded.txt /opt/course/c08/removed-package.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 모듈 완전 차단 = `/etc/modprobe.d/*.conf` 에 `install <m> /bin/false`(+`blacklist`), 즉시 반영은 `modprobe -r`. 확인은 `modprobe -n -v <m>`.
- **헷갈리는 지점**: `blacklist` 만 쓰면 `modprobe sctp` 가 그대로 성공합니다. 설정 파일은 `.conf` 확장자여야 읽힙니다. 패키지 이름은 `telnetd` 가 아니라 배포판에 따라 `inetutils-telnetd` 등일 수 있으니 `dpkg -l`/`dpkg -S` 로 확인합니다.

## 참고 문서

시험 중에는 modprobe·apt 문서를 열 수 없으므로 `man modprobe.d`, `modprobe --help`, `apt-get --help` 로 확인합니다.

- 검색어: `securing a cluster`, `kernel modules`
- https://kubernetes.io/docs/tasks/administer-cluster/securing-a-cluster/
- https://kubernetes.io/docs/concepts/security/linux-kernel-security-constraints/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q09 →](../q09_vap_tenant_pod_security/question.md)
