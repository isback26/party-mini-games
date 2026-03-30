import {
  GameEngine,
  GameRoom,
  GameState,
  GameSubmitPayload,
  GameSubmitResult,
} from "../types";

export class BeondegiGameEngine implements GameEngine {
  readonly gameType = "beondegi" as const;

  createInitialState(room: GameRoom): GameState {
    
    return {
      gameType: this.gameType,
      roomCode: room.code,
      phase: "playing",
      currentTurnSocketId: room.players[0]?.socketId ?? null,
      turnStartedAt: null,
      turnDeadlineAt: null,
      round: 1,
      metadata: {
        introMessage: "게임은 시작됐다. 확률은 2분의 1 이~히히, 이~히히",
        alivePlayers: room.players.map((player) => ({
          socketId: player.socketId,
          nickname: player.nickname,
        })),
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
      message: "번데기게임 엔진은 아직 구현 전입니다.",
    };
  }
}