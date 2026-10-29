# Git과 PR 작업

## 브랜치와 커밋

- `feature/<작업명>` 브랜치에서 작업하며 PR 대상은 `develop`이다.
- 브랜치 이름에 이슈 번호를 넣지 않는다. 각 커밋 제목 끝에는 해당 작업 이슈 번호를 `#27`처럼 붙인다.
- 커밋 제목과 본문을 한국어로 작성한다. Tuist 기반, Core, UI, 문서 등 독립적인 변경은 나누어 커밋한다.
- 다른 작업자의 수정이 섞여 있을 수 있으므로 `git status`와 `git diff`를 확인하고 소유 파일만 stage한다.
- PR 변경 규모는 2,000줄 이내로 나누고, 검증이 끝난 PR은 squash merge한다.

## 스쿼시 머지 메시지

- 최종 커밋 제목은 변경 의도를 간결한 한국어로 적고 해당 작업 이슈 번호를 끝에 붙인다.
- 본문에는 필요한 변경 요약만 남긴다. GitHub가 자동으로 채운 개별 커밋 제목과 본문 목록은 머지 전에 모두 삭제한다. PR 설명은 이 규칙과 별도로 유지한다.
- CLI에서는 `gh pr merge <PR 번호> --squash --subject '<한국어 제목 #이슈번호>' --body-file <요약 파일>`처럼 제목과 본문을 모두 명시한다. 요약 파일에도 개별 커밋 내역을 넣지 않는다.
- 머지 후 `gh pr view <PR 번호> --json mergeCommit -q .mergeCommit.oid`로 해당 PR의 머지 커밋을 찾고, `gh api repos/FESTICORE/FestiCore-iOS/commits/<OID> --jq '.commit.message'`로 최종 메시지를 확인한다. 자동 생성 커밋 목록이 남았다면 기록하고 다음 머지부터 규칙을 적용한다. 메시지 수정을 위해 `develop` 이력을 다시 쓰지 않는다.

## PR 검증

PR을 생성할 때 `gh pr create --assignee Roy-wonji`로 작성자를 담당자로 지정한다. 다른 방법으로 PR을 만들었다면 `gh pr edit <PR 번호> --add-assignee Roy-wonji`를 실행한다. 생성 직후 `gh pr view <PR 번호> --json assignees`로 할당 여부를 확인한다.

PR 본문에는 변경 범위, 테스트 명령과 결과, 실행하지 못한 검증을 구분해 쓴다. PR 라벨은 저장소에 있는 작업 유형 라벨을 사용한다. CI 성공과 로컬 테스트, 실기기 검증을 같은 결과로 표현하지 않는다. 이슈는 작업 PR이 합쳐지고 요구 사항을 확인한 뒤 닫는다.

AI 리뷰가 요청되면 결과가 도착했는지 확인한다. 리뷰 요청만으로 승인이나 완료를 추정하지 않는다.
