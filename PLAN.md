# JochungCam 개발 계획서

## 분석 요약

### 꿀캠 원본 구조
```
Honeycam/
├── Honeycam.exe          — Win32 C++ 네이티브 앱 (MSVC)
├── config.ini            — 글로벌 설정 (URL, 색상 등)
├── VersionNo.ini         — BuildNo=42151
├── resource.h            — UI 리소스 정의 (~600개 컨트롤 ID)
├── skin.dat              — 커스텀 스킨 시스템
├── data/
│   ├── chatbubble.dat    — 말풍선 에셋
│   ├── collage.dat       — 콜라주 레이아웃
│   ├── photoframe.dat    — 액자 효과 에셋
│   ├── sticker.dat       — 스티커 에셋
│   ├── font_preset.ini   — 폰트 프리셋 (아웃라인, 그림자, 색상)
│   ├── cursor_*.cur      — 커서 에셋 (컬러피커, 이동, 삭제, 회전, 리사이즈, 텍스트)
│   ├── icon_*.png        — UI 아이콘
│   ├── magnifier*        — 돋보기 툴 에셋
│   ├── sample.*          — 샘플 이미지
│   └── web32.exe         — 웹 업로드 헬퍼
├── dll/
│   ├── libavif.enc.x64.dll    — AVIF 인코더 (5.6MB)
│   ├── libmf.x64.dll          — Media Foundation 래퍼 (221KB)
│   ├── libopencv-hcm.x64.dll  — OpenCV 커스텀빌드 (5.9MB)
│   ├── libwebm.x64.dll        — WebM 인코더 (1.9MB)
├── langs/                — 28개 언어 지원
├── models/
│   └── super_resolution/ — AI 업스케일링 모델
│       ├── ESPCN_x2/x3/x4.pb    — 경량 (86~100KB)
│       └── FSRCNN_x2/x3/x4.pb   — 초경량 (39~42KB)
```

### 오픈소스 기술 스택 (OpenSourceLicense.txt 기반)
| 라이브러리 | 버전 | 역할 | 맥 대체 |
|---|---|---|---|
| GIFLIB | 5.2.1 | GIF 인코딩/디코딩 | ImageIO (네이티브) |
| **libimagequant** | 2.5.1 | **GIF 양자화 (핵심)** | libimagequant (동일) |
| pngnq | 1.1 | 팔레트 양자화 대안 | — |
| SimplePaletteQuantizer | — | Octree/NeuQuant 양자화 | 직접 구현 |
| libWebP | 1.2.2 | WebP 인코딩 | libwebp (Homebrew) |
| libvpx | 1.8.2 | VP8/VP9 인코딩 | libvpx (Homebrew) |
| libwebm | 1.8.2 | WebM 컨테이너 | libwebm |
| libavif + libaom | 0.10.1 / 3.3.0 | AVIF 포맷 | libavif (Homebrew) |
| libjpeg-turbo | 2.1.2 | JPEG | ImageIO (네이티브) |
| libpng | 1.6.37 | PNG | ImageIO (네이티브) |
| zlib | 1.2.11 | 압축 | 시스템 내장 |
| OpenCV | 4.6.0 | 이미지 프로세싱 + DNN | Core Image + Vision |
| DXGICaptureSample | — | 화면 캡처 | ScreenCaptureKit |
| Super Resolution | — | AI 업스케일링 | Core ML / Vision |
| Mean-Shift-Segmentation | — | 세그멘테이션 | Vision Framework |
| LZ4 | 1.9.3 | 디스크 캐시 압축 | lz4 / NSData compression |
| CTPL | — | 스레드 풀 | Swift Concurrency |
| jsoncpp | 0.9.4 | 설정 파싱 | Codable (네이티브) |

### 꿀캠 기능 전체 목록 (resource.h + lang 파일 분석)

#### 1. 녹화 시스템
- 영역 선택 녹화 (드래그)
- 전체 화면 / 반 / 1/4 녹화
- 사전정의 크기 (320x240 ~ 1920x1080 + 커스텀)
- FPS: 1, 5, 10, 15, 20, 25, 30, 33, 50, 60 + 커스텀
- 최대 녹화 시간 설정
- 녹화 일시정지/재개
- 커서 캡처 (on/off)
- 커서 강조 (하이라이트 색상 설정)
- 커서 클릭 효과 (좌클릭/우클릭 색상 분리)
- 마우스 트래킹 모드
- 동일 프레임 스킵
- DXGI 캡처 (고성능)
- 녹화 위치 기억 (4슬롯)
- 녹화 후 바로 편집 진입 옵션
- 다이렉트 세이브 (녹화 중 실시간 저장)
- 녹화 툴바 위치 (상/하)
- 카운트다운

#### 2. 편집 시스템
- **프레임 편집**
  - 프레임 삭제/복제/이동/잘라내기/붙여넣기
  - 프레임 순서 뒤집기 (전체/선택)
  - 프레임 시간 개별 조정
  - 속도 조절 (10% 단위 빠르게/느리게)
  - 요요 프레임 (앞뒤 반복)
  - 프레임 줄이기 (짝수/홀수/N번째/유사프레임)
  - 비디오 서머리 (자동 요약)
  - 프레임 병합
  - 선택: 전체/짝수/홀수/N번째 프레임 선택

- **자르기 (Crop)**
  - 드래그 크롭
  - 비율 고정 크롭
  - 크롭 위치 지정 (좌표)
  - 크롭 그리드 표시
  - 배경색 (검정/흰색/투명/커스텀)

- **크기 조정**
  - 리사이즈 (비율/절대값)
  - 2x 확대
  - **Super Resolution AI 업스케일** (ESPCN x2/x3/x4, FSRCNN x2/x3/x4)
  - 비율 유지 옵션

- **필터/효과**
  - 밝기 (Brightness)
  - 대비 (Contrast)
  - 감마 (Gamma)
  - 채도 (Saturation)
  - 블룸 (Bloom) — 강도, 블러, 알파
  - 그레이스케일
  - 세피아
  - 비네팅 (Vignetting)
  - 스캔라인
  - 필터 프리셋 저장/불러오기 (4슬롯)

- **그리기 (Drawing)**
  - 전체/선택 프레임에 적용
  - 바이리니어 정밀 모드

- **삽입 (Insert)**
  - 텍스트 — 폰트, 크기, 색상, 아웃라인, 그림자 (거리/각도/블러/알파)
  - 텍스트 프리셋 (font0~font6+)
  - 실시간 텍스트 미리보기
  - 스티커
  - 말풍선
  - 오브젝트 애니메이션 효과
  - 로고/워터마크 (이미지, 위치 9곳, 스케일, 배경)
  - 텍스트 워터마크

- **액자 효과 (Photoframe)**
  - 커스텀 액자 프레임
  - 마진 조정 (상하좌우)

- **줌 애니메이션**
  - 줌 인/아웃 효과 (확대 영역 지정)

- **콜라주**
  - 여러 이미지 합성 레이아웃

- **트랜지션**
  - 프레임 간 전환 효과
  - 화이트로/블랙으로/오버랩/플래시/화이트에서/블랙에서

- **Undo/Redo**
  - 상태 저장/복원
  - 디스크 캐시 사용 옵션
  - 메모리 사용량 제한 설정

#### 3. 저장/내보내기
- **포맷**: GIF, WebP, WebM, MP4, APNG, AVIF
- **GIF 옵션**
  - 양자화 알고리즘 선택 (LIQ, NeuQuant, Octree)
  - 양자화 품질/속도 조절
  - 색상 수 (최대 256)
  - 디더링 on/off
  - 중앙 포커스 컬러 디더링
  - 유사 픽셀 제거
  - GIF 코멘트 저장 여부
  - 루프 횟수 (무한/유한)
  - 50fps 제한 경고
  - 양자화 스킵 (Q=100일 때)
  - 색상 보호 (Preserve Colors)
  - Bandi Color Compress
- **WebP 옵션**
  - 품질 조절
  - Lossy/Lossless/Auto
  - 압축률 (tradeoff)
  - iPhone 호환 모드
  - 루프 횟수
  - 알파 채널 (적응형/저장/미저장)
- **WebM 옵션**
  - 코덱 선택
  - 품질 조절
  - 알파 채널
- **MP4 옵션**
  - H.264 프로파일 선택
  - 품질 조절
  - Media Foundation 기반
- **APNG 옵션**
  - 색상 (256/24bit)
  - 양자화 설정
  - 루프 횟수
- **AVIF 옵션**
  - libavif + libaom 기반
- **공통**
  - 출력 파일 크기 제한 (FPS 조절/이미지 크기 조절/유사프레임 스킵)
  - 프로그레스 바 임베드 옵션
  - 저장 경로 프리셋
  - 파일명 규칙 설정
  - 저장 후 폴더 열기
  - 배치 변환

#### 4. 임포트
- 이미지 파일 (JPEG, PNG, BMP, TIFF...)
- 애니메이션 파일 (GIF, WebP, APNG)
- 동영상 파일 (MP4, WebM, MOV...)
- 클립보드에서 붙여넣기
- 드래그&드롭
- 비디오 컷 (구간 잘라서 임포트)
- 리사이즈 설정 (임포트 시)
- 프레임 타임 설정

#### 5. UI/UX
- 커스텀 스킨 시스템
- 탭: 녹화 / 편집 / 자르기 / 효과 / 삽입 / 액자 / 줌FX / 콜라주 / 임포트 / 관리
- 미니맵 표시
- 줌 패널 (100%, 확대/축소, 자동맞춤)
- 2x 프리뷰
- 단축키 시스템 (녹화/일시정지/클립보드/에디터/찾기/선택캡처/프린트)
- 항상 위 옵션
- ESC 동작 선택 (종료/최소화/무동작)
- 위치 기억 (녹화/편집)
- 다국어 (28개 언어)

#### 6. 기타
- imgur 업로드
- 파일 관리자 (이름변경/폴더열기/편집/삭제)
- 업데이트 체크 (정식/베타)
- 라이선스 시스템
- 크래시 리포트
- 설정 내보내기/가져오기

---

## 개발 계획

### Phase 1: 코어 (MVP) — 1~2주
> 녹화 + 기본 편집 + GIF/WebP 저장

1. **화면 캡처 엔진** ✅ (완료)
   - ScreenCaptureKit 기반 영역 선택 녹화
   - FPS 조절, 일시정지/재개
   - 커서 캡처 + 클릭 추적

2. **GIF 인코더 업그레이드**
   - libimagequant 통합 (SPM 패키지 or C 바인딩)
   - NeuQuant, Octree 양자화 구현
   - 디더링 옵션
   - 파일 크기 최적화 (색상 수, FPS 조절, 유사프레임 스킵)

3. **WebP 인코더**
   - libwebp C 바인딩 (Homebrew)
   - Lossy/Lossless/Auto

4. **기본 편집** ✅ (완료)
   - 프레임 삭제/복제/이동/뒤집기
   - 속도 조절
   - 프레임 시간 개별 편집

5. **기본 UI** ✅ (완료)
   - 녹화 화면, 에디터, 타임라인, 툴 패널

### Phase 2: 편집 심화 — 1~2주
> 꿀캠 편집 기능 90% 달성

6. **자르기 (Crop) UI**
   - 인터랙티브 크롭 오버레이
   - 비율 고정, 좌표 입력
   - 그리드 표시

7. **필터 엔진 확장**
   - 감마, 블룸 (강도/블러/알파), 비네팅, 스캔라인
   - 필터 프리셋 저장/불러오기

8. **텍스트 오버레이 고급**
   - 아웃라인 + 그림자 (거리/각도/블러/알파)
   - 폰트 프리셋 시스템
   - 오브젝트 애니메이션

9. **트랜지션 효과**
   - 화이트/블랙/오버랩/플래시 전환

10. **Undo/Redo 시스템**
    - 상태 스냅샷
    - 디스크 캐시 (LZ4 압축)

### Phase 3: 고급 기능 — 2~3주
> 꿀캠 차별화 기능

11. **AI 업스케일링 (Super Resolution)**
    - ESPCN/FSRCNN 모델 Core ML 변환
    - x2/x3/x4 옵션

12. **추가 포맷**
    - MP4 (H.264) ✅ (완료)
    - WebM (VP9) — libvpx 바인딩
    - APNG — ImageIO 기반
    - AVIF — libavif 바인딩

13. **커서 렌더링**
    - 커서 하이라이트 (색상 커스텀)
    - 좌/우 클릭 효과 (색상 분리)

14. **콜라주/액자**
    - 콜라주 레이아웃 시스템
    - 액자 프레임 + 마진

15. **줌 애니메이션**
    - 키프레임 기반 줌 인/아웃

### Phase 4: 완성도 — 1~2주
> 프로덕션 품질

16. **파일 관리**
    - 저장 경로 관리
    - 파일명 규칙
    - 배치 변환

17. **단축키 시스템**
    - 글로벌 단축키 커스텀
    - 충돌 감지

18. **설정/환경설정**
    - 전체 설정 UI
    - 설정 내보내기/가져오기

19. **임포트 고급**
    - 비디오 컷 (구간 지정)
    - 드래그&드롭
    - 클립보드

20. **다국어**
    - 한국어/영어/일본어 우선

---

## 기술 의사결정

### 양자화 (가장 중요)
꿀캠 GIF 화질의 핵심 = **libimagequant**. 이건 반드시 통합해야 함.
- libimagequant는 MIT 라이선스. Swift에서 C 바인딩으로 사용 가능.
- NeuQuant, Octree는 직접 구현 or 오픈소스 포팅.

### AI 업스케일링
- 꿀캠은 OpenCV DNN + TensorFlow pb 모델 사용
- 맥: Core ML로 변환 (coremltools) or Vision framework
- 모델 크기 극소 (40~100KB) → 앱 번들에 포함

### 화면 캡처
- 꿀캠: DXGI (DirectX)
- 맥: ScreenCaptureKit — 이미 완료, 동급 성능

### 멀티스레딩
- 꿀캠: CTPL (C++ 스레드풀)
- 맥: Swift Concurrency (async/await, TaskGroup)

---

## 파일 구조 (최종)
```
JochungCam/
├── Package.swift
├── Resources/
│   ├── Models/           — Core ML 업스케일링 모델
│   ├── Presets/          — 폰트, 필터 프리셋
│   ├── Stickers/         — 스티커 에셋
│   ├── Frames/           — 액자 에셋
│   └── Localization/     — 다국어
├── Sources/JochungCam/
│   ├── App/              — 진입점, 상태 관리
│   ├── Capture/          — 화면 캡처, 영역 선택, 커서
│   ├── Encoder/          — GIF, WebP, WebM, MP4, APNG, AVIF
│   ├── Quantizer/        — libimagequant, NeuQuant, Octree
│   ├── Editor/           — 프레임 편집, 필터, 트랜지션
│   ├── Overlay/          — 텍스트, 스티커, 말풍선, 로고
│   ├── SuperRes/         — AI 업스케일링
│   ├── UI/               — SwiftUI 뷰
│   ├── Hotkey/           — 글로벌 단축키
│   └── Util/             — LZ4 캐시, 설정, 파일 관리
```

---

## 우선순위 요약

| 순위 | 기능 | 근거 |
|---|---|---|
| 🔴 1 | libimagequant GIF 양자화 | 꿀캠 화질의 핵심. 이거 없으면 의미 없음 |
| 🔴 2 | 인터랙티브 크롭 UI | 가장 자주 쓰는 편집 기능 |
| 🟠 3 | 텍스트 아웃라인/그림자 | 꿀캠 특유의 자막 스타일 |
| 🟠 4 | 트랜지션 효과 | 움짤 퀄리티 차별화 |
| 🟡 5 | AI 업스케일링 | 꿀캠 3.0+ 핵심 기능 |
| 🟡 6 | WebM/APNG/AVIF | 포맷 완성도 |
| 🟢 7 | 콜라주/액자 | 부가 기능 |
| 🟢 8 | 배치 변환 | 파워유저 기능 |
