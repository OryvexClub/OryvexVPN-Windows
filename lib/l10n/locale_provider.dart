import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  final Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isRtl => false;
}
