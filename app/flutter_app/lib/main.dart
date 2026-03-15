import 'package:flutter/material.dart';
import 'services/socket_service.dart';

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
    socketService.disconnect();
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('닉네임 "$nickname" 확인 완료')));
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
