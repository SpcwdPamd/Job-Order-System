
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Tk {
  final bool dark;
  const Tk([this.dark = false]);

  Color get bg    => dark ? const Color(0xFF080E1C) : const Color(0xFFF0F5FA);
  Color get surf  => dark ? const Color(0xFF101827) : const Color(0xFFFFFFFF);
  Color get surf2 => dark ? const Color(0xFF161F30) : const Color(0xFFF7FAFD);
  Color get surf3 => dark ? const Color(0xFF1C2840) : const Color(0xFFEFF4FB);
  Color get bd    => dark ? const Color(0xFF1E2E47) : const Color(0xFFDDE6F0);
  Color get bd2   => dark ? const Color(0xFF283D5C) : const Color(0xFFC3D4E8);
  Color get txtHead  => dark ? const Color(0xFFEDF2FF) : const Color(0xFF0D1F3C);
  Color get txt      => dark ? const Color(0xFFAFC4DE) : const Color(0xFF2D4263);
  Color get txtMuted => dark ? const Color(0xFF475F7E) : const Color(0xFF7A93B4);
  Color get blue    => dark ? const Color(0xFF4D90F0) : const Color(0xFF1D6FE8);
  Color get blueMid => dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
  Color get blueBg  => dark ? const Color(0xFF0C1E3D) : const Color(0xFFEBF3FF);
  Color get blueBd  => dark ? const Color(0xFF1A3869) : const Color(0xFFBDD6FF);
  Color get sideBg  => dark ? const Color(0xFF05090F) : const Color(0xFF0E2A57);
  Color get sideHov => dark ? const Color(0xFF0C1525) : const Color(0xFF163872);
  Color get sideBd  => dark ? const Color(0xFF0C1525) : const Color(0xFF163872);
  Color get sideTxt => dark ? const Color(0xFFB0C8E8) : const Color(0xFFD6E4F7);
  Color get sideMut => dark ? const Color(0xFF3A5578) : const Color(0xFF6B90BC);
  Color get green    => const Color(0xFF059669);
  Color get greenBg  => dark ? const Color(0xFF051E12) : const Color(0xFFECFDF5);
  Color get greenBd  => dark ? const Color(0xFF064E2E) : const Color(0xFFA7F3D0);
  Color get red      => const Color(0xFFDC2626);
  Color get redBg    => dark ? const Color(0xFF250909) : const Color(0xFFFEF2F2);
  Color get redBd    => dark ? const Color(0xFF551414) : const Color(0xFFFECACA);
  Color get amber    => const Color(0xFFD97706);
  Color get amberBg  => dark ? const Color(0xFF221400) : const Color(0xFFFFFBEB);
  Color get amberBd  => dark ? const Color(0xFF4D2E00) : const Color(0xFFFDE68A);
  Color get violet   => const Color(0xFF7C3AED);
  Color get violetBg => dark ? const Color(0xFF150A2E) : const Color(0xFFF5F3FF);
  Color get cyan     => const Color(0xFF0891B2);
  Color get cyanBg   => dark ? const Color(0xFF051821) : const Color(0xFFECFEFF);
  Color get pink     => const Color(0xFFDB2777);
  Color get pinkBg   => dark ? const Color(0xFF250918) : const Color(0xFFFDF2F8);
  Color get indigo   => const Color(0xFF4338CA);
  Color get indigoBg => dark ? const Color(0xFF0C0A2C) : const Color(0xFFEEF2FF);

  List<BoxShadow> get shadowSm => dark
      ? [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 10, offset: const Offset(0, 2)),
    BoxShadow(color: const Color(0xFF4D90F0).withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 2))]
      : [BoxShadow(color: const Color(0xFF1D6FE8).withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
    BoxShadow(color: const Color(0xFF0D1F3C).withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))];

  List<BoxShadow> get shadowMd => dark
      ? [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 28, offset: const Offset(0, 8)),
    BoxShadow(color: const Color(0xFF4D90F0).withOpacity(0.12), blurRadius: 28, offset: const Offset(0, 6))]
      : [BoxShadow(color: const Color(0xFF1D6FE8).withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 6)),
    BoxShadow(color: const Color(0xFF0D1F3C).withOpacity(0.05), blurRadius: 4,  offset: const Offset(0, 2))];

  Color workColor(String? code) {
    switch (code) {
      case '101': return blue; case '102': return cyan; case '103': return violet;
      case '104': return amber; case '201': return green; case '202': return red;
      case '203': return indigo; case '301': return pink; default: return txtMuted;
    }
  }
  Color workBg(String? code) {
    switch (code) {
      case '101': return blueBg; case '102': return cyanBg; case '103': return violetBg;
      case '104': return amberBg; case '201': return greenBg; case '202': return redBg;
      case '203': return indigoBg; case '301': return pinkBg; default: return surf3;
    }
  }
  Color diffColor(int? lvl) {
    switch (lvl) { case 1: return green; case 2: return amber; case 3: return red; default: return txtMuted; }
  }
  Color diffBg(int? lvl) {
    switch (lvl) { case 1: return greenBg; case 2: return amberBg; case 3: return redBg; default: return surf3; }
  }
  String diffLabel(int? lvl) {
    switch (lvl) { case 1: return 'Minor'; case 2: return 'Moderate'; case 3: return 'Major'; default: return '—'; }
  }

  ThemeData get materialTheme => ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: dark
        ? ColorScheme.dark(primary: blue, secondary: blueMid, surface: surf, background: bg, error: red)
        : ColorScheme.light(primary: blue, secondary: blueMid, surface: surf, background: bg, error: red),
    scaffoldBackgroundColor: bg,
    cardTheme: CardThemeData(color: surf, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: bd))),
    dividerTheme: DividerThemeData(color: bd, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(backgroundColor: surf, foregroundColor: txtHead, elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark),
    dialogTheme: DialogThemeData(backgroundColor: surf, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: bd))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: surf, surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20)))),
    inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: surf,
        labelStyle: TextStyle(color: txtMuted), hintStyle: TextStyle(color: txtMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: bd)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: bd)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: blue, width: 1.5))),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
    popupMenuTheme: PopupMenuThemeData(color: surf, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: bd))),
    snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? const Color(0xFF1C2840) : const Color(0xFF0E2A57),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
  );
}

class ThemeNotifier extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;
  void toggle()   { _isDark = !_isDark; notifyListeners(); }
  void setLight() { _isDark = false;    notifyListeners(); }
  void setDark()  { _isDark = true;     notifyListeners(); }
}

final themeNotifier = ThemeNotifier();

class TkProvider extends InheritedWidget {
  final Tk tk;
  const TkProvider({super.key, required this.tk, required super.child});
  static Tk of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<TkProvider>();
    assert(p != null, 'No TkProvider found in context');
    return p!.tk;
  }
  @override
  bool updateShouldNotify(TkProvider old) => tk.dark != old.tk.dark;
}

extension TkContext on BuildContext {
  Tk get tk => TkProvider.of(this);
  bool get isDark => TkProvider.of(this).dark;
}