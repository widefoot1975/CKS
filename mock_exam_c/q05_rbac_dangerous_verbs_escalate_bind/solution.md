# q05 — Remove dangerous RBAC permissions in a tenant namespace · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The tenant namespace `tenant-x` collected risky RBAC rules. A rule is **dangerous** if it grants any
> of the following:
>
> - the verbs `escalate`, `bind` or `impersonate` (on any resource)
> - any verb on `secrets` through the wildcard verb `*`
> - the verb `create` on `pods/exec`
>
> Consider all Roles in namespace `tenant-x` and every ClusterRole that is referenced by a
> RoleBinding in `tenant-x`, but ignore the default ClusterRoles shipped with Kubernetes (`admin`,
> `edit`, `view`, `cluster-admin` and `system:*`).
>
> 1. Write every Role / ClusterRole that contains at least one dangerous rule to
>    `/opt/course/c05/dangerous.txt`, one per line in the form `Role/<name>` or `ClusterRole/<name>`,
>    sorted alphabetically.
> 2. Remove the dangerous rules from those objects. All other rules must stay exactly as they are,
>    and do not delete any Role, ClusterRole, RoleBinding or ServiceAccount.
> 3. Write the output of
>    `kubectl auth can-i --list --as=system:serviceaccount:tenant-x:ops -n tenant-x` to
>    `/opt/course/c05/ops-after.txt`.

**해석**

테넌트 namespace `tenant-x` 에 위험한 RBAC 규칙이 쌓였다. 다음 중 하나라도 주는 규칙을 **위험** 하다고 본다.

- `escalate`, `bind`, `impersonate` 동사(리소스 무관)
- 와일드카드 동사 `*` 로 `secrets` 에 대한 모든 권한
- `pods/exec` 에 대한 `create`

`tenant-x` 의 모든 Role 과, `tenant-x` 의 RoleBinding 이 참조하는 ClusterRole 을 대상으로 하되, 쿠버네티스 기본 ClusterRole
(`admin`, `edit`, `view`, `cluster-admin`, `system:*`)은 제외한다.

1. 위험한 규칙이 하나라도 있는 Role/ClusterRole 을 `Role/<이름>` 또는 `ClusterRole/<이름>` 형식으로 한 줄씩, 알파벳 순으로
   `/opt/course/c05/dangerous.txt` 에 쓴다.
2. 그 객체들에서 위험한 규칙만 지운다. 나머지 규칙은 그대로 두고, Role·ClusterRole·RoleBinding·ServiceAccount 는 삭제하지 않는다.
3. `kubectl auth can-i --list --as=system:serviceaccount:tenant-x:ops -n tenant-x` 출력을 `/opt/course/c05/ops-after.txt` 에 쓴다.

## 모범 풀이

**1) 대상 모으기**

```bash
alias k=kubectl
k -n tenant-x get role
k -n tenant-x get rolebinding -o custom-columns=NAME:.metadata.name,KIND:.roleRef.kind,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name
# NAME              KIND          ROLE               SUBJECTS
# ci-deployer       Role          ci-deployer        ci
# auditor-secrets   Role          secret-reader      auditor
# ops-roles         Role          role-manager       ops
# ops-helper        ClusterRole   tenant-x-helper    ops
# web-view          Role          viewer             web
# auditor-view      ClusterRole   view               auditor      ← 기본 ClusterRole, 제외
```

ClusterRole 은 RoleBinding 으로 묶이면 그 namespace 안에서만 효력이 있지만, 규칙은 ClusterRole 객체에 있으므로 함께 봐야 합니다.

**2) 위험 규칙 찾기 (jq)**

```bash
DANGER='any(.rules[]?; (.verbs|index("escalate") or index("bind") or index("impersonate"))
          or ((.resources|index("secrets")) and (.verbs|index("*")))
          or ((.resources|index("pods/exec")) and (.verbs|index("create"))))'

{
  k -n tenant-x get role -o json | jq -r ".items[] | select($DANGER) | \"Role/\"+.metadata.name"
  for cr in $(k -n tenant-x get rolebinding -o jsonpath='{range .items[?(@.roleRef.kind=="ClusterRole")]}{.roleRef.name}{"\n"}{end}' | sort -u); do
    case $cr in admin|edit|view|cluster-admin|system:*) continue;; esac
    k get clusterrole $cr -o json | jq -r "select($DANGER) | \"ClusterRole/\"+.metadata.name"
  done
} | sort > /opt/course/c05/dangerous.txt
cat /opt/course/c05/dangerous.txt
# ClusterRole/tenant-x-helper
# Role/ci-deployer
# Role/role-manager
# Role/secret-reader
```

(jq 의 `index` 는 못 찾으면 `null`, 찾으면 위치 숫자를 돌려주고 0 도 참입니다.) `viewer` 는 깨끗하므로 목록에 없습니다.

**3) 위험 규칙만 지우기**

```bash
k -n tenant-x edit role ci-deployer       # pods/exec create 규칙 삭제
k -n tenant-x edit role secret-reader     # secrets "*" 규칙 삭제 (configmaps 규칙은 유지)
k -n tenant-x edit role role-manager      # roles escalate 규칙 삭제
k edit clusterrole tenant-x-helper        # serviceaccounts impersonate, clusterroles bind 규칙 삭제
```

수정 후 남는 규칙:

| 객체 | 남기는 규칙 | 지운 규칙 |
|---|---|---|
| Role `ci-deployer` | deployments get/list/update/patch, pods·pods/log get/list | pods/exec create,get |
| Role `secret-reader` | configmaps get/list | secrets `*` |
| Role `role-manager` | roles·rolebindings get/list/create | roles escalate |
| ClusterRole `tenant-x-helper` | events get/list | serviceaccounts impersonate, clusterroles bind |

**왜 위험한가**

RBAC 에는 권한 상승 방지 장치가 있습니다. RoleBinding 을 만들 때 API 서버는 "만드는 사람이 그 Role 의 권한을 이미 모두 갖고
있는가" 를 검사하고, Role 을 만들거나 고칠 때도 "자신에게 없는 권한을 넣는가" 를 검사합니다. 그런데:

| 동사 | 우회하는 것 | 결과 |
|---|---|---|
| `bind` (roles/clusterroles) | RoleBinding 생성 시 검사 | `rolebindings create` 와 함께 있으면 `admin`·`cluster-admin` 같은 강한 역할을 자기 SA 에 묶을 수 있음 |
| `escalate` (roles/clusterroles) | Role 생성·수정 시 검사 | 자기가 묶인 Role 에 `*` 규칙을 추가해 권한을 키움 |
| `impersonate` | 주체 자체 | 더 강한 SA/사용자로 가장해 요청 (`--as`) |
| secrets `*` | — | 같은 namespace 의 모든 SA 토큰·자격 증명 읽기/수정 |
| pods/exec `create` | — | 실행 중인 컨테이너에서 명령 실행 → 그 Pod 의 SA 토큰·마운트 탈취 |

여기서 SA `ops` 는 `rolebindings create` 가 있으므로, `clusterroles bind` 까지 있으면 혼자서 namespace 관리자 권한을 얻을 수
있는 상태였습니다. 이런 동사는 꼭 필요하면 `resourceNames` 로 특정 Role 하나에만 한정합니다.

**4) 결과 기록**

```bash
k auth can-i --list --as=system:serviceaccount:tenant-x:ops -n tenant-x > /opt/course/c05/ops-after.txt
```

## 검증

```bash
SA=system:serviceaccount:tenant-x
k auth can-i create pods/exec        --as=$SA:ci      -n tenant-x   # no
k auth can-i update deployments      --as=$SA:ci      -n tenant-x   # yes  (남겨야 할 권한)
k auth can-i get secrets             --as=$SA:auditor -n tenant-x   # no   (view 도 secrets 는 못 읽는다)
k auth can-i list configmaps         --as=$SA:auditor -n tenant-x   # yes
k auth can-i escalate roles          --as=$SA:ops     -n tenant-x   # no
k auth can-i bind clusterroles       --as=$SA:ops     -n tenant-x   # no
k auth can-i impersonate serviceaccounts --as=$SA:ops -n tenant-x   # no
k auth can-i create rolebindings     --as=$SA:ops     -n tenant-x   # yes
grep -E 'escalate|bind|impersonate' /opt/course/c05/ops-after.txt || echo clean
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 권한 상승 3대 동사 `escalate`·`bind`·`impersonate`, 그리고 secrets 전체와 `pods/exec`. 찾을 때는 Role 만이 아니라 RoleBinding 이 가리키는 ClusterRole 까지 본다.
- **헷갈리는 지점**: Role 을 통째로 지우면 함께 있던 정상 권한까지 사라져 감점입니다. 기본 ClusterRole `view` 는 의도적으로 secrets 를 빼 두었습니다. `kubectl auth can-i --list` 는 RoleBinding 으로 받은 ClusterRole 권한도 합쳐서 보여 줍니다.

## 참고 문서

- 검색어: `rbac privilege escalation prevention`, `rbac bind escalate`, `role based access control good practices`
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/concepts/security/rbac-good-practices/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/#user-impersonation

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q06 →](../q06_exposed_admin_ui_lockdown/question.md)
