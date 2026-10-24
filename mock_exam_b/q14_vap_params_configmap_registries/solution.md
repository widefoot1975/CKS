# q14 — ValidatingAdmissionPolicy with ConfigMap parameters · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Only images from approved registries may run in selected namespaces. The list of approved
> registry prefixes is maintained in the ConfigMap `registry-allowlist` in namespace
> `policy-config` (key `registries`, comma-separated).
>
> 1. Create a ValidatingAdmissionPolicy `allowed-registries` that uses ConfigMaps as parameters
>    and checks Pods on `CREATE` and `UPDATE`: every image of `containers` and `initContainers` must
>    start with one of the prefixes from the parameter's `registries` key. Use a
>    `messageExpression` whose message contains the rejected image(s).
> 2. Create a ValidatingAdmissionPolicyBinding `allowed-registries-binding` that uses the
>    ConfigMap `registry-allowlist` in namespace `policy-config` as parameter, applies only to
>    namespaces labeled `registry-check=enforced`, uses the validation actions `Deny` and `Audit`,
>    and denies requests if the parameter cannot be found.
> 3. Label namespace `team-red` with `registry-check=enforced`.
> 4. In namespace `team-red`: create Pod `ok` with image `docker.io/library/nginx:1.27-alpine`
>    (must succeed), try to create Pod `short` with image `nginx:1.27-alpine` and apply
>    `/opt/course/b14/bad-init.yaml` (both must be denied). Write both error messages to
>    `/opt/course/b14/denied.txt`. In namespace `team-blue`, Pod `free` with image
>    `nginx:1.27-alpine` must be created successfully.

**해석**

선택한 네임스페이스에서는 승인된 레지스트리의 이미지만 실행할 수 있어야 한다. 승인된 레지스트리 접두사 목록은 `policy-config` 의 ConfigMap
`registry-allowlist`(키 `registries`, 쉼표 구분)에서 관리한다.

1. ConfigMap 을 파라미터로 쓰는 ValidatingAdmissionPolicy `allowed-registries` 를 만든다. Pod 의 `CREATE`·`UPDATE` 를 검사하며, `containers` 와
   `initContainers` 의 모든 이미지가 파라미터 `registries` 의 접두사 중 하나로 시작해야 한다. 거부된 이미지를 메시지에 담는 `messageExpression` 을 쓴다.
2. `policy-config` 의 `registry-allowlist` 를 파라미터로 쓰고, 라벨 `registry-check=enforced` 인 네임스페이스에만 적용되고, 검증 동작 `Deny`·`Audit`
   를 쓰며, 파라미터를 못 찾으면 거부하는 ValidatingAdmissionPolicyBinding `allowed-registries-binding` 을 만든다.
3. `team-red` 에 `registry-check=enforced` 라벨을 붙인다.
4. `team-red` 에서 이미지 `docker.io/library/nginx:1.27-alpine` 의 Pod `ok` 는 생성되고, `nginx:1.27-alpine` 의 Pod `short` 와
   `/opt/course/b14/bad-init.yaml` 은 거부되어야 한다. 두 오류 메시지를 `/opt/course/b14/denied.txt` 에 쓴다. `team-blue` 에서는 `nginx:1.27-alpine` 의
   Pod `free` 가 생성되어야 한다.

## 모범 풀이

**1) 정책**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: allowed-registries
spec:
  failurePolicy: Fail
  paramKind:
    apiVersion: v1
    kind: ConfigMap
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  variables:
  - name: allowed
    expression: "params.data['registries'].split(',')"
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image) +
      (has(object.spec.initContainers) ? object.spec.initContainers.map(c, c.image) : [])
  - name: rejected
    expression: "variables.images.filter(i, !variables.allowed.exists(r, i.startsWith(r)))"
  validations:
  - expression: "size(variables.rejected) == 0"
    messageExpression: "'image(s) not from an allowed registry: ' + variables.rejected.join(', ')"
    reason: Forbidden          # 생략하면 Invalid(422, "is invalid")
EOF
```

- `paramKind` 가 정책이 받을 파라미터 리소스의 종류입니다. CEL 에서는 `params` 로 접근하고 ConfigMap 이면 `params.data['키']`.
- `split`, `join` 은 쿠버네티스 CEL 의 strings 확장 함수입니다.
- `initContainers` 는 없을 수도 있는 필드라 `has()` 로 감쌉니다. 없는 필드에 바로 접근하면 평가 오류가 나고, `failurePolicy: Fail` 이라
  **모든** Pod 가 거부됩니다.

**2) 바인딩**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: allowed-registries-binding
spec:
  policyName: allowed-registries
  validationActions: [Deny, Audit]
  paramRef:
    name: registry-allowlist
    namespace: policy-config
    parameterNotFoundAction: Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        registry-check: enforced
EOF
```

> 함정 1: `paramRef.namespace` 를 생략하면 파라미터를 **검사 대상 객체의 네임스페이스**(여기서는 `team-red`)에서 찾습니다. `team-red` 에는
> ConfigMap 이 없으니 `parameterNotFoundAction: Deny` 에 따라 모든 Pod 가 거부됩니다. 중앙 ConfigMap 을 쓰려면 namespace 를 명시합니다.

| `validationActions` | 동작 |
|---|---|
| `Deny` | 실패 시 요청 거부 |
| `Warn` | 클라이언트에 경고만(`Deny` 와 함께 쓸 수 없음) |
| `Audit` | 감사 로그 이벤트에 `validation.policy.admission.k8s.io/validation_failure` 어노테이션 추가 |

**3) · 4) 라벨과 테스트**

```bash
kubectl label ns team-red registry-check=enforced
kubectl -n team-red run ok --image=docker.io/library/nginx:1.27-alpine           # pod/ok created
kubectl -n team-red run short --image=nginx:1.27-alpine 2> /opt/course/b14/denied.txt
kubectl apply -f /opt/course/b14/bad-init.yaml 2>> /opt/course/b14/denied.txt
cat /opt/course/b14/denied.txt
# Error from server (Forbidden): pods "short" is forbidden: ValidatingAdmissionPolicy 'allowed-registries' with binding
#   'allowed-registries-binding' denied request: image(s) not from an allowed registry: nginx:1.27-alpine
# Error from server (Forbidden): error when creating "/opt/course/b14/bad-init.yaml": pods "bad-init" is forbidden:
#   ValidatingAdmissionPolicy 'allowed-registries' ... denied request: image(s) not from an allowed registry: quay.io/prometheus/busybox:latest
kubectl -n team-blue run free --image=nginx:1.27-alpine                           # pod/free created (라벨 없음)
```

> 함정 2: `nginx:1.27-alpine` 은 런타임이 `docker.io/library/nginx:1.27-alpine` 으로 해석하지만, admission 단계의 `object.spec.containers[].image`
> 는 **사용자가 쓴 문자열 그대로**입니다. 접두사 검사는 정규화된 이름을 보지 않으므로 짧은 이름은 거부됩니다. 이것이 정책이 이미지 이름을
> 전체 경로로 쓰도록 강제하는 효과도 냅니다.

`bad-init.yaml` 은 메인 컨테이너가 `registry.k8s.io/pause:3.10`(허용)이고 initContainer 만 `quay.io/...` 입니다. `containers` 만 검사했다면 통과해
버렸을 경우입니다. (Deployment 등 상위 리소스를 막지 않으므로 Deployment 자체는 만들어지고, ReplicaSet 이 만드는 Pod 가 거부되어 이벤트로 남습니다.)

## 검증

```bash
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
kubectl get vap allowed-registries -o jsonpath='{.status.typeChecking}{"\n"}'      # 타입 경고가 없으면 비어 있음
kubectl -n team-red get pod                                                         # ok 만
kubectl -n team-blue get pod                                                        # free
kubectl -n policy-config patch cm registry-allowlist --type=merge -p '{"data":{"registries":"registry.k8s.io/,docker.io/library/,quay.io/prometheus/"}}'
kubectl apply -f /opt/course/b14/bad-init.yaml --dry-run=server                      # 이제 허용 (파라미터 변경이 즉시 반영)
kubectl -n policy-config patch cm registry-allowlist --type=merge -p '{"data":{"registries":"registry.k8s.io/,docker.io/library/"}}'
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 정책 `spec.paramKind{apiVersion, kind}` + 바인딩 `spec.paramRef{name, namespace, parameterNotFoundAction}`. CEL 에서 `params.data[...]`, `variables.<name>`, `messageExpression`.
- **헷갈리는 지점**: `namespaceSelector` 는 바인딩(`matchResources`)이나 정책(`matchConstraints`) 모두에 둘 수 있는데, "이 파라미터를 이 네임스페이스들에" 처럼 바인딩마다 다르게 하려면 바인딩 쪽에 둡니다. 정책을 고치면 기존 Pod 는 다시 검사되지 않습니다(admission 은 요청 시점에만). `ephemeralContainers` 까지 막으려면 `pods/ephemeralcontainers` 하위 리소스도 규칙에 넣어야 합니다.

## 참고 문서

- 검색어: `validating admission policy`, `paramKind`, `CEL`
- https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/
- https://kubernetes.io/docs/reference/using-api/cel/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q15 →](../q15_falco_investigate_existing_alerts/question.md)
