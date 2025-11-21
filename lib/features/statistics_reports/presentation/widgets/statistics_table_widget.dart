import 'package:flutter/material.dart';

class StatisticsTableWidget extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final Function(int)? onRowTap;
  final bool showIndex;

  const StatisticsTableWidget({
    super.key,
    required this.headers,
    required this.rows,
    this.onRowTap,
    this.showIndex = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          if (rows.isEmpty)
            _buildEmptyState()
          else
            _buildRows(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final displayHeaders = showIndex ? ['#', ...headers] : headers;
    
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: displayHeaders.asMap().entries.map((entry) {
          final index = entry.key;
          final header = entry.value;
          
          return Expanded(
            flex: _getColumnFlex(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Text(
                header,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRows() {
    return Column(
      children: rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        
        return _buildRow(index, row);
      }).toList(),
    );
  }

  Widget _buildRow(int index, List<String> row) {
    final displayRow = showIndex ? ['${index + 1}', ...row] : row;
    final isEven = index % 2 == 0;
    
    return InkWell(
      onTap: onRowTap != null ? () => onRowTap!(index) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isEven ? Colors.grey.withOpacity(0.05) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: displayRow.asMap().entries.map((entry) {
            final colIndex = entry.key;
            final cell = entry.value;
            
            return Expanded(
              flex: _getColumnFlex(colIndex),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Text(
                  cell,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getCellColor(colIndex, cell),
                    fontWeight: _getCellFontWeight(colIndex),
                  ),
                  textAlign: _getCellAlignment(colIndex),
                  maxLines: null,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.table_chart_outlined,
            size: 48,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Không có dữ liệu để hiển thị',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  int _getColumnFlex(int columnIndex) {
    if (showIndex && columnIndex == 0) return 1; // Index column
    
    final actualIndex = showIndex ? columnIndex - 1 : columnIndex;
    
    // Customize flex based on content type
    if (headers.length > actualIndex) {
      final header = headers[actualIndex].toLowerCase();
      
      if (header.contains('tên') || header.contains('sách')) {
        return 4; // Much wider for names to show full text
      } else if (header.contains('ngày') || header.contains('tháng')) {
        return 2; // Medium for dates
      } else {
        return 1; // Narrow for numbers
      }
    }
    
    return 1;
  }

  Color _getCellColor(int columnIndex, String cellValue) {
    // Color coding for specific values
    if (cellValue.toLowerCase().contains('quá hạn') || 
        (columnIndex > 0 && _isNumericColumn(columnIndex) && 
         headers.length > (showIndex ? columnIndex - 1 : columnIndex) &&
         headers[showIndex ? columnIndex - 1 : columnIndex].toLowerCase().contains('quá hạn') &&
         int.tryParse(cellValue) != null && int.parse(cellValue) > 0)) {
      return const Color(0xFFE53E3E); // Red for overdue
    }
    
    if (cellValue.toLowerCase().contains('đã trả') ||
        (columnIndex > 0 && _isNumericColumn(columnIndex) && 
         headers.length > (showIndex ? columnIndex - 1 : columnIndex) &&
         headers[showIndex ? columnIndex - 1 : columnIndex].toLowerCase().contains('trả'))) {
      return const Color(0xFF38A169); // Green for returned
    }
    
    return const Color(0xFF2D3748); // Default dark gray
  }

  FontWeight _getCellFontWeight(int columnIndex) {
    if (showIndex && columnIndex == 0) return FontWeight.bold; // Index
    
    final actualIndex = showIndex ? columnIndex - 1 : columnIndex;
    if (headers.length > actualIndex && headers[actualIndex].toLowerCase().contains('tên')) {
      return FontWeight.w600; // Bold for names
    }
    
    return FontWeight.normal;
  }

  TextAlign _getCellAlignment(int columnIndex) {
    if (showIndex && columnIndex == 0) return TextAlign.center; // Index
    
    final actualIndex = showIndex ? columnIndex - 1 : columnIndex;
    if (headers.length > actualIndex) {
      final header = headers[actualIndex].toLowerCase();
      if (header.contains('tên') || header.contains('sách')) {
        return TextAlign.left; // Left align for text
      }
    }
    
    return TextAlign.center; // Center align for numbers and dates
  }

  bool _isNumericColumn(int columnIndex) {
    final actualIndex = showIndex ? columnIndex - 1 : columnIndex;
    if (headers.length > actualIndex) {
      final header = headers[actualIndex].toLowerCase();
      return header.contains('số') || 
             header.contains('tổng') || 
             header.contains('mượn') ||
             header.contains('trả') ||
             header.contains('hạn');
    }
    return false;
  }
}