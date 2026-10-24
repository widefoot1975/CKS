# q04 — Remove a wildcard rule from a Role · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> ServiceAccount `finance-app` in namespace `finance` only needs to read ConfigMaps and
> Deployments, but it is currently able to delete Secrets.
>
> 1. Find the Role in namespace `finance` that gives `finance-app` this access and write its name to
>    `/opt/course/f04/role.txt`.
> 2. Edit that Role and remove only the rule that uses wildcards (`*`). Keep its other rules and do
>    not change or delete any RoleBinding.
> 3. Write the output of
>    `kubectl auth can-i --list -n finance --as=system:serviceaccount:finance:finance-app` to
>    `/opt/course/f04/can-i.txt`. `finance-app` must no longer be able to delete Secrets, but must
>    still be able to list ConfigMaps and Deployments.

**해석**

namespace `finance` 의 ServiceAccount `finance-app` 은 ConfigMap 과 Deployment 를 읽기만 하면 되는데, 지금은 Secret 을 지울 수 있다.

1. `finance-app` 에게 이 권한을 주는 namespace `finance` 의 Role 을 찾아 이름을 `/opt/course/f04/role.txt` 에 쓴다.
2. 그 Role 을 고쳐 와일드카드(`*`)를 쓰는 규칙만 지운다. 나머지 규칙은 남기고 RoleBinding 은 바꾸거나 지우지 않는다.
3. `kubectl auth can-i --list -n finance --as=system:serviceaccount:finance:finance-app` 의 출력을 `/opt/course/f04/can-i.txt` 에 쓴다.
   `finance-app` 은 더 이상 Secret 을 지울 수 없어야 하고, ConfigMap 과 Deployment 는 계속 list 할 수 있어야 한다.

## 모범 풀이

**1) 어떤 Role 인가 — RoleBinding 에서 거꾸로 찾는다**

```bash
alias k=kubectl
SA=system:serviceaccount:finance:finance-app
k auth can-i delete secrets -n finance --as=$SA          # yes
k -n finance get rolebinding -o wide
# NAME                  ROLE               AGE   USERS   GROUPS   SERVICEACCOUNTS
# finance-app-reader    Role/app-reader    1m                     finance/finance-app
# finance-app-manager   Role/app-manager   1m                     finance/finance-app
k -n finance get role app-reader app-manager -o yaml | grep -B2 -A8 '^  rules'
```

`app-reader` 는 ConfigMap 읽기만 있고, `app-manager` 의 세 번째 규칙이 `apiGroups: ["*"]`, `resources: ["*"]`, `verbs: ["*"]` 입니다.

```bash
echo app-manager > /opt/course/f04/role.txt
```

**2) 와일드카드 규칙만 지우기**

```bash
k -n finance get role app-manager -o jsonpath='{range .rules[*]}{.apiGroups} {.resources} {.verbs}{"\n"}{end}'
# [""] ["configmaps"] ["get","list","watch"]
# ["apps"] ["deployments"] ["get","list","watch"]
# ["*"] ["*"] ["*"]                                      ← 인덱스 2
k -n finance patch role app-manager --type=json -p '[{"op":"remove","path":"/rules/2"}]'
```

`k -n finance edit role app-manager` 로 마지막 규칙 블록을 지워도 됩니다. 인덱스로 지울 때는 **먼저 순서를 확인**합니다.
Role 을 지우고 다시 만들면 규칙이 사라지는 동안 바인딩이 깨지고, 문제 조건(다른 규칙 유지)도 놓치기 쉽습니다.

RBAC 은 허용만 더하는 방식이라 거부 규칙이 없습니다. 바인딩된 Role 들의 규칙이 **합집합**으로 적용되므로, 위험한 규칙이 한 Role 에만
있어도 전체 권한이 열립니다. 그래서 `app-reader` 는 건드릴 필요가 없습니다.

**3) 결과 기록**

```bash
k auth can-i --list -n finance --as=$SA | tee /opt/course/f04/can-i.txt
# Resources                                       Non-Resource URLs   Resource Names   Verbs
# selfsubjectreviews.authentication.k8s.io        []                  []               [create]
# selfsubjectaccessreviews.authorization.k8s.io   []                  []               [create]
# selfsubjectrulesreviews.authorization.k8s.io    []                  []               [create]
# configmaps                                      []                  []               [get list watch]
# deployments.apps                                []                  []               [get list watch]
# ...                                             [/api/*] ...                         [get]   (system:discovery 등 기본 권한)
```

`*.*` 줄이 사라졌는지 봅니다.

## 검증

```bash
k auth can-i delete secrets -n finance --as=$SA          # no
k auth can-i list configmaps -n finance --as=$SA         # yes
k auth can-i list deployments.apps -n finance --as=$SA   # yes
k -n finance get rolebinding                             # 두 개 그대로
grep -c '\*\.\*' /opt/course/f04/can-i.txt                # 0
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `kubectl get rolebinding -o wide` 로 SA → Role 을 찾고, `can-i --list --as=system:serviceaccount:<ns>:<sa>` 로 실제 권한을 본다.
- **헷갈리는 지점**: `--as` 에는 SA 이름만 쓰면 안 되고 `system:serviceaccount:` 접두사가 필요합니다. `can-i --list` 는 namespace 를 안 주면 `default` 기준이라 `-n finance` 를 꼭 붙입니다. 그룹 `system:serviceaccounts:finance` 에 바인딩된 권한도 이 SA 에 적용되므로 `GROUPS` 열도 확인합니다.

## 참고 문서

- 검색어: `rbac`, `kubectl auth can-i`
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/concepts/security/rbac-good-practices/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q05 →](../q05_sa_default_automount_off_dedicated_sa/question.md)
