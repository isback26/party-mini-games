import {
  GameEngine,
  GameRoom,
  GameState,
  GameSubmitPayload,
  GameSubmitResult,
} from "../types";

export class NunchiGameEngine implements GameEngine {
  readonly gameType = "nunchi" as const;

  createInitialState(room: GameRoom): GameState {
    return {
      gameType: this.gameType,
      roomCode: room.code,
      phase: "playing",
      currentTurnSocketId: null,
      round: 1,
      metadata: {
        introMessage: "시작!!",
        submittedNumbers: [],
      },
    };
  }

  submitTurn(
    _room: GameRoom,
    gameState: GameState,
    _payload: GameSubmitPayload
  ): GameSubmitResult {
    return {
      gameState,
      isCorrect: false,
      isFinished: false,
      message: "눈치게임 엔진은 아직 구현 전입니다.",
    };
  }
}
