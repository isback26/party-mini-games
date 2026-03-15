import { GameEngine, GameRoom, GameState } from "../types";

export class ThreeSixNineEngine implements GameEngine {
  readonly gameType = "three_six_nine" as const;

  createInitialState(room: GameRoom): GameState {
    return {
      gameType: this.gameType,
      roomCode: room.code,
      phase: "playing",
      currentTurnSocketId: room.players[0]?.socketId ?? null,
      round: 1,
      metadata: {
        introMessage: "삼육구, 삼육구",
        expectedNumber: 1,
        clapNumbers: [3, 6, 9],
      },
    };
  }
}