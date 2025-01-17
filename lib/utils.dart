import 'package:fimber/fimber.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info/package_info.dart';

import 'app.dart';
import 'note.dart';
import 'state_container.dart';

Future<String> getVersionString() async {
  var info = await PackageInfo.fromPlatform();
  var versionText = "";
  if (info != null) {
    versionText = info.appName + " " + info.version + "+" + info.buildNumber;

    if (JournalApp.isInDebugMode) {
      versionText += " (Debug)";
    }
  }

  return versionText;
}

Future<bool> shouldEnableAnalytics() async {
  try {
    const _platform = const MethodChannel('gitjournal.io/git');
    final bool result = await _platform.invokeMethod('shouldEnableAnalytics');
    return result;
  } on MissingPluginException catch (e) {
    Fimber.d("shouldEnableAnalytics: $e");
    return false;
  }
}

/// adb logcat
/// Returns the file path where the logs were dumped
Future<String> dumpAppLogs() async {
  const _platform = const MethodChannel('gitjournal.io/git');
  final String logsFilePath = await _platform.invokeMethod('dumpAppLogs');
  return logsFilePath;
}

SnackBar buildUndoDeleteSnackbar(
  BuildContext context,
  Note deletedNote,
  int deletedNoteIndex,
) {
  var snackbar = SnackBar(
    content: Text("Note Deleted"),
    action: SnackBarAction(
      label: "Undo",
      onPressed: () {
        Fimber.d("Undoing delete");
        var stateContainer = StateContainer.of(context);
        stateContainer.undoRemoveNote(deletedNote, deletedNoteIndex);
      },
    ),
  );

  return snackbar;
}
