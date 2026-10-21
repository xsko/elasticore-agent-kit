# 같은 과제, 세 에이전트, kit 없이와 kit과 함께

kit은 코딩 에이전트가 Spring Boot 과제를 하는 방식을 얼마나 바꾸는가? 세 에이전트에 같은 과제를 두 번 주었습니다 - 한 번은
과제 그대로, 한 번은 kit과 함께 "ElastiCORE로 만들라"는 한 줄을 더해서. 별도의 채점자가 프로젝트마다 직접 빌드·실행·호출해
같은 21개 항목으로 확인했습니다. 이 폴더에 과제, 채점표, 실행 스크립트, 수치를 두어 읽고 다시 돌릴 수 있게 했습니다.

[English](README.md)

## 조건

- **과제:** 도서 대출 API - [task.ko.md](task.ko.md)(에이전트가 받은 원문) / [task.md](task.md)(영문). 13자리 ISBN이 키인
  도서, 이메일이 유일하고 가입일은 서버가 정하는 회원, 대출일·반납 예정일을 서버가 정하는 대출, 남은 권수가 없으면 409,
  반납이라는 업무 동작, "아직 반납 안 된 것" 검색, 400/404/409 응답, API를 적은 README. **kit의 도서관 레시피는 바로 이
  과제의 모델과 코드입니다** - 첫 실행이 보여 준 것으로 첫 실행 뒤에 썼습니다. kit 0.3.0과 함께 한 세 실행은 레시피의 27줄
  `entity.yml`을 그대로(셋 다 바이트까지 같게), 그리고 레시피의 서비스 메서드와 컨트롤러를 썼습니다. 그러니 kit과 함께 한 수치는
  kit에 레시피가 있는 과제의 수치이고, 레시피가 없는 과제의 수치는 첫 실행(kit 0.2.0, *이전 실행* 절)입니다.
- **프롬프트 하나, 질문 없음:** 모든 실행은 빈 폴더에서 과제, 자기 포트, "스스로 판단해 진행하라"는 지시로 시작했고, 실행 중에
  답해 주는 사람은 없었습니다. Claude Code와 Codex 실행은 25분 제한이었고(걸린 것은 Codex kit 실행 하나, 그것도 답을 낸 뒤 -
  *이전 실행* 절), opencode 실행은 더 긴 제한이었는데 걸린 실행은 없습니다 - kit 없는 시도들은 멈춘 호출 몇 분 뒤에 스스로
  종료 코드 1로 끝났습니다.
- **실행 조건:**

  | 에이전트 | 실행 방법 | kit을 줄 때 |
  |---|---|---|
  | Claude Code, Sonnet | `claude -p --model sonnet`, 권한 확인 없음, 사용자 설정·MCP 서버 없음 ([run_claude.py](run_claude.py)) | 플러그인 전체를 `--plugin-dir`로: skill, hook, agent, command |
  | Codex CLI 0.163.0, `gpt-5.6-sol`, reasoning low | `codex exec --json`, 샌드박스·승인 없음 ([run_codex.py](run_codex.py)) | skill을 프로젝트의 `.agents/skills/elasticore`에 복사 - skill만. hook은 Claude Code와 opencode의 것 |
  | opencode, `qwen3.8-flash-next-a5b`(로컬 vLLM 서버의 작은 모델) | `opencode run --auto`, 이름으로 프로세스를 끄는 것을 막는 격리 설정 ([run_opencode.py](run_opencode.py)) | skill과 kit의 opencode 플러그인(hook 스크립트를 돌림) |

- **버전:** kit 0.3.0, ElastiCORE 3.0.261021 릴리스 전 빌드(로컬 Maven 저장소에 `3.0.261021-SNAPSHOT`으로 올린 것; 과제가
  그렇게 말함). kit 0.2.0과 ElastiCORE 3.0.261020-alpha2로 한 이전 실행은 *이전 실행* 절에.
- **채점:** [checklist.md](checklist.md), 21개 항목, 항목마다 근거와 함께 PASS / PARTIAL / FAIL; 점수 = PASS + 0.5 x PARTIAL.
  채점자는 실행에 관여하지 않은 별도의 Claude Code 에이전트로, 프로젝트를 직접 빌드하고 그 실행의 포트로 띄워 요청을 보냈습니다.
  에이전트의 최종 보고가 사실과 맞는지(D2 항목)와 규칙 위반 - 다른 포트, 이름으로 끈 프로세스, 켜 둔 서버 - 도 봤습니다.
- **측정:** 에이전트 프로세스 시작부터 종료까지의 벽시계 시간(Claude Code, opencode), Codex는 최종 답까지(이유는 *이전 실행*
  절). 토큰 수는 각 도구의 기록에서: Claude Code의 `result` 이벤트, Codex의 세션 롤아웃(API 호출마다 `token_count`), opencode의
  `step_finish` ([usage.py](usage.py)). "읽은 컨텍스트"는 실행 동안 모델이 읽은 모든 프롬프트 토큰(캐시 적중 포함), "최대"는
  가장 큰 프롬프트 하나.
- **환경:** Windows 11 PC 한 대, Gradle과 의존성은 이미 로컬 캐시에 있는 상태. 첫 실행(kit 없는 실행들, kit 0.2.0)은
  2026-10-20, kit 0.3.0과 Codex 실행은 2026-10-21.

## 결과

| 에이전트 | kit 없이 | kit과 함께 |
|---|---|---|
| Claude Code, Sonnet | 4분 41초, 21점 중 **20.5** | **2분 18초**, 21점 중 **20.5** |
| Codex CLI, `gpt-5.6-sol` | 7분 13초, 21점 중 **21** | **3분 45초**, 21점 중 **21** |
| opencode, `qwen3.8-flash-next-a5b` | 네 번 시도해 최종 보고에 이른 실행 없음. 가장 나은 것은 README 없이 21점 중 19.5 | **11분 42초**, 21점 중 **21** |

| 실행 | 모델 호출 | 읽은 컨텍스트 | 그중 캐시 | 최대 프롬프트 | 생성 토큰 | 비용 |
|---|---|---|---|---|---|---|
| Claude Code, kit 없이 | 16 | 657k | 618k | 56k | 26.0k | $0.48 |
| Claude Code, kit과 함께 | 10 | 437k | 400k | 54k | 7.5k | $0.26 |
| Codex, kit 없이 | 29 | 1,000k | 947k | 47k | 14.6k | (구독) |
| Codex, kit과 함께 | 24 | 859k | 817k | 45k | 9.5k | (구독) |
| opencode, kit 없이 (4회차) | 66 | 1,396k | 0 | 34k | 16.9k | 로컬 |
| opencode, kit과 함께 | 48 | 1,993k | 0 | 62k | 15.2k | 로컬 |

Claude Code가 kit 없이 잃은 0.5점: 최종 보고에서 통합 테스트가 없는 회원뿐 아니라 없는 도서의 404도 확인했다고 했는데, 확인한
것은 회원뿐이었습니다. kit과 함께 잃은 0.5점: README가 jar를 `library-0.0.1-SNAPSHOT.jar`라고 적었는데 빌드는 `library.jar`를
만들었습니다. Codex의 두 보고와 opencode의 kit 실행 보고에서는 채점자가 사실과 다른 주장을 찾지 못했습니다.

## 에이전트마다 한 일

- **Claude Code, kit 없이** (호출 16): 엔티티·DTO·리포지토리·서비스·컨트롤러·오류 처리기를 전부 손으로 쓰고, 빌드하고,
  서버를 띄워 확인하고, README와 테스트를 썼습니다.
- **Claude Code, kit과 함께** (호출 10): skill의 한 장짜리 요약과 도서관 레시피를 읽고, 27줄 YAML 하나를 쓰고, 생성하고,
  레시피가 주는 서비스 메서드 둘과 컨트롤러 하나를 넣고, 빌드하고, 서버를 띄워 요청 열다섯 개를 보내고(잘못된 ISBN 400,
  중복·남은 권수 없음·재반납 409, 없는 회원 404), 프로세스 ID로 서버를 끄고, 확인하지 못한 것까지 적어 보고했습니다.
  가이드도 jar도 열지 않았습니다.
- **Codex, kit 없이** (호출 29): Java 파일 23개를 손으로(테스트 포함). Spring Boot 4에서 옮겨진 `@AutoConfigureMockMvc`를
  찾기까지 빌드 네 번 실패, `~/.gradle`의 jar를 30초 뒤짐. 그다음 빌드, 서버, 확인, README.
- **Codex, kit과 함께** (호출 24): `SKILL.md`와 페이지 넷을 읽고(먼저 `~/.agents/skills`에서 찾느라 읽기 네 번 실패), 레시피의
  27줄 YAML을 쓰고, 생성하고, 레시피의 메서드와 25줄짜리 컨트롤러를 넣고, `--no-daemon` 빌드 한 번, 서버, 400·404·409 둘까지 확인,
  적어 둔 PID로 서버 종료.
- **opencode, kit 없이:** 9~32분짜리 시도 네 번. 모두 돌아오지 않는 셸 호출에 걸려 최종 보고 없이 끝났고, 4회차는 서버를 띄우는
  호출에서 멈췄습니다. 그 4회차는 멈출 때 동작하는 서버가 있어 19.5점을 받았지만 README는 없었습니다.
- **opencode, kit과 함께** (호출 48): skill의 길대로 - YAML, 생성, 레시피의 메서드, 빌드, 서버, 확인, README - 11분 42초에
  21점 중 21.

## 이전 실행과 거기서 바뀐 것

- **kit 0.2.0, ElastiCORE 3.0.261020-alpha2 - 과제에 맞는 레시피가 없던 kit.** Claude Code kit과 함께: 7분 47초, 20.5, 호출 21,
  읽은 컨텍스트 1.1M - kit 없이보다 느렸습니다. kit의 페이지(게시판 레시피 포함)와 생성된 소스를 읽고, DSL에 없는 것을 Java로
  썼습니다: 요청이 덮어쓸 수 있는 서버가 정하는 날짜, "아직 반납 안 된 것" 검색, ISBN 형식 규칙, 중첩된 회원 객체를 보내야 하는
  대출, 자기 메시지가 있는 409. 그것이 ElastiCORE 3.0.261021의 `@readonly`, `@search(isnull)`, `@pattern('re', 'message')`,
  `ref: Entity!`, `ConflictException`이 됐고, 이 과제의 모델과 코드가 kit 0.3.0의 도서관 레시피가 됐습니다.
  opencode kit과 함께: 18분 57초, 19(README 없음, 미반납만 보기 없음), 다시 시도해 34분 2초, 20.
- **kit 0.3.0, Claude Code 첫 실행: 15분 32초, 21.** 그중 10분이 12초 만에 끝난 `sh ./gradlew build` 하나였습니다. Windows에서
  Unix 래퍼 스크립트는 Gradle 데몬을 띄우면 Claude Code의 Bash 도구로 돌아오지 않고(데몬이 도구의 파이프를 물려받음), 호출은
  제한 시간까지 기다렸다가 백그라운드에서 중단됩니다. kit의 페이지가 그 명령(`sh ./gradlew build`)을 쓰라고 안내하고 있었습니다.
  고친 페이지(`./gradlew.bat`, Git Bash에서도)로 같은 실행이 2분 18초.
- **Codex: 답을 낸 뒤에도 프로세스가 살아 있었습니다.** kit과 함께 한 Codex는 3분 45초에 최종 보고를 썼지만 `codex exec`는 25분
  제한에 걸려 멈출 때까지 돌고 있었고, kit 없이는 보고 6분 뒤에 끝났습니다. 셸 호출 안에서 띄운 Gradle 데몬이 그 호출의
  파이프를 붙듭니다: `gradle wrapper --gradle-version 8.14.3`으로 재현(답 16초, 5분 뒤에도 살아 있음), `gradle --no-daemon
  wrapper ...`로는 없음(답과 함께 종료). kit의 페이지는 이제 그 명령에 `--no-daemon`을 붙이라고 안내하고, `run_codex.py`는
  `GRADLE_OPTS=-Dorg.gradle.daemon=false`를 줍니다. 위의 Codex 시간은 세션 롤아웃에서 읽은 최종 보고까지의 시간입니다
  ([timeline_codex.py](timeline_codex.py)).

## 유의할 점

- 도서관 레시피는 첫 실행에서 나온 이 과제의 답입니다. kit과 함께 한 결과는 과제의 영역에 맞는 레시피를 가진 에이전트를 잰
  것이고, 레시피가 없는 경우의 수치는 kit 0.2.0 실행입니다.
- 이 과제가 시험 대상 ElastiCORE 버전의 DSL 추가 다섯 가지를 끌어냈고, 그 버전(3.0.261021)은 아직 Maven Central에 없습니다.
  3.0.261020-alpha2에서는 레시피 마지막 절이 적은 손으로 쓸 검사들이 필요합니다.
- Claude Code kit과 함께의 수치는 첫 실행이 드러낸 문제(돌아오지 않는 Gradle 호출)를 고친 뒤의 두 번째 실행이고, kit 없는
  실행은 한 번뿐입니다.
- 조건당 실행 한 번(opencode kit 없이는 네 번). 실행 간 편차는 재지 않았습니다.
- 비교는 에이전트마다 그 안에서입니다 - 같은 에이전트, 같은 모델로 kit 없이와 kit과 함께. 세 에이전트는 모델·가격·속도가
  다르므로, 이 수치로 에이전트끼리 순위를 매길 수는 없습니다.
- 과제는 하나이고, kit의 레시피가 겨냥하는 종류입니다. DSL로 표현할 수 없는 과제라면 다르게 보일 것입니다.
- 채점자도 AI 에이전트입니다. 항목별 근거(요청, 상태 코드, `file:line`)는 실행마다 남겼고 일부를 직접 확인했지만, 이 저장소에는
  없습니다.
- kit을 만든 쪽이 비교를 돌렸습니다.
- 시간에는 Gradle 빌드가 들어 있고, 의존성은 이미 캐시된 상태였으며, 다른 작업도 하는 PC였습니다.

## 다시 돌리기

Windows(스크립트가 `taskkill`, `netstat`, PowerShell을 씀), 에이전트 설치·로그인, PATH에 JDK 17과 Gradle 8.14 이상, 과제가
말하는 ElastiCORE 버전이 있는 상태에서. 3.0.261021이 Maven Central에 오르기 전에는 직접 빌드합니다:
[xsko/ElastiCORE](https://github.com/xsko/ElastiCORE)를 pull request 4의 머지 커밋(`879716d`)으로 받아
`./gradlew publishToMavenLocal`을 돌리고 `ELASTICORE_VERSION=3.0.261021-SNAPSHOT`을 주면, 스크립트가 에이전트에게 로컬 Maven
저장소를 쓰라고 말합니다.

```bash
cd benchmarks/library
python run_claude.py  C:/tmp/exp plain      18101 25      # 그다음: elasticore 18102
python run_codex.py   C:/tmp/exp plain      18111 25      # 그다음: elasticore 18112
OPENCODE_MODEL=provider/model python run_opencode.py C:/tmp/exp plain 18121 25
python usage.py claude-plain C:/tmp/exp/plain/events.jsonl ...     # 토큰 표
python timeline_claude.py C:/tmp/exp/plain/events.jsonl --sum      # Claude Code 실행의 시간이 어디에 갔는지
python timeline_codex.py  C:/tmp/exp/plain/events.jsonl            # Codex도 같게, 롤아웃에서
```

`ELASTICORE_VERSION`, `KIT_DIR`, `TASK`로 과제가 말하는 버전, 플러그인 폴더, 과제 파일을 바꿉니다. 한 번에 한 조건만 돌리고,
조건마다 다른 포트를 주고, 프로젝트마다 [checklist.md](checklist.md)로 - 에이전트든 사람이든 - 다른 프로젝트를 먼저 보지 않고
채점합니다.
