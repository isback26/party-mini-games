export type GameType = "three_six_nine" | "nunchi" | "beondegi";

export type GamePlayer = {
  socketId: string;
  nickname: string;
};

export type GameRoom = {
  code: string;
  hostSocketId: string;
  selectedGame: GameType;
  players: GamePlayer[];
  status: "waiting" | "playing";
};

export type GameState = {
  gameType: GameType;
  roomCode: string;
  phase: "waiting_start" | "playing" | "finished";
  currentTurnSocketId: string | null;
  round: number;
  metadata: Record<string, unknown>;
};

export interface GameEngine {
  readonly gameType: GameType;
  createInitialState(room: GameRoom): GameState;
}