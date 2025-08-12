import 'dart:convert';
import 'dart:html' as html show FileUploadInputElement, FileReader;
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class Product {
  final String? id;            // Firestore doc id
  final String code;           // 상품코드
  final String name;           // 제품명
  final String spec;           // 제품 스펙
  final String? supplier;      // 공급사
  final double? supplyPrice;   // 공급가액
  final double salePrice;      // 판매가액

  Product({
    this.id,
    required this.code,
    required this.name,
    required this.spec,
    this.supplier,
    this.supplyPrice,
    required this.salePrice,
  });

  Product copyWith({
    String? id,
    String? code,
    String? name,
    String? spec,
    String? supplier,
    double? supplyPrice,
    double? salePrice,
  }) => Product(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        spec: spec ?? this.spec,
        supplier: supplier ?? this.supplier,
        supplyPrice: supplyPrice ?? this.supplyPrice,
        salePrice: salePrice ?? this.salePrice,
      );

  factory Product.fromMap(Map<String, dynamic> m, {String? id}) => Product(
        id: id,
        code: (m['상품코드'] ?? m['code'] ?? '').toString(),
        name: (m['제품명'] ?? m['name'] ?? '').toString(),
        spec: (m['제품 스펙'] ?? m['spec'] ?? '').toString(),
        supplier: _toStrOrNull(m['공급사'] ?? m['supplier']),
        supplyPrice: _toDouble(m['공급가액'] ?? m['supplyPrice']),
        salePrice: _toDouble(m['판매가액'] ?? m['price']) ?? 0,
      );

  Map<String, dynamic> toMap() => {
        // 한글 키(원본 컬럼 유지)
        '상품코드': code,
        '제품명': name,
        '제품 스펙': spec,
        '공급사': supplier,
        '공급가액': supplyPrice,
        '판매가액': salePrice,
        // 영문 키(검색/정렬/호환)
        'code': code,
        'name': name,
        'spec': spec,
        'supplier': supplier,
        'supplyPrice': supplyPrice,
        'price': salePrice,
      };

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', ''));
  }

  static String? _toStrOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // ---------- UI state ----------
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = false;

  // 페이지네이션
  int _pageSize = 20;
  DocumentSnapshot? _lastDoc; // next의 커서
  final List<DocumentSnapshot?> _cursors = []; // prev를 위해 커서 스택
  bool _hasNext = true;
  bool _hasPrev = false;

  // 현재 페이지의 문서들
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  // ---------- Helpers (ID/Excel/Parse) ----------
  String _sanitizeId(String input) => input
      .replaceAll('/', '_')
      .replaceAll('.', '_')
      .replaceAll('#', '_')
      .replaceAll(r'$', '_')
      .replaceAll('[', '_')
      .replaceAll(']', '_')
      .trim();

  String _truncateUtf8(String s, int maxBytes) {
    final bytes = utf8.encode(s);
    if (bytes.length <= maxBytes) return s;
    int end = maxBytes;
    while (end > 0) {
      try {
        return utf8.decode(bytes.sublist(0, end));
      } catch (_) {
        end--;
      }
    }
    return '';
  }

  String _safeIdFromName(String name, {int maxBytes = 200}) {
    final cleaned = _sanitizeId(name);
    if (cleaned.isEmpty) return cleaned;
    final len = utf8.encode(cleaned).length;
    if (len <= maxBytes) return cleaned;
    final hash = sha1.convert(utf8.encode(cleaned)).toString().substring(0, 8);
    final room = maxBytes - utf8.encode('-$hash').length;
    final base = _truncateUtf8(cleaned, room);
    return '$base-$hash';
  }

  String? _asStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().replaceAll(',', '').trim();
    if (s.isEmpty) return null;
    final d = double.tryParse(s);
    if (d != null) return d.round();
    return int.tryParse(s);
  }

  // ---------- Firestore Query ----------
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('products');

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _cursors.clear();
      _lastDoc = null;
      _hasPrev = false;
    });

    try {
      final q = _buildQuery();
      final snap = await q.limit(_pageSize).get();
      _docs = snap.docs;
      _hasNext = _docs.length == _pageSize;
      _lastDoc = _docs.isEmpty ? null : _docs.last;
      setState(() {});
    } catch (e) {
      _showSnack('불러오기 실패: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (!_hasNext || _lastDoc == null) return;
    setState(() => _loading = true);
    try {
      _cursors.add(_lastDoc); // prev를 위한 커서 push
      final q = _buildQuery().startAfterDocument(_lastDoc!);
      final snap = await q.limit(_pageSize).get();
      _docs = snap.docs;
      _hasNext = _docs.length == _pageSize;
      _lastDoc = _docs.isEmpty ? null : _docs.last;
      _hasPrev = _cursors.isNotEmpty;
      setState(() {});
    } catch (e) {
      _showSnack('다음 페이지 실패: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPrevPage() async {
    if (!_hasPrev) return;
    setState(() => _loading = true);
    try {
      // 현재 페이지의 첫 문서를 기준으로 이전 페이지를 읽으려면
      // Firestore는 별도 역방향 쿼리가 필요하지만,
      // 여기서는 커서를 스택으로 저장해 앞선 페이지의 "마지막 문서"를 재사용합니다.
      final backCursor = _cursors.isNotEmpty ? _cursors.removeLast() : null;
      final q = _buildQuery();
      QuerySnapshot<Map<String, dynamic>> snap;
      if (backCursor == null) {
        snap = await q.limit(_pageSize).get();
      } else {
        snap = await q.startAtDocument(backCursor).limit(_pageSize).get();
      }
      _docs = snap.docs;
      _hasNext = _docs.length == _pageSize;
      _lastDoc = _docs.isEmpty ? null : _docs.last;
      _hasPrev = _cursors.isNotEmpty;
      setState(() {});
    } catch (e) {
      _showSnack('이전 페이지 실패: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // 제품명(prefix) 검색 지원
  Query<Map<String, dynamic>> _buildQuery() {
    final text = _searchCtrl.text.trim();
    if (text.isEmpty) {
      return _col.orderBy('제품명'); // 기본 정렬
    } else {
      // Firestore prefix 검색 패턴: >= text AND < text+\uf8ff (orderBy 동일필드 필요)
      final endText = '$text\uf8ff';
      return _col
          .orderBy('제품명')
          .where('제품명', isGreaterThanOrEqualTo: text)
          .where('제품명', isLessThanOrEqualTo: endText);
    }
  }

  // ---------- Excel 업서트(Web) ----------
  Future<void> _pickAndUpsertExcel() async {
    final input = html.FileUploadInputElement()..accept = '.xlsx';
    input.click();
    await input.onChange.first;
    final file = input.files?.first;
    if (file == null) return;

    setState(() => _loading = true);
    try {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final bytes = reader.result as List<int>;
      final book = excel_pkg.Excel.decodeBytes(bytes);
      if (book.tables.isEmpty) throw '시트를 찾을 수 없습니다.';

      // 가장 데이터 많은 시트
      final tables = book.tables.values.toList()
        ..sort(
            (a, b) => (b.maxRows * b.maxCols).compareTo(a.maxRows * a.maxCols));
      final sheet = tables.first;

      // 헤더 탐지
      String? strCell(int c, int r) {
        final v = sheet
            .cell(excel_pkg.CellIndex.indexByColumnRow(
                columnIndex: c, rowIndex: r))
            .value;
        final s = v?.toString().trim();
        return (s == null || s.isEmpty) ? null : s;
      }

      String norm(String s) => s
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^0-9a-zA-Z가-힣]'), '')
          .toLowerCase();

      final alias = <String, Set<String>>{
        '상품코드': {'상품코드', '제품코드', 'sku', 'code', 'productcode', '상품id', '상품아이디'}
            .map(norm)
            .toSet(),
        '상품명': {
          '상품명',
          '제품명',
          '품명',
          'name',
          'productname',
          '상품명국문',
          '국문상품명',
          '상품명한글',
          '한글상품명'
        }.map(norm).toSet(),
        '제품 스펙': {
          '제품스펙',
          '제품 스펙',
          '스펙',
          '사양',
          '규격',
          'spec',
          '상품간략설명',
          '상품 간략설명',
          '간략설명',
          '상품설명',
          '설명'
        }.map(norm).toSet(),
        '판매가액': {'판매가액', '판매가', '가격', 'price', 'saleprice', '정가', '소비자가'}
            .map(norm)
            .toSet(),
      };

      int headerRow = 0, bestHits = -1;
      for (int r = 0; r < sheet.maxRows && r < 5; r++) {
        int hits = 0;
        for (int c = 0; c < sheet.maxCols; c++) {
          final h = strCell(c, r);
          if (h == null) continue;
          final n = norm(h);
          if (alias.values.any((set) => set.contains(n))) hits++;
        }
        if (hits > bestHits) {
          bestHits = hits;
          headerRow = r;
        }
      }

      int? colCode, colName, colSpec, colSale;
      for (int c = 0; c < sheet.maxCols; c++) {
        final h = strCell(c, headerRow);
        if (h == null) continue;
        final n = norm(h);
        if (alias['상품코드']!.contains(n)) colCode = c;
        if (alias['상품명']!.contains(n)) colName = c; // ← 문서ID = 상품명
        if (alias['제품 스펙']!.contains(n)) colSpec = c;
        if (alias['판매가액']!.contains(n)) colSale = c;
      }

      // 데이터 시작 행
      int dataStart = headerRow + 1;
      bool rowHasAny(int r) {
        final vals = <String?>[
          if (colName != null) strCell(colName, r),
          if (colCode != null) strCell(colCode, r),
          if (colSale != null) strCell(colSale, r),
          if (colSpec != null) strCell(colSpec, r),
        ];
        return vals.any((e) => e != null && e.isNotEmpty);
      }

      while (dataStart < sheet.maxRows && !rowHasAny(dataStart)) {
        dataStart++;
      }

      // 수집
      final rows = <Map<String, dynamic>>[];
      for (int r = dataStart; r < sheet.maxRows; r++) {
        final name = colName != null ? strCell(colName, r) : null;
        if (name == null || name.isEmpty) continue; // 이름 없으면 skip

        final code = colCode != null ? strCell(colCode, r) : null;
        final spec = colSpec != null ? strCell(colSpec, r) : null;
        final sale = colSale != null ? _asInt(strCell(colSale, r)) : null;

        final id = _safeIdFromName(name);
        if (id.isEmpty) continue;

        rows.add({
          'id': id,
          '상품코드': code,
          '제품명': name,
          '제품 스펙': spec,
          '공급사': null,
          '공급가액': null,
          '판매가액': sale,
          'name': name,
          'price': sale,
        });
      }

      // 업서트(400개 청크)
      const chunkSize = 400;
      for (int i = 0; i < rows.length; i += chunkSize) {
        final chunk = rows.sublist(
            i, (i + chunkSize < rows.length) ? i + chunkSize : rows.length);
        final batch = FirebaseFirestore.instance.batch();
        for (final row in chunk) {
          final ref = _col.doc(row['id'] as String);
          batch.set(
              ref,
              {
                '상품코드': row['상품코드'],
                '제품명': row['제품명'],
                '제품 스펙': row['제품 스펙'],
                '공급사': row['공급사'],
                '공급가액': row['공급가액'],
                '판매가액': row['판매가액'],
                'name': row['name'],
                'price': row['price'],
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }
        await batch.commit();
      }

      _showSnack('엑셀 업로드 완료: ${rows.length}건(업서트)');
      await _loadFirstPage();
    } catch (e) {
      _showSnack('엑셀 처리 실패: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('제품 관리')),
      body: Column(
        children: [
          _buildToolbar(),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _docs.isEmpty
                    ? const Center(child: Text('데이터가 없습니다.'))
                    : _buildTable(),
          ),
          _buildPager(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // 검색: 제품명 prefix
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '제품명(상품명)으로 검색',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loadFirstPage,
                ),
              ),
              onSubmitted: (_) => _loadFirstPage(),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _pageSize,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _pageSize = v);
              _loadFirstPage();
            },
            items: const [10, 20, 50, 100]
                .map((e) => DropdownMenuItem(value: e, child: Text('페이지당 $e')))
                .toList(),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _pickAndUpsertExcel,
            icon: const Icon(Icons.upload_file),
            label: const Text('엑셀 업로드(업서트)'),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    // 테이블 헤더
    final header = Container(
      color: const Color(0xFFF7F7FB),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: const Row(
        children: [
          _TH('상품코드', 140),
          _TH('제품명', 220),
          _TH('제품 스펙', 260),
          _TH('공급사', 120),
          _TH('공급가액', 120),
          _TH('판매가액', 120),
          _TH('updatedAt', 180),
        ],
      ),
    );

    // row들
    final rows = _docs.map((d) {
      final m = d.data();
      String money(num? v) => v == null ? '-' : '₩${_formatInt(v)}';
      final ts = m['updatedAt'];
      String tsStr = '-';
      if (ts is Timestamp) {
        final dt = ts.toDate();
        tsStr =
            '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
      }
      return Container(
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE6E6E6)))),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            _TD(m['상품코드'], 140),
            _TD(m['제품명'], 220, isBold: true),
            _TD(m['제품 스펙'], 260),
            _TD(m['공급사'], 120),
            _TD(money(m['공급가액']), 120),
            _TD(money(m['판매가액']), 120),
            _TD(tsStr, 180),
          ],
        ),
      );
    }).toList();

    return SingleChildScrollView(
      child: Column(children: [header, ...rows]),
    );
  }

  Widget _buildPager() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
              '총 ${_docs.length}건 / 페이지 ${_hasPrev ? '(이전 있음)' : ''} ${_hasNext ? '(다음 있음)' : ''}'),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _hasPrev ? _loadPrevPage : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('이전'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _hasNext ? _loadNextPage : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('다음'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _formatInt(num v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && idx % 3 == 1) buf.write(',');
    }
    // 위 방식은 간단 예시용. 실제는 NumberFormat 써도 됩니다.
    return buf.toString();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _TH extends StatelessWidget {
  final String label;
  final double width;
  const _TH(this.label, this.width);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _TD extends StatelessWidget {
  final String text;
  final double width;
  final bool isBold;
  _TD(dynamic value, this.width, {this.isBold = false})
      : text = (value == null || value.toString().isEmpty)
            ? '-'
            : value.toString();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style:
            TextStyle(fontWeight: isBold ? FontWeight.w600 : FontWeight.w400),
      ),
    );
  }
}
