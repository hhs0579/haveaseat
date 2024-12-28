import 'dart:io';
import 'dart:math';
import 'package:haveaseat/riverpod/product.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class furniturePage extends ConsumerStatefulWidget {
  final String customerId;

  const furniturePage({super.key, required this.customerId});

  @override
  ConsumerState<furniturePage> createState() => _furniturePageState();
}

class _furniturePageState extends ConsumerState<furniturePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  // furniturePage에 다음 함수들을 추가
// 임시 저장
  Future<void> _saveTempFurniture() async {
    try {
      // 선택된 제품 찾기
      final product = ref
          .read(productProvider.notifier)
          .searchProducts(_searchController.text)
          .firstWhere(
            (p) => p.name == _searchController.text,
            orElse: () => throw Exception('선택된 제품을 찾을 수 없습니다'),
          );

      // 수량 검증
      final quantity = int.tryParse(_quantityController.text);
      if (quantity == null) throw Exception('올바른 수량을 입력해주세요');

      // 고객 정보 가져오기
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null || customer.estimateIds.isEmpty) {
        throw Exception('고객 정보를 찾을 수 없습니다');
      }

      final estimateId = customer.estimateIds[0];

      // 임시 저장 데이터
      final tempData = {
        'customerId': widget.customerId,
        'estimateId': estimateId,
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isTemp': true,
        'furnitureList': [
          {
            'name': product.name,
            'quantity': quantity,
            'price': product.price,
          }
        ]
      };

      // temp_estimates 컬렉션에 저장
      await FirebaseFirestore.instance
          .collection('temp_estimates')
          .doc(estimateId)
          .set(tempData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('임시 저장되었습니다')),
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

// 최종 저장
  Future<void> _saveFurniture() async {
    try {
      // 제품 검증
      final product = ref
          .read(productProvider.notifier)
          .searchProducts(_searchController.text)
          .firstWhere(
            (p) => p.name == _searchController.text,
            orElse: () => throw Exception('선택된 제품을 찾을 수 없습니다'),
          );

      // 수량 검증
      final quantity = int.tryParse(_quantityController.text);
      if (quantity == null) throw Exception('올바른 수량을 입력해주세요');

      // 고객 정보 가져오기
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null || customer.estimateIds.isEmpty) {
        throw Exception('고객 정보를 찾을 수 없습니다');
      }

      final estimateId = customer.estimateIds[0];

      // 가구 데이터
      final furnitureData = {
        'name': product.name,
        'quantity': quantity,
        'price': product.price,
      };

      // 기존 데이터 가져오기
      final estimateDoc = await FirebaseFirestore.instance
          .collection('estimates')
          .doc(estimateId)
          .get();

      if (!estimateDoc.exists) {
        throw Exception('견적서를 찾을 수 없습니다');
      }

      // estimate 컬렉션에 저장
      await FirebaseFirestore.instance
          .collection('estimates')
          .doc(estimateId)
          .set({
        'furnitureList': FieldValue.arrayUnion([furnitureData]),
        'updatedAt': FieldValue.serverTimestamp(),
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
            '/main/addpage/spaceadd/${widget.customerId}/space-detail/furniture/estimate'); // 최종 화면으로 이동
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Widget buildSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 48,
          width: 640,
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              final products =
                  ref.read(productProvider.notifier).searchProducts(value);
              setState(() {
                _filteredProducts = products;
              });
            },
            decoration: const InputDecoration(
              hintText: '상품명을 입력하세요',
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
              border: InputBorder.none,
            ),
          ),
        ),
        if (_searchController.text.isNotEmpty && _filteredProducts.isNotEmpty)
          Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 530),
            decoration: BoxDecoration(
              border: Border.all(color: AppColor.line1),
              color: Colors.transparent,
            ),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: true,
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  scrollbarTheme: ScrollbarThemeData(
                    thumbColor: MaterialStateProperty.all(Colors.black),
                  ),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    final formattedPrice =
                        NumberFormat("#,###").format(product.price);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColor.line1, width: 1),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          _searchController.text = product.name;
                          setState(() {
                            _filteredProducts = [];
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColor.font1,
                                ),
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
            ),
          ),
      ],
    );
  }

  @override
  List<dynamic> _filteredProducts = []; // 이 부분을 추가하세요

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        setState(() {
          _filteredProducts = [];
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose(); // 추가
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
            Container(
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
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 17.87,
                            ),
                            SizedBox(
                                width: 16.25,
                                height: 16.25,
                                child: Image.asset('assets/images/user.png')),
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
                                child: Image.asset('assets/images/corp.png')),
                            const SizedBox(
                              width: 3.85,
                            ),
                            const Text(
                              '업체 정보',
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
                ],
              ),
            ),
            // 메인 컨텐츠
// 테이블 영역 부분만 수정
// 메인 컨텐츠 영역
            Expanded(child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
              final double availableHeight = constraints.maxHeight - 48;
              // constraints를 여기서 받음
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
                                      Text(
                                        '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: AppColor.font1,
                                        ),
                                      ),
                                      const Row(
                                        children: [
                                          Icon(Icons.person_outline_sharp,
                                              color: AppColor.font2),
                                          SizedBox(width: 16),
                                          Icon(
                                              Icons.notifications_none_outlined,
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
                                const SizedBox(height: 48),
                                const Text(
                                  '가구 견적 입력',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.font1,
                                  ),
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                Container(
                                  height: 2,
                                  width: 640,
                                  color: AppColor.primary,
                                ),
                                const SizedBox(
                                  height: 24,
                                ),
                                const Text(
                                  '견적종류',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black),
                                ),

                                const SizedBox(
                                  height: 8,
                                ),
                                buildSearchField(),
                                const SizedBox(
                                  height: 24,
                                ),
                                const Text(
                                  '수량',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black),
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                Container(
                                  height: 48,
                                  width: 640,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColor.line1),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            // 힌트 텍스트를 커스터마이징하여 왼쪽 고정
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16),
                                                child: Text(
                                                  _quantityController
                                                          .text.isEmpty
                                                      ? '숫자입력'
                                                      : '',
                                                  style: const TextStyle(
                                                    color: AppColor.font2,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // 입력 필드
                                            TextField(
                                              controller: _quantityController,
                                              keyboardType:
                                                  TextInputType.number,
                                              textAlign: TextAlign
                                                  .right, // 입력 텍스트는 오른쪽 정렬
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColor.font1,
                                              ),
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 16),
                                                hintText: '', // 힌트 텍스트를 비워둠
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(
                                          '개',
                                          style: TextStyle(
                                            color: AppColor.font2,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  height: 48,
                                ),
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
                                          border:
                                              Border.all(color: AppColor.line1),
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
                                          border:
                                              Border.all(color: AppColor.line1),
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
                                        // 고객 추가 처리
                                        _saveFurniture();
                                      },
                                      child: Container(
                                        width: 60,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppColor.primary,
                                          border:
                                              Border.all(color: AppColor.line1),
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
                              ]))));
            }))
          ],
        ),
      ),
    );
  }
}
