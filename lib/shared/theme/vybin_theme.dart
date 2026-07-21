import 'package:flutter/material.dart';

class VybinTheme {
  VybinTheme._();

  static const Color darkCharcoal = Color(0xFF121212);
  static const Color cardCharcoal = Color(0xFF1C1C1E);
  static const Color inputCharcoal = Color(0xFF2C2C2E);
  static const Color dividerCharcoal = Color(0xFF38383A);

  static const Color whatsappDarkTeal = Color(0xFF075E54);
  static const Color whatsappTeal = Color(0xFF128C7E);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color whatsappLightGrey = Color(0xFFECE5DD);

  static const Color neonHighlight = Color(0xFF00FF66);
  static const Color neonSecondary = Color(0xFF39FF14);
  static const Color neonBlue = Color(0xFF00E5FF);

  static const Color sentBubbleColor = Color(0xFF1A3D22);
  static const Color receivedBubbleColor = Color(0xFF2C2C2E);

  static const Color primaryText = Color(0xFFF2F2F7);
  static const Color secondaryText = Color(0xFF8E8E93);
  static const Color disabledText = Color(0xFF48484A);

  static const Color errorColor = Color(0xFFFF453A);

  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightInput = Color(0xFFE5E5EA);
  static const Color lightDivider = Color(0xFFD1D1D6);
  static const Color lightPrimaryText = Color(0xFF1C1C1E);

  static const TextStyle headline1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    fontFamily: 'Roboto',
  );

  static const TextStyle subtitle1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFamily: 'Roboto',
  );

  static const TextStyle body1 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    fontFamily: 'Roboto',
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: secondaryText,
    fontFamily: 'Roboto',
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: secondaryText,
    fontFamily: 'Roboto',
  );

  static const TextStyle messageText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    fontFamily: 'Roboto',
  );

  static Color getSentBubbleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A3D22)
        : const Color(0xFFE7FFDB);
  }

  static Color getReceivedBubbleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFFFFFFF);
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: darkCharcoal,
      scaffoldBackgroundColor: darkCharcoal,

      colorScheme: const ColorScheme.dark(
        primary: neonHighlight,
        secondary: neonSecondary,
        surface: cardCharcoal,
        error: errorColor,
        onPrimary: darkCharcoal,
        onSecondary: darkCharcoal,
        onSurface: primaryText,
        onError: primaryText,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: cardCharcoal,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: neonHighlight),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: primaryText,
          fontFamily: 'Roboto',
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: headline1.copyWith(color: primaryText),
        titleMedium: subtitle1.copyWith(color: primaryText),
        bodyLarge: body1.copyWith(color: primaryText),
        bodyMedium: body2,
        bodySmall: caption,
      ),

      cardTheme: const CardThemeData(
        color: cardCharcoal,
        elevation: 2,
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: neonHighlight,
        foregroundColor: darkCharcoal,
        elevation: 4,
        shape: CircleBorder(),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputCharcoal,
        hintStyle: const TextStyle(color: secondaryText, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: neonHighlight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: dividerCharcoal,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(color: secondaryText),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: lightBackground,
      scaffoldBackgroundColor: lightBackground,

      colorScheme: const ColorScheme.light(
        primary: whatsappTeal,
        secondary: whatsappTeal,
        surface: lightCard,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightPrimaryText,
        onError: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: lightCard,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: whatsappTeal),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: lightPrimaryText,
          fontFamily: 'Roboto',
        ),
      ),

      textTheme: TextTheme(
        headlineLarge: headline1.copyWith(color: lightPrimaryText),
        titleMedium: subtitle1.copyWith(color: lightPrimaryText),
        bodyLarge: body1.copyWith(color: lightPrimaryText),
        bodyMedium: body2,
        bodySmall: caption,
      ),

      cardTheme: const CardThemeData(
        color: lightCard,
        elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: whatsappTeal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInput,
        hintStyle: const TextStyle(color: secondaryText, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: whatsappTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(color: secondaryText),
    );
  }
}
