---
name: code-search
description: 파일 · 심볼 이름을 모르고 동작이나 개념("온보딩 페이지 점", "알림 꺼짐 안내", "팩 다운로드 재시도")으로 FestiCore 코드를 찾을 때 사용한다. 로컬 ChunkHound MCP 도구 search로 Swift 코드와 문서를 의미 검색한다. 이름을 이미 알면 Grep을 쓴다.
---

# code-search

규칙 원본: `.claude/docs/code-search.md`

## 언제

- 기능 설명만 있고 어느 파일인지 모를 때(새 작업 시작, 버그 위치 찾기, 비슷한 구현 찾기).
- 같은 동작이 여러 모듈(Feature · Domain · Service)에 흩어져 있을 때 한 번에 찾을 때.
- 이름을 알면 쓰지 않는다. Grep · Glob이 더 빠르고 정확하다.

## 방법

1. MCP 도구 `search`를 `type: "semantic"`, 동작을 한 문장으로 설명한 `query`로 부른다. 한국어 · 영어 모두 된다.
2. 범위를 좁히려면 `path`에 `Projects/Feature/` · `Projects/Domain/` · `Projects/App/`을 준다.
3. 결과 상위 몇 개를 직접 Read로 열어 확인한다. 점수만 보고 고치지 않는다.
4. 정확한 문자열 패턴이면 `type: "regex"`를 쓴다.

## 도구가 없을 때

- `search` 도구가 없으면 먼저 `command -v chunkhound`와 MCP 연결 상태를 본다. 설치돼 있지 않을 때만 `.claude/docs/code-search.md`의 "처음 한 번" 설치를 사용자에게 안내하고, 이번 작업은 Grep으로 진행한다.
- 의미 검색만 실패하면 Ollama 실행(`brew services start ollama`)과 모델(`ollama list`에 `qwen3-embedding:0.6b`)을 확인한다.
