import 'dart:developer';

class AudioService {
  static final bool _debugLogEnabled = true;

  static const String _basePath = 'assets/audio/369';
  static const String _turnStartAsset = '$_basePath/turn_start.wav';
  static const String _clapAsset = '$_basePath/clap.wav';
  static const String _gameOverAsset = '$_basePath/game_over.wav';

  static const Map<int, String> _numberAssets = {
    1: '$_basePath/number_1.wav',
    2: '$_basePath/number_2.wav',
    4: '$_basePath/number_4.wav',
    5: '$_basePath/number_5.wav',
    7: '$_basePath/number_7.wav',
    8: '$_basePath/number_8.wav',
  };

  static Future<void> init() async {
    if (_debugLogEnabled) {
      log('[AudioService] init() skipped (audio placeholder)');
    }
  }

  static Future<void> _noop(String label, {String? assetPath}) async {
    if (_debugLogEnabled) {
      final suffix = assetPath == null ? '' : ' | asset=$assetPath';
      log('[AudioService] $label (audio muted placeholder)$suffix');
    }
  }

  static String? numberAssetPath(int number) {
    return _numberAssets[number];
  }

  static String turnStartAssetPath() => _turnStartAsset;

  static String clapAssetPath() => _clapAsset;

  static String gameOverAssetPath() => _gameOverAsset;

  static bool hasNumberVoiceAsset(int number) {
    return _numberAssets.containsKey(number);
  }

  static Future<void> playNumber(int number) async {
    final assetPath = numberAssetPath(number);

    if (assetPath == null) {
      await _noop('playNumber($number) -> missing voice asset');
      return;
    }

    await _noop('playNumber($number)', assetPath: assetPath);
  }

  static Future<void> playClap() async {
    await _noop('playClap()', assetPath: _clapAsset);
  }

  static bool shouldClapForNumber(int number) {
    final text = number.toString();
    return RegExp(r'[369]').hasMatch(text);
  }

  static Future<void> playThreeSixNineCue(int number) async {
    if (shouldClapForNumber(number)) {
      await playClap();
      return;
    }
    await playNumber(number);
  }

  static Future<void> playTurnStart() async {
    await _noop('playTurnStart()', assetPath: _turnStartAsset);
  }

  static Future<void> playGameOver() async {
    await _noop('playGameOver()', assetPath: _gameOverAsset);
  }
}
