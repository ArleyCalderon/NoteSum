import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_item.dart';

class NoteStorageService {
  static const String _notesKey = 'notes_list';

  Future<List<NoteItem>> getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_notesKey);

    if (jsonString == null) return [];

    final List decoded = json.decode(jsonString);

    return decoded.map((e) => NoteItem.fromJson(e)).toList();
  }

  Future<void> saveNotes(List<NoteItem> notes) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonString = json.encode(
      notes.map((e) => e.toJson()).toList(),
    );

    await prefs.setString(_notesKey, jsonString);
  }
}