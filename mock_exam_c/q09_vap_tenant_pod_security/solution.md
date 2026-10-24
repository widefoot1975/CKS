# q09 — Enforce tenant Pod security with a ValidatingAdmissionPolicy · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespaces labeled `tenant=true` host untrusted tenants. Without using Pod Security Admission,
> enforce the following rules for Pods in those namespaces with a ValidatingAdmissionPolicy named
> `tenant-pod-security` and a ValidatingAdmissionPolicyBinding named `tenant-pod-security-binding`.
>
> 1. Reject a Pod if any of the following is true:
>    - any container is `privileged: true`
>    - the Pod uses a `hostPath` volume
>    - the Pod sets `hostNetwork`, `hostPID` or `hostIPC` to `true`
>    - any container would not run with `runAsNonRoot: true` — the value may come from the Pod's
>      `securityContext` or from the container's `securityContext`; a container value overrides
>      the Pod value
> 2. "Container" means regular containers, init containers **and** ephemeral containers. Adding an
>    ephemeral container to a running Pod (`kubectl debug`) must be checked too.
> 3. The policy must apply to `CREATE` and `UPDATE` only, fail closed, and the binding must only
>    select namespaces labeled `tenant=true` and use the validation action `Deny`.
> 4. Create each manifest in `/opt/course/c09/tests/` in namespace `tenant-a` and write one line per
>    file to `/opt/course/c09/results.txt` in the form `<file name>: allowed` or `<file name>: denied`,
>    sorted by file name. Then run
>    `kubectl -n tenant-a debug ok --image=busybox:1.36 --profile=sysadmin -- true` and append a
>    line `debug-sysadmin: allowed` or `debug-sysadmin: denied`.

**해석**

라벨 `tenant=true` namespace 에는 신뢰할 수 없는 테넌트가 있다. Pod Security Admission 을 쓰지 않고, ValidatingAdmissionPolicy
`tenant-pod-security` 와 Binding `tenant-pod-security-binding` 으로 다음 규칙을 강제한다.

1. 다음 중 하나라도 해당하면 Pod 를 거부한다: 어떤 컨테이너든 `privileged: true` / `hostPath` 볼륨 사용 / `hostNetwork`·`hostPID`·`hostIPC`
   가 `true` / 어떤 컨테이너든 `runAsNonRoot: true` 로 실행되지 않음(값은 Pod 또는 컨테이너 `securityContext` 에서 오며, 컨테이너 값이 우선).
2. "컨테이너" 는 일반·init·**ephemeral** 컨테이너 모두다. 실행 중인 Pod 에 ephemeral 컨테이너를 붙이는 것(`kubectl debug`)도 검사해야 한다.
3. 정책은 `CREATE`·`UPDATE` 에만 적용하고 실패 시 거부(fail closed), Binding 은 `tenant=true` namespace 만 고르고 `Deny` 를 쓴다.
4. `/opt/course/c09/tests/` 의 각 매니페스트를 `tenant-a` 에 만들어 보고 파일마다 `<파일명>: allowed|denied` 를 파일명 순으로
   `/opt/course/c09/results.txt` 에 쓴다. 이어서 `kubectl debug ... --profile=sysadmin` 결과를 `debug-sysadmin: ...` 로 덧붙인다.

## 모범 풀이

**1) 정책**

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: tenant-pod-security
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods", "pods/ephemeralcontainers"]
  variables:
  - name: podNonRoot
    expression: >-
      has(object.spec.securityContext) && has(object.spec.securityContext.runAsNonRoot) &&
      object.spec.securityContext.runAsNonRoot
  validations:
  - expression: >-
      !(has(object.spec.hostNetwork) && object.spec.hostNetwork) &&
      !(has(object.spec.hostPID) && object.spec.hostPID) &&
      !(has(object.spec.hostIPC) && object.spec.hostIPC)
    message: "hostNetwork, hostPID and hostIPC are not allowed"
  - expression: "!has(object.spec.volumes) || object.spec.volumes.all(v, !has(v.hostPath))"
    message: "hostPath volumes are not allowed"
  - expression: >-
      object.spec.containers.all(c, !has(c.securityContext) || !has(c.securityContext.privileged) || !c.securityContext.privileged) &&
      (!has(object.spec.initContainers) || object.spec.initContainers.all(c, !has(c.securityContext) || !has(c.securityContext.privileged) || !c.securityContext.privileged)) &&
      (!has(object.spec.ephemeralContainers) || object.spec.ephemeralContainers.all(c, !has(c.securityContext) || !has(c.securityContext.privileged) || !c.securityContext.privileged))
    message: "privileged containers are not allowed"
  - expression: >-
      object.spec.containers.all(c, (has(c.securityContext) && has(c.securityContext.runAsNonRoot)) ? c.securityContext.runAsNonRoot : variables.podNonRoot) &&
      (!has(object.spec.initContainers) || object.spec.initContainers.all(c, (has(c.securityContext) && has(c.securityContext.runAsNonRoot)) ? c.securityContext.runAsNonRoot : variables.podNonRoot)) &&
      (!has(object.spec.ephemeralContainers) || object.spec.ephemeralContainers.all(c, (has(c.securityContext) && has(c.securityContext.runAsNonRoot)) ? c.securityContext.runAsNonRoot : variables.podNonRoot))
    message: "every container must run with runAsNonRoot=true"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: tenant-pod-security-binding
spec:
  policyName: tenant-pod-security
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        tenant: "true"
```

```bash
kubectl apply -f /root/c09-vap.yaml
kubectl get validatingadmissionpolicy tenant-pod-security -o jsonpath='{.status.typeChecking}{"\n"}'   # 빈 값/{} = 타입 오류 없음
```

함정과 이유:

| 함정 | 설명 |
|---|---|
| `has()` 없이 필드 접근 | 선택 필드가 없으면 CEL 평가 오류 → `failurePolicy: Fail` 이라 **정상 Pod 까지 거부** |
| 세 컨테이너 목록을 `+` 로 합치기 | `containers`(Container) 와 `ephemeralContainers`(EphemeralContainer)는 타입이 달라 타입 검사에서 실패할 수 있음 → 목록별로 따로 검사 |
| `pods` 만 매칭 | `kubectl debug` 는 `pods/ephemeralcontainers` **서브리소스** UPDATE 라서 정책이 아예 호출되지 않음. 이때도 `object` 는 Pod 전체 |
| `pods/*` 로 매칭 | kubelet 의 `pods/status` 갱신까지 모두 검사 → 불필요한 부하·오류 위험 |
| runAsNonRoot 를 Pod 수준만 검사 | 컨테이너가 `runAsNonRoot: false` 로 덮어쓰면 통과해 버림 → 컨테이너 값 우선, 없으면 Pod 값 |
| `privileged` 를 일반 컨테이너만 | initContainer 로 우회 가능 |

namespace 선택은 Binding 의 `matchResources.namespaceSelector` 에 두었습니다(정책의 `matchConstraints` 에 둬도 되며, 둘 다 있으면 교집합).
`validationActions` 는 `Deny`, `Warn`, `Audit` 조합이고 `Deny` 와 `Warn` 은 함께 쓸 수 없습니다.

**2) 테스트**

```bash
cd /opt/course/c09/tests
for f in $(ls *.yaml | sort); do
  if kubectl apply -n tenant-a -f $f >/dev/null 2>/tmp/err; then echo "$f: allowed"; else echo "$f: denied"; fi
done | tee /opt/course/c09/results.txt
# bad-container-root.yaml: denied
# bad-hostpath.yaml: denied
# bad-hostpid.yaml: denied
# bad-init-privileged.yaml: denied
# bad-no-nonroot.yaml: denied
# ok.yaml: allowed

kubectl -n tenant-a debug ok --image=busybox:1.36 --profile=sysadmin -- true
# The Pod "ok" is invalid: : ValidatingAdmissionPolicy 'tenant-pod-security' with binding 'tenant-pod-security-binding'
#   denied request: privileged containers are not allowed
echo "debug-sysadmin: denied" >> /opt/course/c09/results.txt
```

## 검증

```bash
kubectl apply -n tenant-b -f /opt/course/c09/tests/bad-hostpid.yaml    # 라벨 없는 namespace → 허용 (정책 범위 밖)
kubectl delete -n tenant-b -f /opt/course/c09/tests/bad-hostpid.yaml
kubectl -n tenant-a get pod                                            # ok 만 있음
kubectl get validatingadmissionpolicybinding tenant-pod-security-binding -o yaml | grep -A3 validationActions
cat /opt/course/c09/results.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: VAP 는 `admissionregistration.k8s.io/v1`(v1.30 GA). 정책(무엇을 검사) + Binding(어디에, 어떤 action) 둘 다 있어야 동작한다. 선택 필드는 항상 `has()` 로 감싼다.
- **헷갈리는 지점**: Deployment 로 만든 Pod 가 거부되면 Deployment 생성은 성공하고 ReplicaSet 이벤트(`FailedCreate`)에만 메시지가 남습니다. ephemeral 컨테이너는 서브리소스라서 `resources` 에 명시해야 합니다. `messageExpression` 으로 거부 메시지에 컨테이너 이름을 넣을 수도 있습니다.

## 참고 문서

- 검색어: `validating admission policy`, `CEL`, `ephemeral containers`
- https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/
- https://kubernetes.io/docs/reference/using-api/cel/
- https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q10 →](../q10_secret_leak_hunt_env_annotations/question.md)
