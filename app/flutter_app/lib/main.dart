import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/socket_service.dart';
import 'services/audio_service.dart';

void main() {
  runApp(const PartyMiniGamesApp());
}

class PartyMiniGamesApp extends StatelessWidget {
  const PartyMiniGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Party Mini Games',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> games = const ['369 게임', '눈치게임', '번데기 게임'];
  final TextEditingController nicknameController = TextEditingController();
  final SocketService socketService = SocketService();

  String connectionText = '서버 연결 전';

  @override
  void initState() {
    super.initState();

    socketService.connect(
      onConnected: () {
        if (!mounted) return;
        setState(() {
          connectionText = '서버 연결됨';
        });
      },
      onDisconnected: () {
        if (!mounted) return;
        setState(() {
          connectionText = '서버 연결 안 됨';
        });
      },
      onConnectError: (_) {
        if (!mounted) return;
        setState(() {
          connectionText = '서버 연결 실패';
        });
      },
    );
  }

  @override
  void dispose() {
    nicknameController.dispose();
    super.dispose();
  }

  void onLobbyEnterPressed() {
    final nickname = nicknameController.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LobbyScreen(nickname: nickname, socketService: socketService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('파티 미니게임'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              '모임에서 바로 즐기는 실시간 미니게임',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              connectionText,
              style: TextStyle(
                fontSize: 14,
                color: socketService.isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: nicknameController,
              decoration: InputDecoration(
                labelText: '닉네임 입력',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '지원 예정 게임',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: games.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(games[index]),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${games[index]} 준비 중')),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onLobbyEnterPressed,
                child: const Text('로비 입장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LobbyScreen extends StatefulWidget {
  final String nickname;
  final SocketService socketService;

  const LobbyScreen({
    super.key,
    required this.nickname,
    required this.socketService,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController roomCodeController = TextEditingController();

  static const Map<String, String> gameLabels = {
    'three_six_nine': '369 게임',
    'nunchi': '눈치게임',
    'beondegi': '번데기 게임',
  };

  String? currentRoomCode;
  List<dynamic> players = [];
  String? hostSocketId;
  String selectedGame = 'three_six_nine';
  String roomStatus = 'waiting';
  bool isLoading = false;
  String statusMessage = '로비에 입장했습니다.';
  String? startedGameLabel;

  @override
  void initState() {
    super.initState();

    widget.socketService.off('room:update');
    widget.socketService.off('game:started');
    widget.socketService.on('room:update', _handleRoomUpdate);
    widget.socketService.on('game:started', _handleGameStarted);
  }

  @override
  void dispose() {
    widget.socketService.off('room:update');
    widget.socketService.off('game:started');
    roomCodeController.dispose();
    super.dispose();
  }

  void _handleRoomUpdate(dynamic data) {
    if (!mounted) return;

    final roomCode = data['code']?.toString();
    final nextPlayers = (data['players'] as List?) ?? [];
    final nextHostSocketId = data['hostSocketId']?.toString();
    final nextSelectedGame = data['selectedGame']?.toString() ?? selectedGame;
    final nextRoomStatus = data['status']?.toString() ?? 'waiting';

    setState(() {
      currentRoomCode = roomCode;
      players = nextPlayers;
      hostSocketId = nextHostSocketId;
      selectedGame = nextSelectedGame;
      roomStatus = nextRoomStatus;
      isLoading = false;
      statusMessage = '대기방 정보가 업데이트되었습니다.';
    });
  }

  void _handleGameStarted(dynamic data) {
    if (!mounted) return;

    final gameType = data['gameType']?.toString() ?? selectedGame;
    final gameState = data['gameState'];

    setState(() {
      startedGameLabel = gameLabels[gameType] ?? gameType;
      roomStatus = 'playing';
      statusMessage = '${startedGameLabel ?? "게임"} 시작됨';
    });

    if (gameType == 'three_six_nine') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ThreeSixNineGameScreen(
            nickname: widget.nickname,
            socketService: widget.socketService,
            roomCode: currentRoomCode ?? '',
            players: players,
            initialGameState: gameState,
          ),
        ),
      );
    }
  }

  Future<void> _createRoom() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
      statusMessage = '방을 만드는 중...';
    });

    widget.socketService.emitWithAck(
      'room:create',
      {'nickname': widget.nickname},
      (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isLoading = false;
            statusMessage =
                response?['message']?.toString() ?? '방 만들기에 실패했습니다.';
          });
          return;
        }

        setState(() {
          final room = response['room'] as Map<String, dynamic>?;
          currentRoomCode =
              room?['code']?.toString() ?? response['roomCode']?.toString();
          players = (room?['players'] as List?) ?? [];
          hostSocketId = room?['hostSocketId']?.toString();
          selectedGame = room?['selectedGame']?.toString() ?? selectedGame;
          isLoading = false;
          statusMessage = '방이 생성되었습니다.';
        });
      },
    );
  }

  Future<void> _joinRoom() async {
    if (isLoading) return;

    final roomCode = roomCodeController.text.trim().toUpperCase();

    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('참가할 방 코드를 입력해주세요.')));
      return;
    }

    setState(() {
      isLoading = true;
      statusMessage = '방에 참가하는 중...';
    });

    widget.socketService.emitWithAck(
      'room:join',
      {'roomCode': roomCode, 'nickname': widget.nickname},
      (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isLoading = false;
            statusMessage = response?['message']?.toString() ?? '방 참가에 실패했습니다.';
          });
          return;
        }

        setState(() {
          final room = response['room'] as Map<String, dynamic>?;
          currentRoomCode = room?['code']?.toString() ?? roomCode;
          hostSocketId = room?['hostSocketId']?.toString();
          selectedGame = room?['selectedGame']?.toString() ?? selectedGame;
          players = (room?['players'] as List?) ?? [];
          isLoading = false;
          statusMessage = '방에 참가했습니다.';
        });
      },
    );
  }

  Future<void> _selectGame(String gameType) async {
    if (currentRoomCode == null || isLoading) return;

    setState(() {
      isLoading = true;
      statusMessage = '게임을 선택하는 중...';
    });

    widget.socketService.emitWithAck(
      'room:select_game',
      {'roomCode': currentRoomCode, 'gameType': gameType},
      (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isLoading = false;
            statusMessage =
                response?['message']?.toString() ?? '게임 선택에 실패했습니다.';
          });
          return;
        }

        setState(() {
          selectedGame = response['selectedGame']?.toString() ?? gameType;
          isLoading = false;
          statusMessage = '게임이 선택되었습니다.';
        });
      },
    );
  }

  Future<void> _startGame() async {
    if (currentRoomCode == null || isLoading) return;

    setState(() {
      isLoading = true;
      statusMessage = '게임을 시작하는 중...';
    });

    widget.socketService.emitWithAck(
      'game:start',
      {'roomCode': currentRoomCode},
      (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isLoading = false;
            statusMessage =
                response?['message']?.toString() ?? '게임 시작에 실패했습니다.';
          });
          return;
        }

        setState(() {
          isLoading = false;
          roomStatus = 'playing';
          startedGameLabel =
              gameLabels[response['gameType']?.toString() ?? selectedGame] ??
              selectedGame;
          statusMessage = '${startedGameLabel ?? "게임"} 시작됨';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inRoom = currentRoomCode != null && currentRoomCode!.isNotEmpty;
    final mySocketId = widget.socketService.socket?.id;
    final isHost = mySocketId != null && hostSocketId == mySocketId;
    final currentGameLabel = gameLabels[selectedGame] ?? selectedGame;

    return Scaffold(
      appBar: AppBar(title: const Text('게임 로비'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '닉네임: ${widget.nickname}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(statusMessage, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '내 역할: ${isHost ? "방장" : "참가자"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!inRoom) ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _createRoom,
                    child: const Text('방 만들기'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: '방 코드 입력',
                    hintText: '예: ABC123',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _joinRoom,
                    child: const Text('방 참가하기'),
                  ),
                ),
              ] else ...[
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '대기방',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '방 코드: $currentRoomCode',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '참가자 목록',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '선택된 게임: $currentGameLabel',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (players.isEmpty)
                          const Text('아직 참가자가 없습니다.')
                        else
                          ...players.map((player) {
                            final nickname =
                                player['nickname']?.toString() ?? '이름 없음';
                            final playerIsHost =
                                player['socketId']?.toString() == hostSocketId;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person),
                              title: Text(nickname),
                              subtitle: Text(playerIsHost ? '방장' : '참가자'),
                            );
                          }),
                        const SizedBox(height: 16),
                        const Text(
                          '게임 선택',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: gameLabels.entries.map((entry) {
                            final isSelected = selectedGame == entry.key;
                            return ChoiceChip(
                              label: Text(entry.value),
                              selected: isSelected,
                              onSelected: (!isHost || roomStatus == 'playing')
                                  ? null
                                  : (_) => _selectGame(entry.key),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed:
                                (!isHost ||
                                    roomStatus == 'playing' ||
                                    players.length < 2)
                                ? null
                                : _startGame,
                            child: Text(
                              roomStatus == 'playing' ? '게임 진행 중' : '게임 시작',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          players.length < 2
                              ? '게임 시작은 최소 2명부터 가능합니다.'
                              : isHost
                              ? '방장이 게임을 선택하고 시작할 수 있습니다.'
                              : '방장이 게임을 시작할 때까지 기다려주세요.',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (startedGameLabel != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '현재 진행 상태: ${startedGameLabel!} 시작됨',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (isLoading) const Center(child: CircularProgressIndicator()),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('뒤로 가기'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class ThreeSixNineGameScreen extends StatefulWidget {
  final String nickname;
  final SocketService socketService;
  final String roomCode;
  final List<dynamic> players;
  final dynamic initialGameState;

  const ThreeSixNineGameScreen({
    super.key,
    required this.nickname,
    required this.socketService,
    required this.roomCode,
    required this.players,
    required this.initialGameState,
  });

  @override
  State<ThreeSixNineGameScreen> createState() => _ThreeSixNineGameScreenState();
}

class _ThreeSixNineGameScreenState extends State<ThreeSixNineGameScreen> {
  final TextEditingController numberController = TextEditingController();

  dynamic gameState;
  String statusMessage = '369 게임이 시작되었습니다.';
  bool isSubmitting = false;
  String? _lastTurnSocketId;

  @override
  void initState() {
    super.initState();
    gameState = widget.initialGameState;
    _lastTurnSocketId = gameState?['currentTurnSocketId']?.toString();

    final mySocketId = widget.socketService.socket?.id;
    final isMyInitialTurn =
        mySocketId != null &&
        _lastTurnSocketId != null &&
        mySocketId == _lastTurnSocketId;

    if (isMyInitialTurn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AudioService.playTurnStart();
      });
    }

    widget.socketService.off('game:state');
    widget.socketService.off('game:over');
    widget.socketService.on('game:state', _handleGameState);
    widget.socketService.on('game:over', _handleGameOver);
  }

  @override
  void dispose() {
    widget.socketService.off('game:state');
    widget.socketService.off('game:over');
    numberController.dispose();
    super.dispose();
  }

  void _handleGameState(dynamic data) {
    if (!mounted) return;

    final mySocketId = widget.socketService.socket?.id;
    final nextTurnSocketId = data?['currentTurnSocketId']?.toString();
    final wasMyTurn =
        mySocketId != null &&
        _lastTurnSocketId != null &&
        _lastTurnSocketId == mySocketId;
    final isMyTurnNow =
        mySocketId != null &&
        nextTurnSocketId != null &&
        nextTurnSocketId == mySocketId;

    if (!wasMyTurn && isMyTurnNow) {
      AudioService.playTurnStart();
    }

    setState(() {
      gameState = data;
      statusMessage =
          data?['metadata']?['lastActionMessage']?.toString() ??
          '상태가 업데이트되었습니다.';
      isSubmitting = false;
    });

    _lastTurnSocketId = nextTurnSocketId;
  }

  void _handleGameOver(dynamic data) {
    if (!mounted) return;

    AudioService.playGameOver();

    setState(() {
      gameState = data?['gameState'];
      statusMessage = data?['message']?.toString() ?? '게임이 종료되었습니다.';
      isSubmitting = false;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('게임 종료'),
          content: Text(statusMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('로비로 돌아가기'),
            ),
          ],
        );
      },
    );
  }

  String _nicknameBySocketId(String? socketId) {
    if (socketId == null) return '알 수 없음';

    for (final player in widget.players) {
      if (player['socketId']?.toString() == socketId) {
        return player['nickname']?.toString() ?? '알 수 없음';
      }
    }
    return '알 수 없음';
  }

  Future<void> _submitGameInput({
    required String moveType,
    int? value,
    String? text,
    String inputMode = 'touch',
    String? recognizedText,
    required String failureMessage,
    VoidCallback? onSuccess,
  }) async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    widget.socketService.submitGameInput(
      roomCode: widget.roomCode,
      moveType: moveType,
      value: value,
      text: text,
      inputMode: inputMode,
      recognizedText: recognizedText,
      callback: (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response?['message']?.toString() ?? failureMessage),
            ),
          );
          return;
        }

        onSuccess?.call();
      },
    );
  }

  Future<void> _submitNumber() async {
    final value = int.tryParse(numberController.text.trim());

    if (value == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('숫자를 정확히 입력해주세요.')));
      return;
    }

    await _submitGameInput(
      moveType: 'number',
      value: value,
      failureMessage: '숫자 제출에 실패했습니다.',
      onSuccess: () {
        numberController.clear();
        AudioService.playThreeSixNineCue(value);
      },
    );
  }

  Future<void> _submitClap() async {
    await _submitGameInput(
      moveType: 'clap',
      text: '👏',
      failureMessage: '박수 제출에 실패했습니다.',
      onSuccess: () {
        AudioService.playClap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mySocketId = widget.socketService.socket?.id;
    final currentTurnSocketId = gameState?['currentTurnSocketId']?.toString();
    final isMyTurn = mySocketId != null && mySocketId == currentTurnSocketId;
    final expectedNumber =
        gameState?['metadata']?['expectedNumber']?.toString() ?? '-';
    final expectedDisplayText =
        gameState?['metadata']?['expectedDisplayText']?.toString() ?? '-';
    final phase = gameState?['phase']?.toString() ?? 'playing';
    final canSubmit = isMyTurn && phase == 'playing' && !isSubmitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('369 게임'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '방 코드: ${widget.roomCode}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('내 닉네임: ${widget.nickname}'),
                      const SizedBox(height: 8),
                      Text(
                        '현재 턴: ${_nicknameBySocketId(currentTurnSocketId)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isMyTurn ? '지금은 당신의 턴입니다.' : '상대방 차례를 기다려주세요.',
                        style: TextStyle(
                          color: isMyTurn ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        '이번 차례 정답',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        expectedDisplayText,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('기준 숫자: $expectedNumber'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: numberController,
                enabled: canSubmit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '숫자 입력',
                  hintText: '예: 1, 2, 4, 5, 10...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: canSubmit ? _submitNumber : null,
                  child: const Text('숫자 제출'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: canSubmit ? _submitClap : null,
                  child: const Text('박수 입력 👏'),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusMessage,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isSubmitting)
                const Center(child: CircularProgressIndicator()),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('로비로 돌아가기'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
