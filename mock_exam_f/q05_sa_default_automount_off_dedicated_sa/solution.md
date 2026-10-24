# q05 — Disable token automount on the default ServiceAccount · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> In namespace `hr`, only Deployment `hr-portal` talks to the Kubernetes API. No other Pod in the
> namespace should get an API token by default.
>
> 1. Configure ServiceAccount `default` in namespace `hr` so that its token is not mounted into Pods
>    automatically.
> 2. Create ServiceAccount `hr-portal-sa` in namespace `hr` and change Deployment `hr-portal` to use
>    it. Pods of `hr-portal` must still get a token mounted.
> 3. Make sure all Pods of both Deployments run with the new settings. Then, from a Pod of
>    `hr-portal`, list the Pods of namespace `hr` through the API with the mounted token and write
>    only the HTTP status code to `/opt/course/f05/api-code.txt`.

**해석**

namespace `hr` 에서 쿠버네티스 API 를 쓰는 것은 Deployment `hr-portal` 뿐이다. 다른 Pod 는 기본으로 API 토큰을 받으면 안 된다.

1. namespace `hr` 의 ServiceAccount `default` 의 토큰이 Pod 에 자동으로 마운트되지 않게 설정한다.
2. namespace `hr` 에 ServiceAccount `hr-portal-sa` 를 만들고 Deployment `hr-portal` 이 이것을 쓰게 바꾼다. `hr-portal` 의 Pod 에는 토큰이 계속 마운트되어야 한다.
3. 두 Deployment 의 Pod 가 모두 새 설정으로 돌게 한다. 그런 다음 `hr-portal` Pod 안에서 마운트된 토큰으로 API 를 불러 namespace `hr` 의 Pod 목록을
   요청하고 HTTP 상태 코드만 `/opt/course/f05/api-code.txt` 에 쓴다.

## 모범 풀이

**1) default SA 의 자동 마운트 끄기**

```bash
alias k=kubectl
k -n hr patch sa default -p '{"automountServiceAccountToken": false}'
k -n hr get sa default -o yaml | grep automount        # automountServiceAccountToken: false
```

`default` SA 는 namespace 를 만들면 컨트롤러가 다시 만들어 주므로 지우는 것은 답이 아닙니다. SA 에 설정을 걸면 그 SA 를 쓰는 **모든 Pod**
의 기본값이 바뀝니다.

**2) 전용 SA 를 만들고 Deployment 에 연결**

```bash
k -n hr create sa hr-portal-sa
k -n hr get rolebinding -o wide                       # portal-api   Role/portal-api   ...   hr/hr-portal-sa (바인딩은 이미 있음)
k -n hr set serviceaccount deploy hr-portal hr-portal-sa
k -n hr get deploy hr-portal -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'   # hr-portal-sa
```

새 SA 에는 `automountServiceAccountToken` 을 쓰지 않았으므로 기본값(마운트함)이 적용됩니다. RoleBinding 은 아직 없는 SA 를 subject 로
가질 수 있어서, SA 를 만드는 순간 권한이 붙습니다.

| SA 설정 | Pod 설정 | 결과 |
|---|---|---|
| 없음 | 없음 | 마운트 |
| `false` | 없음 | 마운트 안 함 |
| `false` | `true` | 마운트 (**Pod 값이 우선**) |
| 없음/`true` | `false` | 마운트 안 함 |

**3) Pod 재생성과 API 호출**

```bash
k -n hr rollout status deploy hr-portal               # SA 를 바꿔서 템플릿이 바뀌었으므로 이미 새 Pod
k -n hr rollout restart deploy hr-static              # 템플릿은 그대로라 직접 재시작해야 한다
k -n hr rollout status deploy hr-static

k -n hr exec deploy/hr-portal -- sh -c '
  D=/var/run/secrets/kubernetes.io/serviceaccount
  curl -s -o /dev/null -w "%{http_code}" --cacert $D/ca.crt \
    -H "Authorization: Bearer $(cat $D/token)" \
    https://kubernetes.default.svc/api/v1/namespaces/hr/pods' > /opt/course/f05/api-code.txt
cat /opt/course/f05/api-code.txt                       # 200
```

토큰 마운트 여부는 **Pod 를 만들 때** admission(ServiceAccount 플러그인)이 결정합니다. SA 를 고쳐도 이미 떠 있는 Pod 는 그대로이므로
`hr-static` 은 재시작해야 토큰이 빠집니다.

## 검증

```bash
k -n hr exec deploy/hr-static -- ls /var/run/secrets/kubernetes.io/serviceaccount 2>&1 | tail -1
# ls: cannot access '/var/run/secrets/kubernetes.io/serviceaccount': No such file or directory
k -n hr get pod -l app=hr-static -o jsonpath='{.items[0].spec.volumes}{"\n"}'
# 빈 줄 — kube-api-access-* 볼륨이 없다
k -n hr exec deploy/hr-portal -- ls /var/run/secrets/kubernetes.io/serviceaccount   # ca.crt namespace token
k auth can-i list pods -n hr --as=system:serviceaccount:hr:hr-portal-sa              # yes
cat /opt/course/f05/api-code.txt                                                     # 200
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `automountServiceAccountToken: false` 는 SA 와 Pod spec 둘 다에 쓸 수 있고 Pod 값이 우선한다. 바꾼 뒤에는 Pod 를 다시 만들어야 적용된다.
- **헷갈리는 지점**: 토큰 파일은 Secret 이 아니라 projected 볼륨(`kube-api-access-xxxxx`)으로 들어오는 시간 제한 토큰입니다(v1.24+ 는 SA 토큰 Secret 을 자동으로 만들지 않음). 결과 코드가 `403` 이면 토큰은 있지만 RBAC 이 없는 것이고, `401` 이면 토큰이 없거나 잘못된 것입니다.

## 참고 문서

- 검색어: `configure service accounts for pods`, `automountServiceAccountToken`
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/concepts/security/service-accounts/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q06 →](../q06_csr_approve_user_kubeconfig/question.md)
