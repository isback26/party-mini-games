import { GameEngine, GameType } from "./types";
import { ThreeSixNineEngine } from "./engines/ThreeSixNineEngine";
import { NunchiGameEngine } from "./engines/NunchiGameEngine";
import { BeondegiGameEngine } from "./engines/BeondegiGameEngine";

export function createGameEngine(gameType: GameType): GameEngine {
  switch (gameType) {
    case "three_six_nine":
      return new ThreeSixNineEngine();
    case "nunchi":
      return new NunchiGameEngine();
    case "beondegi":
      return new BeondegiGameEngine();
    default:
      return new ThreeSixNineEngine();
  }
}