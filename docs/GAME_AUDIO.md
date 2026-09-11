# 젤리몬 게임 오디오

## 제작 컨셉과 적용 위치

BGM v2는 말랑한 젤리 친구를 구조하고 아지트에서 함께 지내는 게임의 작은 규모에 맞춘다. 장난감 피아노·나무 목금·피치카토를 중심으로, 짧은 질문과 응답 같은 멜로디와 쉼표를 사용한다. 일반 퍼즐은 가장 성기게, 보스는 무서운 전투보다 익살스러운 도전으로 요청했다. 스토리는 전용 생성이 두 번 실패하여 새 홈 곡을 음높이 유지·속도 약 91.3%·낮은 음량으로 변주했다. 음악의 공통 편곡 방향을 맞춘 것이며 생성 곡에 동일 선율이 정확히 재현된다는 의미는 아니다.

| BGM | 게임 화면 | v2 제작 방향 | 요청 템포 |
| --- | --- | --- | --- |
| home | 타이틀·집 꾸미기 | 장난감 피아노와 목금의 짧고 다정한 응답 | 92 BPM |
| map | 레벨 선택·월드맵 | 목금·리코더·가볍게 통통 걷는 리듬 | 100 BPM |
| puzzle | 일반 퍼즐 | 성긴 목금 패턴·쉼표·절제된 반복 | 104 BPM |
| boss | 보스 퍼즐 | 목금·바순·피치카토의 장난스러운 도전 | 112 BPM |
| story | 대화·이야기 | 새 홈 곡의 느린 변주·RMS 0.09로 부드럽게 | 84 BPM 기준 변주 |

| 효과음 | 적용 |
| --- | --- |
| pop | 젤리 터짐, 소규모 상호작용 |
| pop_big | 큰 충격, 특수 퍼즐 동작 |
| clear | 성공·구조 완료 |
| fail | 실패·재도전 |
| shiny | 반짝 젤리·아이템·획득 알림 |
| grab | 블록 집기·작은 상호작용·대화 진행 |
| lock | 블록 안착 |
| ui_click | 동적으로 생성되는 메뉴·팝업 버튼 포함 공통 클릭 |
| reward | 출석 보상 수령 팝업 |
| merge, grow, fever | 기존 파일·호출 이름 호환을 위한 추가 라이브러리. 현재 게임 규칙에는 전용 호출 없음 |

현재 게임에 있는 소리 호출을 새 에셋으로 교체한다. 새로운 합치기·성장·피버 게임 규칙을 추가하지는 않는다.

## 생성 서비스와 출처

- 서비스: <http://10.10.4.71:8991/>
- API 문서: <http://10.10.4.71:8991/docs>, 기계 판독 안내: <http://10.10.4.71:8991/ai.md>
- BGM: `ace_step_15`, `music/bgm`, 원본 80초씩 요청.
- 효과음: `stable_audio_open_small`, `sfx`, 0.5~2.8초 요청.
- `POST /api/generate` → 반환된 ID로 `GET /api/jobs/{id}` → 완료 시 `GET /api/assets/{id}/file`.
- 서버는 한 번에 한 작업만 처리한다. `queued` 상태는 실패가 아니다.
- 두 엔진 모두 이 서버에서 seed 지정을 지원하지 않는다. 같은 프롬프트 재요청만으로 동일 음원을 재현한다고 보장하지 않는다.
- 정확한 프롬프트·job ID·asset ID·원본 및 최종 파일 SHA-256·실측 정보는 `AUDIO_ASSET_MANIFEST.json` 참조.

## 반복 BGM 처리

서버의 `loop_repeats`는 요청 구간을 N번 붙이는 기능이므로 게임용 영구 루프 파일을 만드는 데 사용하지 않았다. 80초 원본에서 앞뒤 여유가 있는 중간 구간을 선택한다.

1. 스펙트럼 변화의 자기상관으로 요청 BPM 근처의 실제 템포를 추정한다. 신뢰도가 낮으면 요청 BPM을 사용하고 그 사실을 명세에 기록한다.
2. 16마디에 해당하는 길이를 계산하고, 시작과 끝의 스펙트럼·에너지 차이가 작은 위치를 선택한다.
3. 끝의 한 박자 여유 구간을 시작의 한 박자와 raised-cosine 방식으로 중첩한다. 이음새에 무음을 넣거나 매 반복마다 페이드아웃하지 않는다.
4. 공통 RMS와 피크 상한을 적용한 뒤 스테레오 OGG Vorbis로 저장한다.
5. OGG를 다시 디코딩해 무음·클리핑·반복 경계의 샘플 차이를 검사한다. 원본뿐 아니라 실제 게임에 넣는 압축 파일이 검사 대상이다.

이 방법은 파형의 급격한 단절과 무음 간격을 줄인다. AI 연주가 정확히 일정한 박자·화성으로 생성된다는 보장은 없으므로, 자동 검사를 음악적 청감 승인과 동일시하지 않는다. 기기 스피커와 이어폰에서 반복 구간의 리듬·화성 자연스러움을 최종 확인할 수 있도록 아래 미리듣기를 제공한다.

## 게임 연결

`MusicMgr.gd`는 5개 OGG를 `AudioStreamOggVorbis.loop = true`, `loop_offset = 0`으로 재생한다. 화면 전환 시 2개 플레이어를 0.65초 동안 크로스페이드한다. 퍼즐 일시정지 때 BGM은 기존 음량의 22%로 낮아진다. 사운드를 끄면 페이드 후 스트림도 일시정지해 디코딩을 멈춘다. 같은 화면에서 같은 테마를 요청하면 처음부터 재시작하지 않는다.

기존 GDScript의 샘플별 사인파 합성 루프를 제거했다. 전환이 끝나면 `_process`도 중지한다. 효과음은 기존 14개 플레이어 풀을 유지하고, 사운드를 끄면 현재 재생 중인 효과음도 정지한다. 공통 UI 클릭은 `button_down`에 연결해 해당 버튼 콜백이 화면을 제거하기 전에 재생한다.

## 재가공·검증

브라우저에서 [오디오 미리듣기](AUDIO_PREVIEW.html)를 열면 각 BGM의 끝 4초부터 반복 경계를 들을 수 있다. 한 음원을 재생하면 다른 미리듣기는 자동 정지한다.

```sh
python3 -m venv /tmp/jellymon-audio-venv
/tmp/jellymon-audio-venv/bin/pip install numpy soundfile imageio-ffmpeg
# 원본이 없는 체크아웃에서 같은 서비스에 접근할 수 있을 때:
python3 tools/download_generated_audio.py --output tmp/audio-current
/tmp/jellymon-audio-venv/bin/python tools/process_generated_audio.py --source tmp/audio-current
Godot --headless --editor --path . --quit
Godot --headless --path . --quit-after 900 res://tools/verify_generated_audio.tscn
```

현재 명세의 원본을 복원할 때는 위 명령처럼 별도의 `tmp/audio-current`를 사용한다. 기존 v1 원본을 같은 이름으로 덮어쓰지 않는다. v2 제작 원본은 `tmp/audio-generation-v2`, 이전 BGM과 명세 백업은 그 안의 `previous/`에 보관한다. 미리듣기의 이전 곡 비교는 이 로컬 백업이 있는 작업 환경에서 사용할 수 있다.

가공 도구의 기본 입력은 `tmp/audio-generation/jobs.json`과 같은 폴더의 원본 WAV다. 다운로드가 전부 끝나지 않았으면 기본 실행은 실패하며, `--partial`을 주면 완료한 것만 가공한다. 원본 다운로드와 이전 효과음 백업은 `tmp/audio-generation/`에 남긴다. 이 폴더 및 문서는 `.gdignore`와 export 제외 필터로 빌드에서 빠진다. 게임 배포에는 `audio/`의 최종 OGG/WAV만 포함한다.

엔진 검증은 BGM 5종 로드·반복 경계 재생·일시정지 음량·음소거·음소거 중 테마 변경·효과음 로드·새 UI 버튼 연결을 확인한다. 자동 파형 검사와 실제 청감 확인 범위는 구분해서 기록한다.

## 모델 이용 조건 기록

효과음 제작 도구 표기: **Powered by Stability AI**.

서버가 제공한 모델 정보에서 ACE-Step 1.5는 MIT, Stable Audio Open Small은 Stability AI Community License로 표시된다. [Stable Audio Open Small 공식 라이선스](https://huggingface.co/stabilityai/stable-audio-open-small/blob/main/LICENSE)는 모델 상업 이용의 등록·매출 조건과 출력물 소유를 별도로 다룬다. 출력물은 정의상 모델 Derivative Works에서 제외된다. 이 게임에는 모델 가중치나 추론 서버를 포함하지 않으며 음원 출력 파일만 포함한다.

모델을 운영·생성하는 주체는 해당 이용 조건을 충족해야 한다. 내부 서비스 운영자의 상업 이용 등록이나 별도 계약 상태는 이 코드 작업에서 확인할 수 없다. 생성 결과의 상업 이용을 무조건 보증한다는 기존 README 문구는 삭제했다. 서버가 안내한 연매출 조건은 게임 하나의 매출이 아니라 모델 이용 조직·관계사의 조건임에 유의한다.

## 2026-09-11 최초 제작(v1) 검증 이력

- BGM 5곡 + 효과음 12개 생성 완료. 원본 복구 도구로 17개 SHA-256 일치 확인.
- BGM 길이: 홈 50.57초, 맵 41.60초, 퍼즐 33.36초, 보스 35.21초, 스토리 57.32초.
- 최종 파일 합계 4,180,248 bytes (3.99 MiB): BGM 3,529,602 bytes, 효과음 650,646 bytes.
- 최종 음원 17개 디코딩·무음·클리핑 검사 통과. BGM 5개 루프 경계 검사 통과.
- Godot `verify_generated_audio.tscn`: failures=0. 실제 끝부분 seek 후 다음 루프로 넘어가는 재생, 테마 전환, pause ducking, 음소거와 복원, 동적 버튼 클릭, 효과음 로드 확인.
- Godot `verify_ui_localization.tscn`: failures=0. 공통 버튼 오디오 연결 이후 주요 화면·팝업·외국어 표시 회귀 없음.
- 테스트 종료 시 AudioServer의 다음 믹스 주기까지 기다린 뒤 리소스 누수 경고 없이 종료함을 확인.
- ARM64 디버그 APK: `output/JellyMon-audio-preview.apk`, 132,820,431 bytes (126.67 MiB).
- APK ZIP 내부: 음원 17개의 import 매핑 및 실제 리소스 존재. `tmp/docs/server/native/build/output/tools`와 x86 라이브러리 포함 0건.
- 로그: `/tmp/jellymon-audio-final-mastering.log`, `/tmp/jellymon-audio-final-runtime-console.log`, `/tmp/jellymon-audio-source-recovery.log`, `/tmp/jellymon-audio-ui-regression-console.log`, `/tmp/jellymon-audio-apk-console.log`.

APK는 설치 검토용 디버그 빌드다. Android/iOS 실기기 스피커·이어폰 청감 검사나 스토어 배포 승인을 완료했다는 의미는 아니다. 직접 반복 구간을 들으려면 `AUDIO_PREVIEW.html`의 이음새 버튼 또는 게임의 해당 화면을 이용한다.

## 2026-09-11 BGM v2 적용 결과

- 새 생성곡 4개와 새 홈 테마 기반 스토리 변주 1개로 BGM 5개 모두 교체했다. 이전 효과음 12개의 SHA-256은 변경되지 않았다.
- 스토리 전용 생성은 LM Studio 모델 `google/gemma-4-26b` 프롬프트 변환 HTTP 400으로 두 번 실패했다. 완료된 원본을 사용한 변주로 대체했으며 5곡 모두 독립 생성됐다고 표기하지 않는다. 원본 job/asset ID와 변주 속도는 명세에 기록했다.
- 음높이를 유지하는 변주는 로컬 FFmpeg `atempo`를 사용했다. 최종 파일은 모두 48 kHz 스테레오 OGG, 16마디 루프다.
- BGM 길이: home 43.29초, map 34.56초, puzzle 34.56초, boss 33.11초, story 47.37초.
- BGM 총 용량: 3,070,486 bytes.
- 디코딩·무음·클리핑·루프 경계 검사 통과. 자동 파형 검사는 음악적 청감 승인과 구분한다. [미리듣기](AUDIO_PREVIEW.html)에서 새 곡·이전 곡·반복 경계를 비교할 수 있다.
- Godot `verify_generated_audio.tscn`: failures=0, 종료 코드 0. 새 루프 실제 재생·전환·일시정지·음소거·효과음 연결 검증 완료. 임포트와 iOS 리소스 export 오류 0건.
- Xcode iPhone Debug 빌드 성공. 새 `build/ios/JellyMon.pck`와 빌드 앱 내부 팩의 SHA-256 일치를 확인했다. 기존 DataStore 수정 브리지는 유지했다.
- 2026-09-11 15:16 KST, 재연결된 iPhone 16 Pro에 새 BGM 빌드(`com.jellymontest.game`) 업데이트 설치 완료. 기존 앱 삭제·저장 초기화는 하지 않았다. 설치 후 자동 실행은 기기 잠금(`Locked`, FBSOpenApplicationErrorDomain 7)으로 차단되어 기기 청감 확인은 남아 있다.
- 2026-09-11 15:19 KST, Android Galaxy Note10+ (`SM_N971N`)에 `output/JellyMon-bgm-v2.apk`를 `adb install -r`로 업데이트 설치했다. APK 132,350,399 bytes, ARM64 전용. 패키지 내부 BGM 리소스 5개가 새 임포트 파일과 바이트 단위로 일치했다. 콜드 실행·오디오 초기화·저장 로드·홈 첫 프레임 확인, 관찰 로그에서 스크립트 오류·크래시 없음. 기기 청감 승인을 대신하는 검사는 아니다.
