# q10 — Hunt down leaked secret values · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> The database password `Pa55-billing-2025` and the API token `tok-7f3a9c` of the `billing`
> application leaked into several objects in namespace `billing`.
>
> 1. Check all ConfigMaps, Secrets and Deployments in namespace `billing` for these two values in
>    **plain text** (not base64-encoded). Write every object that contains at least one of them to
>    `/opt/course/c10/findings.txt`, one per line as `<kind>/<name>` in lowercase (for example
>    `configmap/foo`), sorted.
> 2. Rotate the credentials: Secret `billing-db` must contain the keys `DB_PASSWORD` with value
>    `R0tated-billing-2026` and `API_TOKEN` with value `tok-rotated-2026`. No field or annotation of
>    the Secret may contain a credential in plain text.
> 3. Change Deployment `billing-api` so that it no longer receives the credentials as environment
>    variables. Mount Secret `billing-db` as a read-only volume at `/etc/billing/secrets` instead.
>    `DB_HOST` must still come from ConfigMap `app-config`.
> 4. Remove the key `DB_PASSWORD` from ConfigMap `app-config`.
> 5. Afterwards,
>    `kubectl -n billing get all,configmap,secret -o yaml | grep -cE 'Pa55-billing-2025|tok-7f3a9c'`
>    must print `0`, and the running Pod must be able to read
>    `/etc/billing/secrets/DB_PASSWORD`.

**해석**

`billing` 앱의 DB 비밀번호 `Pa55-billing-2025` 와 API 토큰 `tok-7f3a9c` 가 namespace `billing` 의 여러 객체로 새어 나갔다.

1. `billing` 의 모든 ConfigMap·Secret·Deployment 에서 두 값이 **평문**(base64 아님)으로 있는지 확인한다. 하나라도 있는 객체를
   소문자 `<kind>/<name>` 형식으로 정렬해 `/opt/course/c10/findings.txt` 에 쓴다.
2. 자격 증명을 교체한다. Secret `billing-db` 는 키 `DB_PASSWORD`=`R0tated-billing-2026`, `API_TOKEN`=`tok-rotated-2026` 을 가져야
   하고, Secret 의 어떤 필드·어노테이션에도 평문 자격 증명이 있으면 안 된다.
3. Deployment `billing-api` 가 자격 증명을 환경 변수로 받지 않게 하고, 대신 Secret `billing-db` 를 `/etc/billing/secrets` 에 읽기 전용
   볼륨으로 마운트한다. `DB_HOST` 는 계속 ConfigMap `app-config` 에서 받는다.
4. ConfigMap `app-config` 에서 키 `DB_PASSWORD` 를 지운다.
5. 끝나면 `kubectl -n billing get all,configmap,secret -o yaml | grep -cE '...'` 가 `0` 이어야 하고, 실행 중인 Pod 가
   `/etc/billing/secrets/DB_PASSWORD` 를 읽을 수 있어야 한다.

## 모범 풀이

**1) 평문 유출 찾기**

```bash
alias k=kubectl
P='Pa55-billing-2025|tok-7f3a9c'
for kind in configmap secret deployment; do
  for n in $(k -n billing get $kind -o name); do
    k -n billing get $n -o yaml | grep -qE "$P" && echo "$n"
  done
done | sort | tee /opt/course/c10/findings.txt
# configmap/app-config
# deployment.apps/billing-api        ← 형식에 맞게 deployment/billing-api 로 고친다
# secret/billing-db
sed -i 's#^deployment.apps/#deployment/#' /opt/course/c10/findings.txt
sort -o /opt/course/c10/findings.txt /opt/course/c10/findings.txt
```

어디에 있었나:

| 객체 | 위치 | 왜 문제인가 |
|---|---|---|
| `configmap/app-config` | `data.DB_PASSWORD` | ConfigMap 은 암호화 대상도 아니고 `view` 역할로도 읽힘 |
| `deployment/billing-api` | `env[].value` 리터럴 | Pod spec 은 Deployment/ReplicaSet/Pod 를 읽을 수 있는 누구에게나 보임 |
| `secret/billing-db` | `metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"]` | `kubectl apply` 가 `stringData` 를 **평문 그대로** 어노테이션에 저장 |

Secret 의 `data` 는 base64 라 `grep` 에 안 걸리지만, apply 로 만든 Secret 은 어노테이션에 원본 매니페스트가 그대로 남습니다.

```bash
k -n billing get secret billing-db -o jsonpath='{.metadata.annotations.kubectl\.kubernetes\.io/last-applied-configuration}'; echo
# {"apiVersion":"v1","kind":"Secret",...,"stringData":{"API_TOKEN":"tok-7f3a9c","DB_PASSWORD":"Pa55-billing-2025"},...}
```

**2) Secret 교체 — apply 가 아니라 create | replace**

```bash
k -n billing create secret generic billing-db \
  --from-literal=DB_PASSWORD='R0tated-billing-2026' --from-literal=API_TOKEN='tok-rotated-2026' \
  --dry-run=client -o yaml | k replace -f -
k -n billing get secret billing-db -o jsonpath='{.metadata.annotations}'; echo     # 비어 있어야 함
```

`replace` 는 객체 전체를 PUT 하므로 새 매니페스트에 없는 어노테이션이 사라집니다. `kubectl apply` 를 다시 쓰면 새 값이 또
어노테이션에 남습니다(`delete` 후 `create` 도 됨). 실제 운영이라면 DB 쪽 비밀번호도 함께 바꿔야 "회전" 입니다.

**3) Deployment — env 리터럴 제거, Secret 볼륨 마운트**

```bash
k -n billing edit deploy billing-api
```

```yaml
    spec:
      containers:
      - name: api
        image: nginx:1.27-alpine
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DB_HOST
        # DB_PASSWORD / API_TOKEN value 리터럴, envFrom(app-config) 삭제
        volumeMounts:
        - name: creds
          mountPath: /etc/billing/secrets
          readOnly: true
      volumes:
      - name: creds
        secret:
          secretName: billing-db
          defaultMode: 0400
```

`envFrom: configMapRef: app-config` 가 있었다면 4) 에서 키를 지운 뒤에는 상관없지만, 자격 증명이 다시 ConfigMap 에 들어가면
그대로 환경 변수가 되므로 필요한 키만 `configMapKeyRef` 로 받는 편이 안전합니다. 환경 변수는 `/proc/<pid>/environ`, 크래시 덤프,
로그 출력으로 새기 쉽고, 파일 마운트는 Secret 이 바뀌면 kubelet 이 자동으로 갱신해 줍니다(subPath 제외).

**4) ConfigMap 에서 키 삭제**

```bash
k -n billing patch configmap app-config --type=json -p='[{"op":"remove","path":"/data/DB_PASSWORD"}]'
```

**5) 남은 흔적 — 이전 ReplicaSet**

```bash
k -n billing get all,configmap,secret -o yaml | grep -cE "$P"
# 2  ← 아직 0 이 아님!
k -n billing get rs -o yaml | grep -nE "$P"           # 이전 ReplicaSet 의 Pod 템플릿에 env 리터럴이 남아 있다
k -n billing get rs
k -n billing delete rs $(k -n billing get rs -o jsonpath='{range .items[?(@.spec.replicas==0)]}{.metadata.name} {end}')
# 앞으로도 남기지 않으려면: spec.revisionHistoryLimit: 0  (대신 rollout undo 불가)
k -n billing get all,configmap,secret -o yaml | grep -cE "$P"     # 0
```

Deployment 는 롤백용으로 이전 ReplicaSet(`revisionHistoryLimit` 기본 10)을 보관합니다. 새 템플릿으로 바꿔도 예전 Pod 템플릿의
평문 값은 그 ReplicaSet 에 그대로 남습니다.

## 검증

```bash
k -n billing rollout status deploy billing-api
POD=$(k -n billing get pod -l app=billing-api -o jsonpath='{.items[0].metadata.name}')
k -n billing exec $POD -- cat /etc/billing/secrets/DB_PASSWORD; echo      # R0tated-billing-2026
k -n billing exec $POD -- env | grep -E 'DB_|API_'                        # DB_HOST 만
k -n billing exec $POD -- touch /etc/billing/secrets/x                    # Read-only file system
k -n billing get all,configmap,secret -o yaml | grep -cE 'Pa55-billing-2025|tok-7f3a9c'   # 0
cat /opt/course/c10/findings.txt
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: 평문 유출 3대 장소 = ConfigMap, env 리터럴, `last-applied-configuration` 어노테이션. 그리고 이전 ReplicaSet.
- **헷갈리는 지점**: Secret 의 base64 는 암호화가 아닙니다. etcd 암호화(EncryptionConfiguration)를 켜지 않았다면 etcd 에도 평문이고, 지운 값도 etcd compaction 전까지 이전 리비전에 남아 있습니다. Secret 을 `apply` 로 관리해야 한다면 `stringData` 대신 `data`(base64)를 쓰더라도 어노테이션에는 base64 값이 남는다는 점을 기억합니다.

## 참고 문서

- 검색어: `secrets good practices`, `distribute credentials securely using secrets`, `last-applied-configuration`
- https://kubernetes.io/docs/concepts/security/secrets-good-practices/
- https://kubernetes.io/docs/concepts/configuration/secret/
- https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/
- https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q11 →](../q11_cilium_wireguard_encryption/question.md)
