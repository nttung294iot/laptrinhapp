import 'package:postgres/postgres.dart';
import '../../../../shared/database/database_helper.dart';

/// Cung cấp context về thư viện cho AI
class LibraryContextProvider {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Store recent context for follow-up questions
  String? _lastBookName;
  String? _lastStudentId;
  List<Map<String, dynamic>>? _lastQueryResults;

  /// Lấy system prompt cho AI
  Future<String> getSystemPrompt() async {
    final stats = await getLibraryStats();
    
    return '''
Bạn là trợ lý AI thông minh cho thủ thư của hệ thống quản lý thư viện.

NHIỆM VỤ:
- Trả lời câu hỏi về thống kê, tra cứu thông tin sách, độc giả, phiếu mượn
- Gợi ý hành động xử lý (phiếu quá hạn, nhập sách, etc.)
- Tạo báo cáo nhanh
- Hỗ trợ thủ thư trong công việc hàng ngày

THÔNG TIN THƯ VIỆN HIỆN TẠI:
${stats['summary']}

QUY TẮC:
1. Trả lời ngắn gọn, súc tích, dễ hiểu
2. Sử dụng tiếng Việt
3. Đưa ra số liệu cụ thể khi có thể
4. Gợi ý hành động thực tế
5. Nếu không có thông tin, hãy nói rõ ràng

ĐỊNH DẠNG TRẢ LỜI:
- Sử dụng emoji phù hợp: 📚 📊 ⚠️ ✅ ❌
- Chia thành đoạn ngắn
- Highlight số liệu quan trọng

VÍ DỤ:
User: "Hôm nay có bao nhiêu phiếu mượn?"
Assistant: "📊 Hôm nay có **5 phiếu mượn** mới.

Chi tiết:
- Đã trả: 2 phiếu
- Đang mượn: 3 phiếu
- Quá hạn: 0 phiếu"
''';
  }

  /// Lấy thống kê tổng quan thư viện
  Future<Map<String, dynamic>> getLibraryStats() async {
    try {
      final conn = await _dbHelper.connection;

      // Thống kê sách
      final booksResult = await conn.execute('''
        SELECT 
          COUNT(*) as total_books,
          SUM(total_copies) as total_copies,
          SUM(available_copies) as available_copies
        FROM books
      ''');

      // Thống kê độc giả
      final readersResult = await conn.execute('''
        SELECT COUNT(*) as total_readers
        FROM readers
      ''');

      // Thống kê phiếu mượn
      final borrowCardsResult = await conn.execute('''
        SELECT 
          COUNT(*) as total_borrow_cards,
          COUNT(CASE WHEN status = 'borrowed' THEN 1 END) as borrowed,
          COUNT(CASE WHEN status = 'returned' THEN 1 END) as returned,
          COUNT(CASE WHEN status = 'overdue' THEN 1 END) as overdue
        FROM borrow_cards
      ''');

      // Thống kê hôm nay
      final todayResult = await conn.execute('''
        SELECT COUNT(*) as today_borrows
        FROM borrow_cards
        WHERE borrow_date = CURRENT_DATE
      ''');

      final books = booksResult.first.toColumnMap();
      final readers = readersResult.first.toColumnMap();
      final borrowCards = borrowCardsResult.first.toColumnMap();
      final today = todayResult.first.toColumnMap();

      final summary = '''
- Tổng số sách: ${books['total_books']} đầu sách (${books['total_copies']} cuốn)
- Sách còn lại: ${books['available_copies']} cuốn
- Tổng độc giả: ${readers['total_readers']} người
- Phiếu mượn đang hoạt động: ${borrowCards['borrowed']} phiếu
- Phiếu quá hạn: ${borrowCards['overdue']} phiếu
- Phiếu mượn hôm nay: ${today['today_borrows']} phiếu
''';

      return {
        'summary': summary,
        'books': books,
        'readers': readers,
        'borrow_cards': borrowCards,
        'today': today,
      };
    } catch (e) {
      return {
        'summary': 'Không thể lấy thống kê thư viện',
        'error': e.toString(),
      };
    }
  }

  /// Lấy context cho câu hỏi cụ thể
  Future<String> getContextForQuery(String query) async {
    try {
      final conn = await _dbHelper.connection;
      final queryLower = query.toLowerCase().trim();

      print('🔍 Processing query: "$query"');
      print('🔍 Query lower: "$queryLower"');

      // 1. Thống kê hôm nay / today
      if (queryLower.contains('hôm nay') || 
          queryLower.contains('today') ||
          queryLower == 'thống kê hôm nay') {
        return await _getTodayContext(conn);
      }
      
      // 2. Sách quá hạn / overdue
      if (queryLower.contains('quá hạn') || 
          queryLower.contains('overdue') ||
          queryLower.contains('danh sách') && queryLower.contains('quá hạn')) {
        return await _getOverdueContext(conn);
      }
      
      // 3. Sách phổ biến / top / nhiều nhất
      if (queryLower.contains('phổ biến') || 
          queryLower.contains('nhiều nhất') ||
          queryLower.contains('top') ||
          (queryLower.contains('sách') && queryLower.contains('được mượn'))) {
        return await _getPopularBooksContext(conn);
      }
      
      // 4. Tổng quan thư viện / thống kê chung
      if (queryLower.contains('tổng quan') ||
          queryLower.contains('thống kê chung') ||
          queryLower.contains('tổng số') ||
          queryLower == 'thống kê') {
        final stats = await getLibraryStats();
        return stats['summary'] as String;
      }
      
      // 5. Tìm sách / search book
      if ((queryLower.contains('tìm') || queryLower.contains('search')) && 
          queryLower.contains('sách')) {
        return await _getBookContext(conn, query);
      }
      
      // 6. Thông tin độc giả cụ thể (có mã SV)
      if (RegExp(r'sv\d+', caseSensitive: false).hasMatch(queryLower)) {
        return await _getReaderContext(conn, query);
      }
      
      // 7. Ai đang mượn sách / người mượn
      if ((queryLower.contains('ai') || queryLower.contains('người')) && 
          (queryLower.contains('mượn') || queryLower.contains('đang mượn'))) {
        return await _getBorrowerContext(conn, query);
      }
      
      // 8. Thời gian mượn/trả
      if ((queryLower.contains('thời gian') || queryLower.contains('ngày') || 
           queryLower.contains('khi nào') || queryLower.contains('hạn')) && 
          (queryLower.contains('mượn') || queryLower.contains('trả'))) {
        return await _getTimeContext(conn, query);
      }
      
      // 9. Thông tin chi tiết độc giả (sđt, email, địa chỉ)
      if ((queryLower.contains('số điện thoại') || queryLower.contains('sđt') || 
           queryLower.contains('phone') || queryLower.contains('email') || 
           queryLower.contains('địa chỉ') || queryLower.contains('lớp')) &&
          (queryLower.contains('đó') || queryLower.contains('này') || _lastStudentId != null)) {
        return await _getDetailedReaderInfo(conn, query);
      }
      
      // 10. Tìm sách theo từ khóa chung
      if (queryLower.contains('sách')) {
        return await _getBookContext(conn, query);
      }

      // Default: Thống kê tổng quan
      print('⚠️ No specific intent detected, returning general stats');
      final stats = await getLibraryStats();
      return stats['summary'] as String;
    } catch (e) {
      print('❌ Error in getContextForQuery: $e');
      return '''
Xin lỗi, tôi gặp lỗi khi xử lý câu hỏi của bạn.

Bạn có thể thử các câu hỏi sau:
📊 "Thống kê hôm nay"
⚠️ "Danh sách sách quá hạn"
📚 "Top 10 sách phổ biến"
🔍 "Tìm sách Lập trình"
📖 "Tổng quan thư viện"
''';
    }
  }

  Future<String> _getTimeContext(Connection conn, String query) async {
    try {
      final queryLower = query.toLowerCase();
      String? bookName = _lastBookName;
      String? studentId = _lastStudentId;
      
      // Try to extract book name from query
      final bookNameMatch = RegExp(r'"([^"]+)"').firstMatch(query);
      if (bookNameMatch != null) {
        bookName = bookNameMatch.group(1);
      }
      
      // Build query based on available context
      String sql;
      Map<String, dynamic> params = {};
      
      if (bookName != null && studentId != null) {
        final result = await conn.execute(
          Sql.named('''
            SELECT 
              bc.book_name,
              bc.borrower_name,
              bc.borrower_student_id,
              bc.borrow_date,
              bc.expected_return_date,
              bc.actual_return_date,
              bc.status,
              CASE 
                WHEN bc.status = 'borrowed' AND bc.expected_return_date < CURRENT_DATE 
                THEN CURRENT_DATE - bc.expected_return_date 
                ELSE 0 
              END as days_overdue
            FROM borrow_cards bc
            WHERE bc.book_name ILIKE @bookName
              AND bc.borrower_student_id = @studentId
            ORDER BY bc.borrow_date DESC
            LIMIT 1
          '''),
          parameters: {'bookName': '%$bookName%', 'studentId': studentId},
        );
        return _formatTimeResult(result);
      } else if (bookName != null) {
        final result = await conn.execute(
          Sql.named('''
            SELECT 
              bc.book_name,
              bc.borrower_name,
              bc.borrower_student_id,
              bc.borrow_date,
              bc.expected_return_date,
              bc.actual_return_date,
              bc.status,
              CASE 
                WHEN bc.status = 'borrowed' AND bc.expected_return_date < CURRENT_DATE 
                THEN CURRENT_DATE - bc.expected_return_date 
                ELSE 0 
              END as days_overdue
            FROM borrow_cards bc
            WHERE bc.book_name ILIKE @bookName
              AND bc.status = 'borrowed'
            ORDER BY bc.borrow_date DESC
            LIMIT 1
          '''),
          parameters: {'bookName': '%$bookName%'},
        );
        return _formatTimeResult(result);
      } else if (studentId != null) {
        final result = await conn.execute(
          Sql.named('''
            SELECT 
              bc.book_name,
              bc.borrower_name,
              bc.borrower_student_id,
              bc.borrow_date,
              bc.expected_return_date,
              bc.actual_return_date,
              bc.status,
              CASE 
                WHEN bc.status = 'borrowed' AND bc.expected_return_date < CURRENT_DATE 
                THEN CURRENT_DATE - bc.expected_return_date 
                ELSE 0 
              END as days_overdue
            FROM borrow_cards bc
            WHERE bc.borrower_student_id = @studentId
              AND bc.status = 'borrowed'
            ORDER BY bc.borrow_date DESC
            LIMIT 1
          '''),
          parameters: {'studentId': studentId},
        );
        return _formatTimeResult(result);
      } else {
        return 'Vui lòng cho biết tên sách hoặc người mượn để tôi tra cứu thời gian.';
      }
    } catch (e) {
      print('❌ Error in _getTimeContext: $e');
      return 'Không thể lấy thông tin thời gian. Lỗi: $e';
    }
  }

  String _formatTimeResult(Result result) {
    try {
      if (result.isEmpty) {
        return 'Không tìm thấy thông tin mượn sách phù hợp.';
      }
      
      final data = result.first.toColumnMap();
      final daysOverdue = data['days_overdue'] as int;
      final status = data['status'] as String;
      final expectedReturnDate = DateTime.parse(data['expected_return_date'].toString());
      final now = DateTime.now();
      
      String statusText;
      if (status == 'returned') {
        statusText = '✅ Đã trả vào ngày ${data['actual_return_date']}';
      } else if (expectedReturnDate.isBefore(now) || daysOverdue > 0) {
        // Tính lại số ngày quá hạn chính xác
        final actualDaysOverdue = now.difference(expectedReturnDate).inDays;
        statusText = '⚠️ Quá hạn $actualDaysOverdue ngày';
      } else {
        final daysLeft = expectedReturnDate.difference(now).inDays;
        statusText = '⏰ Còn $daysLeft ngày nữa đến hạn';
      }
      
      return '''
📚 Thông tin mượn sách "${data['book_name']}":

👤 Người mượn: ${data['borrower_name']} (${data['borrower_student_id']})
📅 Ngày mượn: ${data['borrow_date']}
⏰ Hạn trả: ${data['expected_return_date']}
📊 Trạng thái: $statusText
''';
    } catch (e) {
      print('❌ Error formatting time result: $e');
      return 'Lỗi khi format kết quả';
    }
  }

  Future<String> _getDetailedReaderInfo(Connection conn, String query) async {
    try {
      String? studentId = _lastStudentId;
      
      // Try to extract student ID from query
      final studentIdMatch = RegExp(r'SV\d+', caseSensitive: false).firstMatch(query);
      if (studentIdMatch != null) {
        studentId = studentIdMatch.group(0)!.toUpperCase();
      }
      
      if (studentId == null) {
        return 'Vui lòng cho biết mã sinh viên để tôi tra cứu thông tin.';
      }
      
      final result = await conn.execute(
        Sql.named('''
          SELECT 
            r.name,
            r.student_id,
            r.class,
            r.phone,
            r.email,
            r.address
          FROM readers r
          WHERE r.student_id = @studentId
        '''),
        parameters: {'studentId': studentId},
      );
      
      if (result.isEmpty) {
        return 'Không tìm thấy thông tin độc giả với mã $studentId';
      }
      
      final data = result.first.toColumnMap();
      
      return '''
👤 Thông tin chi tiết độc giả:

📛 Họ tên: ${data['name']}
🆔 Mã SV: ${data['student_id']}
🏫 Lớp: ${data['class'] ?? 'Chưa cập nhật'}
📱 Số điện thoại: ${data['phone'] ?? 'Chưa cập nhật'}
📧 Email: ${data['email'] ?? 'Chưa cập nhật'}
🏠 Địa chỉ: ${data['address'] ?? 'Chưa cập nhật'}
''';
    } catch (e) {
      print('❌ Error in _getDetailedReaderInfo: $e');
      return 'Không thể lấy thông tin chi tiết. Lỗi: $e';
    }
  }

  Future<String> _getBorrowerContext(Connection conn, String query) async {
    try {
      // Extract book name from query if mentioned
      final bookNameMatch = RegExp(r'"([^"]+)"').firstMatch(query);
      String? bookName = bookNameMatch?.group(1);
      
      // Check if asking about previous context (using words like "đó", "này", "kia")
      final queryLower = query.toLowerCase();
      if ((queryLower.contains('đó') || queryLower.contains('này') || queryLower.contains('kia')) 
          && _lastBookName != null) {
        bookName = _lastBookName;
        print('🔍 Using context from previous question: $_lastBookName');
      }
      
      // If no book name in quotes, try to find from recent overdue books
      if (bookName == null || bookName.isEmpty) {
        // Get all current borrowed/overdue books with borrower info
        final result = await conn.execute('''
          SELECT 
            bc.book_name,
            bc.borrower_name,
            bc.borrower_student_id,
            bc.borrower_class,
            bc.borrower_phone,
            bc.borrow_date,
            bc.expected_return_date,
            bc.status,
            CASE 
              WHEN bc.status = 'borrowed' AND bc.expected_return_date < CURRENT_DATE 
              THEN CURRENT_DATE - bc.expected_return_date 
              ELSE 0 
            END as days_overdue
          FROM borrow_cards bc
          WHERE bc.status = 'borrowed'
          ORDER BY days_overdue DESC, bc.borrow_date DESC
          LIMIT 10
        ''');

        if (result.isEmpty) {
          return 'Hiện tại không có sách nào đang được mượn.';
        }

        final borrowList = result.map((row) {
          final data = row.toColumnMap();
          final expectedReturnDate = DateTime.parse(data['expected_return_date'].toString());
          final now = DateTime.now();
          
          String status;
          if (expectedReturnDate.isBefore(now)) {
            final actualDaysOverdue = now.difference(expectedReturnDate).inDays;
            status = '⚠️ Quá hạn $actualDaysOverdue ngày';
          } else {
            final daysLeft = expectedReturnDate.difference(now).inDays;
            status = '✅ Còn $daysLeft ngày';
          }
          
          return '''
📚 "${data['book_name']}"
   👤 Người mượn: ${data['borrower_name']} (${data['borrower_student_id']})
   📱 SĐT: ${data['borrower_phone'] ?? 'Chưa có'}
   🏫 Lớp: ${data['borrower_class'] ?? 'Chưa có'}
   📅 Ngày mượn: ${data['borrow_date']}
   ⏰ Hạn trả: ${data['expected_return_date']}
   $status''';
        }).join('\n\n');

        return '''
Danh sách người đang mượn sách (${result.length} phiếu):

$borrowList
''';
      }

      // Search for specific book
      final result = await conn.execute(
        '''
        SELECT 
          bc.book_name,
          bc.borrower_name,
          bc.borrower_student_id,
          bc.borrower_class,
          bc.borrower_phone,
          bc.borrow_date,
          bc.expected_return_date,
          bc.status,
          CASE 
            WHEN bc.status = 'borrowed' AND bc.expected_return_date < CURRENT_DATE 
            THEN CURRENT_DATE - bc.expected_return_date 
            ELSE 0 
          END as days_overdue
        FROM borrow_cards bc
        WHERE bc.book_name ILIKE @bookName
          AND bc.status = 'borrowed'
        ORDER BY bc.borrow_date DESC
        LIMIT 5
        ''',
        parameters: {'bookName': '%$bookName%'},
      );

      if (result.isEmpty) {
        return 'Không tìm thấy ai đang mượn sách "$bookName"';
      }

      // Store context for next question
      _lastQueryResults = result.map((row) => row.toColumnMap()).toList();
      if (_lastQueryResults!.isNotEmpty) {
        _lastStudentId = _lastQueryResults!.first['borrower_student_id'] as String?;
      }

      final borrowList = result.map((row) {
        final data = row.toColumnMap();
        final expectedReturnDate = DateTime.parse(data['expected_return_date'].toString());
        final now = DateTime.now();
        
        String status;
        if (expectedReturnDate.isBefore(now)) {
          final actualDaysOverdue = now.difference(expectedReturnDate).inDays;
          status = '⚠️ Quá hạn $actualDaysOverdue ngày';
        } else {
          final daysLeft = expectedReturnDate.difference(now).inDays;
          status = '✅ Còn $daysLeft ngày';
        }
        
        return '''
👤 ${data['borrower_name']} (${data['borrower_student_id']})
   📱 SĐT: ${data['borrower_phone'] ?? 'Chưa có'}
   🏫 Lớp: ${data['borrower_class'] ?? 'Chưa có'}
   📅 Ngày mượn: ${data['borrow_date']}
   ⏰ Hạn trả: ${data['expected_return_date']}
   $status''';
      }).join('\n\n');

      return '''
Người đang mượn sách "$bookName":

$borrowList
''';
    } catch (e) {
      print('❌ Error in _getBorrowerContext: $e');
      return 'Không thể lấy thông tin người mượn sách. Lỗi: $e';
    }
  }

  Future<String> _getTodayContext(Connection conn) async {
    try {
      final result = await conn.execute('''
        SELECT 
          COUNT(*) as total,
          COUNT(CASE WHEN status = 'borrowed' THEN 1 END) as borrowed,
          COUNT(CASE WHEN status = 'returned' THEN 1 END) as returned
        FROM borrow_cards
        WHERE borrow_date = CURRENT_DATE
      ''');

      final data = result.first.toColumnMap();
      final total = data['total'] as int;
      final borrowed = data['borrowed'] as int;
      final returned = data['returned'] as int;
      
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';
      
      String summary;
      if (total == 0) {
        summary = '📊 Hôm nay ($dateStr) chưa có phiếu mượn nào.';
      } else {
        summary = '''
📊 Thống kê hôm nay ($dateStr):

📝 Tổng phiếu mượn: $total phiếu
📚 Đang mượn: $borrowed phiếu
✅ Đã trả: $returned phiếu

${borrowed > 0 ? '💡 Có $borrowed phiếu đang chờ trả sách.' : ''}
${returned > 0 ? '✨ Đã xử lý $returned phiếu trả sách thành công.' : ''}
''';
      }
      
      return summary;
    } catch (e) {
      print('❌ Error in _getTodayContext: $e');
      return 'Không thể lấy thống kê hôm nay. Lỗi: $e';
    }
  }

  Future<String> _getOverdueContext(Connection conn) async {
    try {
      final result = await conn.execute('''
        SELECT 
          bc.id,
          bc.borrower_name,
          bc.borrower_student_id,
          bc.borrower_phone,
          bc.book_name,
          bc.expected_return_date,
          bc.borrow_date,
          CURRENT_DATE - bc.expected_return_date as days_overdue
        FROM borrow_cards bc
        WHERE bc.status = 'borrowed'
          AND bc.expected_return_date < CURRENT_DATE
        ORDER BY days_overdue DESC
        LIMIT 10
      ''');

      if (result.isEmpty) {
        _lastQueryResults = null;
        return '''
✅ Tuyệt vời! Hiện tại không có phiếu mượn nào quá hạn.

📊 Tất cả độc giả đều trả sách đúng hạn.
💡 Hãy tiếp tục duy trì công tác nhắc nhở tốt!
''';
      }

      // Store results for follow-up questions
      _lastQueryResults = result.map((row) => row.toColumnMap()).toList();
      if (_lastQueryResults!.isNotEmpty) {
        _lastBookName = _lastQueryResults!.first['book_name'] as String?;
        _lastStudentId = _lastQueryResults!.first['borrower_student_id'] as String?;
      }

      final overdueList = result.map((row) {
        final data = row.toColumnMap();
        final daysOverdue = data['days_overdue'] as int;
        String urgency = '';
        if (daysOverdue > 30) {
          urgency = '🔴 CỰC KỲ KHẨN CẤP';
        } else if (daysOverdue > 14) {
          urgency = '🟠 KHẨN CẤP';
        } else if (daysOverdue > 7) {
          urgency = '🟡 CẦN XỬ LÝ';
        } else {
          urgency = '🟢 MỚI QUÁ HẠN';
        }
        
        return '''
${result.toList().indexOf(row) + 1}. $urgency
   👤 ${data['borrower_name']} (${data['borrower_student_id']})
   📱 SĐT: ${data['borrower_phone'] ?? 'Chưa có'}
   📚 Sách: "${data['book_name']}"
   ⏰ Quá hạn: $daysOverdue ngày (Hạn trả: ${data['expected_return_date']})''';
      }).join('\n\n');

      return '''
⚠️ DANH SÁCH SÁCH QUÁ HẠN (${result.length} phiếu):

$overdueList

💡 GỢI Ý XỬ LÝ:
• Liên hệ ngay với các trường hợp quá hạn > 7 ngày
• Gửi email/SMS nhắc nhở
• Xem xét áp dụng phí phạt nếu cần
• Cập nhật trạng thái sau khi xử lý
''';
    } catch (e) {
      print('❌ Error in _getOverdueContext: $e');
      return 'Không thể lấy danh sách sách quá hạn. Lỗi: $e';
    }
  }

  Future<String> _getPopularBooksContext(Connection conn) async {
    try {
      final result = await conn.execute('''
        SELECT 
          b.title,
          b.author,
          b.category,
          COUNT(bc.id) as borrow_count
        FROM books b
        LEFT JOIN borrow_cards bc ON b.book_code = bc.book_code
        WHERE bc.borrow_date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY b.id, b.title, b.author, b.category
        HAVING COUNT(bc.id) > 0
        ORDER BY borrow_count DESC
        LIMIT 10
      ''');

      if (result.isEmpty) {
        return '''
📊 Chưa có dữ liệu về sách phổ biến trong 30 ngày qua.

Có thể do:
- Chưa có phiếu mượn nào trong 30 ngày qua
- Dữ liệu chưa được cập nhật

Hãy thử hỏi: "Tổng quan thư viện" để xem thống kê tổng thể.
''';
      }

      final bookList = result.map((row) {
        final data = row.toColumnMap();
        return '${result.toList().indexOf(row) + 1}. "${data['title']}" - ${data['author']}\n   📚 Thể loại: ${data['category']}\n   📊 Số lượt mượn: ${data['borrow_count']}';
      }).join('\n\n');

      return '''
📈 Top ${result.length} sách được mượn nhiều nhất (30 ngày qua):

$bookList

💡 Gợi ý: Các sách này rất được ưa chuộng, nên đảm bảo luôn có sẵn bản sao.
''';
    } catch (e) {
      print('❌ Error in _getPopularBooksContext: $e');
      return 'Không thể lấy thông tin sách phổ biến. Lỗi: $e';
    }
  }

  Future<String> _getReaderContext(Connection conn, String query) async {
    // Check if asking about previous context
    final queryLower = query.toLowerCase();
    String? studentId;
    
    if ((queryLower.contains('người đó') || queryLower.contains('bạn đó') || queryLower.contains('họ')) 
        && _lastStudentId != null) {
      studentId = _lastStudentId;
      print('🔍 Using student ID from previous question: $_lastStudentId');
    } else {
      // Extract student ID from query
      final studentIdMatch = RegExp(r'SV\d+', caseSensitive: false).firstMatch(query);
      if (studentIdMatch == null) {
        return 'Vui lòng cung cấp mã sinh viên (ví dụ: SV001)';
      }
      studentId = studentIdMatch.group(0)!.toUpperCase();
    }

    final result = await conn.execute(
      '''
      SELECT 
        r.name,
        r.student_id,
        r.class,
        r.email,
        COUNT(bc.id) as total_borrows,
        COUNT(CASE WHEN bc.status = 'borrowed' THEN 1 END) as current_borrows,
        COUNT(CASE WHEN bc.status = 'overdue' THEN 1 END) as overdue_borrows
      FROM readers r
      LEFT JOIN borrow_cards bc ON r.student_id = bc.borrower_student_id
      WHERE r.student_id = @studentId
      GROUP BY r.id, r.name, r.student_id, r.class, r.email
      ''',
      parameters: {'studentId': studentId},
    );

    if (result.isEmpty) {
      return 'Không tìm thấy độc giả với mã $studentId';
    }

    final data = result.first.toColumnMap();

    // Get current borrowed books
    final booksResult = await conn.execute(
      '''
      SELECT book_name, borrow_date, expected_return_date
      FROM borrow_cards
      WHERE borrower_student_id = @studentId
        AND status = 'borrowed'
      ORDER BY borrow_date DESC
      ''',
      parameters: {'studentId': studentId},
    );

    final booksList = booksResult.isEmpty
        ? 'Không có sách đang mượn'
        : booksResult.map((row) {
            final book = row.toColumnMap();
            return '  - "${book['book_name']}" (Mượn: ${book['borrow_date']}, Hạn trả: ${book['expected_return_date']})';
          }).join('\n');

    return '''
Thông tin độc giả $studentId:
- Họ tên: ${data['name']}
- Lớp: ${data['class']}
- Email: ${data['email']}
- Tổng số lần mượn: ${data['total_borrows']}
- Đang mượn: ${data['current_borrows']} cuốn
- Quá hạn: ${data['overdue_borrows']} phiếu

Sách đang mượn:
$booksList
''';
  }

  Future<String> _getBookContext(Connection conn, String query) async {
    try {
      // Extract book title from query - remove common words
      String searchTerm = query
          .replaceAll(RegExp(r'(là|sách|nào|book|tìm|search|có|gì|về|cho|tôi|mình)', caseSensitive: false), '')
          .trim()
          .replaceAll('"', '')
          .replaceAll("'", '');

      // Remove extra spaces
      searchTerm = searchTerm.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (searchTerm.isEmpty || searchTerm.length < 2) {
        return '''
🔍 Vui lòng cung cấp từ khóa tìm kiếm cụ thể hơn.

Ví dụ:
• "Tìm sách Lập trình"
• "Tìm sách Flutter"
• "Sách về Python"
• "Tìm sách Toán học"
''';
      }

      print('🔍 Searching books with term: "$searchTerm"');

      final result = await conn.execute(
        Sql.named('''
          SELECT 
            b.title,
            b.author,
            b.category,
            b.book_code,
            b.total_copies,
            b.available_copies,
            COUNT(bc.id) as total_borrows
          FROM books b
          LEFT JOIN borrow_cards bc ON b.book_code = bc.book_code
          WHERE b.title ILIKE @searchTerm 
             OR b.author ILIKE @searchTerm
             OR b.category ILIKE @searchTerm
          GROUP BY b.id, b.title, b.author, b.category, b.book_code, b.total_copies, b.available_copies
          ORDER BY b.available_copies DESC
          LIMIT 10
        '''),
        parameters: {'searchTerm': '%$searchTerm%'},
      );

      if (result.isEmpty) {
        return '''
❌ Không tìm thấy sách với từ khóa "$searchTerm"

💡 Gợi ý:
• Thử tìm với từ khóa khác
• Kiểm tra chính tả
• Tìm theo tên tác giả hoặc thể loại
• Hỏi: "Tổng quan thư viện" để xem tất cả sách
''';
      }

      final booksList = result.map((row) {
        final data = row.toColumnMap();
        final available = data['available_copies'] as int;
        final total = data['total_copies'] as int;
        final borrowed = total - available;
        
        String status;
        if (available == 0) {
          status = '🔴 Hết sách';
        } else if (available <= 2) {
          status = '🟡 Sắp hết ($available cuốn)';
        } else {
          status = '🟢 Còn nhiều ($available cuốn)';
        }
        
        return '''
${result.toList().indexOf(row) + 1}. 📚 "${data['title']}"
   ✍️ Tác giả: ${data['author']}
   📂 Thể loại: ${data['category']}
   🏷️ Mã sách: ${data['book_code']}
   📊 Tình trạng: $status
   📈 Tổng: $total cuốn | Đang mượn: $borrowed cuốn
   📖 Lượt mượn: ${data['total_borrows']} lần''';
      }).join('\n\n');

      return '''
🔍 Tìm thấy ${result.length} kết quả cho "$searchTerm":

$booksList

${result.length >= 10 ? '\n💡 Hiển thị 10 kết quả đầu tiên. Hãy tìm kiếm cụ thể hơn nếu cần.' : ''}
''';
    } catch (e) {
      print('❌ Error in _getBookContext: $e');
      return 'Không thể tìm kiếm sách. Lỗi: $e';
    }
  }
}
