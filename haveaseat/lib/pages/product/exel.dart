// FILE: lib/product_excel_page.dart
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/pages/product/repo.dart';
import 'package:haveaseat/riverpod/product.dart';

class ProductExcelPage extends StatefulWidget {
  const ProductExcelPage({super.key});

  @override
  State<ProductExcelPage> createState() => _ProductExcelPageState();
}

class _ProductExcelPageState extends State<ProductExcelPage> {
  final _repo = ProductRepository();

  bool _loading = false;

  // 검색 & 목록
  final _searchCtrl = TextEditingController();
  String _searchText = ''; // IME 조합 문제 방지: 조합 종료 시에만 갱신
  List<Product> _all = [];

  // 페이지네이션 상태
  int _rowsPerPage = 20;
  int _currentPage = 0;

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
                Text('총 $filteredCount건'),
                const Spacer(),
                const Text('페이지당'),
                const SizedBox(width: 8),
                DropdownButton<int>(
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
                    : ListView.separated(
                        itemCount: _paged.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final p = _paged[i];
                          return ListTile(
                            title: Text('${p.name} (${p.code})'),
                            subtitle: Text(
                              '공급사: ${p.supplier ?? '-'} · 공급가: ${p.supplyPrice?.toStringAsFixed(0) ?? '-'} · 판매가: ${p.salePrice.toStringAsFixed(0)}',
                            ),
                            trailing: IconButton(
                              icon:
                                  const Icon(Icons.edit, color: AppColor.main),
                              onPressed: () => _editProduct(p),
                            ),
                          );
                        },
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
    return AlertDialog(
      backgroundColor: Colors.white, // 흰색 바탕
      title: Text(
        widget.initial == null ? '제품 추가' : '제품 수정',
        style:
            const TextStyle(color: AppColor.main, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: '상품코드')),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '제품명')),
              TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(labelText: '제품 스펙')),
              TextField(
                  controller: supplierCtrl,
                  decoration: const InputDecoration(labelText: '공급사')),
              TextField(
                controller: supplyPriceCtrl,
                decoration: const InputDecoration(labelText: '공급가액'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: salePriceCtrl,
                decoration: const InputDecoration(labelText: '판매가액'),
                keyboardType: TextInputType.number,
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
              supplyPrice: _toDouble(supplyPriceCtrl.text),
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
}

// 공용 파서
double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', ''));
}
