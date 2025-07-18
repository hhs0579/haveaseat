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
import 'package:uuid/uuid.dart';

class SpaceDetailPage extends ConsumerStatefulWidget {
  final String customerId;
  final String? estimateId; // 새로 추가 - 기존 견적 편집 시 사용
  final String? name; // 회사명(고객명) 변수명 통일
  const SpaceDetailPage({
    super.key,
    required this.customerId, // required로 필수 파라미터로 지정
    this.estimateId,
    this.name,
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
  Set<String> selectedConcepts = <String>{}; // 빈 Set으로 초기화
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

  @override
  void initState() {
    super.initState();
    selectedBusinessType = null;
    _loadTempEstimate();
  }

  Widget _buildConceptButton(String text) {
    bool isSelected = selectedConcepts.contains(text);
    double buttonWidth = text.length * 14.0 + 24.0;

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedConcepts.remove(text);
          } else {
            selectedConcepts.add(text);
          }
        });
      },
      child: Container(
        width: buttonWidth,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColor.main : AppColor.line1,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(18),
          color: Colors.transparent,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? AppColor.main : AppColor.line1,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

// 1. _loadTempEstimate 함수 수정
  Future<void> _loadTempEstimate() async {
    try {
      String targetEstimateId;

      // 기존 고객의 새 견적 편집 모드
      if (widget.estimateId != null) {
        targetEstimateId = widget.estimateId!;

        // estimates 컬렉션에서 직접 데이터 로드
        final estimateDoc = await FirebaseFirestore.instance
            .collection('estimates')
            .doc(targetEstimateId)
            .get();

        if (estimateDoc.exists) {
          final data = estimateDoc.data()!;
          setState(() {
            _minBudgetController.text = data['minBudget']?.toString() ?? '';
            _maxBudgetController.text = data['maxBudget']?.toString() ?? '';
            selectedUnit = data['spaceUnit'] ?? '평';
            _areaController.text = data['spaceArea']?.toString() ?? '';

            final concepts = data['concept'] as List<dynamic>?;
            if (concepts != null) {
              selectedConcepts = concepts.map((e) => e.toString()).toSet();
            }

            final targetAgeGroups = data['targetAgeGroups'] as List<dynamic>?;
            selectedAgeRange =
                (targetAgeGroups != null && targetAgeGroups.isNotEmpty)
                    ? targetAgeGroups[0]
                    : '10대';

            final businessType = data['businessType'];
            if (businessType != null) {
              final foundType = businessTypes.firstWhere(
                  (type) => type['label'] == businessType,
                  orElse: () => {'value': '', 'label': ''});
              selectedBusinessType =
                  foundType['value'] != null && foundType['value']!.isNotEmpty
                      ? foundType['value']
                      : null;
            }

            _noteController.text = data['detailNotes'] ?? '';
            _otherDocumentUrls =
                List<String>.from(data['designFileUrls'] ?? []);
          });
        }
        return;
      }

      // 새 고객 추가 모드 (기존 로직)
      final customer = await ref
          .read(customerDataProvider.notifier)
          .getCustomer(widget.customerId);
      if (customer == null || customer.estimateIds.isEmpty) return;

      targetEstimateId = customer.estimateIds[0];

      // temp_estimates에서 데이터 로드 (기존 로직)
      final docSnapshot = await FirebaseFirestore.instance
          .collection('temp_estimates')
          .doc(targetEstimateId)
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
            selectedUnit = spaceDetailInfo['spaceUnit'] ?? '평';
            _areaController.text =
                spaceDetailInfo['spaceArea']?.toString() ?? '';

            final concepts = spaceDetailInfo['concept'] as List<dynamic>?;
            if (concepts != null) {
              selectedConcepts = concepts.map((e) => e.toString()).toSet();
            }

            final targetAgeGroups =
                spaceDetailInfo['targetAgeGroups'] as List<dynamic>?;
            selectedAgeRange =
                (targetAgeGroups != null && targetAgeGroups.isNotEmpty)
                    ? targetAgeGroups[0]
                    : '10대';
            final businessType = spaceDetailInfo['businessType'];
            if (businessType != null) {
              final foundType = businessTypes.firstWhere(
                  (type) => type['label'] == businessType,
                  orElse: () => {'value': '', 'label': ''});
              selectedBusinessType =
                  foundType['value'] != null && foundType['value']!.isNotEmpty
                      ? foundType['value']
                      : null;
            }

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

  // 이전 버튼 누르면 이전에 작성한 값 불러오기 (estimates → customers 순, type별 하위맵 우선)
  void _loadPreviousData() async {
    try {
      final estimateId = widget.estimateId;
      if (estimateId != null) {
        final estimateDoc = await FirebaseFirestore.instance
            .collection('estimates')
            .doc(estimateId)
            .get();
        if (estimateDoc.exists) {
          final data = estimateDoc.data()!;
          final type = data['type'] ?? '';
          if (type == '공간상세' && data['spaceDetailInfo'] != null) {
            final detail = data['spaceDetailInfo'];
            setState(() {
              _minBudgetController.text = detail['minBudget']?.toString() ?? '';
              _maxBudgetController.text = detail['maxBudget']?.toString() ?? '';
              selectedUnit = detail['spaceUnit'] ?? '평';
              _areaController.text = detail['spaceArea']?.toString() ?? '';
              _noteController.text = detail['detailNotes'] ?? '';
              // 기타 필요한 필드도 동일하게 복원
            });
          } else {
            setState(() {
              _minBudgetController.text = data['minBudget']?.toString() ?? '';
              _maxBudgetController.text = data['maxBudget']?.toString() ?? '';
              selectedUnit = data['spaceUnit'] ?? '평';
              _areaController.text = data['spaceArea']?.toString() ?? '';
              _noteController.text = data['detailNotes'] ?? '';
            });
          }
          return;
        }
      }
      // customers에서 복원
      final customerId = widget.customerId;
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .get();
      if (customerDoc.exists) {
        final data = customerDoc.data()!;
        setState(() {
          _minBudgetController.text = '';
          _maxBudgetController.text = '';
          selectedUnit = '평';
          _areaController.text = '';
          _noteController.text = data['note'] ?? '';
        });
      }
    } catch (e) {
      print('이전 데이터 불러오기 오류: $e');
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

  Widget _buildAgeRangeButton(String text) {
    bool isSelected = selectedAgeRange == text;

    return InkWell(
      onTap: () {
        setState(() {
          selectedAgeRange = text;
        });
      },
      child: Container(
        width: 51,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColor.main : AppColor.line1,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(18),
          color: Colors.transparent,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? AppColor.main : AppColor.line1,
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
                      setState(() {
                        if (_otherDocumentUrls.length > currentIndex) {
                          _otherDocumentUrls[currentIndex] = url;
                        } else {
                          _otherDocumentUrls.add(url);
                        }
                      });
                    },
                    onFileSelected: (_) {},
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
  }

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

    if (selectedConcepts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('컨셉을 하나 이상 선택해주세요')),
      );
      return false;
    }

    return true;
  }

  // 임시 저장 함수
  Future<void> _saveTempDetailInfo() async {
    try {
      String estimateId = widget.estimateId ?? '';
      if (estimateId.isEmpty) {
        final estimateRef =
            FirebaseFirestore.instance.collection('estimates').doc();
        estimateId = estimateRef.id;
        // 견적 최초 생성시에만 customers.estimateIds 추가
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .set({
          'estimateIds': [estimateId],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      // name 값 보장: widget.name이 없으면 Firestore에서 고객명 조회
      String? nameValue = widget.name;
      if (nameValue == null || nameValue.trim().isEmpty) {
        final customerDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .get();
        nameValue = customerDoc.data()?['name'] ?? '무제';
      }
      final estimateRef =
          FirebaseFirestore.instance.collection('estimates').doc(estimateId);
      final tempData = {
        'customerId': widget.customerId,
        'estimateId': estimateId,
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isDraft': true,
        'type': '공간상세',
        'name': nameValue,
        'spaceDetailInfo': {
          'minBudget': double.tryParse(_minBudgetController.text),
          'maxBudget': double.tryParse(_maxBudgetController.text),
          'spaceArea': double.tryParse(_areaController.text),
          'spaceUnit': selectedUnit,
          'targetAgeGroups': [selectedAgeRange],
          'businessType': businessTypes.firstWhere(
              (type) => type['value'] == selectedBusinessType,
              orElse: () => {'label': ''})['label'],
          'concept': selectedConcepts.toList(),
          'detailNotes': _noteController.text,
          'designFileUrls': _otherDocumentUrls,
        }
      };
      print('임시저장 tempData: $tempData');
      await estimateRef.set(tempData, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('임시 저장되었습니다')),
      );
      context.go('/temp');
    } catch (e) {
      print('임시 저장 중 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('임시 저장 중 오류가 발생했습니다: $e')),
        );
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
        // 견적 최초 생성시에만 customers.estimateIds 추가
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .set({
          'estimateIds': [estimateId],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      final estimateRef =
          FirebaseFirestore.instance.collection('estimates').doc(estimateId);
      final tempData = {
        'customerId': widget.customerId,
        'estimateId': estimateId,
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isDraft': true,
        'type': '가구',
        'name': widget.name ?? '무제',
        'spaceDetailInfo': {
          'minBudget': double.tryParse(_minBudgetController.text),
          'maxBudget': double.tryParse(_maxBudgetController.text),
          'spaceArea': double.tryParse(_areaController.text),
          'spaceUnit': selectedUnit,
          'targetAgeGroups': [selectedAgeRange],
          'businessType': businessTypes.firstWhere(
              (type) => type['value'] == selectedBusinessType,
              orElse: () => {'label': ''})['label'],
          'concept': selectedConcepts.toList(),
          'detailNotes': _noteController.text,
          'designFileUrls': _otherDocumentUrls,
        }
      };
      await estimateRef.set(tempData, SetOptions(merge: true));
      context.go(
          '/main/addpage/spaceadd/${widget.customerId}/$estimateId/space-detail/furniture',
          extra: {'companyName': widget.name ?? '무제'});
    } catch (e) {
      print('다음 단계 저장 중 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다음 단계 저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _saveSpaceDetailInfo() async {
    if (!_validateInputs()) return;
    try {
      String estimateId = widget.estimateId ?? '';
      if (estimateId.isEmpty) {
        final estimateRef =
            FirebaseFirestore.instance.collection('estimates').doc();
        estimateId = estimateRef.id;
        // 견적 최초 생성시에만 customers.estimateIds 추가
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .set({
          'estimateIds': [estimateId],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      final estimateData = {
        'minBudget': double.parse(_minBudgetController.text),
        'maxBudget': double.parse(_maxBudgetController.text),
        'spaceArea': double.parse(_areaController.text),
        'spaceUnit': selectedUnit,
        'targetAgeGroups': [selectedAgeRange],
        'businessType': businessTypes.firstWhere(
            (type) => type['value'] == selectedBusinessType,
            orElse: () => {'label': ''})['label'],
        'concept': selectedConcepts.toList(),
        'detailNotes': _noteController.text,
        'designFileUrls': _otherDocumentUrls,
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDraft': false,
        'customerId': widget.customerId,
        'estimateId': estimateId,
      };
      await FirebaseFirestore.instance
          .collection('estimates')
          .doc(estimateId)
          .set(estimateData, SetOptions(merge: true));
      await ref.read(estimatesProvider.notifier).updateSpaceDetailInfo(
            estimateId: estimateId,
            minBudget: double.parse(_minBudgetController.text),
            maxBudget: double.parse(_maxBudgetController.text),
            spaceArea: double.parse(_areaController.text),
            spaceUnit: selectedUnit,
            targetAgeGroups: [selectedAgeRange],
            businessType: businessTypes.firstWhere(
                (type) => type['value'] == selectedBusinessType,
                orElse: () => {'label': ''})['label']!,
            concept: selectedConcepts.toList(),
            detailNotes: _noteController.text,
            designFileUrls: _otherDocumentUrls,
          );
      if (widget.estimateId == null) {
        await FirebaseFirestore.instance
            .collection('temp_estimates')
            .doc(estimateId)
            .delete();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다')),
        );
        if (widget.estimateId != null) {
          context.go(
              '/main/customer/${widget.customerId}/estimate/${widget.estimateId}/edit/space-detail/furniture');
        } else {
          context.go(
              '/main/addpage/spaceadd/${widget.customerId}/space-detail/furniture');
        }
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
            desktop: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeFocus(
                    child: Container(
                      width: 240,
                      height: MediaQuery.of(context).size.height,
                      decoration: const BoxDecoration(
                        border:
                            Border(right: BorderSide(color: AppColor.line1)),
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
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: InkWell(
                              onTap: _handleLogout,
                              child: Container(
                                width: 200,
                                height: 48,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.red.shade300),
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
                  const SizedBox(
                    width: 48,
                  ),
                  Expanded(
                      child: SingleChildScrollView(
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
                                            color: AppColor.font3,
                                            fontSize: 14),
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
                                            color: AppColor.font3,
                                            fontSize: 14),
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
                                          selectedUnit = newValue; // 단순히 단위만 변경
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
                                            color: AppColor.font3,
                                            fontSize: 14),
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
                                  Icon(Icons.add,
                                      color: AppColor.font1, size: 16)
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
                          const SizedBox(
                            height: 48,
                          ),
                        ]),
                  )),
                ],
              ),
            )));
  }
}
