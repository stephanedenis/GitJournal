import 'package:flutter/material.dart';
import 'package:journal/settings.dart';
import 'package:journal/utils.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SettingsList(),
    );
  }
}

class SettingsList extends StatefulWidget {
  @override
  SettingsListState createState() {
    return SettingsListState();
  }
}

class SettingsListState extends State<SettingsList> {
  final gitAuthorKey = GlobalKey<FormFieldState<String>>();
  final gitAuthorEmailKey = GlobalKey<FormFieldState<String>>();

  @override
  Widget build(BuildContext context) {
    var saveGitAuthor = (String gitAuthor) {
      Settings.instance.gitAuthor = gitAuthor;
      Settings.instance.save();
    };

    var gitAuthorForm = Form(
      child: TextFormField(
        key: gitAuthorKey,
        style: Theme.of(context).textTheme.title,
        decoration: const InputDecoration(
          icon: Icon(Icons.person),
          hintText: 'Who should author the changes?',
          labelText: 'Git Author',
        ),
        validator: (String value) {
          value = value.trim();
          if (value.isEmpty) {
            return 'Please enter a name';
          }
          return null;
        },
        textInputAction: TextInputAction.done,
        onFieldSubmitted: saveGitAuthor,
        onSaved: saveGitAuthor,
        initialValue: Settings.instance.gitAuthor,
      ),
      onChanged: () {
        if (!gitAuthorKey.currentState.validate()) return;
        var gitAuthor = gitAuthorKey.currentState.value;
        saveGitAuthor(gitAuthor);
      },
    );

    var saveGitAuthorEmail = (String gitAuthorEmail) {
      Settings.instance.gitAuthorEmail = gitAuthorEmail;
      Settings.instance.save();
    };
    var gitAuthorEmailForm = Form(
      child: TextFormField(
        key: gitAuthorEmailKey,
        style: Theme.of(context).textTheme.title,
        decoration: const InputDecoration(
          icon: Icon(Icons.email),
          hintText: 'Who should author the changes?',
          labelText: 'Git Author Email',
        ),
        validator: (String value) {
          value = value.trim();
          if (value.isEmpty) {
            return 'Please enter an email';
          }

          bool emailValid =
              RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value);
          if (!emailValid) {
            return 'Please enter a valid email';
          }
          return null;
        },
        textInputAction: TextInputAction.done,
        onFieldSubmitted: saveGitAuthorEmail,
        onSaved: saveGitAuthorEmail,
        initialValue: Settings.instance.gitAuthorEmail,
      ),
      onChanged: () {
        if (!gitAuthorEmailKey.currentState.validate()) return;
        var gitAuthorEmail = gitAuthorEmailKey.currentState.value;
        saveGitAuthorEmail(gitAuthorEmail);
      },
    );

    var listView = ListView(children: <Widget>[
      SettingsHeader("Git Settings"),
      ListTile(title: gitAuthorForm),
      ListTile(title: gitAuthorEmailForm),
      SizedBox(height: 16.0),
      VersionNumberTile(),
    ]);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: listView,
    );
  }
}

class SettingsHeader extends StatelessWidget {
  final String text;
  SettingsHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        text,
        style: Theme.of(context).textTheme.title,
      ),
      enabled: false,
    );
  }
}

class VersionNumberTile extends StatefulWidget {
  @override
  VersionNumberTileState createState() {
    return VersionNumberTileState();
  }
}

class VersionNumberTileState extends State<VersionNumberTile> {
  String versionText = "";

  @override
  void initState() {
    super.initState();

    () async {
      var str = await getVersionString();
      setState(() {
        versionText = str;
      });
    }();
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    return ListTile(
      title: Text("Version Info", style: textTheme.subhead),
      subtitle: Text(
        versionText,
        style: textTheme.body1,
        textAlign: TextAlign.left,
      ),
      enabled: false,
    );
  }
}
