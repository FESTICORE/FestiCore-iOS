# FestiCore Design Export

선택한 Figma 프레임 또는 섹션을 Codex 또는 Claude가 읽을 수 있는 로컬 파일로 추출하는 개발용 플러그인입니다. 계정 토큰, 서버, 빌드 도구가 필요하지 않습니다.

## 설치와 실행

1. [FESTICORE 디자인 파일](https://www.figma.com/design/VPZzKIKZKruAKvKQTiQACx/FESTICORE?node-id=13-2340)을 Figma 데스크톱 앱에서 엽니다.
2. Figma 메뉴에서 **Plugins → Development → Import plugin from manifest...**를 선택하고 이 폴더의 `manifest.json`을 지정합니다.
3. 원본이 보기 전용이면 Figma의 **파일 → 초안으로 복제**로 현재 원본을 복제합니다. 이전에 만든 복제본은 최신 디자인과 다를 수 있습니다.
4. 추출할 **FRAME 또는 SECTION 하나**를 선택합니다. 링크의 `node-id=13-2340`은 Figma API 노드 ID `13:2340`에 해당합니다. 해당 노드가 페이지라면 안쪽의 필요한 프레임이나 섹션을 선택합니다.
5. **Plugins → Development → FestiCore Design Export**를 실행하고 **선택 영역 추출**을 누릅니다.
6. **디자인 JSON 저장**과 **미리보기 PNG 저장**을 각각 누릅니다. 브라우저에서 실행했다면 다운로드 허용이 필요할 수 있습니다.

저장한 두 파일을 작업 저장소에 놓거나 Codex/Claude 대화에 첨부한 뒤, 대상 화면 구현 또는 디자인 검토를 요청하면 됩니다. 플러그인이 Codex/Claude에 직접 접속하거나 파일을 자동 전송하지는 않습니다. 민감한 디자인이라면 파일을 공유하기 전에 내용을 확인하세요.

## 원본 페이지 위치를 복제본에 맞추기

1. 원본 파일의 원하는 페이지(예: `Widget`)를 열고 **현재 페이지 위치 JSON 저장**을 누릅니다. 페이지의 FRAME·SECTION마다 이름과 타입을 포함한 전체 부모 경로, 부모 기준 `x`·`y` 좌표가 저장됩니다.
2. 편집 가능한 복제본에서 대응하는 페이지를 열고 저장한 `festicore-page-layout.json`을 선택합니다.
3. **위치 대조**를 누릅니다. 원본과 복제본의 페이지 이름과 부모 경로가 정확히 일치해야 합니다. 원본과 같은 파일에서의 적용, 누락, 중복 이름으로 모호한 경로, 원본에 없는 복제본 항목, 자동 배치로 좌표를 직접 바꿀 수 없는 항목을 먼저 보고하며 이 중 하나라도 있으면 적용 버튼을 열지 않습니다.
4. 문제가 없고 이동 개수를 확인했다면 **대조한 위치 적용**을 누릅니다. 적용 직전에 레이어 경로와 미리보기 당시 좌표를 다시 확인합니다.

이 기능은 현재 페이지의 FRAME·SECTION 위치만 바꿉니다. **복제본에 없는 콘텐츠를 추가하거나 업데이트하지 않습니다.** 크기·회전·다른 레이어 속성은 바꾸지 않으며 INSTANCE 내부는 포함하지 않습니다. 자동 배치의 일반 자식은 Figma API가 `x`·`y` 설정을 무시하므로 적용 대상에서 제외합니다. 원본 파일은 읽기 전용으로 사용할 수 있고 복제본에는 편집 권한이 필요합니다. JSON 다운로드 완료와 Figma 복제본의 실제 변경은 각각 확인해야 합니다. 위치 내보내기·대조의 3,000개 제한은 전체 레이어가 아닌 FRAME·SECTION 개수에 적용됩니다.

## 출력

- `프레임이름-노드ID.json`: `figmaRest`에 Figma의 `JSON_REST_V1` 응답, `source`에 원본 식별자, `imageFills.references`에 노드·속성·인덱스별 이미지 해시, `imageFills.byHash`에 원본 이미지 MIME 유형과 base64 바이트가 들어 있습니다. 같은 이미지 채우기는 한 번만 포함합니다.
- `프레임이름-노드ID.png`: 프레임의 미리보기입니다. 가로 최대 1440px로 축소될 수 있으므로 원본 해상도 자산으로 사용하지 마세요.

레이어가 3,000개, 고유 이미지가 100개, 이미지 원본 합계가 20MB, PNG가 8MB, 결과 JSON이 1,600만 자를 넘으면 오류를 표시합니다. 이 경우 더 작은 프레임을 선택하세요. Figma 플러그인 API에서 읽을 수 없는 비디오·외부 콘텐츠와 폰트 파일은 별도 추출하지 않습니다. 추출 결과는 저장 버튼을 누르기 전까지 플러그인 UI의 메모리에만 있습니다.

## 확인 근거

Figma 공식 문서: [플러그인 매니페스트](https://developers.figma.com/docs/plugins/manifest/), [노드 `exportAsync`](https://developers.figma.com/docs/plugins/api/properties/nodes-exportasync/), [이미지 바이트 읽기](https://developers.figma.com/docs/plugins/api/Image/), [UI 메시지 전달](https://developers.figma.com/docs/plugins/creating-ui/), [동적 페이지 로딩](https://developers.figma.com/docs/plugins/migrating-to-dynamic-loading/), [상대 좌표](https://developers.figma.com/docs/plugins/api/properties/nodes-relativetransform/), [자동 배치 위치](https://developers.figma.com/docs/plugins/api/properties/nodes-layoutpositioning/).
