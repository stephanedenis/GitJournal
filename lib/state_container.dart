import 'dart:async';
import 'dart:io';

import 'package:fimber/fimber.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:journal/analytics.dart';
import 'package:journal/apis/git_migration.dart';
import 'package:journal/appstate.dart';
import 'package:journal/datetime_utils.dart';
import 'package:journal/note.dart';
import 'package:journal/storage/git_storage.dart';
import 'package:journal/storage/notes_repository.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class StateContainer extends StatefulWidget {
  final Widget child;
  final bool localGitRepoConfigured;
  final bool remoteGitRepoConfigured;
  final String localGitRepoPath;
  final String remoteGitRepoFolderName;
  final String remoteGitRepoSubFolder;

  final String gitBaseDirectory;
  final bool onBoardingCompleted;

  StateContainer({
    @required this.localGitRepoConfigured,
    @required this.remoteGitRepoConfigured,
    @required this.localGitRepoPath,
    @required this.remoteGitRepoFolderName,
    @required this.remoteGitRepoSubFolder,
    @required this.gitBaseDirectory,
    @required this.onBoardingCompleted,
    @required this.child,
  });

  static StateContainerState of(BuildContext context) {
    return (context.inheritFromWidgetOfExactType(_InheritedStateContainer)
            as _InheritedStateContainer)
        .data;
  }

  @override
  State<StatefulWidget> createState() {
    var st = StateContainerState();
    st.appState.localGitRepoConfigured = localGitRepoConfigured;
    st.appState.remoteGitRepoConfigured = remoteGitRepoConfigured;
    st.appState.localGitRepoPath = localGitRepoPath;
    st.appState.remoteGitRepoFolderName = remoteGitRepoFolderName;
    st.appState.remoteGitRepoSubFolder = remoteGitRepoSubFolder;
    st.appState.gitBaseDirectory = gitBaseDirectory;
    st.appState.onBoardingCompleted = onBoardingCompleted;

    return st;
  }
}

class StateContainerState extends State<StateContainer> {
  AppState appState = AppState();
  GitNoteRepository noteRepo;

  @override
  void initState() {
    super.initState();

    assert(appState.localGitRepoConfigured);

    if (appState.remoteGitRepoConfigured) {
      noteRepo = GitNoteRepository(
        baseDirectory: appState.gitBaseDirectory,
        dirName: appState.remoteGitRepoFolderName,
        subDirName: appState.remoteGitRepoSubFolder,
      );
    } else if (appState.localGitRepoConfigured) {
      noteRepo = GitNoteRepository(
        baseDirectory: appState.gitBaseDirectory,
        dirName: appState.localGitRepoPath,
        subDirName: "",
      );
    }

    // Just a fail safe
    if (!appState.remoteGitRepoConfigured) {
      removeExistingRemoteClone();
    }

    _loadNotesFromDisk();
    _syncNotes();
  }

  void removeExistingRemoteClone() async {
    var remoteGitDir = Directory(
        p.join(appState.gitBaseDirectory, appState.remoteGitRepoFolderName));
    var dotGitDir = Directory(p.join(remoteGitDir.path, ".git"));

    bool exists = await dotGitDir.exists();
    if (exists) {
      await remoteGitDir.delete(recursive: true);
    }
  }

  void _loadNotesFromDisk() {
    Fimber.d("Loading Notes From Disk");
    appState.isLoadingFromDisk = true;
    noteRepo.listNotes().then((loadedNotes) {
      setState(() {
        appState.isLoadingFromDisk = false;
        appState.notes = loadedNotes;
        appState.hasJournalEntries = loadedNotes.isNotEmpty;

        getAnalytics().logEvent(
          name: "notes_loaded",
          parameters: <String, dynamic>{
            'count': loadedNotes.length,
          },
        );
      });
    }).catchError((err, stack) {
      setState(() {
        Fimber.d("Load Notes From Disk Error: " + err.toString());
        Fimber.d(stack.toString());
        appState.isLoadingFromDisk = false;

        getAnalytics().logEvent(
          name: "notes_loading_failed",
          parameters: <String, dynamic>{
            'error': err.toString(),
          },
        );
      });
    });
  }

  Future syncNotes() async {
    if (!appState.remoteGitRepoConfigured) {
      Fimber.d("Not syncing because RemoteRepo not configured");
      return true;
    }

    await noteRepo.sync();

    try {
      appState.isLoadingFromDisk = true;
      var loadedNotes = await noteRepo.listNotes();
      setState(() {
        appState.isLoadingFromDisk = false;
        appState.notes = loadedNotes;
        appState.hasJournalEntries = loadedNotes.isNotEmpty;
      });
    } catch (err, stack) {
      setState(() {
        Fimber.d("Load Notes From Disk Error: " + err.toString());
        Fimber.d(stack.toString());
        appState.isLoadingFromDisk = false;
      });
    }

    return true;
  }

  void _syncNotes() {
    if (!appState.remoteGitRepoConfigured) {
      Fimber.d("Not syncing because RemoteRepo not configured");
      return;
    }

    Fimber.d("Starting to syncNotes");
    noteRepo.sync().then((loaded) {
      Fimber.d("NotesRepo Synced: " + loaded.toString());
      _loadNotesFromDisk();
    }).catchError((err) {
      Fimber.d("NotesRepo Sync: " + err.toString());
    });
  }

  void addNote(Note note) {
    insertNote(0, note);
  }

  void removeNote(Note note) {
    setState(() {
      appState.notes.remove(note);
      noteRepo.removeNote(note).then((NoteRepoResult _) async {
        // FIXME: Is there a way of figuring this amount dynamically?
        // The '4 seconds' is taken from snack_bar.dart -> _kSnackBarDisplayDuration
        // We wait an aritfical amount of time, so that the user has a change to undo
        // their delete operation, and that commit is not synced with the server, till then.
        await Future.delayed(const Duration(seconds: 4));
        _syncNotes();
      });
    });
  }

  /*
  String _getGitDir(BuildContext context) {
    var state = StateContainer.of(context).appState;
    if (state.remoteGitRepoConfigured) {
      return state.remoteGitRepoFolderName;
    } else {
      return state.localGitRepoPath;
    }
  }
  */

  void undoRemoveNote(Note note, int index) {
    setState(() {
      appState.notes.insert(index, note);
      noteRepo.resetLastCommit().then((NoteRepoResult _) {
        _syncNotes();
      });
    });
  }

  void insertNote(int index, Note note) {
    Fimber.d("State Container insertNote");
    setState(() {
      if (note.filePath == null || note.filePath.isEmpty) {
        note.filePath = toIso8601WithTimezone(note.created) + '.md';
      }
      appState.notes.insert(index, note);
      appState.hasJournalEntries = true;
      noteRepo.addNote(note).then((NoteRepoResult _) {
        _syncNotes();
      });
    });
  }

  void updateNote(Note note) {
    Fimber.d("State Container updateNote");
    setState(() {
      // Update that specific note
      for (var i = 0; i < appState.notes.length; i++) {
        var n = appState.notes[i];
        if (n.filePath == note.filePath) {
          appState.notes[i] = note;
        }
      }

      noteRepo.updateNote(note).then((NoteRepoResult _) {
        _syncNotes();
      });
    });
  }

  void completeGitHostSetup(String subFolder) {
    () async {
      appState.remoteGitRepoConfigured = true;
      appState.remoteGitRepoFolderName = "journal";
      appState.remoteGitRepoSubFolder = subFolder;

      await migrateGitRepo(
        fromGitBasePath: appState.localGitRepoPath,
        toGitBaseFolder: appState.remoteGitRepoFolderName,
        toGitBaseSubFolder: appState.remoteGitRepoSubFolder,
        gitBasePath: appState.gitBaseDirectory,
      );

      noteRepo = GitNoteRepository(
        baseDirectory: appState.gitBaseDirectory,
        dirName: appState.remoteGitRepoFolderName,
        subDirName: appState.remoteGitRepoSubFolder,
      );

      await _persistConfig();
      _loadNotesFromDisk();
      _syncNotes();

      setState(() {});
    }();
  }

  void completeOnBoarding() {
    setState(() {
      appState.onBoardingCompleted = true;
      _persistConfig();
    });
  }

  Future _persistConfig() async {
    var pref = await SharedPreferences.getInstance();
    await pref.setBool(
        "remoteGitRepoConfigured", appState.remoteGitRepoConfigured);
    await pref.setString("remoteGitRepoPath", appState.remoteGitRepoFolderName);
    await pref.setString(
        "remoteGitRepoSubFolder", appState.remoteGitRepoSubFolder);
    await pref.setBool("onBoardingCompleted", appState.onBoardingCompleted);
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedStateContainer(
      data: this,
      child: widget.child,
    );
  }
}

class _InheritedStateContainer extends InheritedWidget {
  final StateContainerState data;

  _InheritedStateContainer({
    Key key,
    @required this.data,
    @required Widget child,
  }) : super(key: key, child: child);

  // Note: we could get fancy here and compare whether the old AppState is
  // different than the current AppState. However, since we know this is the
  // root Widget, when we make changes we also know we want to rebuild Widgets
  // that depend on the StateContainer.
  @override
  bool updateShouldNotify(_InheritedStateContainer old) => true;
}
