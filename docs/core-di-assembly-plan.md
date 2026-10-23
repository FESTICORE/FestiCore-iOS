# Core 모듈 DI 조립 계획

## 목표

Attendance_iOS처럼 Core의 생성 경계를 `CoreAssembly`에 모으고, 각 구현 모듈이 소유한 등록 함수를 상위 조립 계층에서 호출한다. 앱은 `ServiceAssembly`에서 네트워크·인증의 수명주기를 연결한다. 이번 PR의 변경량은 2,000라인 이내로 유지한다.

## 확인한 현재 구조

- `FestiCoreStorage/StorageFactory`는 저장소 생성과 `DependencyValues` 등록을 이미 소유한다.
- `ServiceAssembly/NetworkContainer`는 인증 서비스와 인증 클라이언트 한 쌍을 생성한다.
- `ServiceDependencyAssembly`는 저장소를 직접 등록하고 두 인증 의존성을 조립한다.
- Attendance_iOS는 `CoreAssembly/StorageAssembly`가 저장소의 등록을 호출하고 `ServiceAssembly`가 인증 의존성을 조립한다.

## 변경

1. `Projects/Core/CoreAssembly`에 `NetworkAssembly`와 `StorageAssembly`를 추가한다. 두 타입은 기존 `NetworkClientFactory`와 `StorageFactory`를 사용한다.
2. Tuist 모듈 목록과 `ServiceAssembly` 의존성을 갱신한다. `ServiceDependencyAssembly`는 `StorageAssembly.register(into:)`를 호출한다. Attendance처럼 인증 클라이언트와 인증 서비스의 live `DependencyKey`도 `ServiceAssembly`가 등록하며, 두 값은 `NetworkContainer`의 동일한 인스턴스를 사용한다.
3. Swift Testing으로 Core 생성과 Service 등록 동작을 확인한다. 현재 앱의 인증·저장소 동작을 바꾸지 않는다.
4. README의 Team ID 표기를 제거한다. 번들 ID와 iOS 지원 버전은 유지한다.

## 검증

- `./make generate`로 Tuist 그래프 생성을 확인한다.
- `./make test`로 `FestiCore-Stage` 테스트 플랜 전체를 실행한다. `TuistTool.swift`의 `testFull`이 선택적 테스트를 끄는 명령임을 확인했다.
- `git diff --check`와 `git diff --stat`으로 공백 오류와 PR 변경량을 확인한다.

## 제약

- WeaveDI와 신규 패키지는 추가하지 않는다.
- Attendance 전용 저장소·네트워크 기능은 이번 범위에 복제하지 않는다.
- Live Activity 서명 수정 PR #19와 변경을 섞지 않는다.
