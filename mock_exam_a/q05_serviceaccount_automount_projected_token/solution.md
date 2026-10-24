# q05 — Lock down ServiceAccount tokens and use an audience-bound projected token · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Workloads in namespace `ledger` have far too much API access.
>
> 1. Find every ClusterRoleBinding that grants ClusterRole `cluster-admin` to ServiceAccounts
>    of namespace `ledger` (directly or through a group), delete them, and write their names,
>    one per line and sorted alphabetically, to `/opt/course/a05/crb.txt`. Do not delete any
>    other binding.
> 2. ServiceAccount `default` in `ledger` must no longer mount its token automatically.
> 3. Create ServiceAccount `ledger-api` in `ledger` that does not mount its token
>    automatically.
> 4. Change Deployment `ledger-api` to use ServiceAccount `ledger-api`. Its Pods must not get
>    the default API token mounted. Instead mount a projected ServiceAccount token in volume
>    `vault-token` at `/var/run/secrets/vault` (read-only), file name `token`, audience `vault`,
>    expiry `3600` seconds.
> 5. Write the `aud` claim of the token found in a running Pod at
>    `/var/run/secrets/vault/token` to `/opt/course/a05/aud.txt`.

**해석**

namespace `ledger` 의 워크로드가 API 권한을 지나치게 많이 갖고 있다.

1. `ledger` 의 ServiceAccount 에게 (직접 또는 그룹을 통해) ClusterRole `cluster-admin` 을 주는 ClusterRoleBinding 을 모두 찾아 지우고,
   이름을 알파벳 순으로 한 줄씩 `/opt/course/a05/crb.txt` 에 쓴다. 다른 바인딩은 지우지 않는다.
2. `ledger` 의 SA `default` 는 더 이상 토큰을 자동 마운트하지 않아야 한다.
3. 토큰을 자동 마운트하지 않는 SA `ledger-api` 를 `ledger` 에 만든다.
4. Deployment `ledger-api` 가 SA `ledger-api` 를 쓰게 한다. Pod 에는 기본 API 토큰이 마운트되지 않아야 하고, 대신 볼륨 `vault-token` 으로
   projected SA 토큰을 `/var/run/secrets/vault`(읽기 전용)에 파일 이름 `token`, audience `vault`, 만료 3600초로 마운트한다.
5. 실행 중인 Pod 의 `/var/run/secrets/vault/token` 토큰에서 `aud` 클레임을 꺼내 `/opt/course/a05/aud.txt` 에 쓴다.

## 모범 풀이

**1) cluster-admin 바인딩 찾기 — 그룹 바인딩까지**

```bash
kubectl get clusterrolebinding -o json | jq -r '
  .items[] | select(.roleRef.name=="cluster-admin")
  | select(any(.subjects[]?;
        (.kind=="ServiceAccount" and .namespace=="ledger")
     or (.kind=="Group" and (.name=="system:serviceaccounts:ledger" or .name=="system:serviceaccounts"))))
  | .metadata.name' | sort | tee /opt/course/a05/crb.txt
# ledger-break-glass
# ledger-ops-admin
kubectl get clusterrolebinding ledger-ops-admin ledger-break-glass -o wide
kubectl delete clusterrolebinding $(cat /opt/course/a05/crb.txt)
```

jq 가 없으면 `kubectl get clusterrolebinding -o wide | grep cluster-admin` 으로 후보를 보고 `-o yaml` 로 subjects 를 확인합니다.
SA 는 사용자 이름 `system:serviceaccount:<ns>:<name>` 외에 그룹 `system:serviceaccounts`(모든 SA)와 `system:serviceaccounts:<ns>`
(그 namespace 의 모든 SA)에 자동으로 속합니다. `subjects` 의 `kind: ServiceAccount` 만 찾으면 그룹 바인딩 `ledger-break-glass` 를 놓칩니다.
`ledger-metrics-view`(ClusterRole `view`)는 cluster-admin 이 아니므로 남깁니다.

**2) · 3) SA 의 자동 마운트 끄기**

```bash
kubectl -n ledger patch sa default -p '{"automountServiceAccountToken": false}'
kubectl -n ledger create sa ledger-api
kubectl -n ledger patch sa ledger-api -p '{"automountServiceAccountToken": false}'
```

**4) Deployment — Pod 수준 설정이 SA 설정보다 우선**

```bash
kubectl -n ledger get deploy ledger-api -o jsonpath='{.spec.template.spec.automountServiceAccountToken}{"\n"}'   # true !
kubectl -n ledger edit deploy ledger-api
```

```yaml
    spec:
      serviceAccountName: ledger-api
      automountServiceAccountToken: false     # true → false (이게 SA 설정을 덮어쓴다)
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
        volumeMounts:
        - name: vault-token
          mountPath: /var/run/secrets/vault
          readOnly: true
      volumes:
      - name: vault-token
        projected:
          sources:
          - serviceAccountToken:
              audience: vault
              expirationSeconds: 3600
              path: token
```

```bash
kubectl -n ledger rollout status deploy ledger-api
```

| 설정 위치 | 값 | 결과 |
|---|---|---|
| SA `automountServiceAccountToken: false` + Pod 미지정 | – | 마운트 안 함 |
| SA `false` + Pod `true` | Pod 우선 | **마운트함** (setup 의 함정) |
| SA `true` + Pod `false` | Pod 우선 | 마운트 안 함 |
| `automount: false` + projected `serviceAccountToken` 볼륨 | – | 직접 지정한 토큰만 마운트 |

자동 마운트를 꺼도 projected 볼륨으로 **직접** 요청한 토큰은 마운트됩니다. kubelet 이 TokenRequest API 로 audience·만료가 정해진
토큰을 받아 만료 80% 시점(또는 24시간)마다 갱신합니다. `expirationSeconds` 는 최소 600 입니다. 이미 떠 있던 Pod 는 SA 설정을
바꿔도 그대로이므로 롤아웃으로 새 Pod 를 만들어야 합니다.

**5) aud 클레임 꺼내기**

```bash
T=$(kubectl -n ledger exec deploy/ledger-api -- cat /var/run/secrets/vault/token)
P=$(echo "$T" | cut -d. -f2 | tr '_-' '/+'); while [ $(( ${#P} % 4 )) -ne 0 ]; do P="$P="; done
echo "$P" | base64 -d | jq -r '.aud[]' > /opt/course/a05/aud.txt
cat /opt/course/a05/aud.txt                                # vault
echo "$P" | base64 -d | jq '{sub, exp, iat}'               # sub = system:serviceaccount:ledger:ledger-api, exp-iat = 3600
```

JWT 의 가운데 부분(payload)은 base64url 이고 패딩이 없어서 `tr` 로 문자를 바꾸고 `=` 를 채운 뒤 디코딩합니다.

## 검증

```bash
kubectl -n ledger exec deploy/ledger-api -- ls /var/run/secrets/kubernetes.io/serviceaccount   # No such file or directory
kubectl -n ledger exec deploy/ledger-api -- ls -l /var/run/secrets/vault                        # token
kubectl auth can-i '*' '*' --as=system:serviceaccount:ledger:default                            # no
kubectl auth can-i get pods -A --as=system:serviceaccount:ledger:monitor                        # yes (view 는 유지)
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
curl -sk -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $T" $APISERVER/api      # 401 (audience 가 vault 라 apiserver 가 거부)
cat /opt/course/a05/crb.txt /opt/course/a05/aud.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: Pod 의 `automountServiceAccountToken` 이 SA 의 값을 이긴다. 외부 시스템용 토큰은 projected `serviceAccountToken`(audience, expirationSeconds ≥ 600, path)으로 따로 받는다.
- **헷갈리는 지점**: SA 권한은 `ServiceAccount` subject 뿐 아니라 `system:serviceaccounts[:<ns>]` 그룹 바인딩으로도 생깁니다. audience 가 `vault` 인 토큰은 apiserver(`--api-audiences`)가 받지 않으므로 유출되어도 클러스터 API 에는 쓸 수 없습니다. v1.24 부터 SA 토큰 Secret 은 자동 생성되지 않습니다.

## 참고 문서

- 검색어: `configure service accounts for pods`, `projected volume serviceAccountToken`, `service accounts`
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/concepts/security/service-accounts/
- https://kubernetes.io/docs/concepts/storage/projected-volumes/
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q06 →](../q06_noderestriction_admission/question.md)
