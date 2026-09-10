# UI 테마 통일

메인 화면에서 선택한 A/B/D 테마를 다른 화면과 팝업에도 적용한다. A는 크림·코랄, 기본 B는 크림·민트, D는 자주색·금빛 UI를 사용한다. 아래 기본 팔레트는 A 기준이며, D의 패널·글자·상태색은 `ArtDirection`의 테마별 접근자로 전환한다. 상세 색상과 화면은 [홈 테마 문서](HOME_ROOM_THEMES.md)를 참고한다.

## 공통 규칙

| 역할 | 색상 |
|---|---|
| 패널 | `#fff7e9` |
| 주요 행동 | `#f58f7d` |
| 본문·제목 | `#765338` |
| 테두리 | `#dfc7a9` |
| 선택·완료 | `#d4eee2` |
| 완료 상태 글자 | `#285d4a` |
| 비활성 | `#e9e0d4` |
| 보조 글자 | `#8b705a` |
| 경고·강조 글자 | `#ad453d` |

기존 유광 반사선, 두꺼운 입체 테두리, 큰 그림자, UI 글자 외곽선을 제거했다. 젤리와 게임 오브젝트의 식별 색상 및 장면 배경은 유지한다.

## 적용 범위

- 홈의 테마 선택, 꾸미기, 촬영, 토스트.
- 상점, 구매 확인, 출석, 일일 미션, 시즌 생활, 마을 복구, 도감, 앨범, 피드백.
- 설정, ON/OFF 스위치, 언어 선택 목록, 닉네임 입력, 계정/해금 안내.
- 지도 상단 UI, 레벨 버튼, 레벨 상세, 에너지 부족 안내.
- 스토리 제목·대사 패널과 건너뛰기.
- 게임 HUD, 시간·목표·힌트, 부스터, 튜토리얼, 일시정지, 성공·실패 팝업.

현재 지도 레벨은 코랄, 완료 레벨은 민트, 잠긴 레벨은 비활성 색상으로 구분한다. 지도 팝업은 현재 위치 캐릭터보다 위에 표시한다. 시간 부족 경고, ON/OFF, 보상 수령 및 버튼 비활성 상태의 기능은 그대로 사용한다.

## 구현

`ArtDirection.gd`의 `surface`, `apply_button`, `ui_theme`가 공통 스타일을 만든다. 홈의 `_home_surface`도 같은 함수를 사용한다. `ui_theme`는 한 번 생성해 공유하며 각 화면 루트, 게임 HUD, 언어 선택 팝업에 연결한다. 기본 입력창과 스크롤바까지 같은 테마를 사용한다.

기존 `panel`·`glass_panel`의 색상/그림자 인수는 이전 호출과의 호환을 위해 받지만 공통 크림 재질을 반환한다. 새로운 상태별 색상은 `surface(ArtDirection.SELECTED)`처럼 명시적으로 지정한다. 기존 `decorate_surface`는 유광 장식을 생성하지 않는다.

## 검증

`tools/verify_ui_theme.tscn`은 플레이어 저장을 사용하지 않는 테스트로 25개 화면을 촬영하고, ON/OFF·비활성·포커스·언어 선택 목록 테마를 검사한다. 최종 검사 오류는 0건이다. 결과 이미지는 `output/ui-theme/`에 저장한다. 기본 테마 연결 후 스토리 오버레이 검사도 다시 통과했다.

기존 `tools/verify_release.mjs --quick`의 번역, 스토리 번역, 타이핑, 스토리 오버레이, 지연 함정, 종료 검사 6개를 통과했다. 모바일 실기기 검사는 이번 작업 범위에 포함하지 않았다.

## 미리보기

- [상점](../output/ui-theme/shop.png)
- [설정](../output/ui-theme/settings.png)
- [언어 선택](../output/ui-theme/language_options.png)
- [출석](../output/ui-theme/attendance.png)
- [시즌 생활](../output/ui-theme/lifestyle.png)
- [지도](../output/ui-theme/map.png)
- [스토리](../output/ui-theme/story.png)
- [게임](../output/ui-theme/game.png)
- [성공](../output/ui-theme/clear.png)
- [실패](../output/ui-theme/fail.png)

## 테마별 강조색

B의 주요 버튼 및 진행 막대는 `ArtDirection.primary_color()`가 반환하는 민트색을 사용한다. A/D는 코랄색을 사용한다. 메인 화면의 B 전용 아이콘과 비교 화면은 [방 테마 문서](HOME_ROOM_THEMES.md)의 B 전용 UI 항목을 참고한다.
