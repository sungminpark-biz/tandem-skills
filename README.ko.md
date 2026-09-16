# tandem

**설계와 리뷰는 Claude, 코드는 Grok.** Claude Code와 Grok Build를 위한 교차 모델 에이전트 팀 스킬.

[English README](README.md)

탠덤 자전거처럼 — 한 명은 방향을 잡고, 한 명은 페달을 밟습니다. 저장소에서 Grok Build 세션 하나만
열고 `/team <작업>`이라고 치면:

```
Claude가 설계 초안 작성
  → Grok이 적대적으로 검토 (저장소를 직접 읽고 설계를 깨뜨리려 시도)
  → Claude가 항목별로 근거를 들어 반박/수용하고 문서 수정      (최대 2라운드)
  → ★ 사람이 설계 승인 ★
  → Grok이 구현
  → Claude가 diff 리뷰 + 테스트 재실행                          (최대 3라운드)
  → Grok이 수정 → 보고
```

오케스트레이션 서버도, MCP도, 데몬도 없습니다. `claude -p`와 `grok -p`를 헤드리스로 부르는 셸
스크립트 2개와, 두 에이전트가 이미 읽을 줄 아는 `SKILL.md` 2개가 전부입니다.

## 왜

단일 모델 에이전트는 자기 숙제를 자기가 채점합니다. 모든 모델에는 맹점이 있고, 그걸 잡는 가장
싼 방법은 파일 접근 권한과 반대할 동기를 가진 *다른* 모델입니다. 기존 교차 모델 도구는 API로
한 번 "2차 의견"을 받거나(저장소 접근 없음, 왕복 없음) 라이브 세션 두 개를 잇는 브리지 데몬이
필요합니다. 이 프로젝트는 그 중간입니다: 모델들이 라운드로 논쟁하고 `파일:라인`을 인용하며,
코드 한 줄이 쓰이기 전에 사람이 설계를 승인합니다.

## 구성

| 스킬 | 드라이버 | 하는 일 |
|---|---|---|
| `/team` | Grok (또는 Claude) | 위의 설계 → 적대 검토 → 승인 → 구현 → 코드 리뷰 전체 루프 |
| `/debate` | Claude | Claude가 초안, Grok이 라운드로 비판(읽기 전용), Claude가 각 항목을 코드로 검증해 합의안 보고. 설계 결정에 단독으로 쓰거나, Claude 주도 `/team`의 적대 검토에 사용 |

두 스킬이 양방향으로 동작하는 이유: **Grok Build가 `~/.claude/skills/`를** (그리고
`~/.claude/CLAUDE.md`를) 그대로 읽기 때문입니다 — `grok inspect`로 확인.

## 요구사항

- [Claude Code](https://code.claude.com) ≥ 2.1 (`claude` PATH, 로그인)
- [Grok Build](https://x.ai/cli) ≥ 1.0 (`grok` PATH, 로그인)
- `jq`, `git`
- 선택: [Orca](https://github.com/stablyai/orca) — Claude 주도 경로에서만 필요 (Grok이 터미널 탭이
  보이는 Orca 워커로 실행됨)

Claude Code 2.1.273 (Claude Opus 5), Grok Build 1.0.30 (Grok 4.6), macOS에서 테스트.

## 설치

```bash
git clone https://github.com/sungminpark-biz/tandem.git
cd tandem && ./install.sh          # skills/ 를 ~/.claude/skills/ 로 복사
# 또는: ./install.sh --link        # 심볼릭 링크 — git pull 하면 바로 반영
```

확인:
```bash
grok inspect        # Skills: team, debate  [claude]
claude              # /team 또는 /debate 입력
```

## 사용법

### Grok 주도 (기본)

아무 git 저장소에서 Grok Build를 열고:

```
/team auth 서비스에 refresh-token 로테이션 추가
```

Grok이:
1. Claude를 헤드리스로 불러(`docs/design/**`만 쓰기 가능) `docs/design/<날짜>-<slug>.md` 작성
2. 설계와 저장소를 읽고 적대 검토 작성 (치명 / 누락 / 모호, 근거 첨부)
3. 검토를 Claude에게 보냄 → Claude가 항목별로 코드 확인 후 문서 수정 또는 반박
4. **멈추고 요약을 보여줌 — "승인"이라고 할 때까지 아무것도 구현하지 않음**
5. 구현, 완료 기준 테스트 실행
6. `git diff`를 Claude에게 리뷰 요청; `APPROVE`까지 수정 (최대 3라운드)
7. 보고: 검토로 바뀐 것, 변경 파일, 테스트, Claude 비용

### Claude 주도

Orca 워크트리 안의 Claude Code에서:

```
/team auth 서비스에 refresh-token 로테이션 추가
```

Claude가 설계를 쓰고 `grok-turn.sh`로 Grok의 적대 검토를 받고, 승인을 기다린 뒤, Grok을 Orca
orchestration 워커로 띄워(`worker-start --agent grok`) 질문에 답하고, diff를 리뷰하고, 같은
워커에게 수정을 지시합니다.

### 논의만

```
/debate 세션 저장소를 Redis에서 Postgres로 옮겨야 할까?
```

## 안전장치

모델이 "잘 행동하겠다"는 약속에 기대지 않습니다:

| 모드 | 권한 | 효과 |
|---|---|---|
| `claude-turn.sh design` | `--permission-mode dontAsk` + `Write(docs/design/**)`, `Edit(docs/design/**)`, 읽기 전용 Bash | 설계문서만 쓸 수 있음. 소스 쓰기는 하네스가 거부 |
| `claude-turn.sh review` | `dontAsk` + `Bash` 허용, `Write`/`Edit`와 `git commit/checkout/reset`, `rm`, `mv`, `sed -i`… 거부 | 테스트는 돌리되 파일은 못 바꿈 |
| `grok-turn.sh` | `--permission-mode plan` | Grok 읽기 전용 |
| 승인 게이트 | 스킬 규칙 | 설계 확정 후 구현자는 턴을 끝내고 기다려야 함 |

실전에서 나온 디테일:
- Claude 세션 id를 **실행 전에** 정해 `/tmp/team/last-claude-session`에 기록 → 죽거나 타임아웃된 설계 호출을 탐색 컨텍스트째로 resume 가능
- 설계 프롬프트에 "10분 안에 뼈대 먼저, 그다음 채우기"와 도구 호출 상한 — 없으면 Opus(high effort)는 한 글자도 안 쓰고 20분 넘게 탐색함
- 설계 수정과 모든 코드 리뷰가 같은 Claude 세션을 resume → 리뷰어가 자기가 쓴 설계를 기억
- `error_max_turns` → 같은 세션 resume, 절대 새로 시작하지 않음

## 비용·시간 (실제 실행 기준)

새 Next.js 고객 앱 Phase 1 (30 파일, 테스트 7파일 23개):
Claude 약 $7 (설계 + 리뷰 2라운드, Opus 5, 타임아웃된 설계 시도 1회 포함), Grok 약 55분.
이 실행은 승인 게이트 도입 전이었고, 지금은 정확히 1회 멈춥니다. 큰 범위의 설계 호출은 20~40분.

## 한계

- Grok은 Claude의 **프로젝트 메모리를 받지 못함**; `CLAUDE.md`만. 그래서 설계·리뷰가 Claude 담당.
- review 모드 Bash 차단 목록은 완전하지 않음 (`>` 리다이렉트, `python -c`는 여전히 쓸 수 있음). 프롬프트 뒤의 2차 방어선이지 샌드박스가 아님.
- 구현자가 승인 게이트를 지키는지는 모델 준수 문제이지 하드 블록이 아님. Grok이 규칙을 정확히 읽는 건 확인했지만 전체 실행에서 아직 검증 전 — 첫 실행 때 지켜보세요.
- Claude 주도 경로는 Orca 필요. Grok 주도 경로는 어디서든 동작.
- 실전 실행은 아직 Django + Next.js 모노레포 하나뿐; 스크립트 자체는 언어 무관.

## 구조

```
skills/
  team/SKILL.md          워크플로 (A: Grok 주도, B: Claude 주도)
  team/claude-turn.sh    헤드리스 Claude: design | review
  debate/SKILL.md        논의 루프
  debate/grok-turn.sh    헤드리스 Grok: 읽기 전용 비평가
install.sh
```

## 라이선스

MIT
