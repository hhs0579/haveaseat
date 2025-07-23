import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'package:haveaseat/widget/address.dart';
import 'package:haveaseat/widget/fileupload.dart';

class EstimateEditPage extends ConsumerStatefulWidget {
  final String customerId;
  final String estimateId;

  const EstimateEditPage({
    super.key,
    required this.customerId,
    required this.estimateId,
  });

  @override
  ConsumerState<EstimateEditPage> createState() => _EstimateEditPageState();
}

class _EstimateEditPageState extends ConsumerState<EstimateEditPage> {
  final _formKey = GlobalKey<FormState>();

  // 페이지 상태 관리
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // 공간 기본 정보
  final _siteAddressController = TextEditingController();
  final _detailSiteAddressController = TextEditingController();
  final _recipientController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _additionalNotesController = TextEditingController();
  DateTime? _openingDate;
  String? _shippingMethod;
  String? _paymentMethod;

  // 공간 상세 정보
  final _minBudgetController = TextEditingController();
  final _maxBudgetController = TextEditingController();
  final _areaController = TextEditingController();
  final _detailNotesController = TextEditingController();
  String _selectedUnit = '평';
  String _selectedBusinessType = '';
  List<String> _selectedAgeGroups = [];
  List<String> _selectedConcepts = [];
  List<String> _designFileUrls = [];

  // 가구 정보
  List<ExistingFurniture> _furnitureList = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEstimateData();
  }

  @override
  void dispose() {
    _siteAddressController.dispose();
    _detailSiteAddressController.dispose();
    _recipientController.dispose();
    _contactNumberController.dispose();
    _additionalNotesController.dispose();
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    _areaController.dispose();
    _detailNotesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadEstimateData() async {
    try {
      final estimateDoc = await FirebaseFirestore.instance
          .collection('estimates')
          .doc(widget.estimateId)
          .get();

      if (estimateDoc.exists) {
        final data = estimateDoc.data()!;

        setState(() {
          // 공간 기본 정보
          _siteAddressController.text = data['siteAddress'] ?? '';
          _recipientController.text = data['recipient'] ?? '';
          _contactNumberController.text = data['contactNumber'] ?? '';
          _additionalNotesController.text = data['basicNotes'] ?? '';
          _openingDate = (data['openingDate'] as Timestamp?)?.toDate();

          // 드롭다운 값들 - null이면 기본값 설정, 빈 문자열이면 null로 설정
          final shippingMethodValue = data['shippingMethod'] as String?;
          _shippingMethod =
              (shippingMethodValue == null || shippingMethodValue.isEmpty)
                  ? null
                  : shippingMethodValue;

          final paymentMethodValue = data['paymentMethod'] as String?;
          _paymentMethod =
              (paymentMethodValue == null || paymentMethodValue.isEmpty)
                  ? null
                  : paymentMethodValue;

          // 공간 상세 정보
          _minBudgetController.text = data['minBudget']?.toString() ?? '';
          _maxBudgetController.text = data['maxBudget']?.toString() ?? '';
          _areaController.text = data['spaceArea']?.toString() ?? '';
          _detailNotesController.text = data['detailNotes'] ?? '';
          _selectedUnit = data['spaceUnit'] ?? '평';
          _selectedBusinessType = data['businessType'] ?? '';
          _selectedAgeGroups = List<String>.from(data['targetAgeGroups'] ?? []);
          _selectedConcepts = List<String>.from(data['concept'] ?? []);
          _designFileUrls = List<String>.from(data['designFileUrls'] ?? []);

          // 가구 정보
          _furnitureList = (data['furnitureList'] as List<dynamic>?)
                  ?.map((e) => ExistingFurniture.fromJson(e))
                  .toList() ??
              [];

          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading estimate data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 단계별 페이지 이동
  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // 공간 기본 정보 저장
  Future<void> _saveSpaceBasicInfo() async {
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) throw Exception('로그인이 필요합니다');

      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final estimateData = {
        'siteAddress':
            '${_siteAddressController.text} ${_detailSiteAddressController.text}',
        'openingDate':
            _openingDate != null ? Timestamp.fromDate(_openingDate!) : null,
        'recipient': _recipientController.text,
        'contactNumber': _contactNumberController.text,
        'shippingMethod': _shippingMethod ?? '',
        'paymentMethod': _paymentMethod ?? '',
        'basicNotes': _additionalNotesController.text,
        'managerName': userData.data()?['name'] ?? '',
        'managerPhone': userData.data()?['phoneNumber'] ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('estimates')
          .doc(widget.estimateId)
          .set(estimateData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공간 기본 정보가 수정되었습니다')),
        );
        context.go('/main/customer/${widget.customerId}');
      }
    } catch (e) {
      print('Error saving space basic info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 공간 상세 정보 저장
  Future<void> _saveSpaceDetailInfo() async {
    try {
      final estimateData = {
        'minBudget': double.tryParse(_minBudgetController.text) ?? 0,
        'maxBudget': double.tryParse(_maxBudgetController.text) ?? 0,
        'spaceArea': double.tryParse(_areaController.text) ?? 0,
        'spaceUnit': _selectedUnit,
        'businessType': _selectedBusinessType,
        'targetAgeGroups': _selectedAgeGroups,
        'concept': _selectedConcepts,
        'detailNotes': _detailNotesController.text,
        'designFileUrls': _designFileUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('estimates')
          .doc(widget.estimateId)
          .set(estimateData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공간 상세 정보가 수정되었습니다')),
        );
        context.go('/main/customer/${widget.customerId}');
      }
    } catch (e) {
      print('Error saving space detail info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 가구 정보 저장
  Future<void> _saveFurnitureInfo() async {
    try {
      final estimateData = {
        'furnitureList': _furnitureList.map((f) => f.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('estimates')
          .doc(widget.estimateId)
          .set(estimateData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가구 정보가 수정되었습니다')),
        );
        context.go('/main/customer/${widget.customerId}');
      }
    } catch (e) {
      print('Error saving furniture info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: ResponsiveLayout(
        mobile: const Center(child: Text('모바일은 지원되지 않습니다')),
        desktop: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildStepIndicator(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildSpaceBasicInfoPage(),
                        _buildSpaceDetailInfoPage(),
                        _buildFurnitureInfoPage(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final userData = ref.watch(UserProvider.userDataProvider);

    return Container(
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
                return Text(
                  UserProvider.getUserName(data),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColor.font1,
                  ),
                );
              }
              return const Text('사용자 정보를 불러올 수 없습니다.');
            },
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => Text('오류: $error'),
          ),
          const SizedBox(height: 16),
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
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: InkWell(
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                context.go('/login');
              },
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
                    Icon(Icons.logout, color: Colors.red.shade300, size: 20),
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
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => context.go('/main/customer/${widget.customerId}'),
            child: const Row(
              children: [
                Icon(Icons.arrow_back_ios),
                SizedBox(width: 4),
                Text(
                  '이전',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '견적 편집',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColor.font1,
            ),
          ),
          const Row(
            children: [
              Icon(Icons.person_outline_sharp, color: AppColor.font2),
              SizedBox(width: 16),
              Icon(Icons.notifications_none_outlined, color: AppColor.font2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildStepItem(0, '공간 기본 정보'),
          _buildStepConnector(0),
          _buildStepItem(1, '공간 상세 정보'),
          _buildStepConnector(1),
          _buildStepItem(2, '가구 정보'),
        ],
      ),
    );
  }

  Widget _buildStepItem(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? AppColor.main
            : (isCompleted ? AppColor.main : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isActive || isCompleted ? Colors.white : Colors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStepConnector(int stepIndex) {
    final isCompleted = _currentStep > stepIndex;

    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? AppColor.main : Colors.grey.shade300,
      ),
    );
  }

  // 공간 기본 정보 페이지
  Widget _buildSpaceBasicInfoPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '공간 기본 정보',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 24),

              // 현장 주소
              const Text('현장주소 *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _siteAddressController,
                      decoration: const InputDecoration(
                        hintText: '주소를 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // 주소 검색 기능
                    },
                    child: const Text('주소 검색'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _detailSiteAddressController,
                decoration: const InputDecoration(
                  hintText: '상세주소를 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 공간 오픈 일정
              const Text('공간오픈일정 *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _openingDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _openingDate = date;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _openingDate != null
                        ? '${_openingDate!.year}년 ${_openingDate!.month}월 ${_openingDate!.day}일'
                        : '날짜를 선택하세요',
                    style: TextStyle(
                      color: _openingDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 수령자
              const Text('수령자 *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _recipientController,
                decoration: const InputDecoration(
                  hintText: '수령자명을 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 연락처
              const Text('연락처 *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contactNumberController,
                decoration: const InputDecoration(
                  hintText: '연락처를 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 배송방법
              const Text('배송방법', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _shippingMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '배송방법을 선택하세요',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('선택하세요'),
                  ),
                  ...['직접배송', '택배', '화물'].map((method) {
                    return DropdownMenuItem(value: method, child: Text(method));
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _shippingMethod = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // 결제방법
              const Text('결제방법', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '결제방법을 선택하세요',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('선택하세요'),
                  ),
                  ...['현금', '카드', '계좌이체', '외상'].map((method) {
                    return DropdownMenuItem(value: method, child: Text(method));
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _paymentMethod = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // 기타 입력사항
              const Text('기타 입력사항',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _additionalNotesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '기타 사항을 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),

              // 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () =>
                        context.go('/main/customer/${widget.customerId}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('이전'),
                  ),
                  ElevatedButton(
                    onPressed: _saveSpaceBasicInfo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.main,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('수정'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 공간 상세 정보 페이지
  Widget _buildSpaceDetailInfoPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '공간 상세 정보',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                InkWell(
                  onTap: () {
                    context.go(
                        '/main/customer/${widget.customerId}/estimate/${widget.estimateId}/edit/space-detail');
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
            const SizedBox(height: 24),

            // 예산
            const Text('예산', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minBudgetController,
                    decoration: const InputDecoration(
                      hintText: '최소 예산',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('~'),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _maxBudgetController,
                    decoration: const InputDecoration(
                      hintText: '최대 예산',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 공간 면적
            const Text('공간면적', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _areaController,
                    decoration: const InputDecoration(
                      hintText: '면적을 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                    items: ['평', '㎡'].map((unit) {
                      return DropdownMenuItem(value: unit, child: Text(unit));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUnit = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 업종
            const Text('업종', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _selectedBusinessType,
              decoration: const InputDecoration(
                hintText: '업종을 입력하세요',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _selectedBusinessType = value;
              },
            ),
            const SizedBox(height: 16),

            // 기타 입력사항
            const Text('기타 입력사항',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _detailNotesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '기타 사항을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _previousStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('이전'),
                ),
                ElevatedButton(
                  onPressed: _saveSpaceDetailInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.main,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('수정'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 가구 정보 페이지
  Widget _buildFurnitureInfoPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '가구 정보',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
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
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _addFurniture,
                    icon: const Icon(Icons.add),
                    label: const Text('가구 추가'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.main,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: _furnitureList.isEmpty
                ? const Center(
                    child: Text(
                      '추가된 가구가 없습니다.\n가구 추가 버튼을 클릭해주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _furnitureList.length,
                    itemBuilder: (context, index) {
                      final furniture = _furnitureList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(furniture.name),
                          subtitle: Text(
                              '수량: ${furniture.quantity}개 | 가격: ₩${furniture.price.toInt()}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _editFurniture(index),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                onPressed: () => _removeFurniture(index),
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 24),

          // 총합 표시
          if (_furnitureList.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '총 금액',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₩${_calculateTotalAmount().toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColor.main,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _previousStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('이전'),
              ),
              ElevatedButton(
                onPressed: _saveFurnitureInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.main,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('수정'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 가구 추가 다이얼로그
  void _addFurniture() {
    showDialog(
      context: context,
      builder: (context) => _FurnitureDialog(
        onSave: (furniture) {
          setState(() {
            _furnitureList.add(furniture);
          });
        },
      ),
    );
  }

  // 가구 편집 다이얼로그
  void _editFurniture(int index) {
    showDialog(
      context: context,
      builder: (context) => _FurnitureDialog(
        furniture: _furnitureList[index],
        onSave: (furniture) {
          setState(() {
            _furnitureList[index] = furniture;
          });
        },
      ),
    );
  }

  // 가구 제거
  void _removeFurniture(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가구 삭제'),
        content: const Text('선택한 가구를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _furnitureList.removeAt(index);
              });
              Navigator.of(context).pop();
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 총 금액 계산
  double _calculateTotalAmount() {
    return _furnitureList.fold(
        0, (sum, furniture) => sum + (furniture.price * furniture.quantity));
  }
}

// 가구 추가/편집 다이얼로그
class _FurnitureDialog extends StatefulWidget {
  final ExistingFurniture? furniture;
  final Function(ExistingFurniture) onSave;

  const _FurnitureDialog({
    this.furniture,
    required this.onSave,
  });

  @override
  State<_FurnitureDialog> createState() => _FurnitureDialogState();
}

class _FurnitureDialogState extends State<_FurnitureDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.furniture != null) {
      _nameController.text = widget.furniture!.name;
      _quantityController.text = widget.furniture!.quantity.toString();
      _priceController.text = widget.furniture!.price.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.furniture == null ? '가구 추가' : '가구 편집'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '가구명 *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '가구명을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: '수량 *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '수량을 입력해주세요';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return '올바른 수량을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: '단가 *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '단가를 입력해주세요';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return '올바른 단가를 입력해주세요';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final furniture = ExistingFurniture(
                id: widget.furniture?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                name: _nameController.text,
                quantity: int.parse(_quantityController.text),
                price: double.parse(_priceController.text),
              );

              widget.onSave(furniture);
              Navigator.of(context).pop();
            }
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
