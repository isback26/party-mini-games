import express from "express";
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
  players: Player[];
  status: "waiting" | "playing";
};

const rooms = new Map<string, Room>();

function generateRoomCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let result = "";
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
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

  socket.on("disconnect", () => {
    console.log(`User disconnected: ${socket.id}`);

    for (const [roomCode, room] of rooms.entries()) {
      const originalLength = room.players.length;
      room.players = room.players.filter((player) => player.socketId !== socket.id);

      if (room.players.length !== originalLength) {
        if (room.players.length === 0) {
          rooms.delete(roomCode);
          console.log(`[ROOM REMOVED] ${roomCode}`);
        } else {
          if (room.hostSocketId === socket.id) {
            room.hostSocketId = room.players[0].socketId;
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