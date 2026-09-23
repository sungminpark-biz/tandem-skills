# tandem-skills

**설계와 리뷰는 Claude, 코드는 Grok.** Claude Code와 Grok Build를 위한 교차 모델 에이전트 팀 스킬.

[English README](README.md)

탠덤 자전거처럼 — 한 명은 방향을 잡고, 한 명은 페달을 밟습니다. 저장소에서 Claude Code를 열고
`/team <작업>`이라고 치면:

```
Claude가 설계 초안 작성
  → Grok이 적대적으로 검토 (저장소를 직접 읽고 설계를 깨뜨리려 시도)
  → Claude가 항목별로 근거를 들어 반박/수용하고 문서 수정      (최대 2라운드)
  → ★ 사람이 설계 승인 ★
  → Grok이 구현 (자기 터미널 탭에서 도는 감독받는 워커)
  → Claude가 diff 리뷰 + 테스트 재실행                          (최대 3라운드)
  → Grok이 수정 → 보고
```

서비스를 처음부터 만드나요? `/team foundation <서비스>`가 먼저 서비스 정본(charter), 되돌리기 비싼
결정, 슬라이스 지도를 정하고 — 그다음 슬라이스마다 위의 루프를 돕니다.

MCP도, 데몬도 없습니다. `claude -p`와 `grok`을 헤드리스로 부르는 셸 스크립트 2개와, 두 에이전트가
이미 읽을 줄 아는 `SKILL.md` 2개가 전부입니다. 기본 경로는 Grok을 [Orca](https://github.com/stablyai/orca)
워커로 띄웁니다. Orca가 없으면 Grok 주도 대체 경로는 스크립트만으로 동작합니다.

## 왜

단일 모델 에이전트는 자기 숙제를 자기가 채점합니다. 모든 모델에는 맹점이 있고, 그걸 잡는 가장
싼 방법은 파일 접근 권한과 반대할 동기를 가진 *다른* 모델입니다. 기존 교차 모델 도구는 API로
한 번 "2차 의견"을 받거나(저장소 접근 없음, 왕복 없음) 라이브 세션 두 개를 잇는 브리지 데몬이
필요합니다. 이 프로젝트는 그 중간입니다: 모델들이 라운드로 논쟁하고 `파일:라인`을 인용하며,
코드 한 줄이 쓰이기 전에 사람이 설계를 승인합니다.

기본 드라이버가 Claude인 이유: 설계는 설계자가 어떤 환경에서 도는지가 가장 크게 작용하는 단계입니다.
대화형 Claude Code 세션에는 MCP 서버, 웹 검색, 프로젝트 메모리, 그리고 질문에 답하고 승인해 줄
사용자가 있습니다. 헤드리스 설계 호출에는 웹 검색도, 물어볼 사람도 없고, 권한 설정이 허용하는 것만 닿습니다.

## 구성

| 스킬 | 드라이버 | 하는 일 |
|---|---|---|
| `/team` | Claude (또는 Grok) | 기능 모드: 위의 설계 → 적대 검토 → 승인 → 구현 → 코드 리뷰 루프. 기초 설계 모드: 첫 슬라이스 전에 정본 → 결정 기록 → 슬라이스 지도 → 적대 검토 → 승인 |
| `/debate` | Claude | Claude가 초안, Grok이 라운드로 비판(읽기 전용), Claude가 각 항목을 코드로 검증해 합의안 보고. 설계 결정에 단독으로 사용. Claude가 주도하는 `/team`의 모든 적대 검토는 이 스킬의 `grok-turn.sh`를 (자체 검토 형식으로) 재사용 |

두 스킬이 양방향으로 동작하는 이유: **Grok Build가 `~/.claude/skills/`를** (그리고
`~/.claude/CLAUDE.md`를) 그대로 읽기 때문입니다 — `grok inspect`로 확인.

## 요구사항

- [Claude Code](https://code.claude.com) ≥ 2.1 (`claude` PATH, 로그인)
- [Grok Build](https://x.ai/cli) ≥ 1.0 (`grok` PATH, 로그인)
- `jq`, `git`, `uuidgen` (또는 python3)
- [Orca](https://github.com/stablyai/orca) — 기본 기능 경로에서 필요 (Grok이 터미널 탭이 보이는 Orca
  워커로 실행됨). 기초 설계 모드와 Grok 주도 대체 경로는 없어도 동작

Claude Code 2.1.273–2.1.280 (Claude Opus 5), Grok Build 1.0.30–1.0.40, macOS에서 테스트.

## 설치

```bash
git clone https://github.com/sungminpark-biz/tandem-skills.git
cd tandem-skills && ./install.sh          # skills/ 를 ~/.claude/skills/ 로 복사
# 또는: ./install.sh --link        # 심볼릭 링크 — git pull 하면 바로 반영
```

확인:
```bash
grok inspect        # Skills: team, debate  [claude]
claude              # /team 또는 /debate 입력
```

## 사용법

### 기능 (기본)

Orca 워크트리 안의 Claude Code에서:

```
/team auth 서비스에 refresh-token 로테이션 추가
```

Claude가:
1. `docs/design/<날짜>-<slug>.md` 작성 (범위, 시그니처, 순서, 완료 기준, 일부러 안 만드는 것)
2. `grok-turn.sh`로 Grok의 적대 검토를 받고 (치명 / 누락 / 모호, 근거 첨부) 항목별로 코드를 확인해 문서 수정 또는 반박
3. **멈추고 요약을 보여줌 — "승인"이라고 할 때까지 아무것도 구현하지 않음**
4. Grok을 Orca orchestration 워커로 띄우고(`worker-start --agent grok`) 질문에 답함
5. diff 리뷰 + 테스트 재실행, 승인될 때까지 같은 워커에게 수정 지시 (최대 3라운드)
6. 보고: 검토로 바뀐 것, 변경 파일, 테스트, 비용

Orca가 없으면? Claude가 1~3단계까지 하고, Grok Build에서 `/team implement <설계 문서>`를 실행하라고 안내합니다.

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
4. 기초 설계 전체에 대해 Grok의 적대 검토 (모순, 빠졌거나 잘못 분류된 결정, 설계 상한 대비 과설계)
5. **승인을 받으려고 멈춤**, 그다음 S1을 일반 기능으로 진행

기초 설계 문서가 정본입니다: 기능 설계는 이를 인용만 하고 덮어쓰지 않습니다. 슬라이스에서 결정이
틀렸다고 드러나면 그 슬라이스를 멈추고, 대체하는 결정 기록을 새로 써서 검토·승인한 뒤 재개합니다.

### Grok 주도 (대체 경로)

아무 git 저장소에서 Grok Build를 열고:

```
/team auth 서비스에 refresh-token 로테이션 추가
```

Grok이 Claude를 헤드리스로 불러(`claude-turn.sh`; `docs/design/**`만 쓰기 가능, `docs/design/foundation/`은 제외) 설계를 받고, 직접 적대
검토한 뒤 Claude에게 돌려보내고, 승인을 기다렸다가 구현하고, `APPROVE`가 나올 때까지 Claude에게 diff
리뷰를 요청합니다.

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

모델이 "잘 행동하겠다"는 약속에 기대지 않습니다:

| 모드 | 권한 | 효과 |
|---|---|---|
| `claude-turn.sh design` | `--permission-mode dontAsk` + `Write(docs/design/**)`, `Edit(docs/design/**)` (`docs/design/foundation/**` 제외), Bash 허용 규칙 없음, 변경 git/셸 명령 거부 | 설계문서만 쓸 수 있음. Bash는 Claude Code가 읽기 전용으로 판정한 것만 실행 — `git stash`, `git branch`, `touch`, `>` 리다이렉트는 거부 |
| `claude-turn.sh review` | `dontAsk` + `Bash` 허용, `Write`/`Edit`와 `git commit/checkout/reset`, `rm`, `mv`, `sed -i`… 거부 | 테스트는 돌리되 파일은 못 바꿈 |
| `grok-turn.sh` | `--permission-mode plan` | Grok 읽기 전용 |
| 승인 게이트 | 스킬 규칙 | 설계(그리고 기초 설계) 확정 후 드라이버는 턴을 끝내고 기다려야 함 |

실전에서 나온 디테일:
- 세션 id를 **실행 전에** 정해 프롬프트 파일 옆(`/tmp/team/<slug>/last-claude-session`, `/tmp/team/<slug>/last-grok-session`)에 기록 → 죽거나 타임아웃된 호출을 탐색 컨텍스트째로 resume 가능, 동시에 도는 작업끼리 덮어쓰지 않음
- 턴 한도 도달(Claude `error_max_turns`, Grok `"maxTurns": true`) → 같은 세션 resume, 절대 새로 시작하지 않음
- 설계 프롬프트에 "뼈대 먼저, 그다음 채우기"와 도구 호출 상한 — 없으면 Opus(high effort)는 한 글자도 안 쓰고 20분 넘게 탐색함
- Grok 주도 경로에서는 설계 수정과 모든 코드 리뷰가 같은 Claude 세션을 resume → 리뷰어가 자기가 쓴 설계를 기억

## 비용·시간 (실제 실행 기준)

새 Next.js 고객 앱 Phase 1 (30 파일, 테스트 7파일 23개), Grok 주도:
Claude 약 $7 (설계 + 리뷰 2라운드, Opus 5, 타임아웃된 설계 시도 1회 포함), Grok 약 55분. 큰 범위의 설계 호출은 20~40분.
Grok 적대 검토 한 턴은 약 $0.25~0.4.

## 한계

- Grok은 Claude의 **프로젝트 메모리를 받지 못함**; `CLAUDE.md`만. 그래서 설계·리뷰가 Claude 담당.
- 사용자 자신의 Claude Code 설정에 있는 허용 규칙은 헤드리스 호출에도 그대로 적용됨 (`dontAsk`는 아무것도 허용하지 않는 것만 거부). 스크립트의 거부 목록이 이름 붙인 명령에 한해 그보다 우선함 — 사용자 설정에 프로덕션에 닿는 허용(예: `kubectl exec`)이 있는지 확인하세요.
- review 모드 Bash 차단 목록은 완전하지 않음 (`>` 리다이렉트, `python -c`는 여전히 쓸 수 있음). 프롬프트 뒤의 2차 방어선이지 샌드박스가 아님.
- 승인 게이트는 모델 준수 문제이지 하드 블록이 아님.
- 기본 기능 경로는 Orca 필요. 기초 설계 모드와 Grok 주도 대체 경로는 어디서든 동작.
- 기초 설계 모드는 새로 추가되어 아직 전체 실행 전 — 첫 실행을 지켜보세요.
- Claude 주도 실행에서 Grok 워커가 자기 편집 승인 프롬프트에서 멈출 수 있음; 스킬이 Claude에게 푸는 법을 알려 주지만 탭을 지켜보세요.

## 구조

```
skills/
  team/SKILL.md          워크플로 (0: 모드와 경로, F: 기초 설계, C: Claude 주도, G: Grok 주도)
  team/claude-turn.sh    헤드리스 Claude: design | review   (Grok 주도 경로)
  debate/SKILL.md        논의 루프
  debate/grok-turn.sh    헤드리스 Grok: 읽기 전용 비평가     (Claude가 주도하는 모든 적대 검토)
install.sh
```

## 라이선스

MIT
