import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Firestore 제품 모델(하드코딩/리버팟 provider 대체)
class ProductRef {
  final String id;
  final String name;
  final int price;
  ProductRef({required this.id, required this.name, required this.price});

  factory ProductRef.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final name = (data['name'] ?? '').toString();
    final priceVal = data['price'];
    int price;
    if (priceVal is int) {
      price = priceVal;
    } else if (priceVal is double) {
      price = priceVal.round();
    } else if (priceVal is String) {
      price = int.tryParse(priceVal.replaceAll(',', '')) ?? 0;
    } else {
      price = 0;
    }
    return ProductRef(id: doc.id, name: name, price: price);
  }
}

enum FurnitureProductType { imported, custom } // 수입/제작

class furniturePage extends ConsumerStatefulWidget {
  final String customerId;
  final String? estimateId;
  final String? name; // 회사명(고객명) 변수명 통일
  const furniturePage({
    super.key,
    required this.customerId,
    this.estimateId,
    this.name,
  });

  @override
  ConsumerState<furniturePage> createState() => _furniturePageState();
}

class FurnitureRow {
  FurnitureProductType productType; // 제품종류 (수입/제작)
  final TextEditingController nameController; // 상품명
  final TextEditingController specificationController; // 규격
  final TextEditingController quantityController; // 수량
  final TextEditingController priceController; // 단가
  List<ProductRef> filteredProducts; // 수입상품 검색용

  FurnitureRow({FurnitureProductType? productType})
      : productType = productType ?? FurnitureProductType.imported,
        nameController = TextEditingController(),
        specificationController = TextEditingController(),
        quantityController = TextEditingController(),
        priceController = TextEditingController(),
        filteredProducts = [];

  void dispose() {
    nameController.dispose();
    specificationController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}

class _furniturePageState extends ConsumerState<furniturePage> {
  // 통합된 가구 행 리스트
  final List<FurnitureRow> _furnitureRows = [];

  // 현재 검색 리스트가 표시되는 행 인덱스
  int? _activeSearchRowIndex;

  // ===== Firestore 검색 =====
  Future<List<ProductRef>> _searchProductsFS(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final qLower = q.toLowerCase();

      // 1) prefix 검색 (성능 우선)
      final pref = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('name')
          .startAt([q])
          .endAt(['$q\\uf8ff'])
          .limit(50)
          .get();
      final prefixHits = pref.docs.map((d) => ProductRef.fromDoc(d)).toList();

      // 2) 부분 포함(contains) 보강: 상위 N개 스캔 후 클라 필터
      final scan = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('name')
          .limit(500) // 데이터가 매우 많다면 줄이세요
          .get();
      final containsHits = scan.docs
          .map((d) => ProductRef.fromDoc(d))
          .where((p) => p.name.toLowerCase().contains(qLower))
          .toList();

      // 3) 통합 + 중복 제거
      final Map<String, ProductRef> map = {
        for (final p in prefixHits) p.id: p,
        for (final p in containsHits) p.id: p,
      };
      final merged = map.values.toList();

      // 4) 간단 정렬: 포함여부 > 이름길이
      merged.sort((a, b) {
        final aC = a.name.toLowerCase().contains(qLower) ? 1 : 0;
        final bC = b.name.toLowerCase().contains(qLower) ? 1 : 0;
        if (aC != bC) return bC - aC;
        return a.name.length.compareTo(b.name.length);
      });

      return merged.take(50).toList();
    } catch (e) {
      debugPrint('searchProductsFS error: $e');
      return [];
    }
  }

  Future<ProductRef?> _getProductByName(String name) async {
    final q = name.trim();
    if (q.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: q)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return ProductRef.fromDoc(snap.docs.first);
    } catch (e) {
      debugPrint('getProductByName error: $e');
      return null;
    }
  }

  // 임시 저장
  Future<void> _saveTempFurniture() async {
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) throw Exception('로그인이 필요합니다');

      final userData = await UserProvider.getUserData(user.uid);
      final managerName = userData?['name'] ?? user.displayName ?? '담당자 미정';
      final managerPhone = userData?['phoneNumber'] ?? user.phoneNumber ?? '';

      String estimateId = widget.estimateId ?? '';
      if (estimateId.isEmpty) {
        final existingEstimate = await FirebaseFirestore.instance
            .collection('estimates')
            .where('customerId', isEqualTo: widget.customerId)
            .where('isDraft', isEqualTo: true)
            .limit(1)
            .get();

        if (existingEstimate.docs.isNotEmpty) {
          estimateId = existingEstimate.docs.first.id;
        } else {
          final estimateRef =
              FirebaseFirestore.instance.collection('estimates').doc();
          estimateId = estimateRef.id;
        }
      }

      String? nameValue = widget.name;
      if (nameValue == null || nameValue.trim().isEmpty) {
        if (estimateId.isNotEmpty) {
          try {
            final existingDoc = await FirebaseFirestore.instance
                .collection('estimates')
                .doc(estimateId)
                .get();
            if (existingDoc.exists) {
              nameValue = existingDoc.data()?['name']?.toString().trim();
            }
          } catch (e) {
            print('기존 estimate 조회 실패: $e');
          }
        }

        if (nameValue == null || nameValue.trim().isEmpty) {
          try {
            final customerDoc = await FirebaseFirestore.instance
                .collection('customers')
                .doc(widget.customerId)
                .get();
            if (customerDoc.exists) {
              final customerData = customerDoc.data()!;
              nameValue = customerData['name']?.toString().trim() ??
                  customerData['directDomain']?.toString().trim() ??
                  '무제';
            } else {
              nameValue = '무제';
            }
          } catch (e) {
            nameValue = '무제';
          }
        }
      }

      // furnitureList 생성
      List<Map<String, dynamic>> furnitureList = [];
      for (var row in _furnitureRows) {
        if (row.nameController.text.trim().isEmpty) continue;

        final quantity = int.tryParse(row.quantityController.text);
        final price = int.tryParse(row.priceController.text);

        if (quantity == null || price == null) continue;

        furnitureList.add({
          'name': row.nameController.text.trim(),
          'specification': row.specificationController.text.trim(),
          'quantity': quantity,
          'price': price,
          'isCustom': row.productType == FurnitureProductType.custom,
          'productType':
              row.productType == FurnitureProductType.custom ? '제작' : '수입',
        });
      }

      final estimateRef =
          FirebaseFirestore.instance.collection('estimates').doc(estimateId);
      final tempData = {
        'customerId': widget.customerId,
        'estimateId': estimateId,
        'status': 'IN_PROGRESS',
        'lastUpdated': FieldValue.serverTimestamp(),
        'isDraft': true,
        'type': '가구',
        'name': nameValue,
        'managerName': managerName,
        'managerPhone': managerPhone,
        'furnitureList': furnitureList,
        'customerInfo': {
          'name': nameValue,
          'assignedTo': user.uid,
          'managerName': managerName,
          'managerPhone': managerPhone,
        },
      };

      await estimateRef.set(tempData, SetOptions(merge: true));
      await estimateRef.update({'name': nameValue});
      await estimateRef.update({'customerInfo.name': nameValue});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('임시저장이 완료되었습니다.'),
            backgroundColor: AppColor.main,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('임시 저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      context.go('/login'); // 로그인 페이지로 이동
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다')),
        );
      }
    }
  }

  Future<void> _saveFurniture() async {
    try {
      bool noFurnitureData = _furnitureRows
          .any((row) => row.nameController.text.trim().isNotEmpty);
      if (!noFurnitureData) {
        throw Exception('가구 정보를 입력해주세요');
      }

      String estimateId = widget.estimateId ?? '';
      bool isNewEstimate = false;
      if (estimateId.isEmpty) {
        final estimateRef =
            FirebaseFirestore.instance.collection('estimates').doc();
        estimateId = estimateRef.id;
        isNewEstimate = true;
      }

      List<Map<String, dynamic>> furnitureList = [];

      for (var row in _furnitureRows) {
        if (row.nameController.text.trim().isEmpty) continue;

        final quantity = int.tryParse(row.quantityController.text);
        final price = int.tryParse(row.priceController.text);

        if (quantity == null) throw Exception('올바른 수량을 입력해주세요');
        if (price == null) throw Exception('올바른 가격을 입력해주세요');

        // 수입 상품인 경우 Firestore에서 제품 확인
        if (row.productType == FurnitureProductType.imported) {
          final product = await _getProductByName(row.nameController.text);
          if (product == null) {
            throw Exception('선택된 제품을 찾을 수 없습니다: ${row.nameController.text}');
          }
          furnitureList.add({
          'name': product.name,
            'specification': row.specificationController.text.trim(),
          'quantity': quantity,
          'price': product.price,
          'isCustom': false,
            'productType': '수입',
          });
        } else {
          furnitureList.add({
            'name': row.nameController.text.trim(),
            'specification': row.specificationController.text.trim(),
          'quantity': quantity,
          'price': price,
          'isCustom': true,
            'productType': '제작',
        });
      }
      }

      if (!isNewEstimate) {
        final estimateDoc = await FirebaseFirestore.instance
            .collection('estimates')
            .doc(estimateId)
            .get();
        if (!estimateDoc.exists) {
          throw Exception('견적서를 찾을 수 없습니다');
        }
      }

      await FirebaseFirestore.instance
          .collection('estimates')
          .doc(estimateId)
          .set({
        'furnitureList': furnitureList,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (widget.estimateId == null) {
        await FirebaseFirestore.instance
            .collection('temp_estimates')
            .doc(estimateId)
            .delete();
      }

      if (mounted) {
        if (isEditMode) {
          context.go('/main/customer/${widget.customerId}',
              extra: {'refresh': true});
        } else {
          context.go(
              '/main/addpage/spaceadd/${widget.customerId}/$estimateId/space-detail/furniture/estimate',
              extra: {'companyName': widget.name ?? '무제'});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // 검색 드롭다운 위젯 빌드
  Widget _buildSearchDropdown(int index, FurnitureRow row) {
    return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // 제품종류 컬럼 너비만큼 공간 (140 + 구분선 1)
        const SizedBox(width: 141),
        // 상품명 컬럼 너비에 맞춘 검색 리스트
        Expanded(
          flex: 3,
          child: Material(
            elevation: 10,
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColor.line1, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: row.filteredProducts.length,
                  itemBuilder: (context, prodIndex) {
                  final product = row.filteredProducts[prodIndex];
                  return Material(
                    color: Colors.white,
                      child: InkWell(
                        onTap: () {
                        row.nameController.text = product.name;
                        row.priceController.text = product.price.toString();
                          setState(() {
                          row.filteredProducts = [];
                          _activeSearchRowIndex = null;
                          });
                        },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: AppColor.line1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              '${NumberFormat("#,###").format(product.price)}원',
                              style: const TextStyle(
                                fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ),
        ),
        // 나머지 컬럼들 공간 (규격, 수량, 단가, 삭제)
        const Expanded(flex: 2, child: SizedBox()),
        const SizedBox(width: 120), // 수량
        const SizedBox(width: 1), // 구분선
        const SizedBox(width: 180), // 단가
        const SizedBox(width: 1), // 구분선
        const SizedBox(width: 60), // 삭제
      ],
    );
  }

  // 테이블 행 위젯 빌드
  Widget _buildTableRow(int index) {
    final row = _furnitureRows[index];

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColor.line1, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 제품종류
          Container(
            width: 140,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        row.productType = FurnitureProductType.imported;
                        row.filteredProducts = [];
                      });
                    },
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: row.productType == FurnitureProductType.imported
                            ? AppColor.primary
                            : Colors.transparent,
                        border: Border.all(color: AppColor.line1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                    child: Text(
                          '수입',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                row.productType == FurnitureProductType.imported
                                    ? Colors.white
                                    : AppColor.font1,
                            fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        row.productType = FurnitureProductType.custom;
                        row.filteredProducts = [];
                      });
                    },
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: row.productType == FurnitureProductType.custom
                            ? AppColor.primary
                            : Colors.transparent,
                        border: Border.all(color: AppColor.line1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '제작',
                style: TextStyle(
                            fontSize: 12,
                            color:
                                row.productType == FurnitureProductType.custom
                                    ? Colors.white
                                    : AppColor.font1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
          ),
          Container(width: 1, height: 48, color: AppColor.line1),

          // 상품명 (검색 가능)
          Expanded(
            flex: 3,
            child: Container(
          height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: row.nameController,
                enabled: true,
                onChanged: row.productType == FurnitureProductType.imported
                    ? (value) async {
                        if (value.isEmpty) {
                          setState(() {
                            row.filteredProducts = [];
                            _activeSearchRowIndex = null;
                          });
                          return;
                        }
                        setState(() {
                          _activeSearchRowIndex = index;
                        });
                        final products = await _searchProductsFS(value);
                        if (!mounted) return;
                        setState(() {
                          row.filteredProducts = products;
                          _activeSearchRowIndex = index;
                        });
                      }
                    : (value) {
                        // 제작 상품일 때는 검색 결과 초기화
                        setState(() {
                          row.filteredProducts = [];
                          _activeSearchRowIndex = null;
                        });
                      },
                onTap: () {
                  if (row.productType == FurnitureProductType.imported &&
                      row.nameController.text.isNotEmpty &&
                      row.filteredProducts.isNotEmpty) {
                    setState(() {
                      _activeSearchRowIndex = index;
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: row.productType == FurnitureProductType.imported
                      ? '상품명 검색'
                      : '상품명 입력',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 48, color: AppColor.line1),

          // 규격
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
                controller: row.specificationController,
            decoration: const InputDecoration(
                  hintText: '규격 입력',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
          ),
          Container(width: 1, height: 48, color: AppColor.line1),

          // 수량
        Container(
            width: 120,
          height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                  child: TextField(
                    controller: row.quantityController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                      hintText: '0',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                ),
              ),
                const Text('개', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
          Container(width: 1, height: 48, color: AppColor.line1),

          // 단가
        Container(
            width: 180,
          height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                  child: TextField(
                    controller: row.priceController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                      hintText: '0',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                ),
              ),
                const Text('원', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
          Container(width: 1, height: 48, color: AppColor.line1),

          // 삭제 버튼
          SizedBox(
            width: 60,
              height: 48,
            child: _furnitureRows.length > 1
                ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () {
                  setState(() {
                        _furnitureRows[index].dispose();
                        _furnitureRows.removeAt(index);
                  });
                },
                  )
                : const SizedBox(),
          ),
      ],
      ),
    );
  }

  Future<void> _loadExistingEstimateData() async {
    if (widget.estimateId != null) {
      try {
        final estimateDoc = await FirebaseFirestore.instance
            .collection('estimates')
            .doc(widget.estimateId!)
            .get();

        if (estimateDoc.exists) {
          final data = estimateDoc.data()!;
          final furnitureList = data['furnitureList'] as List<dynamic>? ?? [];

          setState(() {
            _furnitureRows.clear();
          });

          for (var furniture in furnitureList) {
            final productType = furniture['productType'] == '제작'
                ? FurnitureProductType.custom
                : FurnitureProductType.imported;

            final row = FurnitureRow(productType: productType);
            row.nameController.text = furniture['name'] ?? '';
            row.specificationController.text = furniture['specification'] ?? '';
            row.quantityController.text =
                  furniture['quantity']?.toString() ?? '';
            row.priceController.text = furniture['price']?.toString() ?? '';

              setState(() {
              _furnitureRows.add(row);
              });
          }

          // 데이터가 없거나 5개 미만이면 기본 행 추가
          if (_furnitureRows.length < 5) {
            final rowsToAdd = 5 - _furnitureRows.length;
            for (int i = 0; i < rowsToAdd; i++) {
            setState(() {
                _furnitureRows.add(FurnitureRow());
            });
          }
          }
        }
      } catch (e) {
        debugPrint('Error loading existing estimate data: $e');
      }
    }
  }

  // 다음 버튼 클릭 시
  void _goNext() async {
    try {
      String estimateId = widget.estimateId ?? '';
      if (estimateId.isEmpty) {
        final estimateRef =
            FirebaseFirestore.instance.collection('estimates').doc();
        estimateId = estimateRef.id;
        // 임시저장이므로 customers 컬렉션에 저장하지 않음
      }

      // name 값 보장: widget.name이 없으면 Firestore에서 고객명 조회
      String? nameValue = widget.name;
      if (nameValue == null || nameValue.trim().isEmpty) {
        try {
          final customerDoc = await FirebaseFirestore.instance
              .collection('customers')
              .doc(widget.customerId)
              .get();

          if (customerDoc.exists && customerDoc.data() != null) {
            nameValue = customerDoc.data()!['name'] ?? '무제';
            print('_goNext: 고객명 조회 성공 - $nameValue'); // 디버깅 로그
          } else {
            nameValue = '무제';
            print('_goNext: 고객 문서가 존재하지 않음'); // 디버깅 로그
          }
        } catch (e) {
          nameValue = '무제';
          print('_goNext: 고객명 조회 실패 - $e'); // 디버깅 로그
        }
      }

      final estimateRef =
          FirebaseFirestore.instance.collection('estimates').doc(estimateId);
      final tempData = {
        'customerId': widget.customerId,
        'estimateId': estimateId,
        'status': 'IN_PROGRESS',
        'lastUpdated': FieldValue.serverTimestamp(),
        'isDraft': true,
        'type': '견적',
        'name': nameValue,
        'furnitureList': [],
      };
      print('_goNext: 저장할 tempData = $tempData'); // 디버깅 로그
      // name 필드를 항상 명시적으로 업데이트하여 회사명이 보이도록 함
      await estimateRef.set(tempData, SetOptions(merge: true));
      await estimateRef.update({'name': nameValue});
      print('_goNext: name 필드 명시적 업데이트 완료 - $nameValue'); // 디버깅 로그
      context.go(
          '/main/addpage/spaceadd/${widget.customerId}/$estimateId/space-detail/furniture/estimate');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다음 단계 저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // 이전 버튼 누르면 이전에 작성한 값 불러오기
  void _loadPreviousData() async {
    // 데이터는 이미 로드되어 있으므로 아무것도 하지 않음
  }

  @override
  void initState() {
    super.initState();

    // 처음 생성 시 기본 5줄 생성
    if (widget.estimateId == null) {
      for (int i = 0; i < 5; i++) {
        _furnitureRows.add(FurnitureRow());
    }
    } else {
    // 기존 견적 데이터 로드
    _loadExistingEstimateData();
    }
  }

  // 편집 모드인지 확인하는 getter
  bool get isEditMode {
    final currentPath =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    return currentPath.contains('/edit');
  }

  // 취소 시 임시저장 데이터 삭제 함수
  Future<void> _deleteTempData() async {
    try {
      // customerId로 임시저장된 데이터 찾아서 삭제
      final tempEstimates = await FirebaseFirestore.instance
          .collection('estimates')
          .where('customerId', isEqualTo: widget.customerId)
          .where('isDraft', isEqualTo: true)
          .get();

      for (var doc in tempEstimates.docs) {
        await doc.reference.delete();
        print('임시저장 데이터 삭제 완료: ${doc.id}');
      }
    } catch (e) {
      print('임시저장 데이터 삭제 중 오류: $e');
    }
  }

  @override
  void dispose() {
    // 컨트롤러 정리
    for (var row in _furnitureRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(UserProvider.userDataProvider);

    return Scaffold(
      body: ResponsiveLayout(
        mobile: const SingleChildScrollView(),
        desktop: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사이드바
            ExcludeFocus(
              child: Container(
                width: 240,
                height: MediaQuery.of(context).size.height,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: AppColor.line1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    InkWell(
                      onTap: () => context.go('/main'),
                      child: SizedBox(
                        width: 137,
                        height: 17,
                        child: Image.asset('assets/images/logo.png'),
                      ),
                    ),
                    const SizedBox(height: 56),
                    userData.when(
                      data: (data) {
                        if (data != null) {
                          return Column(
                            children: [
                              Text(
                                UserProvider.getUserName(data),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.font1,
                                ),
                              ),
                            ],
                          );
                        }
                        return const Text('사용자 정보를 불러올 수 없습니다.');
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (error, stack) => Text('오류: $error'),
                    ),
                    const SizedBox(height: 40),
                    // 메뉴 버튼들
                    InkWell(
                      onTap: () => context.go('/main'),
                      child: Container(
                          width: 200,
                          height: 48,
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 17.87,
                              ),
                              SizedBox(
                                  width: 16.25,
                                  height: 16.25,
                                  child: Image.asset(
                                    'assets/images/user.png',
                                    color: AppColor.font1,
                                  )),
                              const SizedBox(
                                width: 3.85,
                              ),
                              const Text(
                                '담당 고객정보',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.font1,
                                    fontSize: 16),
                              ),
                            ],
                          )),
                    ),
                    InkWell(
                      onTap: () => context.go('/all-customers'),
                      child: Container(
                          width: 200,
                          height: 48,
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 17.87,
                              ),
                              SizedBox(
                                  width: 16.25,
                                  height: 16.25,
                                  child:
                                      Image.asset('assets/images/group.png')),
                              const SizedBox(
                                width: 3.85,
                              ),
                              const Text(
                                '전체 고객정보',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.font1,
                                    fontSize: 16),
                              ),
                            ],
                          )),
                    ),

                    const SizedBox(
                      height: 48,
                    ),
                    InkWell(
                      onTap: () => context.go('/temp'),
                      child: Container(
                          width: 200,
                          height: 48,
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 17.87,
                              ),
                              SizedBox(
                                  width: 16.25,
                                  height: 16.25,
                                  child:
                                      Image.asset('assets/images/draft.png')),
                              const SizedBox(
                                width: 3.85,
                              ),
                              const Text(
                                '임시저장',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.font1,
                                    fontSize: 16),
                              ),
                            ],
                          )),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: InkWell(
                        onTap: _handleLogout,
                        child: Container(
                          width: 200,
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout,
                                  color: Colors.red.shade300, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '로그아웃',
                                style: TextStyle(
                                  color: Colors.red.shade300,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 메인 컨텐츠
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double availableWidth = constraints.maxWidth - 48;

                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 상단 영역 (날짜 및 아이콘)
                            SizedBox(
                              width: availableWidth,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      context.pop();
                                    },
                                    child: const Row(
                                      children: [
                                        Icon(Icons.arrow_back_ios),
                                        SizedBox(width: 4),
                                        Text(
                                          '이전',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600),
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 56),
                            const Text(
                              '가구 견적 입력',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColor.font1,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // 테이블 형태 입력
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColor.line1),
                              ),
                              child: Column(
                              children: [
                                  // 테이블 헤더
                                  Container(
                                    height: 48,
                                    decoration: const BoxDecoration(
                                      color: AppColor.back2,
                                      border: Border(
                                        bottom: BorderSide(
                                            color: AppColor.line1, width: 2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 140,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: const Text(
                                            '제품종류',
                                  style: TextStyle(
                                              fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                  ),
                                ),
                                        Container(
                                            width: 1,
                                            height: 48,
                                            color: AppColor.line1),
                                        Expanded(
                                          flex: 3,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: const Text(
                                              '상품명',
                                  style: TextStyle(
                                                fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ),
                                        ),
                                        Container(
                                            width: 1,
                                            height: 48,
                                            color: AppColor.line1),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: const Text(
                                              '규격',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                                  ),
                                                ),
                                        Container(
                                            width: 1,
                                            height: 48,
                                            color: AppColor.line1),
                                        Container(
                                          width: 120,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: const Text(
                                                  '수량',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                                Container(
                                            width: 1,
                                            height: 48,
                                                  color: AppColor.line1),
                                        Container(
                                          width: 180,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: const Text(
                                            '단가',
                                                style: TextStyle(
                                              fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            textAlign: TextAlign.center,
                                            ),
                                          ),
                                        Container(
                                            width: 1,
                                            height: 48,
                                            color: AppColor.line1),
                                        const SizedBox(
                                          width: 60,
                                          child: SizedBox(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 테이블 행들
                                  ...List.generate(_furnitureRows.length,
                                      (index) {
                                    final row = _furnitureRows[index];
                                            return Column(
                                              children: [
                                        _buildTableRow(index),
                                        // 검색 리스트를 해당 행 아래에 표시
                                        if (_activeSearchRowIndex == index &&
                                            row.productType ==
                                                FurnitureProductType.imported &&
                                            row.nameController.text
                                                .isNotEmpty &&
                                            row.filteredProducts.isNotEmpty)
                                          _buildSearchDropdown(index, row),
                                              ],
                                            );
                                  }),
                                ],
                              ),
                                        ),
                            const SizedBox(height: 16),
                            // 행 추가 버튼
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                          onTap: () {
                                            setState(() {
                                    _furnitureRows.add(FurnitureRow());
                                            });
                                          },
                                          child: Container(
                                            height: 36,
                                  width: 140,
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                    border: Border.all(color: AppColor.line1),
                                            ),
                                            child: const Center(
                                              child: Text(
                                      '행 추가 +',
                                                style: TextStyle(
                                                  color: AppColor.primary,
                                        fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // 하단 버튼들
                            Row(
                              children: [
                                InkWell(
                                  onTap: () async {
                                    if (isEditMode) {
                                      // 편집 모드일 때는 customer 화면으로 돌아가기 (새로고침 플래그 전달)
                                      context.go(
                                          '/main/customer/${widget.customerId}',
                                          extra: {'refresh': true});
                                    } else {
                                      // 새로 생성 모드일 때는 임시저장 데이터 삭제 후 메인 화면으로
                                      await _deleteTempData();
                                      GoRouter.of(context).go('/main');
                                    }
                                  },
                                  child: Container(
                                    width: 60,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      border: Border.all(color: AppColor.line1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        isEditMode ? '이전' : '취소',
                                        style: const TextStyle(
                                          color: AppColor.primary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!isEditMode) ...[
                                  InkWell(
                                    onTap: _saveTempFurniture, // 임시 저장
                                    child: Container(
                                      width: 87,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        border:
                                            Border.all(color: AppColor.line1),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '임시 저장',
                                          style: TextStyle(
                                            color: AppColor.primary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                InkWell(
                                  onTap: _saveFurniture, // 저장/다음
                                  child: Container(
                                    width: 60,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColor.primary,
                                      border: Border.all(color: AppColor.line1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        isEditMode ? '수정' : '다음',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
