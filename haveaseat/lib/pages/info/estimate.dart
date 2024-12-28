import 'dart:io';
import 'dart:math';
import 'package:haveaseat/pages/login/signup.dart';
import 'package:haveaseat/riverpod/signupmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'package:haveaseat/widget/address.dart';
import 'package:haveaseat/widget/fileupload.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haveaseat/components/colors.dart';
import 'dart:html' as html;

class EstimatePage extends ConsumerStatefulWidget {
  final String customerId;

  const EstimatePage({super.key, required this.customerId});

  @override
  ConsumerState<EstimatePage> createState() => _EstimatePageState();
}

class _EstimatePageState extends ConsumerState<EstimatePage> {
  // EstimatePage의 _EstimatePageState 클래스 내부에 추가할 코드

// 데이터 로드
  Future<Map<String, dynamic>> _loadEstimateData() async {
    try {
      // 고객 정보 가져오기
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null) throw Exception('고객 정보를 찾을 수 없습니다');

      // 견적 정보 가져오기
      final estimateDoc = await FirebaseFirestore.instance
          .collection('estimates')
          .doc(customer.estimateIds[0])
          .get();

      if (!estimateDoc.exists) throw Exception('견적 정보를 찾을 수 없습니다');

      return {
        'customer': customer,
        'estimate': estimateDoc.data(),
      };
    } catch (e) {
      print('Error loading estimate data: $e');
      rethrow;
    }
  }

  Widget _buildInfoCell(String label, String value) {
    return Container(
      width: 396, // 화면 비율에 맞게 조정할 예정
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColor.line1, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            color: AppColor.back2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCell(String label, String value) {
    String getFileName(String url) {
      try {
        // URL의 마지막 '/' 이후의 문자열을 가져옴
        String fileName = url.split('/').last;
        // URL 인코딩 디코드
        fileName = Uri.decodeFull(fileName);
        // '?' 이전의 실제 파일명만 추출
        fileName = fileName.split('?').first;
        return fileName;
      } catch (e) {
        return url;
      }
    }

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColor.line1, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            color: AppColor.back2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: value.isEmpty
                ? const Text('미첨부', style: TextStyle(color: Colors.red))
                : InkWell(
                    onTap: () {
                      html.window.open(value, '_blank');
                    },
                    child: Text(
                      getFileName(value),
                      style: const TextStyle(
                        color: AppColor.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
          ))
        ],
      ),
    );
  }

  Widget _buildFullWidthCell(String label, String value) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColor.line1, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            color: AppColor.back2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// 각 섹션 위젯들
  Widget _buildCustomerSection(Map<String, dynamic> data) {
    final customer = data['customer'] as Customer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '고객 정보',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          width: double.infinity,
          height: 2,
          color: Colors.black,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - 48) / 2;

            return Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('고객명', customer.name),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('연락처', customer.phone),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('이메일주소', customer.email),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('배송지주소', customer.address),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child:
                          _buildFileCell('사업자등록증', customer.businessLicenseUrl),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildFileCell(
                          '기타서류', customer.otherDocumentUrls.join(', ')),
                    ),
                  ],
                ),
                _buildFullWidthCell('기타입력사항', customer.note),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSpaceSection(Map<String, dynamic> data) {
    final estimate = data['estimate'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '공간 정보',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          width: double.infinity,
          height: 2,
          color: Colors.black,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - 48) / 2;

            return Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child:
                          _buildInfoCell('현장주소', estimate['siteAddress'] ?? ''),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell(
                          '공간오픈일정', _formatDate(estimate['openingDate'])),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('예산',
                          '${estimate['minBudget']?.toString() ?? '0'} ~ ${estimate['maxBudget']?.toString() ?? '0'}원'),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('공간면적',
                          '${estimate['spaceArea']?.toString() ?? '0'} ㎡'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child:
                          _buildInfoCell('업종', estimate['businessType'] ?? ''),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('공간컨셉', estimate['concept'] ?? ''),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell('수령자', estimate['recipient'] ?? ''),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell(
                          '연락처', estimate['contactNumber'] ?? ''),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell(
                          '배송방법', estimate['shippingMethod'] ?? ''),
                    ),
                    SizedBox(
                      width: cellWidth,
                      child: _buildInfoCell(
                          '결제방법', estimate['paymentMethod'] ?? ''),
                    ),
                  ],
                ),
                _buildFileCell(
                    '공간도면 및 설계파일',
                    (estimate['designFileUrls'] as List<dynamic>?)
                            ?.join(', ') ??
                        ''),
                _buildFullWidthCell('기타입력사항', estimate['basicNotes'] ?? ''),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEstimateSection(Map<String, dynamic> data) {
    final estimate = data['estimate'] as Map<String, dynamic>;
    final furnitureList = (estimate['furnitureList'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '견적 정보',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          width: double.infinity,
          height: 2,
          color: Colors.black,
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColor.line1),
          ),
          child: Column(
            children: [
              // 테이블 헤더
              Container(
                color: AppColor.back2,
                child: Row(
                  children: [
                    _buildTableHeader('견적종류', 2),
                    _buildTableHeader('가구명', 3),
                    _buildTableHeader('수량', 1),
                    _buildTableHeader('견적일자', 2),
                    _buildTableHeader('가격', 2),
                  ],
                ),
              ),
              // 테이블 내용
              ...furnitureList
                  .map((furniture) => Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColor.line1),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildTableCell('기존가구', 2),
                            _buildTableCell(furniture['name'] ?? '', 3),
                            _buildTableCell(
                                furniture['quantity']?.toString() ?? '', 1),
                            _buildTableCell(
                                _formatDate(estimate['updatedAt']), 2),
                            _buildTableCell(
                                '${_formatNumber(furniture['price'])}원', 2),
                          ],
                        ),
                      ))
                  .toList(),
              // 총 합계
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColor.line1, width: 2),
                  ),
                ),
                child: Row(
                  children: [
                    const Spacer(flex: 8),
                    _buildTableCell('총 합계', 1, isHeader: true),
                    _buildTableCell(
                      '${_formatNumber(_calculateTotal(furnitureList))}원',
                      1,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManagerSection(Map<String, dynamic> data) {
    final customer = data['customer'] as Customer;
    final userData = data['userData'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '담당자 정보',
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          width: double.infinity,
          height: 2,
          color: Colors.black,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - 48) / 2;

            return Row(
              children: [
                SizedBox(
                  width: cellWidth,
                  child: _buildInfoCell('담당자 성함', userData?['name'] ?? ''),
                ),
                // SizedBox(
                //   width: cellWidth,
                //   child: _buildInfoCell('연락처', userData?.phone ?? ''),
                // ),
              ],
            );
          },
        ),
      ],
    );
  }

// 유틸리티 함수들
  Widget _buildTableHeader(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, int flex,
      {bool isHeader = false, TextAlign textAlign = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
          textAlign: textAlign,
        ),
      ),
    );
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  int _calculateTotal(List<dynamic> furnitureList) {
    return furnitureList.fold(0, (total, furniture) {
      return total +
          ((furniture['quantity'] as int?) ?? 0) *
              ((furniture['price'] as int?) ?? 0);
    });
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.year}년 ${dt.month}월 ${dt.day}일';
    }
    return '';
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
                  SizedBox(
                    width: 137,
                    height: 17,
                    child: Image.asset('assets/images/logo.png'),
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
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: FutureBuilder<Map<String, dynamic>>(
                        future: _loadEstimateData(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                                child: Text('오류가 발생했습니다: ${snapshot.error}'));
                          }

                          if (!snapshot.hasData) {
                            return const Center(child: Text('데이터를 찾을 수 없습니다'));
                          }

                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                        Icon(Icons.notifications_none_outlined,
                                            color: AppColor.font2),
                                        SizedBox(width: 16),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 56),
                                const Text(
                                  '견적서',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.font1,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                _buildCustomerSection(snapshot.data!),
                                const SizedBox(height: 48),
                                _buildSpaceSection(snapshot.data!),
                                const SizedBox(height: 48),
                                _buildEstimateSection(snapshot.data!),
                                const SizedBox(height: 48),
                                _buildManagerSection(snapshot.data!),
                                const SizedBox(height: 48)
                              ]);
                        })))
          ],
        ),
      ),
    );
  }
}
