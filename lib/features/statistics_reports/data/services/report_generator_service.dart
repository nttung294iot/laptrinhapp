import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../shared/models/borrow_card.dart';
import '../models/statistics_data.dart';
import '../../../../core/utils/pdf_font_helper.dart';

class ReportGeneratorService {
  /// Generate PDF report from statistics data
  Future<Uint8List> generatePdfReport({
    required StatisticsSummary summary,
    required List<UserStatistics> userStats,
    required List<MonthlyStatistics> monthlyStats,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();
    
    // Load Vietnamese-compatible font
    final vietnameseFont = await _loadVietnameseFont();

    // Add title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BÁO CÁO THỐNG KÊ THƯ VIỆN',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        font: vietnameseFont,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      _getDateRangeText(startDate, endDate),
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                        font: vietnameseFont,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Summary section
              pw.Text(
                'TỔNG QUAN',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  font: vietnameseFont,
                ),
              ),
              pw.SizedBox(height: 15),
              
              _buildSummaryTable(summary, vietnameseFont),
              
              pw.SizedBox(height: 30),
              
              // Top borrowers section
              pw.Text(
                'TOP NGƯỜI MƯỢN SÁCH NHIỀU NHẤT',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  font: vietnameseFont,
                ),
              ),
              pw.SizedBox(height: 15),
              
              _buildUserStatsTable(userStats.take(10).toList(), vietnameseFont),
            ],
          );
        },
      ),
    );

    // Add monthly statistics page if data exists
    if (monthlyStats.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'THỐNG KÊ THEO THÁNG',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    font: vietnameseFont,
                  ),
                ),
                pw.SizedBox(height: 15),
                
                _buildMonthlyStatsTable(monthlyStats, vietnameseFont),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Generate Excel report from statistics data
  Future<Uint8List> generateExcelReport({
    required StatisticsSummary summary,
    required List<UserStatistics> userStats,
    required List<MonthlyStatistics> monthlyStats,
    required List<BorrowCard> borrowCards,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final excel = Excel.createExcel();
    
    // Remove default sheet
    excel.delete('Sheet1');

    // Create summary sheet
    _createSummarySheet(excel, summary, startDate, endDate);
    
    // Create user statistics sheet
    _createUserStatsSheet(excel, userStats);
    
    // Create monthly statistics sheet
    _createMonthlyStatsSheet(excel, monthlyStats);
    
    // Create raw data sheet
    _createRawDataSheet(excel, borrowCards);

    return Uint8List.fromList(excel.encode()!);
  }

  /// Save report to file
  Future<String> saveReportToFile(
    Uint8List reportData,
    String fileName,
    ReportFormat format,
  ) async {
    try {
      // Request storage permission first
      await _requestStoragePermission();
      
      Directory? directory;
      
      try {
        // Try to get external storage directory (usually /storage/emulated/0/)
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Navigate to the public Downloads folder
          // /storage/emulated/0/Android/data/package/files -> /storage/emulated/0/Download
          final externalPath = directory.path;
          final publicDownloads = externalPath.split('/Android/data/')[0] + '/Download';
          
          final downloadsDir = Directory(publicDownloads);
          if (await downloadsDir.exists()) {
            directory = downloadsDir;
            print('Using public Downloads: ${directory.path}');
          } else {
            // Create app-specific Downloads folder
            final appDownloads = Directory(path.join(directory.path, 'Downloads'));
            if (!await appDownloads.exists()) {
              await appDownloads.create(recursive: true);
            }
            directory = appDownloads;
            print('Using app Downloads: ${directory.path}');
          }
        }
      } catch (e) {
        print('External storage not available: $e');
      }
      
      // Fallback to application documents directory
      directory ??= await getApplicationDocumentsDirectory();
      
      final extension = format == ReportFormat.pdf ? 'pdf' : 'xlsx';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = path.join(directory.path, '${fileName}_$timestamp.$extension');
      
      final file = File(filePath);
      await file.writeAsBytes(reportData);
      
      print('File saved to: $filePath');
      return filePath;
    } catch (e) {
      throw Exception('Failed to save report: $e');
    }
  }

  /// Request storage permission
  Future<void> _requestStoragePermission() async {
    try {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    } catch (e) {
      print('Permission request failed: $e');
    }
  }

  // PDF Helper methods
  pw.Widget _buildSummaryTable(StatisticsSummary summary, pw.Font font) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        _buildTableRow('Tổng số lượt mượn', summary.totalBorrows.toString(), font),
        _buildTableRow('Đang mượn', summary.activeBorrows.toString(), font),
        _buildTableRow('Đã trả', summary.returnedBorrows.toString(), font),
        _buildTableRow('Quá hạn', summary.overdueBorrows.toString(), font),
        _buildTableRow('Số người mượn', summary.uniqueBorrowers.toString(), font),
        _buildTableRow('Số sách khác nhau', summary.uniqueBooks.toString(), font),
        _buildTableRow('Thời gian mượn TB (ngày)', summary.averageBorrowDuration.toStringAsFixed(1), font),
        _buildTableRow('Sách phổ biến nhất', summary.mostPopularBook, font),
        _buildTableRow('Người mượn tích cực nhất', summary.mostActiveBorrower, font),
      ],
    );
  }

  pw.TableRow _buildTableRow(String label, String value, pw.Font font) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label, 
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              font: font,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: pw.TextStyle(font: font),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildUserStatsTable(List<UserStatistics> userStats, pw.Font font) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Tên người mượn', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Tổng mượn', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Đang mượn', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Quá hạn', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font)),
            ),
          ],
        ),
        // Data rows
        ...userStats.map((stats) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(stats.borrowerName, style: pw.TextStyle(font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(stats.totalBorrows.toString(), style: pw.TextStyle(font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(stats.activeBorrows.toString(), style: pw.TextStyle(font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(stats.overdueBorrows.toString(), style: pw.TextStyle(font: font)),
            ),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildMonthlyStatsTable(List<MonthlyStatistics> monthlyStats, pw.Font font) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Tháng/Năm', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Tổng mượn', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Tổng trả', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Quá hạn', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font)),
            ),
          ],
        ),
        // Data rows
        ...monthlyStats.map((stats) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('${stats.monthName}/${stats.year}', style: pw.TextStyle(font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(stats.totalBorrows.toString(), style: pw.TextStyle(font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(stats.totalReturns.toString(), style: pw.TextStyle(font: font)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(stats.overdueCount.toString(), style: pw.TextStyle(font: font)),
            ),
          ],
        )),
      ],
    );
  }

  // Excel Helper methods
  void _createSummarySheet(Excel excel, StatisticsSummary summary, DateTime? startDate, DateTime? endDate) {
    final sheet = excel['Tổng quan'];
    
    // Title
    sheet.cell(CellIndex.indexByString('A1')).value = 'BÁO CÁO THỐNG KÊ THƯ VIỆN';
    sheet.cell(CellIndex.indexByString('A2')).value = _getDateRangeText(startDate, endDate);
    
    // Headers
    sheet.cell(CellIndex.indexByString('A4')).value = 'Chỉ số';
    sheet.cell(CellIndex.indexByString('B4')).value = 'Giá trị';
    
    // Data
    final summaryData = [
      ['Tổng số lượt mượn', summary.totalBorrows],
      ['Đang mượn', summary.activeBorrows],
      ['Đã trả', summary.returnedBorrows],
      ['Quá hạn', summary.overdueBorrows],
      ['Số người mượn', summary.uniqueBorrowers],
      ['Số sách khác nhau', summary.uniqueBooks],
      ['Thời gian mượn TB (ngày)', summary.averageBorrowDuration.toStringAsFixed(1)],
      ['Sách phổ biến nhất', summary.mostPopularBook],
      ['Người mượn tích cực nhất', summary.mostActiveBorrower],
    ];
    
    for (int i = 0; i < summaryData.length; i++) {
      final row = i + 5;
      sheet.cell(CellIndex.indexByString('A$row')).value = summaryData[i][0].toString();
      sheet.cell(CellIndex.indexByString('B$row')).value = summaryData[i][1].toString();
    }
  }

  void _createUserStatsSheet(Excel excel, List<UserStatistics> userStats) {
    final sheet = excel['Thống kê người dùng'];
    
    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = 'Tên người mượn';
    sheet.cell(CellIndex.indexByString('B1')).value = 'Tổng mượn';
    sheet.cell(CellIndex.indexByString('C1')).value = 'Đang mượn';
    sheet.cell(CellIndex.indexByString('D1')).value = 'Đã trả';
    sheet.cell(CellIndex.indexByString('E1')).value = 'Quá hạn';
    sheet.cell(CellIndex.indexByString('F1')).value = 'Lần mượn cuối';
    
    // Data
    for (int i = 0; i < userStats.length; i++) {
      final row = i + 2;
      final stats = userStats[i];
      
      sheet.cell(CellIndex.indexByString('A$row')).value = stats.borrowerName;
      sheet.cell(CellIndex.indexByString('B$row')).value = stats.totalBorrows;
      sheet.cell(CellIndex.indexByString('C$row')).value = stats.activeBorrows;
      sheet.cell(CellIndex.indexByString('D$row')).value = stats.returnedBorrows;
      sheet.cell(CellIndex.indexByString('E$row')).value = stats.overdueBorrows;
      sheet.cell(CellIndex.indexByString('F$row')).value = stats.lastBorrowDate?.toString().split(' ')[0] ?? 'N/A';
    }
  }

  void _createMonthlyStatsSheet(Excel excel, List<MonthlyStatistics> monthlyStats) {
    final sheet = excel['Thống kê theo tháng'];
    
    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = 'Tháng/Năm';
    sheet.cell(CellIndex.indexByString('B1')).value = 'Tổng mượn';
    sheet.cell(CellIndex.indexByString('C1')).value = 'Tổng trả';
    sheet.cell(CellIndex.indexByString('D1')).value = 'Mượn mới';
    sheet.cell(CellIndex.indexByString('E1')).value = 'Quá hạn';
    
    // Data
    for (int i = 0; i < monthlyStats.length; i++) {
      final row = i + 2;
      final stats = monthlyStats[i];
      
      sheet.cell(CellIndex.indexByString('A$row')).value = '${stats.monthName}/${stats.year}';
      sheet.cell(CellIndex.indexByString('B$row')).value = stats.totalBorrows;
      sheet.cell(CellIndex.indexByString('C$row')).value = stats.totalReturns;
      sheet.cell(CellIndex.indexByString('D$row')).value = stats.newBorrows;
      sheet.cell(CellIndex.indexByString('E$row')).value = stats.overdueCount;
    }
  }

  void _createRawDataSheet(Excel excel, List<BorrowCard> borrowCards) {
    final sheet = excel['Dữ liệu chi tiết'];
    
    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = 'ID';
    sheet.cell(CellIndex.indexByString('B1')).value = 'Tên người mượn';
    sheet.cell(CellIndex.indexByString('C1')).value = 'Lớp';
    sheet.cell(CellIndex.indexByString('D1')).value = 'Tên sách';
    sheet.cell(CellIndex.indexByString('E1')).value = 'Ngày mượn';
    sheet.cell(CellIndex.indexByString('F1')).value = 'Ngày dự kiến trả';
    sheet.cell(CellIndex.indexByString('G1')).value = 'Ngày trả thực tế';
    sheet.cell(CellIndex.indexByString('H1')).value = 'Trạng thái';
    
    // Data
    for (int i = 0; i < borrowCards.length; i++) {
      final row = i + 2;
      final card = borrowCards[i];
      
      sheet.cell(CellIndex.indexByString('A$row')).value = card.id ?? 0;
      sheet.cell(CellIndex.indexByString('B$row')).value = card.borrowerName;
      sheet.cell(CellIndex.indexByString('C$row')).value = card.borrowerClass ?? '';
      sheet.cell(CellIndex.indexByString('D$row')).value = card.bookName;
      sheet.cell(CellIndex.indexByString('E$row')).value = card.borrowDate.toString().split(' ')[0];
      sheet.cell(CellIndex.indexByString('F$row')).value = card.expectedReturnDate.toString().split(' ')[0];
      sheet.cell(CellIndex.indexByString('G$row')).value = card.actualReturnDate?.toString().split(' ')[0] ?? '';
      sheet.cell(CellIndex.indexByString('H$row')).value = _getStatusText(card.status);
    }
  }

  String _getDateRangeText(DateTime? startDate, DateTime? endDate) {
    if (startDate != null && endDate != null) {
      return 'Từ ${startDate.toString().split(' ')[0]} đến ${endDate.toString().split(' ')[0]}';
    }
    return 'Tất cả thời gian';
  }

  String _getStatusText(BorrowStatus status) {
    switch (status) {
      case BorrowStatus.borrowed:
        return 'Đang mượn';
      case BorrowStatus.returned:
        return 'Đã trả';
      case BorrowStatus.overdue:
        return 'Quá hạn';
    }
  }

  /// Load Vietnamese-compatible font
  Future<pw.Font> _loadVietnameseFont() async {
    return await PdfFontHelper.getVietnameseFont();
  }
}

enum ReportFormat { pdf, excel }