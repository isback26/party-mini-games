import { GameEngine, GameRoom, GameState } from "../types";

export class BeondegiGameEngine implements GameEngine {
  readonly gameType = "beondegi" as const;

  createInitialState(room: GameRoom): GameState {
    return {
      gameType: this.gameType,
      roomCode: room.code,
      phase: "playing",
      currentTurnSocketId: room.players[0]?.socketId ?? null,
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
}