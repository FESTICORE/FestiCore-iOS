# 로컬 코드 의미 검색 (ChunkHound)

"첫 진입 화면이 덮는 동안 알림 안내를 미룬다"처럼 동작을 설명하면 관련 코드 위치를 찾는다. 파일 이름 · 심볼 이름을 몰라도 된다.
인덱싱 · 임베딩 · 검색은 모두 이 맥에서 돈다(Ollama). 외부 검색 API로 코드를 보내지 않고 비용이 없다. 단, 에이전트가 MCP로 검색하면 찾은 코드 조각은 다른 파일을 읽을 때처럼 대화 모델에 전달된다.
CIRQLE-Native-Mobile과 같은 구성이다.

## 구성

| 항목 | 위치 · 값 |
| --- | --- |
| 검색 도구 | [ChunkHound](https://github.com/chunkhound/chunkhound) 6.1.0 (MIT), Swift 파서 포함 |
| 임베딩 | Ollama `qwen3-embedding:0.6b` (`http://localhost:11434/v1`) |
| 설정 | 저장소 루트 `.chunkhound.json` (비밀 값 없음, 생성물 · `DesignExports` · `fastlane` 제외) |
| 인덱스 | `.chunkhound/` (git 제외, 사람마다 따로 만든다) |
| 에이전트 연결 | 저장소 루트 `.mcp.json`의 `chunkhound` MCP 서버 (Claude Code가 처음 열 때 사용 승인을 묻는다) |
| 사용 안내 | 스킬 `code-search` |

## 처음 한 번 (맥마다)

```bash
brew install uv ollama
brew services start ollama
ollama pull qwen3-embedding:0.6b
uv tool install --python 3.12 'chunkhound==6.1.0'   # 3.15는 pyarrow 바이너리가 없어 설치가 실패한다
chunkhound index .                         # 저장소 루트에서, 약 15분(파일 1,200개 · M3 기준)
```

- `uv tool`은 `~/.local/bin`에 설치한다. `PATH`에 없으면 추가한다.
- MCP 서버가 떠 있으면 파일이 바뀔 때 인덱스를 알아서 갱신한다. 서버 없이 많이 바뀌었으면 `chunkhound index .`를 다시 돌린다.
- Ollama가 꺼져 있거나 모델이 없으면 의미 검색은 실패하고 정규식 검색(`--regex`)만 된다(`brew services start ollama` · `ollama list`).
- 설치하지 않은 팀원이 `.mcp.json`의 `chunkhound` 서버를 승인하면 이 MCP 연결만 실패한다. 다른 작업과 Grep 검색은 그대로 된다.
- 작업 트리(worktree)마다 인덱스가 따로 생긴다. 검색은 주 체크아웃에서 만든 인덱스로 하고, 작업 트리에서는 Grep을 쓴다.

## 사용

```bash
chunkhound search "온보딩 페이지 점 indicator" --page-size 5
chunkhound search "팩 다운로드 재시도" --path-filter Projects/Domain/
chunkhound search --regex "fcModal\("
```

- 에이전트는 MCP 도구 `search`(의미 · 정규식)를 쓴다. 이름을 이미 알면 Grep이 더 빠르다.
- 결과는 후보다. 찾은 파일은 직접 읽어 확인한 뒤 고친다.

## 고른 이유

| 대안 | 버린 이유 |
| --- | --- |
| 클라우드 임베딩(VoyageAI · OpenAI) | 코드 외부 전송 · API 키 관리가 필요하다. |
| 외부 코드 검색 API | 검색마다 코드를 외부로 보낸다. |
| Grep만 쓰기 | 이름을 모르면 찾지 못한다. |
