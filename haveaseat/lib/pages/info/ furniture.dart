import 'dart:io';
import 'dart:math';
import 'package:haveaseat/riverpod/product.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

enum FurnitureType { existing, custom }

class furniturePage extends ConsumerStatefulWidget {
  final String customerId;

  const furniturePage({super.key, required this.customerId});

  @override
  ConsumerState<furniturePage> createState() => _furniturePageState();
}

class FurnitureField {
  final TextEditingController searchController;
  final TextEditingController quantityController;
  List<dynamic> filteredProducts;

  FurnitureField()
      : searchController = TextEditingController(),
        quantityController = TextEditingController(),
        filteredProducts = [];
}

class CustomFurnitureField {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController priceController;

  CustomFurnitureField()
      : nameController = TextEditingController(),
        descriptionController = TextEditingController(),
        quantityController = TextEditingController(),
        priceController = TextEditingController();
}

class _furniturePageState extends ConsumerState<furniturePage> {
  // 기존 가구 리스트와 제작 가구 리스트를 분리
  final List<FurnitureField> _existingFurnitureFields = [];
  final List<CustomFurnitureField> _customFurnitureFields = [];

  // 현재 선택된 가구 타입
  FurnitureType _selectedFurnitureType = FurnitureType.existing;

  // PageController 추가
  late PageController _pageController;

  // 임시 저장
  Future<void> _saveTempFurniture() async {
    try {
      bool noFurnitureData =
          _existingFurnitureFields.isEmpty && _customFurnitureFields.isEmpty;
      if (noFurnitureData) {
        throw Exception('가구 정보를 입력해주세요');
      }

      // 고객 정보 가져오기
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null || customer.estimateIds.isEmpty) {
        throw Exception('고객 정보를 찾을 수 없습니다');
      }

      final estimateId = customer.estimateIds[0];
      List<Map<String, dynamic>> existingFurnitureList = [];
      List<Map<String, dynamic>> customFurnitureList = [];

      // 기존 가구 정보 처리
      for (var field in _existingFurnitureFields) {
        if (field.searchController.text.isEmpty) {
          continue; // 빈 필드는 건너뛰기
        }

        // 선택된 제품 찾기
        final product = ref
            .read(productProvider.notifier)
            .searchProducts(field.searchController.text)
            .firstWhere(
              (p) => p.name == field.searchController.text,
              orElse: () => throw Exception(
                  '선택된 제품을 찾을 수 없습니다: ${field.searchController.text}'),
            );

        // 수량 검증
        final quantity = int.tryParse(field.quantityController.text);
        if (quantity == null) throw Exception('올바른 수량을 입력해주세요');

        existingFurnitureList.add({
          'name': product.name,
          'quantity': quantity,
          'price': product.price,
          'isCustom': false,
        });
      }

      // 제작 가구 정보 처리
      for (var field in _customFurnitureFields) {
        if (field.nameController.text.isEmpty) {
          continue; // 빈 필드는 건너뛰기
        }

        // 수량과 가격 검증
        final quantity = int.tryParse(field.quantityController.text);
        final price = int.tryParse(field.priceController.text);
        if (quantity == null) throw Exception('올바른 수량을 입력해주세요');
        if (price == null) throw Exception('올바른 가격을 입력해주세요');

        customFurnitureList.add({
          'name': field.nameController.text,
          'description': field.descriptionController.text,
          'quantity': quantity,
          'price': price,
          'isCustom': true,
        });
      }

      // 모든 가구 리스트를 하나로 합침
      final combinedFurnitureList = [
        ...existingFurnitureList,
        ...customFurnitureList
      ];

      // 임시 저장 데이터
      final tempData = {
        'customerId': widget.customerId,
        'estimateId': estimateId,
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isTemp': true,
        'furnitureList': combinedFurnitureList,
      };

      await FirebaseFirestore.instance
          .collection('temp_estimates')
          .doc(estimateId)
          .set(tempData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('임시 저장되었습니다')),
        );
        context.go(
            '/main/addpage/spaceadd/${widget.customerId}/space-detail/furniture/estimate');
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
      print('Error during logout: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다')),
        );
      }
    }
  }

  Future<void> _saveFurniture() async {
    try {
      bool noFurnitureData =
          _existingFurnitureFields.isEmpty && _customFurnitureFields.isEmpty;
      if (noFurnitureData) {
        throw Exception('가구 정보를 입력해주세요');
      }

      // 고객 정보 가져오기
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null || customer.estimateIds.isEmpty) {
        throw Exception('고객 정보를 찾을 수 없습니다');
      }

      final estimateId = customer.estimateIds[0];
      List<Map<String, dynamic>> existingFurnitureList = [];
      List<Map<String, dynamic>> customFurnitureList = [];

      // 메모 정보 (제작 가구가 있으면 첫 번째 제작 가구의 메모 사용)
      String memo = '';
      if (_customFurnitureFields.isNotEmpty &&
          _customFurnitureFields[0].descriptionController.text.isNotEmpty) {
        memo = _customFurnitureFields[0].descriptionController.text;
      }

      // 기존 가구 정보 처리
      for (var field in _existingFurnitureFields) {
        if (field.searchController.text.isEmpty) {
          continue; // 빈 필드는 건너뛰기
        }

        // 선택된 제품 찾기
        final product = ref
            .read(productProvider.notifier)
            .searchProducts(field.searchController.text)
            .firstWhere(
              (p) => p.name == field.searchController.text,
              orElse: () => throw Exception(
                  '선택된 제품을 찾을 수 없습니다: ${field.searchController.text}'),
            );

        // 수량 검증
        final quantity = int.tryParse(field.quantityController.text);
        if (quantity == null) throw Exception('올바른 수량을 입력해주세요');

        existingFurnitureList.add({
          'name': product.name,
          'quantity': quantity,
          'price': product.price,
          'isCustom': false,
        });
      }

      // 제작 가구 정보 처리
      for (var field in _customFurnitureFields) {
        if (field.nameController.text.isEmpty) {
          continue; // 빈 필드는 건너뛰기
        }

        // 수량과 가격 검증
        final quantity = int.tryParse(field.quantityController.text);
        final price = int.tryParse(field.priceController.text);
        if (quantity == null) throw Exception('올바른 수량을 입력해주세요');
        if (price == null) throw Exception('올바른 가격을 입력해주세요');

        customFurnitureList.add({
          'name': field.nameController.text,
          'description': field.descriptionController.text,
          'quantity': quantity,
          'price': price,
          'isCustom': true,
        });
      }

      // 모든 가구 리스트를 하나로 합침
      final combinedFurnitureList = [
        ...existingFurnitureList,
        ...customFurnitureList
      ];

      // 기존 데이터 가져오기
      final estimateDoc = await FirebaseFirestore.instance
          .collection('estimates')
          .doc(estimateId)
          .get();

      if (!estimateDoc.exists) {
        throw Exception('견적서를 찾을 수 없습니다');
      }

      // estimate 컬렉션에 저장 - memo 필드 추가
      await FirebaseFirestore.instance
          .collection('estimates')
          .doc(estimateId)
          .set({
        'furnitureList': combinedFurnitureList,
        'updatedAt': FieldValue.serverTimestamp(),
        'memo': memo, // 메모 필드 추가
      }, SetOptions(merge: true));

      // 임시 저장 데이터 삭제
      await FirebaseFirestore.instance
          .collection('temp_estimates')
          .doc(estimateId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다')),
        );
        context.go(
            '/main/addpage/spaceadd/${widget.customerId}/space-detail/furniture/estimate');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  // 기존 가구 검색 필드 위젯
  Widget buildExistingFurnitureSearchField(int index) {
    final field = _existingFurnitureFields[index];
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              width: 640,
              decoration: BoxDecoration(
                border: Border.all(color: AppColor.line1),
              ),
              child: TextField(
                controller: field.searchController,
                onChanged: (value) {
                  final products =
                      ref.read(productProvider.notifier).searchProducts(value);
                  setState(() {
                    field.filteredProducts = products;
                  });
                },
                decoration: const InputDecoration(
                  hintText: '상품명을 입력하세요',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (field.searchController.text.isNotEmpty &&
                field.filteredProducts.isNotEmpty)
              Container(
                width: 640,
                constraints: const BoxConstraints(maxHeight: 530),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColor.line1),
                  color: Colors.transparent,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: field.filteredProducts.length,
                  itemBuilder: (context, prodIndex) {
                    final product = field.filteredProducts[prodIndex];
                    final formattedPrice =
                        NumberFormat("#,###").format(product.price);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: AppColor.line1)),
                      ),
                      child: InkWell(
                        onTap: () {
                          field.searchController.text = product.name;
                          setState(() {
                            field.filteredProducts = [];
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: const TextStyle(
                                    fontSize: 14, color: AppColor.font1),
                              ),
                            ),
                            Text(
                              '$formattedPrice원',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColor.font1,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        if (index > 0) // 첫 번째가 아닌 경우에만 삭제 버튼 표시
          Container(
            width: 52,
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: AppColor.line1),
            ),
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () {
                setState(() {
                  _existingFurnitureFields[index].searchController.dispose();
                  _existingFurnitureFields[index].quantityController.dispose();
                  _existingFurnitureFields.removeAt(index);
                });
              },
            ),
          ),
      ],
    );
  }

  // 기존 가구 수량 입력 위젯
  Widget buildExistingFurnitureQuantityField(int index) {
    final field = _existingFurnitureFields[index];
    return Container(
      height: 48,
      width: 640,
      decoration: BoxDecoration(
        border: Border.all(color: AppColor.line1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: Text(
                      field.quantityController.text.isEmpty ? '숫자입력' : '',
                      style: const TextStyle(
                        color: AppColor.font2,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: field.quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColor.font1,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(right: 4, bottom: 4.2),
                    hintText: '',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              alignment: Alignment.centerLeft,
              child: const Text(
                '개',
                style: TextStyle(
                  color: AppColor.font2,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 제작 가구 필드 생성 위젯
  Widget buildCustomFurnitureField(int index) {
    final field = _customFurnitureFields[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제품명 필드
        const Text(
          '가구명',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          width: 640,
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1),
          ),
          child: TextField(
            controller: field.nameController,
            decoration: const InputDecoration(
              hintText: '가구명을 입력하세요',
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 상세 설명 필드

        // 수량 입력 필드
        const Text(
          '수량',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          width: 640,
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          field.quantityController.text.isEmpty ? '숫자입력' : '',
                          style: const TextStyle(
                            color: AppColor.font2,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: field.quantityController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColor.font1,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(right: 4, bottom: 4.2),
                        hintText: '',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    '개',
                    style: TextStyle(
                      color: AppColor.font2,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 가격 입력 필드
        const Text(
          '가격',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          width: 640,
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          field.priceController.text.isEmpty ? '숫자입력' : '',
                          style: const TextStyle(
                            color: AppColor.font2,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    TextField(
                      controller: field.priceController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColor.font1,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(right: 4, bottom: 4.2),
                        hintText: '',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    '원',
                    style: TextStyle(
                      color: AppColor.font2,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '메모',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        const SizedBox(height: 8),
        Container(
          height: 300,
          width: 640,
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1),
          ),
          child: TextField(
            controller: field.descriptionController,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '내용을 입력하세요',
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (index > 0) // 첫 번째 항목이 아닌 경우에만 삭제 버튼 표시
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 52,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: AppColor.line1),
              ),
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () {
                  setState(() {
                    _customFurnitureFields[index].nameController.dispose();
                    _customFurnitureFields[index]
                        .descriptionController
                        .dispose();
                    _customFurnitureFields[index].quantityController.dispose();
                    _customFurnitureFields[index].priceController.dispose();
                    _customFurnitureFields.removeAt(index);
                  });
                },
              ),
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    // 첫 번째 항목 추가
    _existingFurnitureFields.add(FurnitureField());
    _customFurnitureFields.add(CustomFurnitureField());

    // 페이지 컨트롤러 초기화
    _pageController = PageController();
  }

  @override
  void dispose() {
    // 컨트롤러 정리
    for (var field in _existingFurnitureFields) {
      field.searchController.dispose();
      field.quantityController.dispose();
    }

    for (var field in _customFurnitureFields) {
      field.nameController.dispose();
      field.descriptionController.dispose();
      field.quantityController.dispose();
      field.priceController.dispose();
    }

    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(UserProvider.userDataProvider);
    final customers = ref.watch(customerDataProvider);

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
                    const SizedBox(height: 16),
                    // 정보수정 버튼
                    Container(
                      width: 152,
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColor.line1),
                      ),
                      child: const Center(
                        child: Text(
                          '정보수정',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColor.font1,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // 메뉴 버튼들
                    InkWell(
                      onTap: () => context.go('/main'),
                      child: Container(
                          width: 200,
                          height: 48,
                          color: const Color(0xffB18E72),
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
                                    color: Colors.white,
                                  )),
                              const SizedBox(
                                width: 3.85,
                              ),
                              const Text(
                                '담당 고객정보',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
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
                                  child: Image.asset('assets/images/group.png')),
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
                      onTap: () {},
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
                                  child: Image.asset('assets/images/as.png')),
                              const SizedBox(
                                width: 3.85,
                              ),
                              const Text(
                                '교환',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.font1,
                                    fontSize: 16),
                              ),
                            ],
                          )),
                    ),
                    InkWell(
                      onTap: () => context.go('/return'),
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
                                  child: Image.asset('assets/images/as.png')),
                              const SizedBox(
                                width: 3.85,
                              ),
                              const Text(
                                '반품',
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
                                  child: Image.asset('assets/images/draft.png')),
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
                  final double availableHeight = constraints.maxHeight - 48;
                  final double availableWidth = constraints.maxWidth - 48;
                  final double tableWidth = max(1200, availableWidth);

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
                                  const Row(
                                    children: [
                                      Icon(Icons.person_outline_sharp,
                                          color: AppColor.font2),
                                      SizedBox(width: 16),
                                      Icon(Icons.notifications_none_outlined,
                                          color: AppColor.font2),
                                      SizedBox(width: 16),
                                    ],
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

                            // 라디오 버튼으로 가구 유형 선택
                            Row(
                              children: [
                                Radio<FurnitureType>(
                                  value: FurnitureType.existing,
                                  groupValue: _selectedFurnitureType,
                                  activeColor: AppColor.primary,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedFurnitureType =
                                          FurnitureType.existing;
                                      _pageController.animateToPage(
                                        0,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    });
                                  },
                                ),
                                const Text(
                                  '수입 상품',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.font1,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Radio<FurnitureType>(
                                  value: FurnitureType.custom,
                                  groupValue: _selectedFurnitureType,
                                  activeColor: AppColor.primary,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedFurnitureType =
                                          FurnitureType.custom;
                                      _pageController.animateToPage(
                                        1,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    });
                                  },
                                ),
                                const Text(
                                  '제작 상품',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.font1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // PageView로 기존 가구/제작 가구 입력 폼 전환
                            SizedBox(
                              height: constraints.maxHeight, // 필요에 따라 높이 조절
                              child: PageView(
                                controller: _pageController,
                                physics:
                                    const NeverScrollableScrollPhysics(), // 스와이프로 페이지 변경 금지 (라디오 버튼으로만 변경)
                                onPageChanged: (index) {
                                  setState(() {
                                    _selectedFurnitureType = index == 0
                                        ? FurnitureType.existing
                                        : FurnitureType.custom;
                                  });
                                },
                                children: [
                                  // 첫 번째 페이지: 기존 가구 입력
                                  SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '수입 상품 견적 입력',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: AppColor.font1,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          height: 2,
                                          width: 640,
                                          color: AppColor.primary,
                                        ),
                                        const SizedBox(height: 24),

                                        // 기존 가구 입력 필드들
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount:
                                              _existingFurnitureFields.length,
                                          itemBuilder: (context, index) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (index > 0)
                                                  const SizedBox(height: 24),
                                                const Text(
                                                  '견적종류',
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black),
                                                ),
                                                const SizedBox(height: 8),
                                                buildExistingFurnitureSearchField(
                                                    index),
                                                const SizedBox(height: 24),
                                                const Text(
                                                  '수량',
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black),
                                                ),
                                                const SizedBox(height: 8),
                                                buildExistingFurnitureQuantityField(
                                                    index),
                                                const SizedBox(height: 24),
                                                Container(
                                                  width: 640,
                                                  height: 1,
                                                  color: Colors.black,
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _existingFurnitureFields
                                                  .add(FurnitureField());
                                            });
                                          },
                                          child: Container(
                                            height: 36,
                                            width: 640,
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              border: Border.all(
                                                  color: AppColor.line1),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                '가구 추가 +',
                                                style: TextStyle(
                                                    color: AppColor.primary,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 두 번째 페이지: 제작 가구 입력
                                  SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '제작 상품 견적 입력',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: AppColor.font1,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          height: 2,
                                          width: 640,
                                          color: AppColor.primary,
                                        ),
                                        const SizedBox(height: 24),

                                        // 제작 가구 입력 필드들
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount:
                                              _customFurnitureFields.length,
                                          itemBuilder: (context, index) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (index > 0)
                                                  const SizedBox(height: 24),
                                                buildCustomFurnitureField(
                                                    index),
                                                const SizedBox(height: 24),
                                                Container(
                                                  width: 640,
                                                  height: 1,
                                                  color: Colors.black,
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _customFurnitureFields
                                                  .add(CustomFurnitureField());
                                            });
                                          },
                                          child: Container(
                                            height: 36,
                                            width: 640,
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              border: Border.all(
                                                  color: AppColor.line1),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                '제작 상품 추가 +',
                                                style: TextStyle(
                                                    color: AppColor.primary,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(
                              height: 32,
                            ),
                            // 하단 버튼들
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    GoRouter.of(context).go('/main');
                                  },
                                  child: Container(
                                    width: 60,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      border: Border.all(color: AppColor.line1),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '취소',
                                        style: TextStyle(
                                            color: AppColor.primary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    // 임시 저장 처리
                                    _saveTempFurniture();
                                  },
                                  child: Container(
                                    width: 87,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      border: Border.all(color: AppColor.line1),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '임시 저장',
                                        style: TextStyle(
                                            color: AppColor.primary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    // 저장 처리
                                    _saveFurniture();
                                  },
                                  child: Container(
                                    width: 60,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColor.primary,
                                      border: Border.all(color: AppColor.line1),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '다음',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
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
