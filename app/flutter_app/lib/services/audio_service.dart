import 'dart:developer';

class AudioService {
  static bool _debugLogEnabled = true;

  static Future<void> init() async {
    if (_debugLogEnabled) {
      log('[AudioService] init() skipped (audio placeholder)');
    }
  }

  static Future<void> _noop(String label) async {
    if (_debugLogEnabled) {
      log('[AudioService] $label (audio muted placeholder)');
    }
  }

  static Future<void> playNumber(int number) async {
    await _noop('playNumber($number)');
  }

  static Future<void> playClap() async {
    await _noop('playClap()');
  }

  static bool shouldClapForNumber(int number) {
    final text = number.toString();
    return text.contains('3') || text.contains('6') || text.contains('9');
  }

  static Future<void> playThreeSixNineCue(int number) async {
    if (shouldClapForNumber(number)) {
      await playClap();
      return;
    }
    await playNumber(number);
  }

  static Future<void> playTurnStart() async {
    await _noop('playTurnStart()');
  }

  static Future<void> playGameOver() async {
    await _noop('playGameOver()');
  }
}
