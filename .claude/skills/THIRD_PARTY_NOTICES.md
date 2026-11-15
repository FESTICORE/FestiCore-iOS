# 외부 스킬 저작권 고지

`.claude/skills/` 안의 아래 스킬은 외부 저장소에서 가져왔다(CIRQLE-Native-Mobile 하네스를 거쳐 복사). `SKILL.md`와 `references/`만 옮겼고 내용은 바꾸지 않았다.
갱신할 때는 원본 저장소의 최신 버전으로 통째로 교체하고 이 표의 버전을 고친다.

| 스킬 | 원본 저장소 | 버전 | 저작권 | 라이선스 |
|------|-------------|------|--------|----------|
| `swiftui-pro` | https://github.com/twostraws/SwiftUI-Agent-Skill | 1.1 | © 2026 Paul Hudson | MIT |
| `swift-testing-pro` | https://github.com/twostraws/Swift-Testing-Agent-Skill | 1.0 | © 2026 Paul Hudson | MIT |
| `swift-concurrency-pro` | https://github.com/twostraws/Swift-Concurrency-Agent-Skill | 1.0 | © 2026 Paul Hudson | MIT |

## 넣지 않은 스킬

| 스킬 | 이유 | 쓰는 방법 |
|------|------|-----------|
| Point-Free `pfw-*` (composable-architecture · dependencies · testing 등) | 독점 라이선스(구독자 전용)라 저장소에 재배포할 수 없다 | 구독자는 각자 Point-Free 안내에 따라 개인 환경(`~/.claude/skills`)에 설치한다 |
| Android · Kotlin 스킬 (`testing-setup` 등 `android/skills` · `Kotlin/kotlin-agent-skills`) | FestiCore는 iOS 전용 저장소다 | 가져오지 않는다 |

## MIT License

```
MIT License

Copyright (c) 2026 Paul Hudson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
