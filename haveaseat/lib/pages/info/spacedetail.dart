import 'dart:io';
import 'package:haveaseat/riverpod/spacemodel.dart';
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
import 'package:flutter_localizations/flutter_localizations.dart';

class SpaceDetailPage extends ConsumerStatefulWidget {
  final String customerId;

  const SpaceDetailPage({
    super.key,
    required this.customerId, // required로 필수 파라미터로 지정
  }); // 중복된 생성자 제거

  @override
  ConsumerState<SpaceDetailPage> createState() =>
      _SpaceDetailPageState(); // ConsumerState 타입으로 수정
}

class _SpaceDetailPageState extends ConsumerState<SpaceDetailPage> {
  final _formKey = GlobalKey<FormState>(); // Form Key 추가
  final _minBudgetController = TextEditingController();
  final _maxBudgetController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final _areaController = TextEditingController();
  final _customerExtraController = TextEditingController();
  String selectedUnit = '평'; // 단위 선택을 위한 상태 변수 추가
  String selectedAgeRange = '10대'; // 초기값을 '10대'로 설정
  // 단위 변환 함수
  String? selectedBusinessType; // 선택된 업종을 저장할 변수
  final List<Widget> _additionalFiles = [];
  List<File?> otherDocumentFiles = []; // 추가
  List<String> _otherDocumentUrls = []; // URL 저장용 리스트 추가
  int _fileFieldCounter = 0;
  final int _textLength = 0;
  // 업종 목록
  final List<Map<String, String>> businessTypes = [
    {'value': 'korean', 'label': '한식'},
    {'value': 'japanese', 'label': '일식'},
    {'value': 'chinese', 'label': '중식'},
    {'value': 'western', 'label': '양식'},
    {'value': 'cafe', 'label': '카페'},
    {'value': 'bakery', 'label': '베이커리'},
    {'value': 'bar', 'label': '주점'},
    {'value': 'fastfood', 'label': '패스트푸드'},
    {'value': 'other', 'label': '기타'},
  ];
  String selectedConcept = '모던'; // 초기 선택값 설정

  Widget _buildConceptButton(String text) {
    bool isSelected = selectedConcept == text;

    // 텍스트 길이에 따라 버튼 너비 조정
    double buttonWidth = text.length * 14.0 + 24.0; // 글자당 14픽셀 + 좌우 패딩

    return InkWell(
      onTap: () {
        setState(() {
          selectedConcept = text;
        });
      },
      child: Container(
        width: buttonWidth,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColor.font1 : AppColor.line1,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(18),
          color: Colors.transparent,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? AppColor.font1 : AppColor.line1,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    selectedBusinessType = null;
    _loadTempEstimate();
  }

  double convertArea(String value, String fromUnit, String toUnit) {
    if (value.isEmpty) return 0;
    double numValue = double.tryParse(value) ?? 0;
    if (fromUnit == toUnit) return numValue;
    if (fromUnit == '평' && toUnit == '㎡') {
      return numValue * 3.305785; // 평 to ㎡
    } else {
      return numValue / 3.305785; // ㎡ to 평
    }
  }

  Widget _buildAgeRangeButton(String text) {
    bool isSelected = selectedAgeRange == text;

    return InkWell(
      onTap: () {
        setState(() {
          selectedAgeRange = text; // 무조건 새로운 값으로 설정 (선택 해제 불가)
        });
      },
      child: Container(
        width: 51,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColor.font1 : AppColor.line1,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(18),
          color: Colors.transparent, // 항상 흰색 배경
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? AppColor.font1 : AppColor.line1,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  void _addFileUploadField() {
    final int currentIndex = _fileFieldCounter++;

    setState(() {
      _additionalFiles.add(
        Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FileUploadField(
                    label: '',
                    uploadPath: 'other_documents',
                    isAllFileTypes: true,
                    onFileUploaded: (String url) {
                      print('추가 파일 업로드 전 URLs: $_otherDocumentUrls');
                      setState(() {
                        if (_otherDocumentUrls.length > currentIndex) {
                          _otherDocumentUrls[currentIndex] = url;
                        } else {
                          _otherDocumentUrls.add(url);
                        }
                      });
                      print('추가 파일 업로드 후 URLs: $_otherDocumentUrls');
                    },
                    onFileSelected: (_) {}, // 웹에서는 필요 없음
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColor.font2),
                  onPressed: () {
                    setState(() {
                      _additionalFiles.removeAt(currentIndex);
                      if (_otherDocumentUrls.length > currentIndex) {
                        _otherDocumentUrls.removeAt(currentIndex);
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      );
    });
    print('파일 필드 추가됨. 현재 개수: ${_additionalFiles.length}');
  }

  // 입력값 검증 메서드
  bool _validateInputs() {
    if (_minBudgetController.text.isEmpty ||
        _maxBudgetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('예산을 입력해주세요')),
      );
      return false;
    }

    final minBudget = double.tryParse(_minBudgetController.text);
    final maxBudget = double.tryParse(_maxBudgetController.text);

    if (minBudget == null || maxBudget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 예산 금액을 입력해주세요')),
      );
      return false;
    }

    if (minBudget > maxBudget) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 예산이 최대 예산보다 클 수 없습니다')),
      );
      return false;
    }

    if (_areaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공간 면적을 입력해주세요')),
      );
      return false;
    }

    if (selectedBusinessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업종을 선택해주세요')),
      );
      return false;
    }

    return true;
  }

  // SpaceDetailPage 클래스 내에 추가할 함수들
// 임시 저장
  Future<void> _saveTempDetailInfo() async {
    try {
      // 입력값 유효성 검사는 유지
      double? minBudget = double.tryParse(_minBudgetController.text);
      double? maxBudget = double.tryParse(_maxBudgetController.text);

      // 면적 처리
      double? spaceArea;
      if (_areaController.text.isNotEmpty) {
        spaceArea = double.tryParse(_areaController.text);
        if (selectedUnit == '평') {
          spaceArea = spaceArea! * 3.305785;
        }
      }

      // 업종 가져오기
      String? businessTypeLabel;
      if (selectedBusinessType != null) {
        businessTypeLabel = businessTypes.firstWhere(
            (type) => type['value'] == selectedBusinessType)['label'];
      }

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
        'spaceDetailInfo': {
          'minBudget': minBudget,
          'maxBudget': maxBudget,
          'spaceArea': spaceArea,
          'targetAgeGroups': [selectedAgeRange],
          'businessType': businessTypeLabel,
          'concept': selectedConcept,
          'detailNotes': _noteController.text,
          'designFileUrls': _otherDocumentUrls,
        }
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
      print('Error saving temp data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('임시 저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

// 임시 저장 데이터 로드
  Future<void> _loadTempEstimate() async {
    try {
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null || customer.estimateIds.isEmpty) return;

      final estimateId = customer.estimateIds[0];
      final docSnapshot = await FirebaseFirestore.instance
          .collection('temp_estimates')
          .doc(estimateId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        final spaceDetailInfo = data['spaceDetailInfo'];

        if (spaceDetailInfo != null) {
          setState(() {
            _minBudgetController.text =
                spaceDetailInfo['minBudget']?.toString() ?? '';
            _maxBudgetController.text =
                spaceDetailInfo['maxBudget']?.toString() ?? '';

            // 면적 변환
            final area = spaceDetailInfo['spaceArea'];
            if (area != null) {
              if (selectedUnit == '평') {
                _areaController.text = (area / 3.305785).toStringAsFixed(2);
              } else {
                _areaController.text = area.toString();
              }
            }

            selectedAgeRange = spaceDetailInfo['targetAgeGroups']?[0] ?? '10대';
            final businessType = spaceDetailInfo['businessType'];
            if (businessType != null) {
              selectedBusinessType = businessTypes
                  .firstWhere((type) => type['label'] == businessType)['value'];
            }
            selectedConcept = spaceDetailInfo['concept'] ?? '모던';
            _noteController.text = spaceDetailInfo['detailNotes'] ?? '';
            _otherDocumentUrls =
                List<String>.from(spaceDetailInfo['designFileUrls'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Error loading temp data: $e');
    }
  }

// 최종 저장
  Future<void> _saveSpaceDetailInfo() async {
    if (!_validateInputs()) return;

    try {
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null || customer.estimateIds.isEmpty) {
        throw Exception('고객 정보를 찾을 수 없습니다');
      }

      final estimateId = customer.estimateIds[0];

      // 견적 업데이트
      await ref.read(estimatesProvider.notifier).updateSpaceDetailInfo(
            estimateId: estimateId,
            minBudget: double.parse(_minBudgetController.text),
            maxBudget: double.parse(_maxBudgetController.text),
            spaceArea: selectedUnit == '평'
                ? double.parse(_areaController.text) * 3.305785
                : double.parse(_areaController.text),
            targetAgeGroups: [selectedAgeRange],
            businessType: businessTypes.firstWhere(
                (type) => type['value'] == selectedBusinessType)['label']!,
            concept: selectedConcept,
            detailNotes: _noteController.text,
            designFileUrls: _otherDocumentUrls,
          );

      // 임시 저장 데이터 삭제
      await FirebaseFirestore.instance
          .collection('temp_estimates')
          .doc(estimateId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다')),
        );
        context.go('/main/addpage/spaceadd/${widget.customerId}/furniture');
      }
    } catch (e) {
      print('Error saving data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(UserProvider.userDataProvider);
    return Scaffold(
        body: ResponsiveLayout(
            mobile: const SingleChildScrollView(),
            desktop: SingleChildScrollView(
                child: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    child: SizedBox(
                      width: 240,
                      child: Container(
                        height: 1420,
                        constraints: const BoxConstraints(maxWidth: 240),
                        decoration: const BoxDecoration(
                            border: Border(
                                right: BorderSide(color: AppColor.line1))),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.center, // center로 변경
                          mainAxisAlignment: MainAxisAlignment.start,
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
                                      // crossAxisAlignment 제거
                                      Text(
                                        UserProvider.getUserName(data),
                                        style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                            color: AppColor.font1),
                                      ),
                                    ],
                                  );
                                }
                                return const Text('사용자 정보를 불러올 수 없습니다.');
                              },
                              loading: () => const CircularProgressIndicator(),
                              error: (error, stack) => Text('오류: $error'),
                            ),
                            const SizedBox(
                              height: 16,
                            ),
                            InkWell(
                              onTap: () {},
                              child: Container(
                                width: 152,
                                height: 48,
                                decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    border: Border.all(
                                      color: AppColor.line1,
                                    )),
                                child: const Center(
                                    child: Text(
                                  '정보수정',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColor.font1,
                                      fontSize: 16),
                                )),
                              ),
                            ),
                            const SizedBox(
                              height: 40,
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
                                          child: Image.asset(
                                              'assets/images/user.png')),
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
                                          child: Image.asset(
                                              'assets/images/group.png')),
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
                                          child: Image.asset(
                                              'assets/images/corp.png')),
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
                                          child: Image.asset(
                                              'assets/images/as.png')),
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
                                          child: Image.asset(
                                              'assets/images/draft.png')),
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
                            const SizedBox(
                              height: 48,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                  ),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const SizedBox(
                          height: 40,
                        ),
                        SizedBox(
                          // Container 추가하여 너비 제한
                          width: MediaQuery.of(context).size.width -
                              288, // 전체 너비 - (왼쪽 사이드바 240 + 간격 48)
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColor.font1),
                              ),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_sharp,
                                    color: AppColor.font2,
                                  ),
                                  SizedBox(width: 16),
                                  Icon(
                                    Icons.notifications_none_outlined,
                                    color: AppColor.font2,
                                  ),
                                  SizedBox(width: 43), // 오른쪽 여백 추가
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 56),
                        const Text(
                          '공간 세부 정보 입력',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColor.font1),
                        ),
                        const SizedBox(
                          height: 32,
                        ),
                        const Text(
                          '세부 정보 입력',
                          style: TextStyle(
                              fontSize: 18,
                              color: AppColor.font1,
                              fontWeight: FontWeight.w600),
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
                          '예산',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColor.font1),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        Row(
                          children: [
                            Container(
                              width: 304.5,
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColor.line1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 16,
                                  left: 16,
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      '최소예산',
                                      style: TextStyle(
                                          color: AppColor.font3, fontSize: 14),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _minBudgetController,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.0, // 라인 높이를 조정하여 수직 정렬 맞춤
                                          color: AppColor.primary,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.only(
                                              top: 2), // 2px 위로 조정
                                          isDense: true, // 더 조밀한 레이아웃
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '원',
                                      style: TextStyle(
                                          color: AppColor.font3, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 7,
                              height: 1,
                              color: AppColor.primary,
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 304.5,
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColor.line1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      '최대예산',
                                      style: TextStyle(color: AppColor.font3),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _maxBudgetController,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.0, // 라인 높이를 조정하여 수직 정렬 맞춤
                                          color: AppColor.primary,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.only(
                                              top: 2), // 2px 위로 조정
                                          isDense: true, // 더 조밀한 레이아웃
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '원',
                                      style: TextStyle(color: AppColor.font3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 24,
                        ),
                        const Text(
                          '공간 면적',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColor.font1),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        Row(
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              width: 75,
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColor.line1),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedUnit,
                                  icon: const Icon(Icons.arrow_drop_down),
                                  style: const TextStyle(
                                    color: AppColor.font1,
                                    fontSize: 14,
                                  ),
                                  isExpanded: true,
                                  alignment: AlignmentDirectional.center,
                                  items: <String>['평', '㎡']
                                      .map<DropdownMenuItem<String>>(
                                          (String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        // 현재 입력된 값을 새로운 단위로 변환
                                        String currentValue =
                                            _areaController.text;
                                        if (currentValue.isNotEmpty) {
                                          double convertedValue = convertArea(
                                              currentValue,
                                              selectedUnit,
                                              newValue);
                                          _areaController.text =
                                              convertedValue.toStringAsFixed(2);
                                        }
                                        selectedUnit = newValue;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 553,
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColor.line1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 16,
                                  left: 16,
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      '숫자 입력',
                                      style: TextStyle(
                                          color: AppColor.font3, fontSize: 14),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _areaController,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.0,
                                          color: AppColor.primary,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding:
                                              EdgeInsets.only(top: 2),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      selectedUnit, // 동적으로 단위 표시
                                      style: const TextStyle(
                                        color: AppColor.font3,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          '타깃 및 컨셉',
                          style: TextStyle(
                              fontSize: 18,
                              color: AppColor.font1,
                              fontWeight: FontWeight.w600),
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
                          '소비자 타깃',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        Row(
                          children: [
                            _buildAgeRangeButton('10대'),
                            const SizedBox(width: 8),
                            _buildAgeRangeButton('20대'),
                            const SizedBox(width: 8),
                            _buildAgeRangeButton('30대'),
                            const SizedBox(width: 8),
                            _buildAgeRangeButton('40대'),
                            const SizedBox(width: 8),
                            _buildAgeRangeButton('50대'),
                          ],
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        Container(
                          height: 48,
                          width: 640,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColor.line1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedBusinessType,
                              isExpanded: true,
                              icon: const Icon(Icons.expand_more,
                                  color: AppColor.font1),
                              hint: const Text(
                                '선택',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColor.font3,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColor.font1,
                              ),
                              items: businessTypes
                                  .map<DropdownMenuItem<String>>(
                                      (Map<String, String> item) {
                                return DropdownMenuItem<String>(
                                  value: item['value'],
                                  child: Text(
                                    item['label']!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColor.font1,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedBusinessType = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 24,
                        ),
                        const Text(
                          '공간 컨셉',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8, // 가로 간격
                              runSpacing: 12, // 세로 간격
                              children: [
                                _buildConceptButton('모던'),
                                _buildConceptButton('미니멀&심플'),
                                _buildConceptButton('내추럴'),
                                _buildConceptButton('북유럽'),
                                _buildConceptButton('빈티지&레트로'),
                                _buildConceptButton('클래식&엔틱'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 12,
                              children: [
                                _buildConceptButton('프렌치&프로방스'),
                                _buildConceptButton('러블리&로맨틱'),
                                _buildConceptButton('인더스트리얼'),
                                _buildConceptButton('한국&전통적인'),
                                _buildConceptButton('유니크'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 24,
                        ),
                        FileUploadField(
                          label: '공간 도면 및 설계 파일',
                          uploadPath: 'other_documents',
                          isAllFileTypes: true,
                          onFileUploaded: (String url) {
                            print('파일 업로드 전 URLs: $_otherDocumentUrls');
                            setState(() {
                              _otherDocumentUrls.add(url);
                            });
                            print('파일 업로드 후 URLs: $_otherDocumentUrls');
                          },
                          onFileSelected: (_) {}, // 웹에서는 필요없음
                        ),
                        ..._additionalFiles,
                        const SizedBox(
                          height: 12,
                        ),
                        InkWell(
                          onTap: () {
                            print('파일 추가 버튼 클릭');
                            _addFileUploadField();
                          },
                          child: Container(
                            height: 36,
                            width: 640,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColor.line1),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '파일 추가',
                                  style: TextStyle(
                                    color: AppColor.font1,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.add, color: AppColor.font1, size: 16)
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 40,
                        ),
                        const Text(
                          '기타 정보 입력',
                          style: TextStyle(
                              fontSize: 18,
                              color: AppColor.font1,
                              fontWeight: FontWeight.w600),
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
                          '기타 입력 사항',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColor.font1,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        Container(
                          width: 640,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColor.line1),
                          ),
                          child: Stack(
                            children: [
                              TextFormField(
                                controller: _noteController,
                                maxLength: 2000,
                                maxLines: null,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.all(16),
                                  border: InputBorder.none,
                                  hintText: '내용을 입력해주세요',
                                  hintStyle: TextStyle(
                                    color: AppColor.font2,
                                    fontSize: 14,
                                  ),
                                  counterText: '',
                                ),
                              ),
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: Text(
                                  '$_textLength/2000자',
                                  style: const TextStyle(
                                    color: AppColor.font2,
                                    fontSize: 12,
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
                                _saveTempDetailInfo();
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
                                // 고객 추가 처리
                                _saveSpaceDetailInfo();
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
                      ])),
                ],
              ),
            ))));
  }
}
