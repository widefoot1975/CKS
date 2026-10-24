# q14 — ValidatingAdmissionPolicy for trusted registries and pinned tags · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Only trusted, pinned images may be deployed into namespaces labeled
> `registry-policy=enforced`. Implement this with a ValidatingAdmissionPolicy (no webhook).
>
> 1. Create a ValidatingAdmissionPolicy `trusted-registries` that checks `CREATE` and `UPDATE`
>    of Pods and of Deployments (`apps/v1`). For every container and init container:
>    - the image must start with `registry.k8s.io/` or `docker.io/library/`
>      (message: `images must come from registry.k8s.io/ or docker.io/library/`)
>    - the image must have an explicit tag that is not `latest`; references by digest
>      (`@sha256:`) are also allowed (message: `images must use an explicit tag other than latest`)
> 2. Create a ValidatingAdmissionPolicyBinding `trusted-registries-binding` that rejects
>    violating requests and applies only to namespaces labeled `registry-policy=enforced`.
> 3. Run the following commands and write their complete output (stdout and stderr) to
>    `/opt/course/a14/tests.txt`. Only `t1` and `t6` may be accepted.
>
>    ```bash
>    kubectl -n orbit run t1 --image=docker.io/library/nginx:1.27-alpine --dry-run=server
>    kubectl -n orbit run t2 --image=nginx:1.27-alpine --dry-run=server
>    kubectl -n orbit run t3 --image=registry.k8s.io/pause --dry-run=server
>    kubectl -n orbit create deploy t4 --image=docker.io/library/busybox:latest --dry-run=server
>    kubectl -n orbit apply -f /opt/course/a14/init-test.yaml --dry-run=server
>    kubectl -n playground run t6 --image=nginx:latest --dry-run=server
>    ```

**해석**

라벨 `registry-policy=enforced` 가 붙은 namespace 에는 신뢰하는, 태그가 고정된 이미지만 배포할 수 있어야 한다. 웹훅 없이 ValidatingAdmissionPolicy 로 구현한다.

1. Pod 와 Deployment(`apps/v1`)의 `CREATE`·`UPDATE` 를 검사하는 ValidatingAdmissionPolicy `trusted-registries` 를 만든다. 모든 컨테이너와 init 컨테이너에 대해
   - 이미지는 `registry.k8s.io/` 또는 `docker.io/library/` 로 시작해야 한다(메시지 지정).
   - 이미지는 `latest` 가 아닌 태그를 명시해야 한다. 다이제스트(`@sha256:`) 참조도 허용한다(메시지 지정).
2. 위반 요청을 거부하고 `registry-policy=enforced` 라벨의 namespace 에만 적용되는 ValidatingAdmissionPolicyBinding `trusted-registries-binding` 을 만든다.
3. 위 명령들을 실행해 전체 출력(표준출력·표준에러)을 `/opt/course/a14/tests.txt` 에 쓴다. `t1` 과 `t6` 만 받아들여져야 한다.

## 모범 풀이

**1) 정책 — Pod 와 Deployment 의 spec 위치가 다르다**

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: trusted-registries
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
    - apiGroups: ["apps"]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["deployments"]
  variables:
  - name: spec
    expression: "object.kind == 'Pod' ? object.spec : object.spec.template.spec"
  - name: images
    expression: >-
      variables.spec.containers.map(c, c.image) +
      (has(variables.spec.initContainers) ? variables.spec.initContainers.map(c, c.image) : [])
  validations:
  - expression: "variables.images.all(i, i.startsWith('registry.k8s.io/') || i.startsWith('docker.io/library/'))"
    message: "images must come from registry.k8s.io/ or docker.io/library/"
  - expression: "variables.images.all(i, i.contains('@sha256:') || (i.substring(i.lastIndexOf('/') + 1).contains(':') && !i.endsWith(':latest')))"
    message: "images must use an explicit tag other than latest"
```

| 함정 | 설명 |
|---|---|
| Deployment 의 컨테이너 위치 | Pod 는 `object.spec.containers`, Deployment 는 `object.spec.template.spec.containers`. 변수 하나로 통일 |
| init 컨테이너 | `initContainers` 는 선택 필드라 `has()` 로 확인하지 않으면 없는 Pod 에서 평가 오류 → `failurePolicy: Fail` 이면 거부 |
| 태그 없는 이미지 | `registry.k8s.io/pause` 는 `:` 가 없지만 런타임에서 `latest` 로 해석됨. 마지막 `/` 뒤에 `:` 가 있는지로 판단 (레지스트리 포트 `host:5000/` 와 구분). `/` 가 없으면 `lastIndexOf` 가 -1 이므로 `+ 1` 로 0 부터 자른다 |
| 짧은 이름 | `nginx:1.27-alpine` 은 실제로는 docker.io/library 에서 오지만 문자열 검사이므로 거부됨 |

Deployment 까지 매칭하면 `kubectl create deploy` 단계에서 바로 거부되어 사용자가 원인을 즉시 봅니다. Pod 만 매칭하면 Deployment 는
만들어지고 ReplicaSet 이 `FailedCreate` 이벤트만 남깁니다. `ephemeralContainers` 는 `pods/ephemeralcontainers` 서브리소스로 들어오므로 막으려면 별도 규칙이 필요합니다.

**2) 바인딩 — 없으면 정책은 아무것도 하지 않는다**

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: trusted-registries-binding
spec:
  policyName: trusted-registries
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        registry-policy: enforced
```

```bash
kubectl apply -f vap.yaml -f vapb.yaml
kubectl get validatingadmissionpolicy trusted-registries -o jsonpath='{.status.typeChecking}{"\n"}'   # 타입 경고 확인 (거부 사유 아님)
```

`validationActions` 는 `Deny`(거부), `Warn`(kubectl 경고), `Audit`(감사 로그 어노테이션)을 조합할 수 있고 `Deny` 와 `Warn` 은 같이 쓰지 않습니다.
namespace 선택은 정책의 `matchConstraints` 가 아니라 바인딩의 `matchResources.namespaceSelector` 로 좁히는 것이 일반적입니다.
정책과 바인딩은 모두 cluster-scoped 이고, 적용까지 몇 초 걸릴 수 있습니다.

**3) 테스트**

```bash
{
  kubectl -n orbit run t1 --image=docker.io/library/nginx:1.27-alpine --dry-run=server
  kubectl -n orbit run t2 --image=nginx:1.27-alpine --dry-run=server
  kubectl -n orbit run t3 --image=registry.k8s.io/pause --dry-run=server
  kubectl -n orbit create deploy t4 --image=docker.io/library/busybox:latest --dry-run=server
  kubectl -n orbit apply -f /opt/course/a14/init-test.yaml --dry-run=server
  kubectl -n playground run t6 --image=nginx:latest --dry-run=server
} > /opt/course/a14/tests.txt 2>&1
cat /opt/course/a14/tests.txt
# pod/t1 created (server dry run)
# The pods "t2" is invalid: : ValidatingAdmissionPolicy 'trusted-registries' with binding 'trusted-registries-binding' denied request: images must come from registry.k8s.io/ or docker.io/library/
# The pods "t3" is invalid: : ValidatingAdmissionPolicy ... denied request: images must use an explicit tag other than latest
# error: failed to create deployment: deployments.apps "t4" is forbidden: ValidatingAdmissionPolicy ... images must use an explicit tag other than latest
# The pods "t5" is invalid: : ValidatingAdmissionPolicy ... images must come from registry.k8s.io/ or docker.io/library/
# pod/t6 created (server dry run)
```

`--dry-run=server` 는 admission 을 전부 거치되 저장하지 않으므로 정책 시험에 적합합니다(`--dry-run=client` 는 서버에 가지 않아 의미 없음).
`t5` 는 메인 컨테이너는 정상이고 init 컨테이너(`ghcr.io/…`)만 위반입니다. 메시지 앞부분의 정확한 문구(`is invalid` / `is forbidden`)는 리소스와 kubectl 버전에 따라 다릅니다.

## 검증

```bash
grep -c 'server dry run' /opt/course/a14/tests.txt            # 2
grep -c 'denied request' /opt/course/a14/tests.txt            # 4
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
kubectl -n orbit run real --image=docker.io/library/busybox:1.36 -- sleep 60 && kubectl -n orbit delete pod real   # 실제 생성도 허용
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: VAP(`matchConstraints` + `variables` + `validations[].expression/message`) + Binding(`policyName`, `validationActions: [Deny]`, `matchResources.namespaceSelector`). 둘 다 `admissionregistration.k8s.io/v1`(GA v1.30).
- **헷갈리는 지점**: 바인딩이 없으면 아무 효과가 없습니다. 선택 필드는 `has()` 로 감쌉니다. 이미지 문자열 검사는 레지스트리 생략·태그 생략을 런타임처럼 해석해 주지 않습니다. MutatingAdmissionPolicy 는 v1.36 GA 라 시험 환경(v1.35)에서는 쓰지 않습니다.

## 참고 문서

- 검색어: `validating admission policy`, `CEL kubernetes`, `admission controllers`
- https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/
- https://kubernetes.io/docs/reference/using-api/cel/
- https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q15 →](../q15_falco_custom_rule_shell_output/question.md)
