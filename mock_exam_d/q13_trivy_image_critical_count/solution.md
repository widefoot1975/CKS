# q13 — Count CRITICAL vulnerabilities with Trivy · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> Namespace `quartz` runs two Deployments, `legacy` and `current`. Trivy is installed on `cks-c1`.
>
> 1. Scan the image of each Deployment in namespace `quartz` with `trivy image`, reporting only
>    vulnerabilities of severity `CRITICAL`. Write one line per Deployment in the format
>    `<deployment> <image> <number of CRITICAL vulnerabilities>` to
>    `/opt/course/d13/critical.txt`.
> 2. Scale every Deployment in namespace `quartz` whose image has at least one `CRITICAL`
>    vulnerability to `0` replicas. Do not delete any Deployment.

**해석**

namespace `quartz` 에 Deployment `legacy` 와 `current` 가 돈다. `cks-c1` 에 Trivy 가 설치되어 있다.

1. namespace `quartz` 의 각 Deployment 이미지를 `trivy image` 로 스캔하되 심각도 `CRITICAL` 인 취약점만 보고하게 한다.
   Deployment 마다 한 줄씩 `<deployment> <image> <CRITICAL 취약점 수>` 형식으로 `/opt/course/d13/critical.txt` 에 쓴다.
2. 이미지에 `CRITICAL` 취약점이 하나라도 있는 `quartz` 의 Deployment 는 모두 replicas `0` 으로 줄인다. Deployment 는 지우지 않는다.

## 모범 풀이

**1) 이미지 목록과 스캔**

```bash
alias k=kubectl
k -n quartz get deploy -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[*].image
# NAME      IMAGE
# current   nginx:1.27-alpine
# legacy    nginx:1.19
trivy image --severity CRITICAL nginx:1.19 | grep -B2 'Total:'
# nginx:1.19 (debian 10.x)
# ========================
# Total: NN (CRITICAL: NN)
```

`--severity` 는 보고만 거르는 옵션이라 DB 다운로드·이미지 분석은 똑같이 합니다. 첫 실행은 DB(수십 MB)를 받느라 오래 걸리고,
두 번째부터는 캐시를 씁니다. Trivy 는 컨테이너 엔진 없이 레지스트리에서 이미지를 직접 받아 분석하므로 `cks-c1` 에서 바로 됩니다.

개수는 사람이 표를 세지 말고 JSON 으로 셉니다. 결과(`Results`)가 OS 패키지, 언어 패키지처럼 여러 target 으로 나뉠 수 있어
모두 합쳐야 합니다.

```bash
count() { trivy image -q --severity CRITICAL --format json "$1" | grep -c '"VulnerabilityID"'; }
# jq 가 있으면: trivy image -q --severity CRITICAL --format json "$1" | jq '[.Results[]?.Vulnerabilities[]?] | length'
: > /opt/course/d13/critical.txt
for d in $(k -n quartz get deploy -o jsonpath='{.items[*].metadata.name}'); do
  img=$(k -n quartz get deploy $d -o jsonpath='{.spec.template.spec.containers[0].image}')
  echo "$d $img $(count $img)" >> /opt/course/d13/critical.txt
done
cat /opt/course/d13/critical.txt
# current nginx:1.27-alpine 0        ← DB 시점에 따라 0 이 아닐 수도 있다
# legacy nginx:1.19 NN
```

`grep -c` 는 일치하는 줄이 없으면 `0` 을 출력하고 종료 코드 1 을 돌려줍니다. 출력은 그대로 쓰이므로 문제없습니다.

**2) CRITICAL 이 있는 Deployment 축소**

```bash
awk '$3 > 0 {print $1}' /opt/course/d13/critical.txt | xargs -r -I{} kubectl -n quartz scale deploy {} --replicas=0
k -n quartz get deploy
# NAME      READY   UP-TO-DATE   AVAILABLE
# current   1/1     1            1
# legacy    0/0     0            0
```

파일의 숫자로 판단하므로 두 이미지 모두 CRITICAL 이 있으면 둘 다 0 이 되는 것이 정답입니다.

## 검증

```bash
cat /opt/course/d13/critical.txt                                           # 두 줄, 세 칸씩
k -n quartz get deploy -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas
trivy image -q --severity CRITICAL nginx:1.19 | grep Total                 # 파일의 숫자와 같은지
trivy --version                                                            # Version: 0.69.3
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `trivy image --severity CRITICAL <img>` (여러 개면 `HIGH,CRITICAL`), 개수는 `--format json` 으로. 이미지 목록은 `kubectl get ... -o jsonpath`.
- **헷갈리는 지점**: 같은 이미지라도 DB 가 바뀌면 개수가 달라집니다. `--ignore-unfixed` 는 고친 버전이 없는 취약점을 빼므로 문제에서 요구할 때만 씁니다. 도구 자체도 공급망 위험이라 버전을 고정합니다(Trivy v0.69.4 는 악성 릴리스였다).

## 참고 문서

시험 중에는 Trivy 문서를 열 수 없으므로 `trivy image --help` 로 `--severity`, `--format`, `-q` 를 확인합니다.

- 검색어: `kubectl jsonpath`, `scale deployment`
- https://kubernetes.io/docs/reference/kubectl/jsonpath/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#scaling-a-deployment

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q14 →](../q14_kubesec_score_fix_pod/question.md)
