import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

class PdfFontHelper {
  static pw.Font? _cachedFont;
  
  /// Get Vietnamese-compatible font for PDF
  static Future<pw.Font> getVietnameseFont() async {
    // Return cached font if available
    if (_cachedFont != null) {
      return _cachedFont!;
    }
    
    try {
      // Method 1: Try to load from assets (.ttf)
      try {
        final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        _cachedFont = pw.Font.ttf(fontData);
        print('✅ Loaded Roboto font from assets (TTF)');
        return _cachedFont!;
      } catch (e) {
        print('⚠️ TTF font not in assets: $e');
      }
      
      // Method 1b: Try to load from assets (.woff2) - convert to TTF
      try {
        final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.woff2');
        // Note: PDF package may not support WOFF2 directly
        // We'll try anyway
        _cachedFont = pw.Font.ttf(fontData);
        print('✅ Loaded Roboto font from assets (WOFF2)');
        return _cachedFont!;
      } catch (e) {
        print('⚠️ WOFF2 font not supported or not in assets: $e');
      }
      
      // Method 2: Download and cache font
      final fontBytes = await _downloadAndCacheFont();
      if (fontBytes != null) {
        _cachedFont = pw.Font.ttf(ByteData.sublistView(fontBytes));
        print('✅ Loaded Roboto font from download');
        return _cachedFont!;
      }
      
      // Method 3: Use Times as fallback (better Unicode support than Helvetica)
      print('⚠️ Using Times font as fallback');
      _cachedFont = pw.Font.times();
      return _cachedFont!;
    } catch (e) {
      print('❌ Error loading font: $e');
      _cachedFont = pw.Font.times();
      return _cachedFont!;
    }
  }
  
  /// Download font and cache it
  static Future<Uint8List?> _downloadAndCacheFont() async {
    try {
      final cacheDir = await getApplicationSupportDirectory();
      final fontFile = File('${cacheDir.path}/roboto_regular.ttf');
      
      // Check if font is already cached
      if (await fontFile.exists()) {
        print('📦 Loading font from cache');
        return await fontFile.readAsBytes();
      }
      
      // Download font from multiple sources
      final urls = [
        'https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Regular.ttf',
        'https://raw.githubusercontent.com/google/fonts/main/apache/roboto/static/Roboto-Regular.ttf',
      ];
      
      for (final url in urls) {
        try {
          print('⬇️ Downloading font from: $url');
          final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15),
          );
          
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            // Save to cache
            await fontFile.writeAsBytes(response.bodyBytes);
            print('✅ Font downloaded and cached');
            return response.bodyBytes;
          }
        } catch (e) {
          print('⚠️ Failed to download from $url: $e');
          continue;
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error downloading font: $e');
      return null;
    }
  }
  
  /// Pre-load font at app startup
  static Future<void> preloadFont() async {
    try {
      await getVietnameseFont();
      print('✅ Font preloaded successfully');
    } catch (e) {
      print('⚠️ Font preload failed: $e');
    }
  }
  
  /// Clear cached font
  static void clearCache() {
    _cachedFont = null;
  }
}
