# 2026-11-28 iOS 심사 제출 준비

기준: 2026-11-27 23:48 KST 시작, 목표 2026-11-28 KST(자정 경과 후 오늘 제출 준비). 이 문서는 제출 준비 기록이며 실제 업로드·제출·심사 통과 증명이 아니다. 대상은 develop 기반 `feature/figma-design-item-six`다. Claude 교차검토는 주인 승인으로 생략했다(unreviewed-spec override). 메인 체크아웃의 미커밋 분석 변경은 이식하지 않았다.

## 제출 전 결정해야 할 항목

- [ ] 최종 Prod archive와 서명 확인, ASC에서 선택할 실제 버전/빌드 대조. 기본 xcconfig 값은 1.0.0 (1)이며 업로드된 빌드 번호를 의미하지 않는다. Fastlane은 업로드 직전 기존 TestFlight 번호와 시각 기반 번호를 비교한다. 임의 번호 변경/업로드하지 않는다.
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
| 크루 계약 | join은 optional nickname(1~12), 멤버 편집 API는 nickname 필수 | 앱 가입/편집 nickname 연결 추가는 미완료; 서버 API 추가가 필요한 문제 아님 |

## Privacy Manifest

앱 루트 manifest 유무만으로 판정하지 않는다. Apple은 required-reason API를 사용하는 각 실행 파일/동적 라이브러리의 번들에 선언을 요구한다.

| 자체 번들 | 직접 사용 | 선언 |
|---|---|---|
| FestivalDomain | 선택 축제, 최근 검색, 북마크 등 앱 전용 UserDefaults | UserDefaults `CA92.1` |
| FestiCoreStorage | 첫 설치/업그레이드 판별의 앱 전용 UserDefaults | UserDefaults `CA92.1` |
| FestiCoreStorageInterface | 이전 화면 모드 UserDefaults 읽기 | UserDefaults `CA92.1` |
| FestiCorePack | 앱 캐시 파일 `contentModificationDateKey` | FileTimestamp `C617.1` |

App Group은 파일로 공유하며 직접 App Group UserDefaults 사용은 발견하지 않아 `1C8F.1`을 추가하지 않았다. 디스크 공간/시스템 부팅 시각 이유도 앱 코드 근거 없이 추가하지 않는다. 수집 데이터 없음/추적 없음 선언을 임의로 만들지 않았다. SDK 자체 manifest를 앱 선언으로 대체하지 않는다. unsigned Prod archive에서 자체4개를 포함한26개 manifest가 확인됐다. Sentry 누락은 아래 패키징으로 보완하며 최종 signed archive에서 재확인한다.

공식 근거: [Apple required-reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [이유 코드](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype), [ATT 정의](https://developer.apple.com/app-store/user-privacy-and-data-use/).

## 분석·진단과 ASC 개인정보 입력 대응표

아래는 코드/설정의 정적 확인이다. 운영 서버에서 이벤트 수신 또는 크래시 업로드를 검증하지 않았다. GA4 부재를 심사 차단으로 취급하지 않는다. 메인 분석 작업은 별도 item 4 후속 통합이 필요하며 통합 후 이 표를 다시 확인한다.

| 경로 | Prod 초기화/수집 조건 | 실제 코드상 정보 | ASC 후보 및 확인 |
|---|---|---|---|
| Firebase Core | 포함된 GoogleService-Info.plist가 있으면 configure | 이 기준 브랜치 FestiCoreConfig는 FirebaseCore만 직접 의존 | GA4/Crashlytics 패키지 선언만으로 수집 중이라 표시하지 않음; 최종 링크 확인 |
| Mixpanel | Info.plist의 token이 비어 있지 않을 때 초기화; Prod xcconfig에 값 있음 | 자동 lifecycle events false. 명시 이벤트 sign_up, screen_view, ui_action, flag_follow, timetable_action, pack_sync; 화면·행동·축제/set/flag ID·결과, OS/app/build | Usage Data/Product Interaction, Identifiers/User ID 및 익명 device ID 후보; Analytics 목적, 로그인 후 사용자 연결 있음 |
| Mixpanel 식별 | 로그인 identify(userID), provider People 속성·login_provider·is_logged_in | 로그아웃/탈퇴 시 reset 후 공통 속성 재등록 | reset은 기존 서버 분석 데이터 삭제가 아님; 삭제 처리/보유기간 사업자 확인 |
| Mixpanel 기본 속성 | 로컬 SDK 기본 optOutTrackingByDefault=false, useUniqueDistinctId=false; 명시 opt-in/out UI 연결 없음 | SDK 자동 기기/OS 속성; pinned SDK Flush.swift의 useIPAddressForGeoLocation=true를 앱에서 재정의하지 않음 | IP 기반 Coarse Location 후보. GPS 사용과 구분, 서버 프로젝트 설정과 실제 수신 payload 확인 |
| Sentry | 유효한 HTTPS DSN·환경 stage/production일 때만 시작; 저장소 Prod DSN 기본은 빈 값 | 활성화 시 사용자 ID/provider, crash/hang/watchdog, 성능 trace 0.2, 메트릭, 로그, 네트워크 breadcrumb/실패 요청, screenshot=true | Diagnostics/Crash·Performance·Other Diagnostic Data와 User ID 후보. 화면 캡처에 포함될 수 있는 사용자 콘텐츠 검토 |
| Sentry 필터 | sendDefaultPii=false, replay sample=0, viewHierarchy=false | 로그 sink는 network category 제외. SDK 네트워크 수집은 별도 활성; 명시 beforeSend/screenshot 마스킹 확인 안 됨 | PII=false가 수동 userID/화면 캡처/모든 URL 제거를 의미하지 않음; 활성화 전 민감정보 노출 및 정책 대조 |
| 계정/운영 기능 | Apple/Google 인증과 서버 저장 | 이메일/프로필 범위, 닉네임, 일정·구독·크루/깃발 활동, 푸시 등록 | Contact Info, Identifiers, User Content/Product Interaction 등의 적용 여부를 실제 서버 보유와 함께 확정 |

광고 목적/데이터 브로커 공유는 코드에서 확인하지 못했다. 사업자 확인 전 ASC tracking 여부·수집 범주를 최종 확정하지 않는다. 알림 수신 선택은 분석 동의와 동일하지 않다. 분석 사용 동의의 적합성·지역별 요구는 사업자 확인 항목이며 임의로 법적 보장을 하지 않는다.

SDK 근거: [Mixpanel Swift](https://docs.mixpanel.com/docs/tracking-methods/sdks/swift), [Sentry 수집 데이터](https://docs.sentry.io/platforms/apple/data-management/data-collected/), [Sentry manifest](https://docs.sentry.io/platforms/apple/data-management/apple-privacy-manifest/).

## 공개 정책 보완 초안 — 사업자 확인 후 게시

게시 URL: https://festicore.up.railway.app/api/v1/legal/privacy

> 서비스 이용 현황 분석을 위해 Mixpanel을 사용합니다. 앱 버전·운영체제, 화면 진입과 기능 이용 이벤트, 관련 축제·공연·깃발 식별자와 처리 결과를 처리합니다. 로그인 상태에서는 서비스 내부 사용자 식별자와 로그인 제공자를 연결합니다. 로그아웃 시 앱의 분석 식별 상태를 초기화합니다.
>
> Sentry 진단 수집을 활성화한 배포본에서는 오류·앱 멈춤·성능 및 관련 실행 정보를 서비스 안정성 개선에 사용합니다. 사용자 식별자, 기능 이용 기록과 네트워크 오류 정보가 연결될 수 있습니다. 화면 캡처 수집 여부는 최종 배포 설정에 맞추어 명시합니다.

확정되지 않은 값: 각 서비스 수탁/제공 관계, 사업자 법인명, 처리 국가·리전, 이전 방식/시점, 보유기간, 삭제 요청 절차와 처리 범위, 거부 방법과 영향. 이 값은 계약·콘솔·운영 정책 확인 후 작성한다. 비활성 Sentry를 활성 수집처럼 게시하지 않는다. IP 기반 지리정보와 자동 기기 속성은 최종 설정을 대조한 뒤 반영한다.

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

현재 worktree Stage/Prod는 Mixpanel token 값이 있고 Sentry DSN은 모두 빈 값이며 local xcconfig도 없다(값 자체는 기록하지 않음). Sentry를 이번 제출본에서 사용하려면 사업자가 기존 프로젝트의 Stage/Prod DSN과 데이터 정책을 확정해야 한다. 새 토큰을 발급하지 않는다. GoogleService-Info.plist는 로컬에 존재하며 앱 bundle ID와 일치하지만 GA4 제품 연결/수신 검증은 별도 분석 통합 범위다. 운영 crash 전송 테스트와 analytics dashboard 수신 확인은 실행하지 않았다.

## 로컬 검증 기록

- 최종 `.claude/scripts/verify` 통과(455초). xcresult: 670 passed, 0 failed, 2 skipped, 2 expected failures(총674). Live Activity 실기기 테스트2개는 건너뛰었고 Festival/Analytics 미등록 의존성 보고 테스트2개는 의도된 예상 실패다. 모달/메뉴/CTA 캡처와 manifest 패키징 변경을 포함한다.
- 기본 signed Prod archive는 AppStore profile에 Development 인증서가 선택되어 실패했다. 전역 Distribution override는 macOS 매크로 타깃의 서명 설정까지 바꾸어 실패했다. 인증서/프로파일 자체 부재로 판정하지 않는다.
- 2회 실패 뒤 코디네이터의 한정 승인(msg_ca83b0d72aa2)으로 unsigned archive1회와 앱/확장3타깃 한정 signed archive1회를 추가 검증한다. 인증서/프로파일/키체인을 변경하지 않는다.
- 첫 verify의 건너뜀2개는 실기기 Live Activity 시작/종료 통합 테스트이며, 예상 실패1개는 `FestivalUseCaseTests/missingUseCasesRecordIssues()`의 의도된 issue 기록이다. 실기기 Live Activity 성공으로 보고하지 않는다.

## 제출 전 사업자 결정 질문 후보

| 질문 | 권장안 | 필요한 확인 |
|---|---|---|
| 이번 제출본의 분석/진단 구성은 무엇인가? | 검증한 Prod 설정을 기준으로 Mixpanel 사용과 Sentry 비활성을 정확히 표기하고, 별도 분석 변경을 합치면 표/테스트 재검토 | Mixpanel 프로젝트의 실제 리전·보유기간·삭제 절차·IP 지리정보 처리, 활성화할 SDK 범위 |
| 공개 정책 초안을 게시해도 되는가? | 위 정적 수집 목록을 사업자 계약/운영값으로 완성한 뒤 별도 승인으로 게시 | legal_documents 현재 버전, 법인/문의처/처리 관계와 국가 등 미확정값; 이름 누락만으로 거절을 단정하지 않음 |
| 심사자는 로그인 기능에 어떻게 접근하는가? | 기존 심사용 접근 방법을 ASC 보안 필드로 제공하고 2FA/초대 제한 없이 확인 가능한지 점검 | 계정/대체 접근 허용 여부와 로그인 후 사용 가능한 축제 데이터; 암호는 이 문서 밖에서 전달 |
| 제출할 버전과 빌드는 무엇인가? | ASC에 실제 처리 완료된 Prod 빌드와 이번 검증 커밋을 대조한 뒤 선택 | 현재 ASC 목록 미확인; QA/Stage 배포본과 Prod 제출본을 구분 |

## Sentry 원본 manifest 패키징

unsigned Prod archive에서 26개 manifest를 열거했으나 Sentry 원본은 없었다. `otool -L`에는 별도 Sentry 동적 프레임워크가 없고 `nm`으로 `FestiCoreAnalytics.framework/FestiCoreAnalytics` 안의 Sentry 심볼을 확인했다. pinned Sentry 9.34.0의 소스 제품 `SentrySPM`이 이 프레임워크에 정적으로 링크되며, Package.swift의 해당 소스 타깃에는 공식 manifest를 리소스로 전달하는 선언이 없다.

따라서 이미 사용하는 Tuist 모듈 `Sources` 리소스 전달 경로로 **FestiCoreAnalytics.framework/PrivacyInfo.xcprivacy**를 포함한다. 다른 SDK/앱 manifest를 덮어쓰지 않으며 SDK 원본 내용은 수정하지 않는다. 앱의 사용자 연결/추가 수집에 관한 ASC 답변은 SDK 기본 선언과 별도로 위 대응표에 기록한다.

원천: [pinned SDK 원본](https://github.com/getsentry/sentry-cocoa/blob/aa91bcf6bd6f383dbc49f38bf785d1d775c4f751/Sources/Resources/PrivacyInfo.xcprivacy), SHA256 `118b16e0e97ffe8b6f1f01b7e04f68e5da764474a4d39d2933b0eeaef3cdc0ca`. 다운로드한 원본과 로컬 SDK 파일의 byte 일치를 확인했다. 업그레이드 시 이 사본을 새 pinned 원본과 비교하고 SDK가 리소스를 전달하도록 수정되면 중복 사본을 제거해야 한다. 최종 signed archive의 경로·내용·중복 수를 다시 확인한다.
