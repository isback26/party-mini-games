# EXECUTION_PLAN_v0.3

## 1. 프로젝트 개요

프로젝트명: Party Mini Games

목표:
친구들끼리 방을 만들고 실시간으로 미니게임을 즐길 수 있는 멀티플레이 파티 게임 앱 MVP를 만든다.

현재 우선순위:
1. 로비/대기방 흐름 안정화
2. 369 게임 MVP 완성
3. 게임 진행 상태와 판정 로직 서버화
4. Flutter 게임 화면 분리
5. 멀티플레이 테스트 안정화

---

## 2. 현재까지 완료된 상태

완료:
- GitHub 저장소 생성 및 공개 확인 완료
- Flutter 프로젝트 생성 완료
- Node.js + TypeScript + Socket.IO 서버 구성 완료
- Flutter 홈 화면 기본 UI 구성 완료
- Flutter ↔ Node Socket.IO 연결 완료
- 서버 연결 상태 표시 UI 완료
- 닉네임 입력 후 로비 입장 흐름 완료
- 방 만들기 완료
- 방 참가하기 완료
- room:update 기반 대기방 실시간 갱신 완료
- 방 코드 표시 완료
- 참가자 목록 동기화 완료
- 방장/참가자 구분 표시 완료
- 게임 선택 UI 기본 구조 완료
- 게임 시작 버튼 기본 구조 완료
- Game Engine 기본 인터페이스 파일 구조 추가 완료
- 369 / 눈치 / 번데기 엔진 초기 상태 생성 구조 완료
- Flutter widget test 수정 완료
- TypeScript import 및 파일 구조 문제 수정 완료

실행 확인 완료:
- Windows Flutter 앱 실행 성공
- Node 서버 localhost:3000 실행 성공
- Flutter 앱 2개 실행 기준 멀티 접속 테스트 성공
- 방 생성/방 참가/대기방 동기화 테스트 성공
- 수정 후 테스트 에러 해결 성공

---

## 3. 현재 프로젝트 구조

```text
party-mini-games/
├─ README.md
├─ docs/
│  ├─ EXECUTION_PLAN_v0.2.md
│  └─ EXECUTION_PLAN_v0.3.md
├─ app/
│  └─ flutter_app/
│     ├─ lib/
│     │  ├─ main.dart
│     │  └─ services/
│     │     └─ socket_service.dart
│     └─ test/
│        └─ widget_test.dart
└─ server/
   ├─ package.json
   ├─ tsconfig.json
   └─ src/
      ├─ index.ts
      └─ games/
         ├─ createGameEngine.ts
         ├─ types.ts
         └─ engines/
            ├─ ThreeSixNineEngine.ts
            ├─ NunchiGameEngine.ts
            └─ BeondegiGameEngine.ts