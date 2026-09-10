# 가구 외형 개편

## 방향

A(햇살 크림), B(민트 아침), D(달빛 아지트)의 방 배경에 맞춰 가구를 원목, 패브릭, 도자기, 황동 소재의 부드러운 2D 일러스트로 교체한다. 기본 테마 B와 A형 메뉴 배치를 유지한다. 정면에서 약간 내려다보는 시점이며, 3D 모델이나 등각 투영 리소스를 추가하지 않는다.

## 대상

| 이미지 시트 | 대상 | 수량 |
|---|---|---:|
| everyday_1.png | 쿠션·스탠드·테이블·선반·소파·벤치·러그·수납장·화분·파티션 | 10 |
| everyday_2.png | 카운터·미끄럼틀·침대·책장·티세트·피아노·분수·정원·무대·성채 | 10 |
| keepsakes.png | 구출 및 별 수집 기념 장식 | 10 |
| journey.png | 원정 보상 소품과 가구 | 10 |
| special.png | 패키지 및 시즌 전용 가구 | 10 |

## 연결 구조

- `assets/furniture/`: 런타임 PNG 시트.
- `assets/data/furniture_art.json`: 기존 가구 ID별 시트 경로와 픽셀 영역.
- `scripts/FurnitureArt.gd`: 시트를 한 번 읽고 가구별 AtlasTexture를 공유하는 캐시.
- `scripts/RoomFurniture.gd`: 실제 배치 화면의 그림 표시와 선택 영역.
- `scripts/Title.gd`: 꾸미기 목록의 동일 이미지 미리보기.

가구 ID, 가격, 해금 조건, 보유 여부, 저장 형식, 배치 좌표와 충돌 규칙은 기존 데이터를 사용한다. 새로운 방에는 가구를 자동 배치하지 않는다. 기존 저장에 배치된 가구는 같은 위치에서 새 그림으로 표시한다.

## 배치와 회전

그림은 기존 점유 영역의 바운딩 박스 안에 비율을 유지해서 맞추고 바닥에 정렬한다. 선택 상태에서는 실제 점유 셀을 표시한다. L/T형의 빈 칸은 계속 다른 가구를 배치할 수 있는 칸이므로 그림의 외곽과 점유 셀이 항상 일치하지는 않는다.

회전은 기존 0~3 방향의 점유 칸 변환을 유지한다. 세로로 선 스탠드나 책장이 눕지 않도록 이미지 자체를 90도 기울이지 않는다. 180/270도 방향에는 좌우 반전을 사용한다. 각 방향별 원근을 보여주는 4방향 그림은 이번 리소스에 포함하지 않는다.

전용 가구의 터치 반응과 반짝임은 유지한다. 선택 테두리와 반짝임은 엔진에서 그리므로 추가 이미지가 필요하지 않다.

## 제작 기록 및 검증

이미지는 내장 imagegen 도구로 제작했다. 프롬프트 기록은 `output/furniture-refresh/prompts.json`에 보관한다.

검증 씬: `tools/verify_furniture_art.tscn`. 전체 ID와 투명도, 50종 × 4방향의 점유 영역과 종횡비, 실제 홈 화면 및 꾸미기 회전·삭제를 확인한다. `--render-furniture`를 전달하면 `output/furniture-refresh/`에 A/B/D 배치 화면, 꾸미기 목록, 전체 가구 도감을 저장한다. 플레이어 저장 파일을 읽거나 수정하지 않는 테스트용 저장 객체를 사용한다.

### 검증 결과 (2026-09-08)

- 가구 50종 전체 이미지 및 실제 알파 채널 확인.
- 50종 × 4방향, 총 200개 점유 영역·종횡비 검사 통과.
- A/B/D 실제 홈 화면과 꾸미기 목록 렌더링 확인.
- 회전 및 삭제 동작 통과. 기존 빈 방·테마 선택·저장 회귀 검사 오류 0건.
- 모바일 실기기 빌드/성능 검사는 이번 작업에서 수행하지 않았다.

### 미리보기

- [A 적용 화면](../output/furniture-refresh/A_furnished.png)
- [B 적용 화면](../output/furniture-refresh/B_furnished.png)
- [D 적용 화면](../output/furniture-refresh/D_furnished.png)
- [꾸미기 목록](../output/furniture-refresh/furniture_palette.png)
- [기본 가구 1](../output/furniture-refresh/catalog_1.png), [기본 가구 2](../output/furniture-refresh/catalog_2.png), [기념 가구](../output/furniture-refresh/catalog_3.png), [원정 가구](../output/furniture-refresh/catalog_4.png), [전용 가구](../output/furniture-refresh/catalog_5.png)
- [내장 imagegen 프롬프트 기록](../output/furniture-refresh/prompts.json)
