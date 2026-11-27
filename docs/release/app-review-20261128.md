# 2026-11-28 iOS 심사 제출 준비

기준: 2026-11-27 23:48 KST 시작, 목표 2026-11-28 KST(자정 경과 후 오늘 제출 준비). 이 문서는 제출 준비 기록이며 실제 업로드·제출·심사 통과 증명이 아니다. 대상은 develop 기반 `feature/figma-design-item-six`다. Claude 교차검토는 주인 승인으로 생략했다(unreviewed-spec override). 11/28 추가 지시로 분석 통합을 포함하며 마감은 11/29 오전 KST다. 메인의 기존 분석 구현은 읽기 전용으로 대조·재사용했고 원본 미커밋 파일은 수정하지 않았다. 운영 배포는 추가 승인되었으나 앱 업로드/심사 제출·신규 자격증명 발급까지 승인된 것으로 보지 않는다.

## 제출 전 결정해야 할 항목

- [ ] 분석 변경을 포함한 새 최종 Prod archive와 앱/확장 서명 확인. 기존 디자인 커밋 ebef6eb archive는 검증 통과했으나 새 분석 변경을 포함하지 않는다.
- [ ] ASC에서 선택할 실제 버전/빌드 대조. 기본 xcconfig 값은 1.0.0 (1)이며 업로드된 빌드 번호를 의미하지 않는다. Fastlane은 업로드 직전 기존 TestFlight 번호와 시각 기반 번호를 비교한다. 임의 번호 변경/업로드하지 않는다.
- [ ] ASC 앱 개인정보 답변을 아래 실제 수집 대응표와 대조하고 공개 정책 문구 확정. 외부 서비스 이름 누락 자체를 법적 위반/거절로 단정하지 않는다.
- [ ] 로그인 기능에 접근할 심사용 계정 또는 Apple이 수용할 대체 접근 방법 제공. 새 계정/암호를 만들거나 이 문서에 비밀값을 적지 않는다. Google/Apple 소셜 로그인만으로 심사자가 모든 계정 기능에 접근 가능한지 사업자가 확인한다.
- [ ] ASC 필수 메타데이터, 연락처, 연령 등급, 콘텐츠 권리, 수출규정 답변, 스크린샷 및 선택 빌드 처리 상태 확인. 현재 프로세스에는 ASC API 인증 환경변수 3개가 없어 API 조회로 확인하지 못했다. 새 로그인/자격증명을 발급하지 않는다.
- [ ] 실제 기기에서 로그인→닉네임/약관→일정 저장→로그아웃→재로그인→계정 삭제 흐름과 푸시/Live Activity 권한을 최종 확인. 이번 권한에는 실기기 조작/운영 계정 삭제가 포함되지 않는다.

## 코드 및 공개 URL 점검

| 항목 | 확인 내용 | 근거/남은 확인 |
|---|---|---|
| 운영 API | Prod host `festicore.up.railway.app` | `Config/Prod.xcconfig`; 공개 OpenAPI 및 11/27 이후 축제 목록 GET 200(3건) 대조, 운영 쓰기 호출 없음 |
| 개인정보처리방침 | https://festicore.up.railway.app/api/v1/legal/privacy HTTP 200 HTML | 11/27 직접 GET; 설정 화면의 `privacy` 경로와 일치 |
| 이용약관 | https://festicore.up.railway.app/api/v1/legal/terms HTTP 200 HTML | 11/27 직접 GET; 설정 화면의 `terms` 경로와 일치 |
| 위치 권한 | 귀가 도보 시간 산출을 위한 현재 위치 안내 | `Project+InfoPlist.swift`의 WhenInUse 문구; 정책은 Apple 지도 처리와 서버 미전송을 설명 |
| ATT | IDFA/광고 SDK 또는 다른 회사 데이터와 광고 목적 결합을 확인하지 못함 | 자체 분석만으로 ATT 요구를 단정하지 않음. 사업자의 실제 데이터 이용/공유가 Apple tracking 정의에 해당하면 ATT와 선언 재검토 |
| 로그인/삭제 | Apple/Google 로그인, 계정 설정의 탈퇴 확인 및 coordinator 위임 구현 | Profile 회귀 통과; 실제 운영 계정 삭제는 미실행 |
| 빈 데이터/오프라인 | 기존 상태 UI와 회귀/고정 상태 캡처 존재 | reducer 검증과 실제 네트워크 장애 검증은 구분 |
| 아이콘 | universal iOS 1024px 원본 등록 | `Projects/App/Resources/Assets.xcassets/AppIcon.appiconset` |
| 대상 기기 | iPhone, iOS 18 이상 | Project.Environment; iPad 전용 스크린샷 대상 아님 |
| 깃발 축제 이동 | 기존 이동 기능 유지 | OpenAPI POST `/api/v1/flags/{flagId}/festival-transfer`, JWT·멱등 키와 from/to DTO 대조 |
| 크루 계약 | join은 optional nickname(1~12), 멤버 편집 API는 nickname 필수 | 11/28 OpenAPI GET 재대조: 가입 nickname은 선택, 현행 앱은 계정 기본값을 사용; 전용 닉네임 입력/편집 연결은 없음. 최신 S07/S08 원본에 전용 입력 상태를 찾지 못해 임의 UI 추가하지 않음. 서버 API 추가 불필요 |

## Privacy Manifest

앱 루트 manifest 유무만으로 판정하지 않는다. Apple은 required-reason API를 사용하는 각 실행 파일/동적 라이브러리의 번들에 선언을 요구한다.

| 자체 번들 | 직접 사용 | 선언 |
|---|---|---|
| FestivalDomain | 선택 축제, 최근 검색, 북마크 등 앱 전용 UserDefaults | UserDefaults `CA92.1` |
| FestiCoreStorage | 첫 설치/업그레이드 판별의 앱 전용 UserDefaults | UserDefaults `CA92.1` |
| FestiCoreStorageInterface | 이전 화면 모드 UserDefaults 읽기 | UserDefaults `CA92.1` |
| FestiCorePack | 앱 캐시 파일 `contentModificationDateKey` | FileTimestamp `C617.1` |

App Group은 파일로 공유하며 직접 App Group UserDefaults 사용은 발견하지 않아 `1C8F.1`을 추가하지 않았다. 디스크 공간/시스템 부팅 시각 이유도 앱 코드 근거 없이 추가하지 않는다. 수집 데이터 없음/추적 없음 선언을 임의로 만들지 않았다. SDK 자체 manifest를 앱 선언으로 대체하지 않는다. unsigned Prod archive에서 자체4개를 포함한26개 manifest가 확인됐다. Sentry 누락을 아래 패키징으로 보완했고 분석 추가 전 signed archive에서 기존26개 동일 내용 보존과 원본1개 추가(총27개)를 확인했다.

공식 근거: [Apple required-reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [이유 코드](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype), [ATT 정의](https://developer.apple.com/app-store/user-privacy-and-data-use/).

## 분석·진단과 ASC 개인정보 입력 대응표

아래는 11/28 분석 변경 작업 트리의 정적 확인이다. 최종 커밋·테스트·새 signed archive 증거는 검증 완료 후 고정한다. 기존 ebef6eb archive는 이 변경을 포함하지 않는다. 실제 SDK 대시보드 수신·크래시 보고는 아직 미검증이다.

| 서비스 | 수집 조건·기본값 | 데이터·식별·철회 | 환경별 로그·제한 |
| --- | --- | --- | --- |
| 공통 | 설정의 ‘분석 및 진단 정보 공유’ 기본 OFF; 동의한 Stage/Prod에서만 수집; XCTest 차단 | 기존 AnalyticsUseCase 재사용; 로그인 내부 사용자 ID/provider, 로그아웃·탈퇴 reset; 동의 철회 시 SDK 수집 중지 | 원시 검색어·닉네임·정밀 위치·축제/set/flag ID는 명시 이벤트에 포함하지 않음 |
| Firebase GA4 | FirebaseAnalyticsCore(광고 ID 없는 제품), 자동 화면 추적 OFF; IDFV 수집 OFF; 광고 저장/사용자 데이터/개인화 동의 denied | 명시 screen_view·sign_up·ui_action·flag_follow·timetable_action·pack_sync·festival_journey·crew_action·live_activity_action; 화면/고정 행동/결과·플랫폼/버전/환경 및 SDK 기본 세션/참여 메타데이터(실수신 미확인); 로그인 setUserID, 철회·로그아웃 resetAnalyticsData | Stage notice, Prod/미지 환경 error; debug/verbose 미사용; Crashlytics 추가하지 않고 Sentry로 진단 통합 |
| Mixpanel | 동의 전 초기화하지 않음; 자동 이벤트 OFF; IP 지리정보 OFF | 위 명시 이벤트와 SDK 기본 기기/OS 속성·익명 ID; 로그인 identify 및 provider People 속성; 로그아웃 reset; 철회 optOutTracking | SDK 원시 payload 로그는 모든 환경 OFF; 서버에 이미 수집된 데이터 삭제·보유기간은 별도 운영 정책 확인 |
| Sentry | 동의 및 유효한 DSN/환경 조건; Stage.local/Prod.local의 기존 DSN 사용 | crash/hang/watchdog·성능 trace 0.2·프로파일·세션·메트릭·고정 행동 breadcrumb; 내부 사용자 ID/provider; 철회 사용자 제거 및 SDK close | Prod debug=false/diagnostic error/앱 error 이상; Stage diagnostic warning/앱 info 이상; 네트워크 로그 제외, 앱 로그 본문 app_log로 치환 |
| Sentry 민감정보 제한 | sendDefaultPii=false; replay=0 | network tracking/breadcrumb/failed requests OFF; screenshot/view hierarchy OFF | SDK 자체 진단 컨텍스트 전체의 민감정보 부재를 보장하지 않음; 실제 수신 payload 추가 확인 |

SDK manifest는 원본을 보존하고 최종 bundle 포함 여부를 검증한다. 앱 manifest가 연결된 SDK의 수집 선언을 중복할 필요는 없다는 [Apple 지침](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)을 따른다. 다만 SDK 기본 manifest만으로 수동 사용자 ID 연결과 실제 앱 수집 전체의 ASC 표기가 완성되는 것은 아니므로 아래 입력표를 별도 대조한다.

ASC 입력 후보: GA4·Mixpanel은 Usage Data/Product Interaction 및 Identifiers/User ID·Device ID(실제 SDK payload와 대조), Sentry는 Diagnostics/Crash·Performance·Other Diagnostic Data와 User ID. 목적은 분석·앱 기능/안정성 개선이며 로그인 이후 사용자와 연결될 수 있다. 기본 OFF라고 해서 선택적으로 수집하는 항목을 ASC에서 누락하지 않는다. 광고 목적/브로커 공유는 앱 코드에서 발견하지 못했으나 사업자 설정까지 대조해 Tracking 여부를 최종 확정한다.

SDK 근거: [Firebase 수집 설정](https://firebase.google.com/docs/analytics/ios/configure-data-collection), [Firebase Core 제품](https://github.com/firebase/firebase-ios-sdk/blob/main/FirebaseAnalytics/README.md), [Mixpanel Swift](https://docs.mixpanel.com/docs/tracking-methods/sdks/swift), [Sentry 수집 데이터](https://docs.sentry.io/platforms/apple/data-management/data-collected/).

## 공개 정책 보완 초안 — 사업자 확인 후 게시

게시 URL: https://festicore.up.railway.app/api/v1/legal/privacy

> 선택한 이용자에 한하여 Firebase Analytics와 Mixpanel로 앱 버전·운영체제, 화면 진입·기능 이용 행동과 처리 결과를 분석합니다. 로그인 상태에서는 서비스 내부 사용자 식별자와 로그인 제공자를 연결합니다. 설정의 ‘분석 및 진단 정보 공유’에서 언제든 수집을 끌 수 있으며 로그아웃 시 앱의 분석 식별 상태를 초기화합니다.
>
> 같은 선택에 동의하면 Sentry로 오류·앱 멈춤·성능과 관련 실행 정보를 수집하여 안정성을 개선합니다. 내부 사용자 식별자와 고정된 기능 이용 행동이 연결될 수 있습니다. 앱 설정상 화면 캡처·화면 계층·세션 리플레이·자동 네트워크 요청 수집은 사용하지 않습니다.

확정되지 않은 값: 각 서비스 수탁/제공 관계, 사업자 법인명, 처리 국가·리전, 이전 방식/시점, 보유기간, 삭제 요청 절차와 처리 범위, 거부 방법과 영향. 이 값은 계약·콘솔·운영 정책 확인 후 작성한다. 최종 배포본의 동의 조건과 실제 SDK 설정을 대조한 뒤 게시한다. 서버 처리 국가·보유기간 등 사업자 확인값은 추정하지 않는다.

정책 소스(읽기 전용 확인): Backend `src/modules/legal/privacy-content.ts`가 기본 본문, `legal.controller.ts`가 공개 HTML 제공, `legal.service.ts`가 `legal_documents(kind=privacy)` DB 값을 우선 사용한다. 따라서 파일 변경만으로 현재 운영 본문이 바뀐다고 가정하면 안 된다. 정책 게시/관리자 접근/배포는 이번 작업에서 하지 않는다.

## ASC 한국어 메타데이터 초안

- 이름: 패스티코어 (현재 등록명과 중복/길이 대조 필요)
- 부제: 페스티벌 일정과 친구를 한곳에
- 키워드: 페스티벌,축제,공연,타임테이블,일정,크루
- 설명: 패스티코어에서 페스티벌 정보와 공연 타임테이블을 확인하고 보고 싶은 공연을 일정에 담아 보세요. 깃발과 크루 기능으로 현장에서 친구들과 상태를 공유하고, 준비물과 귀가 정보를 확인할 수 있습니다. 일부 기능은 로그인과 네트워크 연결이 필요하며 축제 정보는 현장 사정에 따라 변경될 수 있습니다.
- 지원 URL 후보: https://festicore.up.railway.app/api/v1/legal/home (지원 연락처/내용 적합성 최종 확인)
- 개인정보 URL: 위 공개 privacy URL
- 저작권/검토 연락처: 사업자 확정값 입력, 임의 기재 금지

심사 메모 초안: “앱은 축제 정보, 공연 일정 저장, 깃발 및 크루 기능을 제공합니다. 위치 권한은 귀가 도보 안내 요청 시 사용하며 GPS 좌표를 깃발 위치로 공유하지 않습니다. 계정 관련 기능은 Apple 또는 Google 로그인이 필요합니다. 계정 삭제는 마이 > 설정 > 계정 설정의 회원 탈퇴에서 진행할 수 있습니다. 심사용 접근 정보는 App Review Information의 보안 입력란에 별도로 제공합니다.” 실제 최종 화면 경로와 접근 정보를 제출자가 확인한다.

스크린샷 준비 목록: 축제 목록, 라이브 축제 정보, 타임테이블/내 일정, 깃발, 크루, 준비/귀가 안내. 실제 제품 캡처를 사용하고 샘플 데이터를 실제 행사/접근 권한으로 오인하게 만들지 않는다. 이번 테스트용 캡처는 개발 증거이며 상태 표시줄/탭/네트워크가 고정되어 있어 ASC 등록용 완성본으로 간주하지 않는다. [Apple 스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)에 맞는 최종 해상도 세트를 별도 확인한다.

## 필요한 기존 설정 목록

Stage/Prod의 기존 Mixpanel 설정과 GoogleService-Info.plist가 로컬에 존재한다. Sentry는 메인 체크아웃의 기존 Config/Stage.local.xcconfig·Prod.local.xcconfig를 이 worktree의 Git 제외 경로에 복사했고, 11/28 xcodebuild resolved settings에서 두 환경 모두 값 존재·치환 완료·Git 제외를 확인했다. 이전 DSN 부재 결론은 local override가 없던 이전 archive에만 해당한다. 값은 로그·문서·커밋에 기록하지 않았다. 새 archive의 실제 주입은 별도 검증 대상이다. 현재 Sentry CLI 인증은 없고 연결된 브라우저도 발견되지 않아 대시보드 실수신은 미확인이다.

## 로컬 검증 기록

- 분석 변경 전 디자인 커밋의 `.claude/scripts/verify` 통과(455초). xcresult: 670 passed, 0 failed, 2 skipped, 2 expected failures(총674). Live Activity 실기기 테스트2개는 건너뛰었고 Festival/Analytics 미등록 의존성 보고 테스트2개는 의도된 예상 실패다. 모달/메뉴/CTA 캡처와 manifest 패키징 변경을 포함한다.
- 기본 signed Prod archive는 AppStore profile에 Development 인증서가 선택되어 실패했다. 전역 Distribution override는 macOS 매크로 타깃의 서명 설정까지 바꾸어 실패했다. 인증서/프로파일 자체 부재로 판정하지 않는다.
- 2회 실패 뒤 코디네이터의 한정 승인(msg_ca83b0d72aa2)으로 unsigned archive1회와 앱/확장3타깃 한정 signed archive1회를 추가 검증한다. 인증서/프로파일/키체인을 변경하지 않는다.
- 첫 verify의 건너뜀2개는 실기기 Live Activity 시작/종료 통합 테스트이며, 예상 실패1개는 `FestivalUseCaseTests/missingUseCasesRecordIssues()`의 의도된 issue 기록이다. 실기기 Live Activity 성공으로 보고하지 않는다.

## 제출 전 사업자 결정 질문 후보

| 질문 | 권장안 | 필요한 확인 |
|---|---|---|
| 이번 제출본의 분석/진단 구성은 무엇인가? | 새 최종 archive의 기본 OFF·선택 동의 기반 GA4/Mixpanel/Sentry 구성을 위 표와 대조 | Mixpanel 프로젝트의 실제 리전·보유기간·삭제 절차·IP 지리정보 처리, 활성화할 SDK 범위 |
| 공개 정책 초안을 게시해도 되는가? | 위 정적 수집 목록을 사업자 계약/운영값으로 완성한 뒤 별도 승인으로 게시 | legal_documents 현재 버전, 법인/문의처/처리 관계와 국가 등 미확정값; 이름 누락만으로 거절을 단정하지 않음 |
| 심사자는 로그인 기능에 어떻게 접근하는가? | 기존 심사용 접근 방법을 ASC 보안 필드로 제공하고 2FA/초대 제한 없이 확인 가능한지 점검 | 계정/대체 접근 허용 여부와 로그인 후 사용 가능한 축제 데이터; 암호는 이 문서 밖에서 전달 |
| 제출할 버전과 빌드는 무엇인가? | ASC에 실제 처리 완료된 Prod 빌드와 이번 검증 커밋을 대조한 뒤 선택 | 현재 ASC 목록 미확인; QA/Stage 배포본과 Prod 제출본을 구분 |

## Sentry 원본 manifest 패키징

unsigned Prod archive에서 26개 manifest를 열거했으나 Sentry 원본은 없었다. `otool -L`에는 별도 Sentry 동적 프레임워크가 없고 `nm`으로 `FestiCoreAnalytics.framework/FestiCoreAnalytics` 안의 Sentry 심볼을 확인했다. pinned Sentry 9.34.0의 소스 제품 `SentrySPM`이 이 프레임워크에 정적으로 링크되며, Package.swift의 해당 소스 타깃에는 공식 manifest를 리소스로 전달하는 선언이 없다.

따라서 이미 사용하는 Tuist 모듈 `Sources` 리소스 전달 경로로 **FestiCoreAnalytics.framework/PrivacyInfo.xcprivacy**를 포함한다. 다른 SDK/앱 manifest를 덮어쓰지 않으며 SDK 원본 내용은 수정하지 않는다. 앱의 사용자 연결/추가 수집에 관한 ASC 답변은 SDK 기본 선언과 별도로 위 대응표에 기록한다.

원천: [pinned SDK 원본](https://github.com/getsentry/sentry-cocoa/blob/aa91bcf6bd6f383dbc49f38bf785d1d775c4f751/Sources/Resources/PrivacyInfo.xcprivacy), SHA256 `118b16e0e97ffe8b6f1f01b7e04f68e5da764474a4d39d2933b0eeaef3cdc0ca`. 다운로드한 원본과 로컬 SDK 파일의 byte 일치를 확인했다. 업그레이드 시 이 사본을 새 pinned 원본과 비교하고 SDK가 리소스를 전달하도록 수정되면 중복 사본을 제거해야 한다. 분석 추가 전 signed archive의 `Products/Applications/FestiCore.app/Frameworks/FestiCoreAnalytics.framework/PrivacyInfo.xcprivacy`가 위 SHA256과 일치하며 동일 원본은 정확히1개다. 기존26개 manifest는 모두 동일 경로·동일 SHA256으로 보존됐다.

## PR 리뷰 경계

PR #670의 최초 HEAD에서 Gemini는 P1/P2 지적 없이 COMMENTED했으며 승인 review는 아니다. Codex 자동 리뷰는 quota 초과로 미생성되어 이번 제출 준비의 필수 게이트에서 명시 면제했다(msg_25df7910b3aa). 교차검토 생략 승인과 별개로 로컬 verify, 자체 diff 점검, 빌드 CI와 archive 검증 결과를 기록한다.

## 분석·위젯 추가 전 디자인 Prod archive 검증 (ebef6eb)

승인된 unsigned1회와 타깃 한정 signed1회 모두 성공했다. 서명 설정은 생성된 Xcode 프로젝트의 앱/확장3타깃 Prod에만 기존 Apple Distribution identity를 적용했고 전역 매크로/의존성에는 전파하지 않았다. 저장소 Fastlane과 같은 타깃 범위이며 이 로컬 생성물 변경은 커밋하지 않는다.

- `codesign --verify --deep --strict` 앱 검증 통과, 각 확장 `--verify --strict` 통과.
- `io.festiCore.co`, `.LiveActivity`, `.NotificationService`의 모든 서명 entitlements가 embedded AppStore profile과 일치한다. `get-task-allow=false`; 프로파일 만료2027-04-09. 앱 push는 production, Apple 로그인/App Group 권한도 일치한다.
- 버전/빌드3타깃 모두1.0.0(1). ASC 업로드 빌드와의 대조·export·업로드·제출은 하지 않았다.
- manifest 총27개: 자체4개, 기존SDK 등22개 보존, Sentry 원본1개. 모든 plist 파싱 통과, 기존26개 해시 보존, Sentry 원본 중복 없음.
- 로컬 산출물: `/Users/suhwonji/orca/reports/item6-ios-design-20261127/FestiCore-Prod-signed.xcarchive`; 증거 `signed-archive-verification.json`, `archive-signed.log`, `verify-final-summary.json`.

서명 archive 성공은 ASC 처리 완료 또는 심사 제출 가능성에 대한 서버 검증 성공을 의미하지 않는다. 상단 외부 확인 항목을 제출 전에 완료해야 한다.

## 11/28 위젯 및 분석 추가 검증

[위젯 대응표](widget-design-matrix-20261128.md)에 최신 최종 원본 7개 상태와 실제6family, Live Activity/Island 경계를 기록했다. 사각형 잠금 위젯의22/12/16pt 두 줄 위계·3pt 간격·남은 시간 보호와 원형 보조10pt/primary를 수정했다. 색은 기존 staticInk 토큰을 직접 재사용하며 별도 색상 값·새 토큰을 만들지 않았다. 시스템 GUI 창 연결 오류가 코디네이터에서도 재현되어 실제 위젯 배치/잠금화면/Island 캡처는 미검증이다. 미배치 홈 스크린샷은 일치 증거로 사용하지 않는다.

분석/동의 한정 재검증:32 passed·1 expected failure·0 failed, 캡처16PNG. 별도 Festival 두 suite는 정확한 선택 집합42개를 열거한 후42 passed·0 failed·0 skipped를 확인했다. 이전 실패 `loggedOutDoesNotLoadMySchedule()` 및 `leavingTabCancelsRequestButKeepsFollowResultUntilConfirmed()` 모두 PASS다. 최종 전체 verify·확장/앱 signed archive는 아래 새 결과로 별도 고정한다.

기존 plan 저장은 `BearerProfileFeatureTests`의 ‘오늘 계획을 다시 고르면 저장할 때 plan을 함께 보내고, 고르지 않았으면 보내지 않는다’ 테스트와 API mapper를 대조했다. 일정의 모든 변경을 깃발에 자동 동기화하는 새 정책은 추가하지 않았다. 실제 운영 쓰기는 실행하지 않았다.

선택 동의 UI 캡처: [320pt 다크 OFF](assets/20261127/S13-consent-off-320-dark-bottom.png), [393pt 라이트 ON](assets/20261127/S13-consent-on-393-light-bottom.png). 이는 UIHostingController 캡처이며 SDK 대시보드 수신 증거가 아니다.

Firebase Analytics/GoogleAppMeasurement의 pinned12.11.0 binary artifact에는 별도 PrivacyInfo.xcprivacy가 없었다. [Google 공식 저장소의 maintainer 설명](https://github.com/google/GoogleAppMeasurement/issues/64)은10.24.0 이후 required-reason API를 호출하지 않는다고 안내한다. 따라서 SDK 이름만으로 누락을 단정하거나 가짜 manifest를 만들지 않는다. 실제 포함되는 FirebaseInstallations·FirebaseCore·GoogleUtilities·FBLPromises 등의 원본 manifest를 최종 archive에서 확인하며, GA4의 실제 데이터 수집은 위 ASC 대응표에 별도로 반영한다.

GitHub 배포 설정 읽기 확인: ios-deploy/ios-preview는 기존 FESTICORE_SENTRY_DSN·FESTICORE_MIXPANEL_TOKEN secret을 참조하며 해당 두 이름과 GOOGLE_SERVICE_INFO_PLIST_BASE64가 저장소 secret 목록에 존재한다. 이름 존재는 값의 유효성이나 대시보드 실수신 증거가 아니다. 값 조회·변경·로그 출력은 하지 않았다.

## 최종 분석·위젯 전체 테스트 (11/28)

최종 xcresult `DFE4C109-470C-4CF7-9956-ED717575C5B4`:1574 total,1563 passed,0 failed,6 skipped,5 expected failures. 파라미터 확장 실행 기준1718 passed. 북마크 토스트의 기존 top route assertion과 이벤트1회 검증, Sentry SDK OFF→ON→OFF writer0→1→1, `loggedOutDoesNotLoadMySchedule()` 및 `leavingTabCancelsRequestButKeepsFollowResultUntilConfirmed()` 모두 이름별 PASS다. UI fixture `deleteExpiredPacks 미등록` runtime warning2건은 테스트 실패와 별도로 남는다.

완성된 결과의 테스트 출력34파일에서 FBLPromise 중복 구현0, Sentry-tagged 시작 전 호출 경고0을 확인했다. 모든 실제 제품 실행이나 대시보드 수신을 검증했다는 의미는 아니다. 테스트 종료 뒤 해당 run의 진단 수집 PID·부모·경로를 확인해 소유 simctl diagnose만 SIGINT로 끝냈고 공유 시뮬레이터 프로세스는 종료하지 않았다.

전체 `.claude/scripts/verify`633초 통과(exit0). Tuist Air 원격 테스트 결과 업로드 한도 경고는 로컬 검증 성공과 별개이며 요금제/결제/설정은 변경하지 않았다.
