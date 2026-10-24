# q13 — Deny Pods from untrusted registries with ValidatingAdmissionPolicy · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespaces labeled `registry-policy=trusted` may only run images from `registry.k8s.io`.
>
> 1. Create a ValidatingAdmissionPolicy named `trusted-registry-only` that applies to `CREATE`
>    and `UPDATE` of `pods` and rejects a Pod if any image in `spec.containers` does not start
>    with `registry.k8s.io/`. Use the message `only images from registry.k8s.io are allowed`.
> 2. Create a ValidatingAdmissionPolicyBinding named `trusted-registry-only-binding` that
>    enforces the policy (action `Deny`) only in namespaces labeled `registry-policy=trusted`.
> 3. Test it: Pod `ok` with image `registry.k8s.io/pause:3.10` in namespace `factory` must be
>    created; Pod `bad` with image `nginx:1.27-alpine` in namespace `factory` must be
>    rejected — write the full error message to `/opt/course/e13/denied.txt`. The same
>    `nginx:1.27-alpine` Pod named `free` in namespace `playground` must still be created.

**해석**

라벨 `registry-policy=trusted` 가 붙은 namespace 에서는 `registry.k8s.io` 의 이미지만 실행할 수 있다.

1. `pods` 의 `CREATE`·`UPDATE` 에 적용되고, `spec.containers` 의 이미지 중 하나라도 `registry.k8s.io/` 로 시작하지 않으면 파드를 거부하는
   ValidatingAdmissionPolicy `trusted-registry-only` 를 만든다. 메시지는 `only images from registry.k8s.io are allowed`.
2. 라벨 `registry-policy=trusted` 가 붙은 namespace 에서만 정책을 강제(`Deny`)하는 ValidatingAdmissionPolicyBinding `trusted-registry-only-binding` 을 만든다.
3. 테스트: `factory` 에서 이미지 `registry.k8s.io/pause:3.10` 의 파드 `ok` 는 만들어져야 하고, 이미지 `nginx:1.27-alpine` 의 파드 `bad` 는
   거부되어야 하며 전체 오류 메시지를 `/opt/course/e13/denied.txt` 에 쓴다. 같은 `nginx:1.27-alpine` 이미지의 파드 `free` 는 `playground` 에서 만들어져야 한다.

## 모범 풀이

**1) · 2) 정책과 바인딩**

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: trusted-registry-only
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: "object.spec.containers.all(c, c.image.startsWith('registry.k8s.io/'))"
    message: "only images from registry.k8s.io are allowed"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: trusted-registry-only-binding
spec:
  policyName: trusted-registry-only
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        registry-policy: trusted
```

```bash
kubectl apply -f vap.yaml
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
```

정책(무엇을 검사할지)과 바인딩(어디에, 어떤 동작으로 적용할지)은 따로입니다. **바인딩이 없으면 정책은 아무것도 하지 않습니다.**
`expression` 이 `true` 면 통과, `false` 면 `message` 로 거부합니다. `all()` 은 리스트의 모든 원소가 조건을 만족할 때만 `true` 입니다.

| `validationActions` | 동작 |
|---|---|
| `Deny` | 요청 거부 |
| `Warn` | 허용하되 클라이언트에 경고 |
| `Audit` | 허용하되 감사 로그 이벤트에 기록 |

**3) 테스트**

```bash
kubectl -n factory run ok --image=registry.k8s.io/pause:3.10          # pod/ok created
kubectl -n factory run bad --image=nginx:1.27-alpine 2> /opt/course/e13/denied.txt
cat /opt/course/e13/denied.txt
# The pods "bad" is invalid: : ValidatingAdmissionPolicy 'trusted-registry-only' with binding 'trusted-registry-only-binding' denied request: only images from registry.k8s.io are allowed
kubectl -n playground run free --image=nginx:1.27-alpine                # pod/free created (바인딩 범위 밖)
```

`nginx:1.27-alpine` 은 실제로는 `docker.io/library/nginx:1.27-alpine` 이지만 API 서버가 보는 것은 **파드 스펙에 적힌 문자열**이라
`registry.k8s.io/` 로 시작하지 않아 거부됩니다. 반대로 이름만 맞으면 통과하므로, 태그 대신 다이제스트(`@sha256:`)까지 강제하는 정책과
함께 쓰는 편이 안전합니다.

## 검증

```bash
kubectl get validatingadmissionpolicybinding trusted-registry-only-binding -o jsonpath='{.spec.validationActions}{" "}{.spec.matchResources.namespaceSelector}{"\n"}'
# ["Deny"] {"matchLabels":{"registry-policy":"trusted"}}
kubectl -n factory get pod                          # ok 만 있음
kubectl -n playground get pod                       # free
cat /opt/course/e13/denied.txt                      # ... denied request: only images from registry.k8s.io are allowed
kubectl -n factory set image pod/ok ok=nginx:1.27-alpine   # UPDATE 도 거부되어야 한다
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: VAP(`matchConstraints` + CEL `validations`) + **Binding**(`policyName`, `validationActions: [Deny]`, `matchResources.namespaceSelector`) 두 개가 한 세트. API 그룹 `admissionregistration.k8s.io/v1` (v1.30 GA).
- **헷갈리는 지점**: CEL 문자열은 YAML 큰따옴표 안에서 작은따옴표로 씁니다. `initContainers`·`ephemeralContainers` 도 막으려면 `(has(object.spec.initContainers) ? object.spec.initContainers : []).all(...)` 처럼 따로 검사해야 합니다(이 문제는 `containers` 만). `kubectl run` 오류는 stderr 로 나오므로 `2>` 로 받습니다.

## 참고 문서

- 검색어: `validating admission policy`, `CEL`, `validationActions`
- https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/
- https://kubernetes.io/docs/reference/using-api/cel/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q14 →](../q14_kubelinter_fix_findings/question.md)
