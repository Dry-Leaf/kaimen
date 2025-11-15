import 'package:toml/toml.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as path;

final configProvider = AsyncNotifierProvider<Config, Map<String, dynamic>>(
  Config.new,
);

class Config extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    return await _read();
  }

  Future<Map<String, dynamic>> _read() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final confLocation = path.join(directory.path, 'config.toml');
      final document = await TomlDocument.load(confLocation);
      return document.toMap();
    } catch (e) {
      return {};
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_read);
  }
}
