import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefsKey = 'app_locale';
const Locale _kEnglish = Locale('en');
const Locale _kArabic = Locale('ar');
const List<Locale> kSupportedLocales = [_kEnglish, _kArabic];

class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs) : _locale = _initialLocale(_prefs);

  final SharedPreferences _prefs;
  Locale _locale;

  Locale get locale => _locale;

  static Future<LocaleController> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LocaleController(prefs);
  }

  static Locale _initialLocale(SharedPreferences prefs) {
    final saved = prefs.getString(_kPrefsKey);
    if (saved == 'en') return _kEnglish;
    if (saved == 'ar') return _kArabic;
    final device = PlatformDispatcher.instance.locale.languageCode;
    if (device == 'ar') return _kArabic;
    return _kEnglish;
  }

  Future<void> setLocale(Locale next) async {
    if (next.languageCode != 'en' && next.languageCode != 'ar') return;
    if (next == _locale) return;
    _locale = next;
    await _prefs.setString(_kPrefsKey, next.languageCode);
    notifyListeners();
  }

  Future<void> toggle() async {
    await setLocale(_locale.languageCode == 'en' ? _kArabic : _kEnglish);
  }
}
