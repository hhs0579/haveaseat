import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
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
import 'package:screenshot/screenshot.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CustomerEstimatePage extends ConsumerStatefulWidget {
  final String customerId;
  final String estimateId;

  const CustomerEstimatePage({
    super.key,
    required this.customerId,
    required this.estimateId,
  });

  @override
  ConsumerState<CustomerEstimatePage> createState() =>
      _CustomerEstimatePageState();
}

class _CustomerEstimatePageState extends ConsumerState<CustomerEstimatePage> {
  final screenshotController = ScreenshotController();

  Future<Map<String, dynamic>> _loadEstimateData() async {
    try {
      // 고객 정보 가져오기
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null) throw Exception('고객 정보를 찾을 수 없습니다');

      // 견적 정보 가져오기 (URL에서 전달받은 estimateId 사용)
      final estimateDoc = await FirebaseFirestore.instance
          .collection('estimates')
          .doc(widget.estimateId)
          .get();

      if (!estimateDoc.exists) throw Exception('견적 정보를 찾을 수 없습니다');

      // 담당자 정보 가져오기 (assignedTo 필드 사용)
      final managerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customer.assignedTo)
          .get();

      return {
        'customer': customer,
        'estimate': estimateDoc.data(),
        'userData': managerDoc.data(), // 담당자 정보 추가
      };
    } catch (e) {
      print('Error loading estimate data: $e');
      rethrow;
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '고객 정보',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black),
            ),
            InkWell(
              onTap: () {
                context.go('/main/customer/${customer.id}/edit');
              },
              child: const Text(
                '수정하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xff757575),
                ),
              ),
            ),
          ],
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '공간 정보',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black),
            ),
            InkWell(
              onTap: () {
                context.go(
                    '/main/customer/${widget.customerId}/estimate/${widget.estimateId}/edit/space-basic');
              },
              child: const Text(
                '수정하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xff757575),
                ),
              ),
            ),
          ],
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
                      child: _buildInfoCell(
                          '공간컨셉', estimate['concept']?.join(', ') ?? ''),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '견적 정보',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black),
            ),
            InkWell(
              onTap: () {
                context.go(
                    '/main/customer/${widget.customerId}/estimate/${widget.estimateId}/edit/space-detail/furniture');
              },
              child: const Text(
                '수정하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xff757575),
                ),
              ),
            ),
          ],
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
                SizedBox(
                  width: cellWidth,
                  child: _buildInfoCell('연락처', userData?['phoneNumber'] ?? ''),
                ),
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

  Future<void> generatePDF(Map<String, dynamic> data) async {
    try {
      final regularFont = await rootBundle.load(
          'assets/fonts/notosans/Noto_Sans_KR/static/NotoSansKR-Regular.ttf');
      final boldFont = await rootBundle.load(
          'assets/fonts/notosans/Noto_Sans_KR/static/NotoSansKR-Bold.ttf');

      final ttf = pw.Font.ttf(regularFont);
      final ttfBold = pw.Font.ttf(boldFont);

      final pdf = pw.Document();

      // 넓은 페이지 크기 설정 (A4 너비의 두 배, 높이는 자동)
      final pageFormat = PdfPageFormat(
        PdfPageFormat.a4.width * 1.5, // 너비를 1.5배로
        PdfPageFormat.a4.height * 2, // 높이를 2배로 (필요에 따라 조정)
        marginAll: 40,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return _buildPDFContent(data, ttf, ttfBold);
          },
        ),
      );

      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement()
        ..href = url
        ..style.display = 'none'
        ..download = _generateFileName(data);
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print('Error generating PDF: $e');
    }
  }

  String _generateFileName(Map<String, dynamic> data) {
    // 현재 날짜 가져오기
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // 고객 정보 가져오기
    final customer = data['customer'] as Customer;
    final customerName = customer.name.replaceAll(' ', '_'); // 공백을 언더스코어로 변경

    // 발주번호나 견적번호가 있다면 사용
    final estimateId =
        customer.estimateIds.isNotEmpty ? customer.estimateIds[0] : '';
    final shortEstimateId =
        estimateId.length > 8 ? estimateId.substring(0, 8) : estimateId;

    // 파일명 생성
    return '견적서_${customerName}_${dateStr}_$shortEstimateId.pdf';
  }

  pw.Widget _buildPDFContent(
      Map<String, dynamic> data, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // 헤더
        _buildPDFHeader(ttfBold),
        pw.SizedBox(height: 56),

        // 제목
        pw.Text(
          '견적서',
          style: pw.TextStyle(
              fontSize: 24, font: ttfBold, color: PdfColor.fromHex('1A1A1A')),
        ),
        pw.SizedBox(height: 32),

        // 각 섹션 - 고객정보 추가, 공간정보 제거
        _buildPDFCustomerSectionWithEstimate(
            data['customer'], data['estimate'], ttf, ttfBold),
        pw.SizedBox(height: 48),
        _buildPDFEstimateSection(data['estimate'], ttf, ttfBold),
        pw.SizedBox(height: 48),
        _buildPDFManagerSection(data['userData'], ttf, ttfBold),
      ],
    );
  }

  pw.Widget _buildPDFCustomerSectionWithEstimate(Customer customer,
      Map<String, dynamic> estimate, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '고객 정보',
          style: pw.TextStyle(
              fontSize: 18, font: ttfBold, color: PdfColor.fromHex('1A1A1A')),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          height: 2,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('000000'),
          ),
        ),
        pw.SizedBox(height: 24),

        // 고객명과 연락처
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildPDFInfoCell('고객명', customer.name, ttf),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: _buildPDFInfoCell('연락처', customer.phone, ttf),
            ),
          ],
        ),

        pw.SizedBox(height: 12),

        // 수령자와 수령자 연락처
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildPDFInfoCell('수령자', estimate['recipient'] ?? '', ttf),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: _buildPDFInfoCell(
                  '수령자 연락처', estimate['contactNumber'] ?? '', ttf),
            ),
          ],
        ),

        pw.SizedBox(height: 12),

        // 배송지와 기타입력사항
        pw.Row(
          children: [
            pw.Expanded(
              child:
                  _buildPDFInfoCell('배송지', estimate['siteAddress'] ?? '', ttf),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: _buildPDFInfoCell('기타입력사항', customer.note, ttf),
            ),
          ],
        ),
      ],
    );
  }

// PDF 헤더 위젯
  pw.Widget _buildPDFHeader(pw.Font ttfBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일',
          style: pw.TextStyle(
            fontSize: 18,
            font: ttfBold,
            color: PdfColor.fromHex('1A1A1A'),
          ),
        ),
      ],
    );
  }

// PDF 고객 정보 섹션
  pw.Widget _buildPDFCustomerSection(
      Customer customer, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '고객 정보',
          style: pw.TextStyle(
              fontSize: 18, font: ttfBold, color: PdfColor.fromHex('1A1A1A')),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          height: 2,
          color: PdfColor.fromHex('000000'),
        ),
        pw.SizedBox(height: 24),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(children: [
              _buildPDFInfoCell('고객명', customer.name, ttf),
              _buildPDFInfoCell('연락처', customer.phone, ttf),
            ]),
            pw.TableRow(children: [
              _buildPDFInfoCell('이메일주소', customer.email, ttf),
              _buildPDFInfoCell('배송지주소', customer.address, ttf),
            ]),
            pw.TableRow(children: [
              _buildPDFInfoCell(
                  '사업자등록증',
                  customer.businessLicenseUrl.isEmpty
                      ? '미첨부'
                      : getFileName(customer.businessLicenseUrl),
                  ttf),
              _buildPDFInfoCell(
                  '기타서류',
                  customer.otherDocumentUrls.isEmpty
                      ? '미첨부'
                      : getFileName(customer.otherDocumentUrls.first),
                  ttf),
            ]),
          ],
        ),
        _buildPDFFullWidthCell('기타입력사항', customer.note, ttf),
      ],
    );
  }

// PDF 공간 정보 섹션
  pw.Widget _buildPDFSpaceSection(
      Map<String, dynamic> estimate, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '공간 정보',
          style: pw.TextStyle(
              fontSize: 18, font: ttfBold, color: PdfColor.fromHex('1A1A1A')),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          height: 2,
          color: PdfColor.fromHex('000000'),
        ),
        pw.SizedBox(height: 24),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(children: [
              _buildPDFInfoCell('현장주소', estimate['siteAddress'] ?? '', ttf),
              _buildPDFInfoCell(
                  '공간오픈일정', _formatDate(estimate['openingDate']), ttf),
            ]),
            pw.TableRow(children: [
              _buildPDFInfoCell(
                  '예산',
                  '${estimate['minBudget']?.toString() ?? '0'} ~ ${estimate['maxBudget']?.toString() ?? '0'}원',
                  ttf),
              _buildPDFInfoCell(
                  '공간면적', '${estimate['spaceArea']?.toString() ?? '0'} ㎡', ttf),
            ]),
            pw.TableRow(children: [
              _buildPDFInfoCell('업종', estimate['businessType'] ?? '', ttf),
              _buildPDFInfoCell(
                  '공간컨셉',
                  (estimate['concept'] as List<dynamic>?)?.join(', ') ?? '',
                  ttf),
            ]),
            pw.TableRow(children: [
              _buildPDFInfoCell('수령자', estimate['recipient'] ?? '', ttf),
              _buildPDFInfoCell('연락처', estimate['contactNumber'] ?? '', ttf),
            ]),
            pw.TableRow(children: [
              _buildPDFInfoCell('배송방법', estimate['shippingMethod'] ?? '', ttf),
              _buildPDFInfoCell('결제방법', estimate['paymentMethod'] ?? '', ttf),
            ]),
          ],
        ),
        _buildPDFFullWidthCell('기타입력사항', estimate['basicNotes'] ?? '', ttf),
      ],
    );
  }

// PDF 담당자 정보 섹션
  pw.Widget _buildPDFManagerSection(
      Map<String, dynamic>? userData, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // 섹션 제목
        pw.Text(
          '담당자 정보',
          style: pw.TextStyle(
              fontSize: 18, font: ttfBold, color: PdfColor.fromHex('1A1A1A')),
        ),
        pw.SizedBox(height: 12),

        // 구분선
        pw.Container(
          width: double.infinity,
          height: 2,
          color: PdfColor.fromHex('000000'),
        ),
        pw.SizedBox(height: 24),

        // 담당자 정보 테이블
        pw.Row(
          children: [
            // 담당자 성함
            pw.Expanded(
              child: pw.Container(
                height: 48,
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColor.fromHex('EAEAEC')),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 120,
                      color: PdfColor.fromHex('F7F7FB'),
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: pw.Text(
                        '담당자 성함',
                        style: pw.TextStyle(
                          fontSize: 14,
                          font: ttf,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                        child: pw.Text(
                          userData?['name'] ?? '',
                          style: pw.TextStyle(
                            fontSize: 14,
                            font: ttf,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 24),
            // 연락처
            pw.Expanded(
              child: pw.Container(
                height: 48,
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColor.fromHex('EAEAEC')),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 120,
                      color: PdfColor.fromHex('F7F7FB'),
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: pw.Text(
                        '연락처',
                        style: pw.TextStyle(
                          fontSize: 14,
                          font: ttf,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                        child: pw.Text(
                          userData?['phoneNumber'] ?? '',
                          style: pw.TextStyle(
                            fontSize: 14,
                            font: ttf,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

// PDF용 정보 셀 위젯
  pw.Widget _buildPDFInfoCell(String label, String value, pw.Font ttf) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromHex('EAEAEC')),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 120,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('F7F7FB'),
            ),
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 14, font: ttf),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8),
              child: pw.Text(
                value,
                style: pw.TextStyle(fontSize: 14, font: ttf),
              ),
            ),
          ),
        ],
      ),
    );
  }

// PDF용 전체 너비 셀 위젯
  pw.Widget _buildPDFFullWidthCell(String label, String value, pw.Font ttf) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border:
            pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('EAEAEC'))),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 120,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            color: PdfColor.fromHex('F7F7FB'),
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 14, font: ttf),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8),
              child: pw.Text(
                value,
                style: pw.TextStyle(fontSize: 14, font: ttf),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String getFileName(String url) {
    try {
      String fileName = url.split('/').last;
      fileName = Uri.decodeFull(fileName);
      fileName = fileName.split('?').first;
      return fileName;
    } catch (e) {
      return url;
    }
  }

  pw.Widget _buildPDFSection(
      String title, List<pw.Widget> content, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
              fontSize: 18, font: ttfBold, color: PdfColor.fromHex('1A1A1A')),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom:
                  pw.BorderSide(color: PdfColor.fromHex('000000'), width: 2),
            ),
          ),
        ),
        pw.SizedBox(height: 24),
        ...content,
      ],
    );
  }

  pw.Widget _buildPDFInfoRow(String label, String value, pw.Font ttf) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromHex('EAEAEC')),
        ),
      ),
      height: 48,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 120,
            color: PdfColor.fromHex('F7F7FB'),
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 14, font: ttf),
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16),
              child: pw.Text(
                value,
                style: pw.TextStyle(fontSize: 14, font: ttf),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFEstimateSection(
      Map<String, dynamic> estimate, pw.Font ttf, pw.Font ttfBold) {
    final furnitureList = (estimate['furnitureList'] as List<dynamic>?) ?? [];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '견적 정보',
          style: pw.TextStyle(
              fontSize: 18, font: ttfBold, color: PdfColor.fromHex('1A1A1A')),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom:
                  pw.BorderSide(color: PdfColor.fromHex('000000'), width: 2),
            ),
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('EAEAEC')),
          ),
          child: pw.Column(
            children: [
              // 테이블 헤더 - 구분선 추가
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F7F7FB'),
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColor.fromHex('EAEAEC')),
                  ),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                        flex: 4,
                        child:
                            pw.Text('상품명', style: pw.TextStyle(font: ttfBold))),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('EAEAEC'),
                      ),
                    ),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('단가',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.center)),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('EAEAEC'),
                      ),
                    ),
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text('수량',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.center)),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('EAEAEC'),
                      ),
                    ),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text('금액',
                            style: pw.TextStyle(font: ttfBold),
                            textAlign: pw.TextAlign.center)),
                  ],
                ),
              ),
              // 테이블 내용 - 모든 행에 구분선 추가
              ...furnitureList.map((furniture) => pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom:
                            pw.BorderSide(color: PdfColor.fromHex('EAEAEC')),
                      ),
                    ),
                    padding: const pw.EdgeInsets.all(16),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                            flex: 4,
                            child: pw.Text(furniture['name'] ?? '',
                                style: pw.TextStyle(font: ttf))),
                        pw.Container(
                          width: 1,
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('EAEAEC'),
                          ),
                        ),
                        pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                                '${_formatNumber(furniture['price'])}원',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.center)),
                        pw.Container(
                          width: 1,
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('EAEAEC'),
                          ),
                        ),
                        pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                                furniture['quantity']?.toString() ?? '',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.center)),
                        pw.Container(
                          width: 1,
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('EAEAEC'),
                          ),
                        ),
                        pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                                '${_formatNumber((furniture['price'] ?? 0) * (furniture['quantity'] ?? 0))}원',
                                style: pw.TextStyle(font: ttf),
                                textAlign: pw.TextAlign.center)),
                      ],
                    ),
                  )),
              // 견적일자와 총금액 행 - 색상 분리
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(
                        color: PdfColor.fromHex('000000'), width: 2),
                    bottom: pw.BorderSide(color: PdfColor.fromHex('EAEAEC')),
                  ),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Row(
                  children: [
                    // 견적일자 레이블 (회색 배경)
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('F7F7FB'),
                        ),
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '견적일자',
                          style: pw.TextStyle(font: ttfBold, fontSize: 14),
                        ),
                      ),
                    ),
                    // 견적일자 값 (흰색 배경)
                    pw.Expanded(
                      flex: 3,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('FFFFFF'),
                        ),
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _formatDate(estimate['updatedAt']),
                          style: pw.TextStyle(font: ttf, fontSize: 14),
                        ),
                      ),
                    ),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('EAEAEC'),
                      ),
                    ),
                    // 총금액 레이블 (회색 배경)
                    pw.Expanded(
                      flex: 1,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('F7F7FB'),
                        ),
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '총금액',
                          style: pw.TextStyle(font: ttfBold, fontSize: 14),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                    pw.Container(
                      width: 1,
                      height: 20,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('EAEAEC'),
                      ),
                    ),
                    // 총금액 값 (흰색 배경)
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('FFFFFF'),
                        ),
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '${_formatNumber(_calculateTotal(furnitureList))}원',
                          style: pw.TextStyle(font: ttfBold, fontSize: 14),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 메모 섹션
        pw.SizedBox(height: 16),
      ],
    );
  }

  // PDF 테이블 셀 생성 헬퍼 함수
  pw.Widget _buildPDFTableCell(String text, {bool header = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: header ? pw.FontWeight.bold : null,
        ),
      ),
    );
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
            // 메인 컨텐츠
// 테이블 영역 부분만 수정
// 메인 컨텐츠 영역
            Expanded(
              child: Screenshot(
                  controller: screenshotController,
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
                              return const Center(
                                  child: Text('데이터를 찾을 수 없습니다'));
                            }

                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
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
                                            SizedBox(
                                              width: 4,
                                            ),
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
                                          Icon(
                                              Icons.notifications_none_outlined,
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
                                  _buildEstimateSection(snapshot.data!),
                                  const SizedBox(height: 48),
                                  _buildSpaceSection(snapshot.data!),
                                  const SizedBox(height: 48),
                                  _buildManagerSection(snapshot.data!),
                                  const SizedBox(height: 48),
                                  InkWell(
                                    onTap: () {
                                      generatePDF(snapshot.data!);
                                    },
                                    child: Container(
                                      height: 48,
                                      width: 131,
                                      decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          border: Border.all(
                                              color: AppColor.line1, width: 1)),
                                      child: const Center(
                                        child: Text(
                                          '견적서 다운로드',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]);
                          }))),
            ),
          ],
        ),
      ),
    );
  }
}
