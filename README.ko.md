# tandem-skills

**설계와 리뷰는 Claude, 코드는 Sonnet 워커.** Claude Code를 위한 에이전트 팀 스킬.

[English README](README.md)

탠덤 자전거처럼 — 한 명은 방향을 잡고, 한 명은 페달을 밟습니다. 저장소에서 Claude Code를 열고
`/team <작업>`이라고 치면:

```
Claude가 설계 초안 작성
  → 읽기 전용 Claude 리뷰어가 설계를 깨뜨리려 시도 (저장소를 직접 읽고 파일:라인 인용)
     결제·DB 마이그레이션·고객 데이터·인증이면 위험 전담 리뷰어가 함께 검토
  → Claude가 항목별로 근거를 들어 반박/수용하고 문서 수정      (최대 2라운드)
  → ★ 사람이 설계 승인 ★
  → Claude Sonnet 워커가 구현 (자기 터미널 탭에서 도는 감독받는 Orca 워커)
  → 리뷰어가 설계 대비 diff 검토 + Claude가 테스트 재실행 + ponytail-review로 과설계 점검
                                                                  (최대 3라운드)
  → 같은 워커가 수정 → 보고
```

서비스를 처음부터 만드나요? `/team foundation <서비스>`가 먼저 서비스 정본(charter), 되돌리기 비싼
결정, 슬라이스 지도를 정하고 — 그다음 슬라이스마다 위의 루프를 돕니다.

MCP도, 데몬도, 스크립트도 없습니다. `SKILL.md` 2개와 리뷰어 서브에이전트 하나가 전부입니다. 구현자는
[Orca](https://github.com/stablyai/orca) 워커로 띄웁니다. Orca가 없으면 승인된 설계를
`claude --model sonnet`에서 구현한 뒤 리뷰를 받으러 돌아오면 됩니다.

> 이전 버전은 Claude와 Grok을 짝지었습니다(Grok이 구현과 교차 검토). 그 구성은 git 이력의 `5e159ff`까지에
> 남아 있습니다.

## 왜

한 컨텍스트에서 설계하고, 만들고, 자기 작업을 채점하는 에이전트는 자기 실수를 잘 못 찾습니다. 그래서
역할을 나눕니다. 드라이버(MCP 서버, 웹 검색, 프로젝트 메모리, 그리고 사용자가 함께 있는 대화형 Claude Code
세션)가 설계하고, 새 컨텍스트에서 편집 권한 없이 반대하는 게 임무인 리뷰어가 설계를 공격하고, 코드 한 줄이
쓰이기 전에 사람이 승인하고, 별도의 워커가 구현하고, 그 코드를 작성한 모델과 다른 모델의 리뷰어가 설계 대비로
검토합니다.

## 구성

| 스킬 | 하는 일 |
|---|---|
| `/team` | 기능 모드: 위의 설계 → 적대 검토 → 승인 → 구현 → 코드 리뷰 루프. 기초 설계 모드: 첫 슬라이스 전에 정본 → 결정 기록 → 슬라이스 지도 → 적대 검토 → 승인 |
| `/debate` | Claude가 초안을 쓰고, 다른 모델(드라이버가 Opus면 Sonnet)의 읽기 전용 반론자가 라운드로 공격하고, Claude가 각 항목을 코드로 검증해 합의안 보고. 설계 결정에 단독으로 사용 |

## 요구사항

- [Claude Code](https://code.claude.com) (`claude` PATH, 로그인; 테스트한 버전은 아래)
- [ponytail](https://github.com/DietrichGebert/ponytail) — Claude Code에 필요. 없으면 `/team`이 시작하지
  않음 (설치 참고)
- [Orca](https://github.com/stablyai/orca) — 터미널 탭이 보이는 감독받는 Sonnet 워커에 필요. 없으면
  `claude --model sonnet`에서 직접 구현하고 리뷰를 받으러 돌아오면 됨. 설계·리뷰·기초 설계 모드는 없어도 동작
- 권장: [context7](https://github.com/upstash/context7) 플러그인 — 설계의 최신성 확인용
  (`/plugin install context7@claude-plugins-official` 후 `/mcp`로 한 번 로그인)

Claude Code 2.1.273–2.1.286 (Claude Opus 5 / 5.5 드라이버, Sonnet 5.5 워커), Orca 1.4.204–1.4.215,
macOS에서 테스트.

## 설치

```bash
git clone https://github.com/sungminpark-biz/tandem-skills.git
cd tandem-skills && ./install.sh          # skills/ 를 ~/.claude/skills/ 로, team-reviewer
                                          # 서브에이전트를 ~/.claude/agents/ 로 복사
# 또는: ./install.sh --link        # 심볼릭 링크 — git pull 하면 바로 반영
```

ponytail (필수) — Claude Code에서 프롬프트 두 번에 나눠서:
```
/plugin marketplace add DietrichGebert/ponytail
/plugin install ponytail@ponytail
```

확인: 새 Claude Code 세션을 열고 `/team` 또는 `/debate`를 입력.

## 사용법

### 기능 (기본)

Orca 워크트리 안의 Claude Code에서:

```
/team auth 서비스에 refresh-token 로테이션 추가
```

Claude가:
1. `docs/design/<날짜>-<slug>.md` 작성 (범위, 시그니처, 순서, 완료 기준, 일부러 안 만드는 것)
2. 읽기 전용 `team-reviewer` 서브에이전트에게 적대 검토를 받고(치명 / 누락 / 모호, 근거 첨부) — 결제, DB
   스키마·마이그레이션, 고객 데이터, 인증이면 위험 전담 리뷰어도 함께 — 항목별로 코드를 확인해 문서 수정 또는 반박
3. **멈추고 요약을 보여줌 — "승인"이라고 할 때까지 아무것도 구현하지 않음**
4. Orca에 Claude Sonnet 워커를 띄우고(`worker-start --spec … --agent claude --model sonnet`) 질문에 답함.
   워커는 설계 범위 안에서 ponytail로 코드를 씀
5. diff 리뷰(Spec 체크: 누락, 요청 안 한 것, 잘못 구현 — 각각 설계 문서 인용) + 워커 보고를 믿지 않고
   테스트를 직접 재실행 + `ponytail-review`, 승인될 때까지 같은 워커에게 수정 지시 (최대 3라운드)
6. 보고: 검토로 바뀐 것, 변경 파일, 테스트

깔끔하게 나뉘는 기능은 병렬 청크로 돌릴 수 있습니다 — 청크마다 Sonnet 워커 하나, 각 청크가 맡는 파일과
청크 사이 계약은 설계 문서에 적습니다. "너가 직접 구현해"라고 하면 워커 대신 Claude가 직접 구현하고, 리뷰
단계는 똑같습니다. `sonnet`은 별칭이어서 워커가 항상 최신 Sonnet을 따라갑니다.

Orca가 없으면? Claude가 1~3단계까지 하고, `claude --model sonnet`에서 설계를 구현한 뒤 리뷰를 받으러
돌아오라고 안내합니다.

ponytail은 워크플로의 일부입니다. 그 사다리(필요한가? → 재사용 → 표준 라이브러리 → 네이티브 → 한 줄)가 설계가 제안하는
것과 코드 작성 방식을 정하고, `ponytail-review` 삭제 목록은 모든 코드 리뷰에서 돌며 Claude가 걸러서 반영합니다. 상시
모드는 켜 둬도 됩니다. team 프로세스와 부딪히는 곳에서는 team 규칙이 이깁니다 — 설계 문서의 모든 섹션은 빠짐없이 쓰고,
승인 게이트는 건너뛰지 않으며, 구현자는 설계에 있는 것을 빼기 전에 먼저 묻습니다.

### 기초 설계 (서비스를 처음부터)

Claude Code에서:

```
/team foundation 셀러와 바이어가 각자 쓰는 메신저로 거래하는 B2B 도매 마켓
```

Claude가:
1. 사용자와 함께 `docs/design/foundation/charter.md` 초안 작성 — 누가, 핵심 흐름, 성공/실패 신호,
   설계 상한, 하지 않는 것. 모르는 건 전부 질문으로 바꾸고, 사업 판단은 사용자가 정함
2. 되돌리기 비싼 결정마다 기록 하나 (`decisions/NNN-<slug>.md`: 데이터 모델, 식별, 외부 연동,
   돈 흐름, 런타임…) — 버린 선택지와 날짜가 찍힌 출처 포함
3. `slices.md` 작성: S1은 모든 결정을 끝에서 끝까지 한 번씩 거치는 가장 얇은 뼈대, 그다음은 위험 순서,
   각각 기능 모드 한 번에 끝나는 크기
4. 기초 설계 전체에 대해 리뷰어와 위험 전담 리뷰어의 적대 검토 (모순, 빠졌거나 잘못 분류된 결정, 설계 상한
   대비 과설계)
5. **승인을 받으려고 멈춤**, 그다음 S1을 일반 기능으로 진행

기초 설계 문서가 정본입니다: 기능 설계는 이를 인용만 하고 덮어쓰지 않습니다. 슬라이스에서 결정이
틀렸다고 드러나면 그 슬라이스를 멈추고, 대체하는 결정 기록을 새로 써서 검토·승인한 뒤 재개합니다.

### 논의만

```
/debate 세션 저장소를 Redis에서 Postgres로 옮겨야 할까?
```

## 설계 품질 기준

설계 단계는 네 가지 규칙을 지키고, 적대 검토가 각각을 확인합니다: **재작성 전에 재사용**(기존 자산 인벤토리
먼저), **오늘 날짜 기준 최신**(플랫폼의 현재 권장 방식을 근거와 함께; 인증·큐·cron 은 손수 짜지 말고 플랫폼
기본 기능), **추측 대신 측정**(읽기 전용 DB·인프라 수치; 새 서비스는 정본의 설계 상한), **오버엔지니어링 금지**
(모든 구성요소를 실측 규모로 정당화, 일부러 안 만든 것을 문서에 명시).

## 안전장치

| 대상 | 방식 | 효과 |
|---|---|---|
| 리뷰어와 debate 반론자 | `team-reviewer` 서브에이전트: `Write`, `Edit`, `NotebookEdit` 금지 | 편집 도구가 없음. 저장소를 읽고 명령을 실행 (Bash는 sandbox가 아님 — 한계 참고) |
| 워커 | Orca 워커 지시서: 설계의 변경 범위, "커밋 금지", 질문은 Orca의 `ask`로 | 변경이 승인된 범위 안에, 커밋되지 않은 채로 리뷰를 기다림 |
| 승인 게이트 | 스킬 규칙 | 설계(그리고 기초 설계) 확정 후 드라이버는 턴을 끝내고 기다려야 함 |

실제 실행에서 나온 세부 사항:
- 설계 방법은 "뼈대를 먼저 쓰고 채워라"라고 하고 도구 호출 수를 제한합니다 — 높은 effort의 Opus는
  그러지 않으면 한 글자 쓰기 전에 20분 넘게 탐색합니다.
- 리뷰어는 기본 `Plan` 에이전트가 아니라 커스텀 서브에이전트입니다. `Plan`은 한 번 실행하고 끝나서(agent ID
  없음) 2라운드 검토를 보낼 수 없고, `CLAUDE.md`도 읽지 않습니다.
- Orca는 `You have N orchestration message…` 알림을 드라이버 터미널에 사용자 입력처럼 넣습니다. 스킬은
  드라이버가 그래도 사용자의 언어로 답하게 합니다.

## 한계

- 리뷰어, 반론자, 워커가 모두 Claude 모델입니다. 코드 리뷰는 항상 모델을 건너가지만(Opus가 Sonnet의 코드를,
  Sonnet이 Claude가 직접 짠 코드를 검토), 다른 회사 모델의 시각은 더 이상 없습니다.
- 리뷰어의 Bash는 sandbox가 아닙니다. "리뷰만, DB·외부 서비스에 쓰지 말 것"은 프롬프트 규칙입니다. 운영
  환경에 닿는 Claude Code 허용 규칙이 있는지 확인하세요.
- 승인 게이트는 모델이 지키는 규칙이지, 하드 블록이 아닙니다.
- 감독받는 워커는 Orca가 필요합니다. 없으면 `claude --model sonnet`에서 직접 구현합니다. 설계·리뷰·기초
  설계 모드는 어디서든 동작합니다.
- 기초 설계 모드는 새로 추가되어 아직 전체 실행 전 — 첫 실행을 지켜보세요.
- 워커가 사람만 답할 수 있는 프롬프트(plan 모드 진입, 질문 카드)에서 멈출 수 있음. 스킬이 `worker-show`의
  `agentWait`로 감지해 답하지만 탭을 지켜보세요.
- Claude Code가 아직 신뢰하지 않은 폴더에서 Claude(Sonnet) 워커를 띄우면 폴더 신뢰 확인 창에서 종료됨 (기본
  선택이 "No, exit"). 드라이버가 도는 워크트리에서는 문제없고, 다른 위치라면 먼저 그곳에서 `claude`를 한 번
  열어 수락하세요.

## 구조

```
skills/
  team/SKILL.md          워크플로 (0: 모드와 경로, 공통 규칙과 템플릿, C: 기능 모드)
  team/foundation.md     F: 기초 설계 모드   (그 경로를 탈 때만 읽음)
  debate/SKILL.md        논의 루프
agents/
  team-reviewer.md       /team과 /debate용 읽기 전용·재개 가능한 리뷰어/반론자 서브에이전트
install.sh
```

## 라이선스

MIT
