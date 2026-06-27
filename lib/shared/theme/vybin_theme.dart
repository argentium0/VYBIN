import 'package:flutter/material.dart';

/// A centralized global app theme for project **VYBIN**.
/// Mimics the clean structure of modern messaging platforms but utilizes a
/// dark charcoal palette with neon highlight accents.
class VybinTheme {
  VybinTheme._();

  // --- Palette Definitions ---
  
  // Backgrounds (Dark Charcoal shades)
  static const Color darkCharcoal = Color(0xFF121212);
  static const Color cardCharcoal = Color(0xFF1C1C1E);
  static const Color inputCharcoal = Color(0xFF2C2C2E);
  static const Color dividerCharcoal = Color(0xFF38383A);

  // WhatsApp Color Palette (Section 8.2 of Spec)
  static const Color whatsappDarkTeal = Color(0xFF075E54);
  static const Color whatsappTeal = Color(0xFF128C7E);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color whatsappLightGrey = Color(0xFFECE5DD);

  // Highlights & Accents (Neon Highlights)
  static const Color neonHighlight = Color(0xFF00FF66); // Cyber Neon Green
  static const Color neonSecondary = Color(0xFF39FF14); // Electric Lime
  static const Color neonBlue = Color(0xFF00E5FF);      // Cyan (e.g. read ticks)

  // Message Bubbles
  static const Color sentBubbleColor = Color(0xFF1A3D22); // Deep Charcoal Green
  static const Color receivedBubbleColor = Color(0xFF2C2C2E); // Dark Grey/Charcoal
  
  // Text Colors
  static const Color primaryText = Color(0xFFF2F2F7);
  static const Color secondaryText = Color(0xFF8E8E93);
  static const Color disabledText = Color(0xFF48484A);

  // Error/Destructive
  static const Color errorColor = Color(0xFFFF453A); // Neon Red

  // Light Palette Definitions
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightInput = Color(0xFFE5E5EA);
  static const Color lightDivider = Color(0xFFD1D1D6);
  static const Color lightPrimaryText = Color(0xFF1C1C1E);

  // --- Typography (As specified in Section 8.3, adapted for dynamic inheritance) ---
  
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

  // --- Dynamic Chat Bubbles ---
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

  /// Returns the global Dark Charcoal and Neon Highlights ThemeData.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: darkCharcoal,
      scaffoldBackgroundColor: darkCharcoal,
      
      // Color Scheme
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

      // AppBar Theme
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

      // Text Theme
      textTheme: TextTheme(
        headlineLarge: headline1.copyWith(color: primaryText),
        titleMedium: subtitle1.copyWith(color: primaryText),
        bodyLarge: body1.copyWith(color: primaryText),
        bodyMedium: body2,
        bodySmall: caption,
      ),

      // Card Theme
      cardTheme: const CardThemeData(
        color: cardCharcoal,
        elevation: 2,
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: neonHighlight,
        foregroundColor: darkCharcoal,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Input Decoration Theme (Text Field styling)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputCharcoal,
        hintStyle: const TextStyle(color: secondaryText, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: dividerCharcoal,
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: secondaryText,
      ),
    );
  }

  /// Returns the Light Theme mimicking WhatsApp minimalism.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: lightBackground,
      scaffoldBackgroundColor: lightBackground,
      
      // Color Scheme
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

      // AppBar Theme
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

      // Text Theme
      textTheme: TextTheme(
        headlineLarge: headline1.copyWith(color: lightPrimaryText),
        titleMedium: subtitle1.copyWith(color: lightPrimaryText),
        bodyLarge: body1.copyWith(color: lightPrimaryText),
        bodyMedium: body2,
        bodySmall: caption,
      ),

      // Card Theme
      cardTheme: const CardThemeData(
        color: lightCard,
        elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: whatsappTeal,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Input Decoration Theme (Text Field styling)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInput,
        hintStyle: const TextStyle(color: secondaryText, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: secondaryText,
      ),
    );
  }
}
