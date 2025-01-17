import 'package:fimber/fimber.dart';
import 'package:flutter/material.dart';
import 'package:function_types/function_types.dart';
import 'package:journal/analytics.dart';

class GitHostSetupButton extends StatelessWidget {
  final Func0<void> onPressed;
  final String text;
  final String iconUrl;

  GitHostSetupButton({
    @required this.text,
    @required this.onPressed,
    this.iconUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (iconUrl == null) {
      return SizedBox(
        width: double.infinity,
        child: RaisedButton(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.button,
          ),
          color: Theme.of(context).primaryColor,
          onPressed: _onPressedWithAnalytics,
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: RaisedButton.icon(
          label: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.button,
          ),
          icon: Image.asset(iconUrl, width: 32, height: 32),
          color: Theme.of(context).primaryColor,
          onPressed: _onPressedWithAnalytics,
        ),
      );
    }
  }

  void _onPressedWithAnalytics() {
    Fimber.d("githostsetup_button_click " + text);
    getAnalytics().logEvent(
      name: "githostsetup_button_click",
      parameters: <String, dynamic>{
        'text': text,
        'icon_url': iconUrl == null ? "" : iconUrl,
      },
    );
    onPressed();
  }
}
