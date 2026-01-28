// FILE: lib/product_excel_page.dart
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/pages/product/repo.dart';
import 'package:haveaseat/riverpod/product.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductExcelPage extends StatefulWidget {
  const ProductExcelPage({super.key});

  @override
  State<ProductExcelPage> createState() => _ProductExcelPageState();
}

class _ProductExcelPageState extends State<ProductExcelPage> {
  final _repo = ProductRepository();

  bool _loading = false;
// 파일 상단 import는 이미 있음: import 'package:intl/intl.dart';

  final _moneyFmt = NumberFormat.decimalPattern('ko_KR');
  String _fmtMoney(num? v) => v == null ? '-' : _moneyFmt.format(v);
  // 검색 & 목록
  final _searchCtrl = TextEditingController();
  String _searchText = ''; // IME 조합 문제 방지: 조합 종료 시에만 갱신
  List<Product> _all = [];

  // 페이지네이션 상태
  int _rowsPerPage = 20;
  int _currentPage = 0;

  // 선택 삭제 기능
  Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadAll();

    // 한글 IME 조합 중에는 검색어를 갱신하지 않기
    _searchCtrl.addListener(() {
      final v = _searchCtrl.value;
      final composing = v.composing;
      final composingActive = composing.isValid && !composing.isCollapsed;
      if (!composingActive) {
        setState(() {
          _searchText = v.text;
          _currentPage = 0;
        });
      }
    });
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      _all = await _repo.fetchAll();
      if (mounted) setState(() {});
    } catch (e) {
      _snack('목록 불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggleSelectAll(List<Product> paged) {
    setState(() {
      if (_selectedIds.length == paged.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = paged
            .where((p) => p.id != null && p.id!.isNotEmpty)
            .map((p) => p.id!)
            .toSet();
      }
    });
  }

  void _toggleSelectItem(String? id) {
    if (id == null || id.isEmpty) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(
            '선택한 ${_selectedIds.length}개의 제품을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _loading = true);
      try {
        final count = _selectedIds.length;
        final batch = FirebaseFirestore.instance.batch();
        for (final id in _selectedIds) {
          batch.delete(
              FirebaseFirestore.instance.collection('products').doc(id));
        }
        await batch.commit();

        if (mounted) {
          setState(() {
            _selectedIds.clear();
          });
          await _loadAll();
          _snack('$count개의 제품이 삭제되었습니다.');
        }
      } catch (e) {
        if (mounted) {
          _snack('삭제 중 오류가 발생했습니다: $e');
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _editProduct(Product p) async {
    final updated = await showDialog<Product?>(
      context: context,
      builder: (_) => _ProductEditDialog(initial: p),
    );
    if (updated == null) return;
    setState(() => _loading = true);
    try {
      await _repo.updateOne(updated);
      await _loadAll();
      _snack('수정 완료');
    } catch (e) {
      _snack('수정 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addProduct() async {
    final created = await showDialog<Product?>(
      context: context,
      builder: (_) => const _ProductEditDialog(),
    );
    if (created == null) return;
    setState(() => _loading = true);
    try {
      await _repo.upsertMany([created]);
      await _loadAll();
      _snack('추가 완료');
    } catch (e) {
      _snack('추가 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Product> get _filtered {
    final q = _searchText.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((p) {
      bool hit(String? s) => (s ?? '').toLowerCase().contains(q);
      return hit(p.name) ||
          hit(p.code) ||
          hit(p.spec) ||
          hit(p.supplier) ||
          hit(p.id);
    }).toList();
  }

  List<Product> get _paged {
    final f = _filtered;
    final start = _currentPage * _rowsPerPage;
    if (start >= f.length) return [];
    final end =
        (start + _rowsPerPage > f.length) ? f.length : start + _rowsPerPage;
    return f.sublist(start, end);
  }

  int get _totalPages {
    final f = _filtered.length;
    if (f == 0) return 1;
    return ((f - 1) ~/ _rowsPerPage) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final filteredCount = _filtered.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('제품 관리'),
        backgroundColor: AppColor.main,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _deleteSelected,
              style: TextButton.styleFrom(foregroundColor: Colors.red[200]),
              child: Text('삭제 (${_selectedIds.length})'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addProduct,
        label: const Text('추가'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColor.main,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              cursorColor: AppColor.main,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: AppColor.main),
                hintText: '제품명/코드/스펙/공급사/ID 검색',
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          // listener에서 _searchText 갱신됨
                        },
                        icon: const Icon(Icons.clear, color: AppColor.main),
                      ),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: AppColor.main.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      const BorderSide(color: AppColor.main, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const Divider(height: 1),

          // 페이지네이션 컨트롤
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('총 ${_moneyFmt.format(filteredCount)}건'),
                const Spacer(),
                const Text('페이지당'),
                const SizedBox(width: 8),
                Theme(
                  data: Theme.of(context).copyWith(
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: DropdownButton<int>(
                    value: _rowsPerPage,
                    underline: const SizedBox.shrink(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _rowsPerPage = v;
                        _currentPage = 0;
                      });
                    },
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 20, child: Text('20')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                      DropdownMenuItem(value: 100, child: Text('100')),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: '처음',
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage = 0)
                      : null,
                  icon: Icon(Icons.first_page,
                      color: _currentPage > 0 ? AppColor.main : null),
                ),
                IconButton(
                  tooltip: '이전',
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage -= 1)
                      : null,
                  icon: Icon(Icons.navigate_before,
                      color: _currentPage > 0 ? AppColor.main : null),
                ),
                Text('${_currentPage + 1} / $_totalPages'),
                IconButton(
                  tooltip: '다음',
                  onPressed: (_currentPage + 1) < _totalPages
                      ? () => setState(() => _currentPage += 1)
                      : null,
                  icon: Icon(Icons.navigate_next,
                      color: (_currentPage + 1) < _totalPages
                          ? AppColor.main
                          : null),
                ),
                IconButton(
                  tooltip: '마지막',
                  onPressed: (_currentPage + 1) < _totalPages
                      ? () => setState(() => _currentPage = _totalPages - 1)
                      : null,
                  icon: Icon(Icons.last_page,
                      color: (_currentPage + 1) < _totalPages
                          ? AppColor.main
                          : null),
                ),
                if (_selectedIds.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete, size: 18),
                    label: Text('삭제 (${_selectedIds.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // 목록
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _paged.isEmpty
                    ? const _Empty()
                    : Column(
                        children: [
                          Builder(
                            builder: (context) {
                              final selectableCount = _paged
                                  .where(
                                      (p) => p.id != null && p.id!.isNotEmpty)
                                  .length;
                              final allSelected = selectableCount > 0 &&
                                  _selectedIds.length == selectableCount;
                              return Container(
                                color: AppColor.main.withOpacity(0.1),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: allSelected,
                                      tristate: false,
                                      onChanged: selectableCount > 0
                                          ? (_) => _toggleSelectAll(_paged)
                                          : null,
                                    ),
                                    Text(
                                      _selectedIds.isEmpty
                                          ? '전체 선택'
                                          : '${_selectedIds.length}개 선택됨',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _paged.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final p = _paged[i];
                                final isSelected =
                                    p.id != null && _selectedIds.contains(p.id);
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor:
                                      AppColor.main.withOpacity(0.1),
                                  title: Text('${p.name} (${p.code})'),
                                  subtitle: Text(
                                    '공급사: ${p.supplier ?? '-'} · 공급가: ${_fmtMoney(p.supplyPrice)}원 · 판매가: ${_fmtMoney(p.salePrice)}원',
                                  ),
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: p.id != null && p.id!.isNotEmpty
                                        ? (_) => _toggleSelectItem(p.id)
                                        : null,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: AppColor.main),
                                        onPressed: () => _editProduct(p),
                                      ),
                                    ],
                                  ),
                                  onTap: p.id != null && p.id!.isNotEmpty
                                      ? () => _toggleSelectItem(p.id)
                                      : null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox, size: 40),
          SizedBox(height: 8),
          Text('데이터가 없습니다'),
        ],
      ),
    );
  }
}

class _ProductEditDialog extends StatefulWidget {
  final Product? initial;
  const _ProductEditDialog({this.initial});

  @override
  State<_ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<_ProductEditDialog> {
  late final TextEditingController codeCtrl;
  late final TextEditingController nameCtrl;
  late final TextEditingController specCtrl;
  late final TextEditingController supplierCtrl;
  late final TextEditingController supplyPriceCtrl;
  late final TextEditingController salePriceCtrl;

  @override
  @override
  void initState() {
    super.initState();
    codeCtrl = TextEditingController(text: widget.initial?.code ?? '');
    nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    specCtrl = TextEditingController(text: widget.initial?.spec ?? '');
    supplierCtrl = TextEditingController(text: widget.initial?.supplier ?? '');
    supplyPriceCtrl = TextEditingController(
        text: widget.initial?.supplyPrice?.toString() ?? '');
    salePriceCtrl = TextEditingController(
        text: widget.initial?.salePrice.toString() ?? '0');

    // 초기 표시도 12,345 형태로
    supplyPriceCtrl.text = _fmtNum(supplyPriceCtrl.text);
    salePriceCtrl.text = _fmtNum(salePriceCtrl.text);
  }

  @override
  void dispose() {
    codeCtrl.dispose();
    nameCtrl.dispose();
    specCtrl.dispose();
    supplierCtrl.dispose();
    supplyPriceCtrl.dispose();
    salePriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String label) => InputDecoration(
          labelText: label,
          isDense: false,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColor.main.withOpacity(0.25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColor.main, width: 1.5),
          ),
        );

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent, // ← 연핑크/틴트 제거
      title: Text(
        widget.initial == null ? '제품 추가' : '제품 수정',
        style:
            const TextStyle(color: AppColor.main, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 480, // 살짝 넓게
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                textAlignVertical: TextAlignVertical.center,
                decoration: dec('상품코드'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                textAlignVertical: TextAlignVertical.center,
                decoration: dec('제품명'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: specCtrl,
                textAlignVertical: TextAlignVertical.center,
                decoration: dec('제품 스펙'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: supplierCtrl,
                textAlignVertical: TextAlignVertical.center,
                decoration: dec('공급사'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: supplyPriceCtrl,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: dec('공급가액'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salePriceCtrl,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: dec('판매가액'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppColor.main),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final p = Product(
              id: widget.initial?.id,
              code: codeCtrl.text.trim(),
              name: nameCtrl.text.trim(),
              spec: specCtrl.text.trim().isEmpty ? '' : specCtrl.text.trim(),
              supplier: supplierCtrl.text.trim().isEmpty
                  ? null
                  : supplierCtrl.text.trim(),
              supplyPrice: _toDouble(supplyPriceCtrl.text), // 콤마 제거 파서 그대로 OK
              salePrice: _toDouble(salePriceCtrl.text) ?? 0,
            );
            Navigator.pop(context, p);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColor.main,
            foregroundColor: Colors.white,
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }

// 공용 파서
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', ''));
  }

  String _fmtNum(String? raw) {
    final s = (raw ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return '';
    return NumberFormat.decimalPattern().format(int.parse(s));
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _f = NumberFormat.decimalPattern();
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = _f.format(int.parse(digits));
    // 커서를 끝으로 (간단/안전한 방식)
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
