import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
// Removing unnecessary import
import 'package:flutter/services.dart';

// This script generates simple placeholder app icons
// Run this script with: flutter run -d macos lib/utils/scripts/generate_placeholder_icons.dart

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Define the icon sizes (commented out instead of removed since they might be needed later)
  // const appIconSize = 1024.0;
  // const foregroundIconSize = 800.0;

  // Create directories if they don't exist
  await Directory('assets/icon').create(recursive: true);
  await Directory('assets').create(recursive: true);

  // Generate icons directly using simpler method
  await generateSimpleIcons();

  print('Icons generated successfully!');
  exit(0);
}

Future<void> generateSimpleIcons() async {
  // Create a purple icon with music note for Android
  final androidIcon = File('assets/android_icon.png');
  final androidForegroundIcon = File('assets/android_icon_foreground.png');
  final iosIcon = File('assets/ios_icon.png');

  // Copy a placeholder icon file from Flutter assets
  ByteData data = await rootBundle.load(
    'packages/flutter/lib/src/material/icons/material/music_note/materialsymbolsoutlined/music_note_wght700grad200fill1_48px.png',
  );
  await androidIcon.writeAsBytes(data.buffer.asUint8List());
  await androidForegroundIcon.writeAsBytes(data.buffer.asUint8List());
  await iosIcon.writeAsBytes(data.buffer.asUint8List());

  // Also copy to the icon directory
  final appIcon = File('assets/icon/app_icon.png');
  final appIconForeground = File('assets/icon/app_icon_foreground.png');
  await appIcon.writeAsBytes(data.buffer.asUint8List());
  await appIconForeground.writeAsBytes(data.buffer.asUint8List());
}

// Simple function to create a basic solid color image with text
Future<void> createSimpleImage(String path, Color color, String text) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..color = color;

  // Draw background
  canvas.drawRect(Rect.fromLTWH(0, 0, 1024, 1024), paint);

  // Draw text
  final textStyle = TextStyle(
    color: Colors.white,
    fontSize: 120,
    fontWeight: FontWeight.bold,
  );

  final textSpan = TextSpan(text: text, style: textStyle);

  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(512 - textPainter.width / 2, 512 - textPainter.height / 2),
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(1024, 1024);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

  final file = File(path);
  await file.writeAsBytes(byteData!.buffer.asUint8List());
}
