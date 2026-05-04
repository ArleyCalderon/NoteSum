import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_item.dart';
import '../services/note_storage_service.dart';
import '../utils/number_utils.dart';
import 'dart:async';
import '../app.dart';

class NoteSumScreen extends StatefulWidget {
  const NoteSumScreen({super.key});

  @override
  State<NoteSumScreen> createState() => _NoteSumScreenState();
}

class _NoteSumScreenState extends State<NoteSumScreen> {
  static const String _noteKey = 'note_text';
  static const String _titleKey = 'note_title';
  static const String _currentNoteIdKey = 'current_note_id';

  final TextEditingController _controller = TextEditingController();
  final NoteStorageService _storageService = NoteStorageService();
  final TextEditingController _titleController = TextEditingController();
  List<double> values = [];
  List<NoteItem> savedNotes = [];
  String? currentNoteId;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadNote();
    _loadSavedNotes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    final prefs = await SharedPreferences.getInstance();

    final savedText = prefs.getString(_noteKey) ?? '';
    final savedTitle = prefs.getString(_titleKey) ?? '';
    final savedCurrentNoteId = prefs.getString(_currentNoteIdKey);

    _controller.text = savedText;
    _titleController.text = savedTitle;
    currentNoteId = savedCurrentNoteId;

    _processText(savedText);
  }



  void _scheduleAutoSave() {
    // Cancela el timer anterior
    _debounce?.cancel();

    // Programa uno nuevo
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      // Si no hay contenido ni título, no hacemos nada
      final content = _controller.text.trim();
      final title = _titleController.text.trim();

      if (content.isEmpty && title.isEmpty) return;

      // Guarda/actualiza en historial
      await _saveCurrentNoteToHistory(showMessage: false);
    });
  }

  Future<void> _deleteNote(NoteItem note) async {
    savedNotes.removeWhere((item) => item.id == note.id);
    await _storageService.saveNotes(savedNotes);

    if (currentNoteId == note.id) {
      currentNoteId = null;
      _titleController.clear();
      _controller.clear();
      _processText('');
      await _saveNote('');
    }

    if (!mounted) return;

    setState(() {});
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nota eliminada'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveNote(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_noteKey, text);
  }

  void _processText(String text) {
    final lines = text.split('\n');
    values = lines.map(extractAmountFromLine).toList();
    setState(() {});
  }

  double get total {
    return values.fold(0.0, (sum, value) => sum + value);
  }

  int get detectedItems {
    return values.where((value) => value > 0).length;
  }

  bool get hasText {
    return _controller.text.trim().isNotEmpty;
  }

  Future<void> _clearNote() async {
    _controller.clear();
    _processText('');
    await _saveNote('');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nota limpiada'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _confirmClear() {
    if (!hasText) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Limpiar nota'),
          content: const Text('¿Seguro que quieres borrar todo el contenido?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _clearNote();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Limpiar'),
            ),
          ],
        );
      },
    );
  }
  Future<void> _loadSavedNotes() async {
    final notes = await _storageService.getNotes();

    setState(() {
      savedNotes = notes;
    });
  }

  String _generateTitle(String content) {
    final firstLine = content
        .split('\n')
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => 'Nueva nota');

    return firstLine.length > 28 ? '${firstLine.substring(0, 28)}...' : firstLine;
  }

  Future<void> _saveTitle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titleKey, title);
  }

  Future<void> _saveCurrentNoteId(String? id) async {
    final prefs = await SharedPreferences.getInstance();

    if (id == null) {
      await prefs.remove(_currentNoteIdKey);
    } else {
      await prefs.setString(_currentNoteIdKey, id);
    }
  }

  Future<void> _saveCurrentNoteToHistory({bool showMessage = true}) async {
    final content = _controller.text.trim();
    final customTitle = _titleController.text.trim();

    if (content.isEmpty && customTitle.isEmpty) return;

    final note = NoteItem(
      id: currentNoteId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: customTitle.isNotEmpty ? customTitle : _generateTitle(content),
      content: content,
      createdAt: DateTime.now(),
    );

    final existingIndex = savedNotes.indexWhere((item) => item.id == note.id);

    if (existingIndex >= 0) {
      savedNotes[existingIndex] = note;
    } else {
      savedNotes.insert(0, note);
    }

    currentNoteId = note.id;
    await _saveCurrentNoteId(currentNoteId);
    await _saveTitle(note.title);

    await _storageService.saveNotes(savedNotes);

    if (!mounted) return;

    setState(() {});

    if (showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota guardada'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _newNote() {
    currentNoteId = null;
    _titleController.clear();
    _controller.clear();
    _processText('');
    _saveNote('');
    _saveTitle('');
    _saveCurrentNoteId(null);
  }

  void _openNote(NoteItem note) {
    currentNoteId = note.id;
    _titleController.text = note.title;
    _controller.text = note.content;
    _processText(note.content);
    _saveNote(note.content);
    _saveTitle(note.title);
    _saveCurrentNoteId(note.id);
    Navigator.pop(context);
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        if (savedNotes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Todavía no hay notas guardadas.'),
          );
        }

        return ListView.builder(
          itemCount: savedNotes.length,
          itemBuilder: (context, index) {
            final note = savedNotes[index];

            return ListTile(
              title: Text(note.title),
              subtitle: Text(
                note.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: const Icon(Icons.note_alt_outlined),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteNote(note),
              ),
              onTap: () => _openNote(note),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = _controller.text.split('\n');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'NoteSum',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
          actions: [
            IconButton(
              onPressed: _newNote,
              icon: const Icon(Icons.add),
            ),
            IconButton(
              onPressed: _saveCurrentNoteToHistory,
              icon: const Icon(Icons.save_outlined),
            ),
            IconButton(
              onPressed: _showHistory,
              icon: const Icon(Icons.history),
            ),
            IconButton(
              onPressed: hasText ? _confirmClear : null,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              onPressed: () {
                NoteSumApp.of(context).toggleTheme();
              },
              icon: const Icon(Icons.dark_mode_outlined),
            ),
          ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4F46E5),
                  Color(0xFF7C3AED),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total actual',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$ ${formatNumber(total)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detectedItems == 1
                      ? '1 valor detectado'
                      : '$detectedItems valores detectados',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),onChanged: (text) {
              _saveTitle(text);
              _scheduleAutoSave();
            },
              decoration: const InputDecoration(
                hintText: 'Nombre de la nota',
                border: InputBorder.none,
                icon: Icon(Icons.edit_note),
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.45,
                      ),
                      decoration:  InputDecoration(
                        hintText:
                        'Escribe tu cuenta aquí...\n\nEj:\nMercado 25000\nGasolina \$ 45.000\nCafé 3.500',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 17,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(18),
                      ),
                      onChanged: (text) {
                        _processText(text);
                        _saveNote(text); // cache rápido
                        _scheduleAutoSave(); // 🔥 auto-guardado
                      },
                    ),
                  ),
                  Container(
                    width: 115,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 18),
                      itemCount: lines.length,
                      itemBuilder: (context, index) {
                        final double value =
                        values.length > index ? values[index] : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          child: Text(
                            value > 0 ? formatNumber(value) : '',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}