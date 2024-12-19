import 'package:shared_preferences/shared_preferences.dart';


class DraftService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> saveDraft(String chatId, String message) async {
    await init();
    print('Saving draft for $chatId: $message'); // Debug print
    if (message.trim().isEmpty) {
      await _prefs?.remove('draft_$chatId');
    } else {
      await _prefs?.setString('draft_$chatId', message);
    }
  }

  static Future<String> getDraft(String chatId) async {
    await init();
    final draft = _prefs?.getString('draft_$chatId') ?? '';
    print('Getting draft for $chatId: $draft'); // Debug print
    return draft;
  }

  static Future<void> deleteDraft(String chatId) async {
    await init();
    await _prefs?.remove('draft_$chatId');
  }
}