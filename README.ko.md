# ElastiCORE agent kit

[ElastiCORE](https://github.com/xsko/ElastiCORE)로 만든 프로젝트를 위한 [Claude Code](https://code.claude.com) 플러그인입니다.
ElastiCORE는 YAML 모델에서 Spring Boot 애플리케이션 - 엔티티, DTO, 리포지토리, 서비스, REST 컨트롤러, 검증, 오류 처리 - 을
생성하고, 빌드할 때마다 다시 생성합니다. 같은 skill을 [opencode](https://opencode.ai)용으로도 패키징했고,
[Codex CLI](https://github.com/openai/codex)에서도 씁니다.

그냥 두면 에이전트는 생성된 Java를 고칩니다. 다음 빌드가 그 수정을 덮어쓰거나, 그 파일이 소리 없이 YAML을 따라가지 않게 되는데
아무도 모르고 지나갑니다. 이 플러그인을 쓰면 에이전트는 YAML을 고치고, 다시 생성하고, 컴파일한 뒤 업무에 무엇이 바뀌었는지 알려 줍니다.

[English](README.md)

## 에이전트가 Java 대신 쓰는 것

게시글·댓글 API의 모델을 kit의 게시판 레시피가 쓰는 대로 (엔티티 둘 중 하나):

```yaml
entity:
  Post:
    meta: entity @root @editable @expose(20) @sort(postId-) -- post
    fields:
      postId:    long @id @sequence
      title:     string(100)! @notblank @search(like) -- title
      body:      text! @notblank -- body
      author:    string(30)! @notblank -- author name
      createdAt: datetime @updatable(false) @jpa:org.springframework.data.annotation.CreatedDate -- written at
```

빌드 한 번이 이것을 JPA 엔티티, 검증이 붙은 요청·응답 DTO(`!`는 필수, `string(100)`은 100자 이하, `@notblank`), 리포지토리,
서비스, REST 컨트롤러 - 등록·조회·수정·삭제, 최신순 페이지 목록, 제목 일부 검색 - 와 400·404로 답하는 오류 처리기로
만듭니다. 에이전트가 Java를 쓰는 곳은 모델이 말하지 못하는 것 - 다른 행을 읽는 규칙, CRUD에 없는 업무 동작 - 뿐이고, 그것도
생성기가 넘겨주는 파일 안에서만입니다.

## 플러그인의 구성

- **skill:** 에이전트가 읽는 페이지. 빠른 길, 한 장짜리 DSL 요약, 완성된 레시피 셋 - 게시판(게시글·댓글), 도서관(도서·회원·대출), 상점(로그인하는 회원·주문)
  - 그리고 셸에서 애플리케이션을 띄우고 확인하는 방법. 생성기가 소유하는 파일이 무엇인지, 변경이 어디에 들어가야 하는지를 압니다.
- **hook:** 편집과 빌드마다 하는 검사. 생성 파일을 고치려 하면 막고 대신 고칠 자리를 알려 주고, `-Pforce` - ElastiCORE가 손으로
  고친 파일을 덮어쓰게 하는 Gradle 속성 - 빌드를 막고, 모델을 고친 뒤에는 생성·컴파일하라고 알려 주며, 성공한 빌드가 둘 다 하기
  전에는 끝내지 못하게 합니다.
- **agent 둘과 command 셋:** 요구사항을 모델 변경으로 바꾸고 업무 말로 보고하는 modeler, reviewer, 그리고
  `/elasticore:generate`, `/elasticore:change-report`, `/elasticore:review`.

## 필요한 것

- Claude Code - 또는 opencode나 Codex CLI, 설치 절 참고.
- JDK 17 이상. 새 프로젝트를 만들려면 PATH에 Gradle 8.14 이상: 템플릿이 그것으로 Gradle wrapper를 만듭니다.
- Windows에서는 Git for Windows. hook은 bash로 실행되고, Claude Code가 Git Bash로 그것을 실행합니다. 없으면 Claude Code가
  편집·명령마다 hook 오류를 표시하니 Git for Windows를 설치하거나 플러그인을 끄세요.
- ElastiCORE 3.0. Maven Central에 정식 전 릴리스(release candidate)로 있고, 새 프로젝트는 거기의 최신 릴리스를 받습니다. 2.x 프로젝트에서는 hook이
  동작하고, 요약과 레시피는 3.0 기준으로 쓰였습니다.

## 설치

```bash
claude plugin marketplace add xsko/elasticore-agent-kit
claude plugin install elasticore@elasticore-agent-kit
```

세션 안에서는 `/plugin marketplace add xsko/elasticore-agent-kit` 다음 `/plugin install elasticore@elasticore-agent-kit`.

**opencode:** 이 저장소를 받아 `opencode/install.sh`(또는 `opencode/install.ps1`)를 실행합니다. 같은 skill과 hook 스크립트,
그것을 돌리는 opencode 플러그인, opencode 형식의 agent·command가 설치됩니다. 자세한 내용은 [opencode/README.md](opencode/README.md).

**Codex CLI:** `plugins/elasticore/skills/elasticore`를 프로젝트의 `.agents/skills/elasticore`로(모든 프로젝트에 쓰려면
`~/.agents/skills/elasticore`로) 복사합니다. Codex는 skill - 빠른 길, 요약, 레시피 - 을 받고, hook은 Claude Code와 opencode의
것입니다. 아래 비교의 Codex도 그렇게 돌렸습니다.

## 써 보기

빈 폴더에서 Claude Code를 시작하고 "ElastiCORE로" 애플리케이션을 만들어 달라고 합니다. 예:

> ElastiCORE로 도서관 REST API를 만들어 줘: 13자리 ISBN이 있는 도서, 이메일이 유일한 회원, 날짜를 서버가 정하는 대출, 남은
> 권수가 없으면 409, 반납 동작. 빌드하고, 18080 포트로 띄워 확인하고, 끄고.

아래에서 측정한 실행에서 에이전트는 skill의 요약과 맞는 레시피를 읽고, YAML을 쓰고, Gradle wrapper로 생성·빌드하고, jar를
백그라운드로 띄우고, 400·404·409까지 요청을 보내고, 프로세스 ID로 서버를 끄고, 확인하지 못한 것까지 적어 보고했습니다.
프로젝트는 Maven Central의 ElastiCORE 릴리스와 kit의 CI가 매주 빌드하는 템플릿으로 만들며, ElastiCORE를 소스에서 빌드하거나
PC의 다른 프로젝트를 읽지 않습니다.

## 업데이트

Claude Code는 이런 마켓플레이스의 플러그인을 저절로 업데이트하지 않습니다. 최신 버전은 이렇게 받습니다.

```bash
claude plugin marketplace update elasticore-agent-kit
claude plugin update elasticore@elasticore-agent-kit
```

그다음 Claude Code 세션을 새로 시작하거나, 열려 있는 세션에서 `/reload-plugins`를 실행합니다.
설치된 버전은 `claude plugin list`로 보고, 바뀐 내용은 [CHANGELOG.md](CHANGELOG.md)에 있습니다.

세션 안에서는 `/plugin` → **Installed** 탭 → `elasticore` → **Update now**. 자동으로 받으려면 `/plugin` → **Marketplaces** 탭 →
`elasticore-agent-kit` → **Enable auto-update**. 그러면 세션을 시작할 때 업데이트되고, 다음 세션부터 새 버전이 적용됩니다.

## 측정: 같은 과제를 kit 없이, kit과 함께

세 에이전트에 과제 - 도서·회원·대출, 남은 권수가 없으면 409, 반납 동작이 있는 도서 대출 API - 를 과제 그대로 한 번, kit과
함께 "ElastiCORE로 만든다"를 더해 한 번 주었습니다. 실행에 관여하지 않은 별도의 Claude Code 에이전트가 프로젝트마다 직접
빌드·실행·호출해 같은 21개 항목으로 채점했습니다. 조건당 실행 한 번, 우리가 직접 돌렸습니다 (2026-10-20/21, Windows PC 한 대,
Gradle 빌드 시간 포함, kit 0.3.0, Codex CLI 0.163.0).

| 에이전트 | kit 없이 | kit과 함께 |
|---|---|---|
| Claude Code, Sonnet | 4분 41초, 21점 중 20.5 | 2분 18초, 21점 중 20.5 |
| Codex CLI, `gpt-5.6-sol` | 7분 13초, 21점 중 21 | 3분 45초, 21점 중 21 |
| opencode, 작은 로컬 모델(`qwen3.8-flash-next-a5b`) | 네 번 시도해 최종 보고 없음 (최고 21점 중 19.5, README 없음) | 11분 42초, 21점 중 21 |

kit 없이는 에이전트가 엔티티·DTO·리포지토리·서비스·컨트롤러·오류 처리기를 전부 손으로 씁니다. kit과 함께면 같은 에이전트가
27줄짜리 YAML 하나와 레시피가 주는 서비스 메서드·컨트롤러 하나를 쓰고 나머지는 생성기가 합니다: Claude Code는 모델 호출
16번 대신 10번에 끝내고 읽은 컨텍스트가 3분의 1 줄었고, Codex는 29번 대신 24번.

표를 읽을 때 둘을 함께 봐야 합니다. kit의 도서관 레시피는 첫 실행 뒤에 바로 이 과제에서 썼으므로, kit과 함께 한 실행은 과제의
영역에 맞는 레시피를 갖고 있었고 그 27줄 YAML을 그대로 썼습니다. 그런 레시피가 없던 첫 실행(kit 0.2.0)은 Claude Code가 7분
47초에 20.5점 - kit 없이보다 느렸고 - 이것이 kit에 레시피가 없는 과제의 수치입니다. 그 실행이 아직 Java로 써야 했던 것이
ElastiCORE 3.0.261021의 DSL 추가 다섯 가지가 되었고, 3.0.261022-rc1 부터 Maven Central에 있습니다. 3.0.261020-alpha2
에서는 레시피가 대신 손으로 쓸 것을 안내합니다.

과제 원문, 채점표, 실행 스크립트, 토큰 수, 에이전트마다 한 일, 이전 실행, 유의할 점 전부는
[benchmarks/library](benchmarks/library/README.ko.md)에 있습니다.

## 들어 있는 것

| 구성 | 하는 일 |
|---|---|
| skill `elasticore` | ElastiCORE 프로젝트에서 일하거나 새로 시작할 때 불려 옵니다. 생성기가 소유하는 파일을 알고, 한 장짜리 DSL 요약과 레시피 둘, 실행·확인 페이지를 갖고 있으며, 변경이 들어갈 자리, 먼저 물어볼 일, 보고 방법을 말합니다. 요약과 레시피의 내용은 계약 테스트가 생성·빌드·호출해 확인하고, 그 밖의 것은 ElastiCORE가 프로젝트에 복사해 둔 가이드를 읽게 합니다. |
| hook | 생성 파일 수정과 `-Pforce` 실행을 막고, DSL을 고친 뒤 실행할 것을 알려 주고, 생성기 경고를 전하고, 성공한 빌드로 생성·컴파일되지 않은 DSL 변경을 둔 채 끝내지 않게 합니다. |
| agent `elasticore:modeler` | 요구사항을 생성·컴파일이 되는 DSL 변경으로 바꾸고, 업무 말로 보고합니다. |
| agent `elasticore:reviewer` | 변경을 검토합니다: 생성 파일 손수정, 가이드나 생성기가 모르는 DSL, DSL과 어긋난 생성 코드, 어느 역할이 접근을 얻고 잃는지. |
| `/elasticore:generate [태스크]` | 다시 생성하고 컴파일한 뒤 경고·건너뛴 파일·오류를 DSL 고치는 법과 함께 설명합니다. |
| `/elasticore:change-report [범위]` | DSL 변경이 업무에 뜻하는 것과 결정이 필요한 것을 씁니다. |
| `/elasticore:review [범위] [full]` | 커밋하지 않은 변경이나 지정한 범위를 reviewer로 검토합니다. 읽기만 하고, `full`을 붙이면 빌드까지 합니다(파일이 다시 생성됨). |

### hook

| 언제 | 무슨 일 |
|---|---|
| 편집 도구로 생성 파일을 고치려 할 때 - 첫 줄이 `//ecd:`이고 `// Initially generated by ElastiCORE;` 줄도 보존 블록도 없는 파일 | 막고, 대신 어디를 고쳐야 하는지 알려 줍니다. 보존 블록(`// !----------` ... `// ------------!`) 하나를 통째로 넣는 수정은 허용 |
| 생성할 때마다 다시 쓰는 파일을 고치려 할 때 - `blueprint/schema.yml`, 복사된 가이드, 기본 `i18n/<도메인>-messages.properties`, 생성된 `orm.xml`(이 둘은 `.elasticore/cache`가 없을 때) | 막습니다 |
| `.elasticore/cache`가 있는 프로젝트(ElastiCORE 3.0.261030-rc5부터: `//ecd:` 줄 없이 생성하고, 고친 내용에 DSL의 변경을 병합)의 생성 파일을 고칠 때 - 메시지 파일과 `orm.xml`도 | 허용합니다: 고친 내용은 남습니다. DSL이 먼저이고, DSL도 바꾸는 줄을 고치면 충돌 표시와 함께 빌드가 멈춘다고 세션마다 한 번 알려 줍니다 |
| 빌드가 병합 `CONFLICT`, 그대로 둔 개발자 파일 `KEPT(yours ...)`, `SKIP(not in the cache)`를 알릴 때 | 충돌 표시를 푸는 법(파일이나 캐시를 지워서 넘어가지 않기), 손으로 옮길 것, 언제 물어볼지를 알려 줍니다 |
| 보존 블록이 있는 생성 파일을 고칠 때 | 허용하되, 블록 안만 재생성 뒤에도 남는다고 알려 줍니다 |
| Gradle을 `-Pforce`로 실행하거나 다른 방법(`-P force`, `ORG_GRADLE_PROJECT_force` 등)으로 그 속성을 줄 때 | 막습니다: 손으로 고친 내용을 덮어씁니다. 결정은 사용자가 합니다 |
| `src/main/resources/blueprint/<도메인>/`의 모델을 고쳤을 때 | 끝내기 전에 `./gradlew compileJava`를 돌리고 경고를 고치라고 알려 줍니다. 2.x 생성기를 쓰는 빌드(`elasticore { output = 'v2' }`, 또는 ElastiCORE 3.0.261028-rc3 전의 `elasticore { }` 블록 없는 빌드)면 접근 규칙·생명주기·계산 값을 무시한다는 것도 알려 줍니다 |
| Gradle 빌드(성공이든 실패든) 출력에 DSL 검증 경고, 읽지 못한 YAML 파일, 손으로 고친 생성 파일이 나올 때 | 그 뜻과 할 일을 알려 줍니다 |
| 성공한 빌드로 생성·컴파일되지 않은 DSL 변경을 둔 채 끝내려 할 때 | 한 번 돌려보내 빌드하게 합니다. 백그라운드 빌드, 잘리거나 걸러진 출력, 생성만 한 실행은 빌드로 치지 않습니다 |

hook은 편집 도구와, Bash나 PowerShell로 돌린 Gradle 실행을 봅니다. 성공한 명령의 출력이 너무 길어 Claude Code가 넘기지 못하면 저장해 둔
파일에서 읽습니다. 실패한 명령은 Claude Code가 앞 10,000자만 넘기므로, 아주 큰 프로젝트에서는 경고가 그 뒤에 있어 hook이 못 볼 수 있습니다.
셸에서 스크립트를 돌려 고치는 것은 막지 못하며, skill이 그렇게 하지 말라고 안내합니다.

그래도 생성 파일을 고치게 하려면 `ELASTICORE_ALLOW_GENERATED_EDITS=1`, `-Pforce`를 허용하려면 `ELASTICORE_ALLOW_FORCE=1`을
설정합니다. 예: `.claude/settings.local.json`

```json
{ "env": { "ELASTICORE_ALLOW_GENERATED_EDITS": "1" } }
```

## ElastiCORE 변화 따라가기

- **kit에는 DSL 문서의 사본을 두지 않습니다** - 한 장짜리 요약과 레시피만 있고, 그것은 계약 테스트가 최신 릴리스에 대해 확인합니다.
  전체 가이드는 ElastiCORE가 생성할 때마다 그 프로젝트가 쓰는 버전의 것을 `src/main/resources/blueprint/`에 복사하는 것이고,
  요약에 없는 것은 skill이 Claude를 그곳으로 보냅니다. 프로젝트가 ElastiCORE를 올리면 Claude는 새 가이드를 읽습니다. 가이드는
  한국어이고, kit의 페이지는 영어입니다.
- **kit이 기대는 ElastiCORE 동작은 실제 빌드로 검사합니다.** 새 프로젝트 템플릿과 예제, 파일 표시, 두 생성기의 상태 문구와 경고
  머리말, 가이드 이름, Gradle 태스크, 띄운 애플리케이션의 응답을 [`tests/contract/check.py`](tests/contract/check.py)가 확인합니다.
  Maven Central의 최신 ElastiCORE 3로 템플릿·예제·2.x 생성기 프로젝트를 만들어 생성하고, 고치고, 일부러 망가뜨리고, 되돌리고,
  띄워 봅니다. CI가 변경마다, 그리고 매주 월요일에 돌리고, 실패하면 깨진 가정과 kit에서 그 가정을 적은 곳을 알려 줍니다.

## 개발

```bash
bash tests/hooks/test-hooks.sh                     # Claude Code가 보내는 JSON으로 hook 스크립트 검사 (HOOK_BASH=/bin/bash로 셸 지정)
python3 tests/contract/check.py                    # PATH에 JDK 17, Gradle 8.14 이상
claude plugin validate ./plugins/elasticore --strict
claude plugin validate . --strict
claude --plugin-dir ./plugins/elasticore           # 작업 중인 플러그인을 ElastiCORE 프로젝트에서 시험
```

`ELASTICORE_VERSION=3.0.261015-alpha1 python3 tests/contract/check.py`로 특정 릴리스를 검사합니다.
`-SNAPSHOT`으로 끝나는 버전은 로컬 Maven 저장소에서도 찾으므로, `publishToMavenLocal`로 올린 ElastiCORE 빌드를 릴리스 전에 검사할 수 있습니다.
도서관 레시피의 계약은 3.0.261021 이상에서 돌고, 그보다 오래된 버전에서는 요약 줄에 건너뛴 수로 셉니다.

## 라이선스

[Apache License 2.0](LICENSE)
