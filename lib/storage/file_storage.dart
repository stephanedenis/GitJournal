import 'dart:async';
import 'dart:io';

import 'package:fimber/fimber.dart';
import 'package:flutter/foundation.dart';
import 'package:journal/note.dart';
import 'package:journal/storage/notes_repository.dart';
import 'package:journal/storage/serializers.dart';
import 'package:path/path.dart' as p;

typedef String NoteFileNameGenerator(Note note);

/// Each Note is saved in a different file
/// Each note must have a fileName which ends in a .md
class FileStorage implements NoteRepository {
  final String baseDirectory;
  final NoteSerializer noteSerializer;

  FileStorage({
    @required this.baseDirectory,
    @required this.noteSerializer,
  }) {
    assert(baseDirectory != null);
    assert(baseDirectory.isNotEmpty);
    Fimber.d("FileStorage Directory: " + baseDirectory);
  }

  @override
  Future<List<Note>> listNotes() async {
    final dir = Directory(baseDirectory);

    var notes = <Note>[];
    var lister = dir.list(recursive: false);
    await for (var fileEntity in lister) {
      Note note = await _loadNote(fileEntity);
      if (note == null) {
        continue;
      }
      if (!note.filePath.toLowerCase().endsWith('.md')) {
        continue;
      }
      notes.add(note);
    }

    // Reverse sort
    notes.sort((a, b) => b.compareTo(a));
    return notes;
  }

  Future<Note> _loadNote(FileSystemEntity entity) async {
    if (entity is! File) {
      return null;
    }
    var file = entity as File;
    final string = await file.readAsString();

    var note = noteSerializer.decode(string);
    note.filePath = p.basename(entity.path);
    return note;
  }

  @override
  Future<NoteRepoResult> addNote(Note note) async {
    var filePath = p.join(baseDirectory, note.filePath);
    Fimber.d("FileStorage: Adding note in " + filePath);

    var file = File(filePath);
    if (file == null) {
      return NoteRepoResult(error: true);
    }
    var contents = noteSerializer.encode(note);
    await file.writeAsString(contents);

    return NoteRepoResult(noteFilePath: filePath, error: false);
  }

  @override
  Future<NoteRepoResult> removeNote(Note note) async {
    var filePath = p.join(baseDirectory, note.filePath);

    var file = File(filePath);
    await file.delete();

    return NoteRepoResult(noteFilePath: filePath, error: false);
  }

  @override
  Future<NoteRepoResult> updateNote(Note note) async {
    return addNote(note);
  }

  @override
  Future<bool> sync() async {
    return false;
  }

  Future<Directory> saveNotes(List<Note> notes) async {
    final dir = Directory(baseDirectory);

    for (var note in notes) {
      var filePath = p.join(dir.path, note.filePath);

      var file = File(filePath);
      var contents = noteSerializer.encode(note);
      await file.writeAsString(contents);
    }

    return dir;
  }
}
