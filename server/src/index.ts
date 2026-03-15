import express from "express";
import { createGameEngine } from "./games/createGameEngine";
import { GameType } from "./games/types";
import cors from "cors";
import { createServer } from "http";
import { Server } from "socket.io";

const app = express();
const httpServer = createServer(app);

const io = new Server(httpServer, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("Party Mini Games Server is running.");
});

type Player = {
  socketId: string;
  nickname: string;
};

type Room = {
  code: string;
  hostSocketId: string;
  selectedGame: GameType;
  players: Player[];
  status: "waiting" | "playing";
};

const allowedGameTypes: GameType[] = ["three_six_nine", "nunchi", "beondegi"];

const rooms = new Map<string, Room>();
const roomGameStates = new Map<string, any>();

type ThreeSixNineSubmitPayload = {
  roomCode: string;
  moveType: "number" | "clap";
  value?: number;
};

function generateRoomCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let result = "";
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

function getNextPlayerSocketId(room: Room, currentSocketId: string | null): string | null {
  if (!currentSocketId || room.players.length === 0) {
    return room.players[0]?.socketId ?? null;
  }

  const currentIndex = room.players.findIndex(
    (player) => player.socketId === currentSocketId
  );

  if (currentIndex === -1) {
    return room.players[0]?.socketId ?? null;
  }

  const nextIndex = (currentIndex + 1) % room.players.length;
  return room.players[nextIndex]?.socketId ?? null;
}

function countClaps(num: number): number {
  return num
    .toString()
    .split("")
    .filter((digit) => digit === "3" || digit === "6" || digit === "9").length;
}

function getExpectedMove(num: number): { moveType: "number" | "clap"; displayText: string } {
  const clapCount = countClaps(num);

  if (clapCount > 0) {
    return {
      moveType: "clap",
      displayText: "👏".repeat(clapCount),
    };
  }

  return { moveType: "number", displayText: String(num) };
}

io.on("connection", (socket) => {
  console.log(`User connected: ${socket.id}`);

  socket.on("room:create", (payload: { nickname: string }, callback) => {
    try {
      const nickname = payload?.nickname?.trim();

      if (!nickname) {
        callback({ ok: false, message: "닉네임을 입력해주세요." });
        return;
      }

      let code = generateRoomCode();
      while (rooms.has(code)) {
        code = generateRoomCode();
      }

      const room: Room = {
        code,
        hostSocketId: socket.id,
        selectedGame: "three_six_nine",
        status: "waiting",
        players: [
          {
            socketId: socket.id,
            nickname,
          },
        ],
      };

      rooms.set(code, room);
      socket.join(code);

      console.log(`[ROOM CREATED] ${code} / host=${nickname}`);

      callback({
        ok: true,
        roomCode: code,
        room,
      });

      io.to(code).emit("room:update", room);
    } catch (error) {
      callback({ ok: false, message: "방 생성 중 오류가 발생했습니다." });
    }
  });

  socket.on(
    "room:join",
    (payload: { nickname: string; roomCode: string }, callback) => {
      try {
        const nickname = payload?.nickname?.trim();
        const roomCode = payload?.roomCode?.trim().toUpperCase();

        if (!nickname) {
          callback({ ok: false, message: "닉네임을 입력해주세요." });
          return;
        }

        if (!roomCode) {
          callback({ ok: false, message: "방 코드를 입력해주세요." });
          return;
        }

        const room = rooms.get(roomCode);

        if (!room) {
          callback({ ok: false, message: "존재하지 않는 방입니다." });
          return;
        }

        const alreadyJoined = room.players.some(
          (player) => player.socketId === socket.id
        );

        if (!alreadyJoined) {
          room.players.push({
            socketId: socket.id,
            nickname,
          });
        }

        socket.join(roomCode);

        console.log(`[ROOM JOIN] ${roomCode} / user=${nickname}`);

        callback({
          ok: true,
          room,
        });

        io.to(roomCode).emit("room:update", room);
      } catch (error) {
        callback({ ok: false, message: "방 입장 중 오류가 발생했습니다." });
      }
    }
  );

  socket.on(
    "room:select_game",
    (
      payload: { roomCode: string; gameType: GameType },
      callback: (response: Record<string, unknown>) => void
    ) => {
      try {
        const roomCode = payload?.roomCode?.trim().toUpperCase();
        const gameType = payload?.gameType;

        if (!roomCode) {
          callback({ ok: false, message: "방 코드가 필요합니다." });
          return;
        }

        const room = rooms.get(roomCode);

        if (!room) {
          callback({ ok: false, message: "존재하지 않는 방입니다." });
          return;
        }

        if (room.hostSocketId !== socket.id) {
          callback({ ok: false, message: "방장만 게임을 선택할 수 있습니다." });
          return;
        }

        if (!allowedGameTypes.includes(gameType)) {
          callback({ ok: false, message: "지원하지 않는 게임입니다." });
          return;
        }

        room.selectedGame = gameType;

        callback({
          ok: true,
          selectedGame: room.selectedGame,
          room,
        });

        io.to(roomCode).emit("room:update", room);
      } catch (error) {
        callback({ ok: false, message: "게임 선택 중 오류가 발생했습니다." });
      }
    }
  );

  socket.on(
    "game:start",
    (
      payload: { roomCode: string },
      callback: (response: Record<string, unknown>) => void
    ) => {
      try {
        const roomCode = payload?.roomCode?.trim().toUpperCase();

        if (!roomCode) {
          callback({ ok: false, message: "방 코드가 필요합니다." });
          return;
        }

        const room = rooms.get(roomCode);

        if (!room) {
          callback({ ok: false, message: "존재하지 않는 방입니다." });
          return;
        }

        if (room.hostSocketId !== socket.id) {
          callback({ ok: false, message: "방장만 게임을 시작할 수 있습니다." });
          return;
        }

        if (room.players.length < 2) {
          callback({ ok: false, message: "최소 2명 이상 있어야 시작할 수 있습니다." });
          return;
        }

        const engine = createGameEngine(room.selectedGame);
        const gameState = engine.createInitialState(room);
        const initialExpectedNumber = Number(gameState?.metadata?.expectedNumber ?? 1);
        const expectedMove = getExpectedMove(initialExpectedNumber);

        gameState.metadata = {
          ...(gameState.metadata ?? {}),
          expectedNumber: initialExpectedNumber,
          expectedMoveType: expectedMove.moveType,
          expectedDisplayText: expectedMove.displayText,
          lastActionMessage: "게임이 시작되었습니다.",
        };

        room.status = "playing";
        roomGameStates.set(roomCode, gameState);

        callback({
          ok: true,
          gameType: room.selectedGame,
          gameState,
        });

        io.to(roomCode).emit("room:update", room);
        io.to(roomCode).emit("game:state", gameState);
        io.to(roomCode).emit("game:started", {
          roomCode: room.code,
          gameType: room.selectedGame,
          gameState,
        });
      } catch (error) {
        callback({ ok: false, message: "게임 시작 중 오류가 발생했습니다." });
      }
    }
  );

  socket.on(
    "game:submit",
    (
      payload: ThreeSixNineSubmitPayload,
      callback: (response: Record<string, unknown>) => void
    ) => {
      try {
        const roomCode = payload?.roomCode?.trim().toUpperCase();
        const moveType = payload?.moveType;
        const value = payload?.value;

        if (!roomCode) {
          callback({ ok: false, message: "방 코드가 필요합니다." });
          return;
        }

        const room = rooms.get(roomCode);

        if (!room) {
          callback({ ok: false, message: "존재하지 않는 방입니다." });
          return;
        }

        if (room.status !== "playing") {
          callback({ ok: false, message: "현재 진행 중인 게임이 없습니다." });
          return;
        }

        if (room.selectedGame !== "three_six_nine") {
          callback({ ok: false, message: "아직 369 게임만 제출할 수 있습니다." });
          return;
        }

        const gameState = roomGameStates.get(roomCode);

        if (!gameState) {
          callback({ ok: false, message: "게임 상태를 찾을 수 없습니다." });
          return;
        }

        if (gameState.currentTurnSocketId !== socket.id) {
          callback({ ok: false, message: "지금은 당신의 턴이 아닙니다." });
          return;
        }

        const expectedNumber = Number(gameState?.metadata?.expectedNumber ?? 1);
        const expectedMove = getExpectedMove(expectedNumber);
        const currentPlayer =
          room.players.find((player) => player.socketId === socket.id)?.nickname ?? "알 수 없음";

        const isCorrect =
          expectedMove.moveType === "clap"
            ? moveType === "clap"
            : moveType === "number" && Number(value) === expectedNumber;

        if (!isCorrect) {
          room.status = "waiting";
          gameState.phase = "finished";
          gameState.metadata = {
            ...(gameState.metadata ?? {}),
            expectedNumber,
            expectedMoveType: expectedMove.moveType,
            expectedDisplayText: expectedMove.displayText,
            lastActionMessage: `${currentPlayer} 님이 틀렸습니다.`,
            loserSocketId: socket.id,
            loserNickname: currentPlayer,
          };

          roomGameStates.set(roomCode, gameState);

          callback({
            ok: true,
            correct: false,
            gameState,
          });

          io.to(roomCode).emit("room:update", room);
          io.to(roomCode).emit("game:state", gameState);
          io.to(roomCode).emit("game:over", {
            roomCode,
            gameType: room.selectedGame,
            gameState,
            message: `${currentPlayer} 님이 틀렸습니다. 게임 종료!`,
          });
          return;
        }

        const nextExpectedNumber = expectedNumber + 1;
        const nextExpectedMove = getExpectedMove(nextExpectedNumber);
        const nextTurnSocketId = getNextPlayerSocketId(room, socket.id);

        gameState.round = Number(gameState.round ?? 1) + 1;
        gameState.currentTurnSocketId = nextTurnSocketId;
        gameState.metadata = {
          ...(gameState.metadata ?? {}),
          expectedNumber: nextExpectedNumber,
          expectedMoveType: nextExpectedMove.moveType,
          expectedDisplayText: nextExpectedMove.displayText,
          lastActionMessage:
            expectedMove.moveType === "clap"
              ? `${currentPlayer} 님이 ${expectedMove.displayText} 입력 성공`
              : `${currentPlayer} 님이 ${expectedNumber} 입력 성공`,
        };

        roomGameStates.set(roomCode, gameState);

        callback({
          ok: true,
          correct: true,
          gameState,
        });

        io.to(roomCode).emit("game:state", gameState);
      } catch (error) {
        callback({ ok: false, message: "입력 처리 중 오류가 발생했습니다." });
      }
    }
  );

  socket.on("disconnect", () => {
    console.log(`User disconnected: ${socket.id}`);

    for (const [roomCode, room] of rooms.entries()) {
      const originalLength = room.players.length;
      room.players = room.players.filter((player) => player.socketId !== socket.id);

      if (room.players.length !== originalLength) {
        if (room.players.length === 0) {
          rooms.delete(roomCode);
          roomGameStates.delete(roomCode);
          console.log(`[ROOM REMOVED] ${roomCode}`);
        } else {
          if (room.hostSocketId === socket.id) {
            room.hostSocketId = room.players[0].socketId;
          }
          const gameState = roomGameStates.get(roomCode);
          if (room.status === "playing" && room.players.length < 2) {
            room.status = "waiting";
          }
          if (gameState?.currentTurnSocketId === socket.id) {
            gameState.currentTurnSocketId = room.players[0]?.socketId ?? null;
            roomGameStates.set(roomCode, gameState);
            io.to(roomCode).emit("game:state", gameState);
          }
          io.to(roomCode).emit("room:update", room);
        }
      }
    }
  });
});

const PORT = 3000;

httpServer.listen(PORT, () => {
  console.log(`Server listening on http://localhost:${PORT}`);
});