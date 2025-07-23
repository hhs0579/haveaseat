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

class SpaceAddPage extends ConsumerStatefulWidget {
  // ConsumerWidget을 ConsumerStatefulWidget으로 변경
  final String customerId; // 고객 ID를 받아옴
  final String? estimateId;
  final String? name; // 회사명(고객명) 변수명 통일

  const SpaceAddPage({
    super.key,
    required this.customerId,
    this.estimateId,
    this.name,
  });

  @override
  ConsumerState<SpaceAddPage> createState() => _SpaceAddPageState();
}

class _SpaceAddPageState extends ConsumerState<SpaceAddPage> {
  final TextEditingController _siteAddressController = TextEditingController();
  final TextEditingController _detailSiteAddressController =
      TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _additionalNotesController =
      TextEditingController();
  String? _shippingMethod; // 배송 방법
  String? _paymentMethod; // 결제 방법
  final _formKey = GlobalKey<FormState>(); // Form Key 추가
  final int _textLength = 0;
  // 상태 변수들
  DateTime? _openingDate;
  String? _deliveryMethod;
  String? _tempSaveDocId;
  final int _notesLength = 0;

  // 배송 방법 옵션
  final List<String> _deliveryMethods = ['직접 배송', '택배', '용달', '기타'];

  @override
  void dispose() {
    _siteAddressController.dispose();
    _detailSiteAddressController.dispose();
    _recipientController.dispose();
    _contactNumberController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadTempEstimate();
  }

  // 편집 모드인지 확인하는 getter
  bool get isEditMode {
    final currentPath =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    return currentPath.contains('/edit');
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

  Future<void> _loadTempEstimate() async {
    try {
      // 기존: customers 문서에서 customer 정보 조회
      // 변경: estimates 문서에서 customerInfo 사용
      String? estimateId;
      if (widget.estimateId != null) {
        estimateId = widget.estimateId;
      } else {
        // 임시저장 플로우에서는 estimateId를 따로 관리해야 함
        // (임시저장페이지에서 이어서 작성 시 estimateId를 넘겨줘야 함)
        return;
      }
      final docSnapshot = await FirebaseFirestore.instance
          .collection('estimates')
          .doc(estimateId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;

        // 수정 모드일 때는 spaceBasicInfo 하위 맵에서 데이터를 불러옴
        Map<String, dynamic> spaceData;
        if (isEditMode && data['spaceBasicInfo'] != null) {
          spaceData = data['spaceBasicInfo'] as Map<String, dynamic>;
        } else {
          spaceData = data; // 최상위 필드에서 불러옴
        }

        setState(() {
          // 주소 처리
          if (spaceData['siteAddress'] != null) {
            final addressParts = spaceData['siteAddress'].split(' ');
            if (addressParts.length > 1) {
              _siteAddressController.text =
                  addressParts.take(addressParts.length - 1).join(' ');
              _detailSiteAddressController.text = addressParts.last;
            } else {
              _siteAddressController.text = spaceData['siteAddress'];
            }
          }
          // 날짜 처리
          if (spaceData['openingDate'] != null) {
            _openingDate = (spaceData['openingDate'] as Timestamp).toDate();
          }
          _recipientController.text = spaceData['recipient'] ?? '';
          _contactNumberController.text = spaceData['contactNumber'] ?? '';
          _shippingMethod = spaceData['shippingMethod'];
          _paymentMethod = spaceData['paymentMethod'];
          _additionalNotesController.text = spaceData['basicNotes'] ?? '';
          // 고객명 등은 필요시 data['customerInfo']에서 사용
        });
      }
    } catch (e) {
      print('임시 저장 데이터 로드 중 오류: $e');
    }
  }

// 임시 저장 함수
  Future<void> _saveTempBasicInfo() async {
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) throw Exception('로그인이 필요합니다');
      String estimateId = widget.estimateId ?? '';
      if (estimateId.isEmpty) {
        final estimateRef =
            FirebaseFirestore.instance.collection('estimates').doc();
        estimateId = estimateRef.id;
      }
      // customers.estimateIds는 최초 생성시에만 추가
      if (widget.estimateId == null) {
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
        'type': '공간기본',
        'name': nameValue,
        'siteAddress':
            '${_siteAddressController.text} ${_detailSiteAddressController.text}',
        'openingDate':
            _openingDate != null ? Timestamp.fromDate(_openingDate!) : null,
        'recipient': _recipientController.text,
        'contactNumber': _contactNumberController.text,
        'shippingMethod': _shippingMethod,
        'paymentMethod': _paymentMethod,
        'basicNotes': _additionalNotesController.text,
        'managerName': user.displayName ?? '',
        'managerPhone': user.phoneNumber ?? '',
        'customerInfo': {
          'name': nameValue,
          'assignedTo': user.uid,
        },
      };
      print('임시저장 tempData: $tempData');
      await estimateRef.set(tempData, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('임시 저장되었습니다')),
        );
        context.go('/temp');
      }
    } catch (e) {
      print('임시 저장 중 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('임시 저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

// spacemodel.dart의 EstimatesNotifier 클래스 내에서 updateSpaceBasicInfo 수정
  Future<void> _saveSpaceBasicInfo() async {
    if (!_validateInputs()) return;
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) throw Exception('로그인이 필요합니다');
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // estimateId가 없으면 새로 생성
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
        'siteAddress':
            '${_siteAddressController.text} ${_detailSiteAddressController.text}',
        'openingDate':
            _openingDate != null ? Timestamp.fromDate(_openingDate!) : null,
        'recipient': _recipientController.text,
        'contactNumber': _contactNumberController.text,
        'shippingMethod': _shippingMethod ?? '',
        'paymentMethod': _paymentMethod ?? '',
        'basicNotes': _additionalNotesController.text,
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
        'managerName': userData.data()?['name'] ?? '',
        'managerPhone': userData.data()?['phoneNumber'] ?? '',
        'customerId': widget.customerId,
        'estimateId': estimateId,
        // 새로 생성할 때만 isDraft: true로 설정
        if (!isEditMode) 'isDraft': true,
        // spaceBasicInfo 하위 맵에도 저장
        'spaceBasicInfo': {
          'siteAddress':
              '${_siteAddressController.text} ${_detailSiteAddressController.text}',
          'openingDate':
              _openingDate != null ? Timestamp.fromDate(_openingDate!) : null,
          'recipient': _recipientController.text,
          'contactNumber': _contactNumberController.text,
          'shippingMethod': _shippingMethod ?? '',
          'paymentMethod': _paymentMethod ?? '',
          'basicNotes': _additionalNotesController.text,
        }
      };

      // 수정 모드일 때는 기존 spaceDetailInfo를 유지
      if (isEditMode) {
        final existingDoc = await FirebaseFirestore.instance
            .collection('estimates')
            .doc(estimateId)
            .get();
        if (existingDoc.exists) {
          final existingData = existingDoc.data()!;
          if (existingData['spaceDetailInfo'] != null) {
            estimateData['spaceDetailInfo'] = existingData['spaceDetailInfo'];
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('estimates')
          .doc(estimateId)
          .set(estimateData, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditMode ? '공간 기본 정보가 수정되었습니다' : '저장되었습니다')),
        );
        if (!isEditMode) {
          // 새로 생성된 estimateId를 URL에 포함하여 전달
          context.go(
              '/main/addpage/spaceadd/${widget.customerId}/$estimateId/space-detail');
        }
      }
    } catch (e) {
      print('저장 중 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

// 입력값 검증
  bool _validateInputs() {
    if (_siteAddressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현장 주소를 입력해주세요')),
      );
      return false;
    }

    if (_openingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공간 오픈 일정을 선택해주세요')),
      );
      return false;
    }

    if (_recipientController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수령자를 입력해주세요')),
      );
      return false;
    }

    if (_contactNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연락처를 입력해주세요')),
      );
      return false;
    }

    return true;
  }

// 캘린더 눌렀을 때 날짜 선택하는 함수
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _openingDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.transparent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
              surface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColor.primary,
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              // 원형 크기 조절
              dayStyle: const TextStyle(fontSize: 14),
              yearStyle: const TextStyle(fontSize: 14),
              // 호버 효과 제거 및 크기 조절을 위한 패딩 설정

              // 오늘 날짜 표시
              todayBorder: const BorderSide(color: AppColor.primary, width: 1),
              todayBackgroundColor:
                  MaterialStateProperty.all(Colors.transparent),
              todayForegroundColor: MaterialStateProperty.all(AppColor.primary),
              // 선택된 날짜 배경색
              dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppColor.primary;
                }
                // 호버 효과 제거
                if (states.contains(MaterialState.hovered)) {
                  return Colors.transparent;
                }
                return Colors.transparent;
              }),
              // 선택된 날짜 텍스트 색상
              dayForegroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return Colors.black;
              }),
              // 년도 선택 스타일
              yearBackgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppColor.primary;
                }
                // 호버 효과 제거
                if (states.contains(MaterialState.hovered)) {
                  return Colors.transparent;
                }
                return Colors.transparent;
              }),
              yearForegroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.white;
                }
                return Colors.black;
              }),
              headerForegroundColor: Colors.black,
              weekdayStyle: const TextStyle(
                color: Colors.black,
                fontSize: 14,
              ),
              // 선택된 날짜 모양 크기 조절
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _openingDate) {
      setState(() {
        _openingDate = picked;
      });
    }
  }

  // 이전 버튼 누르면 이전에 작성한 값 불러오기 (estimates → customers 순, spaceBasicInfo 우선)
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
          // 1. spaceBasicInfo 우선 (없으면 최상위)
          if (data['spaceBasicInfo'] != null) {
            final basic = data['spaceBasicInfo'];
            setState(() {
              _siteAddressController.text =
                  basic['siteAddress']?.split(' ').first ?? '';
              _detailSiteAddressController.text =
                  basic['siteAddress']?.split(' ').skip(1).join(' ') ?? '';
              _recipientController.text = basic['recipient'] ?? '';
              _contactNumberController.text = basic['contactNumber'] ?? '';
              _shippingMethod = basic['shippingMethod'];
              _paymentMethod = basic['paymentMethod'];
              _additionalNotesController.text = basic['basicNotes'] ?? '';
              if (basic['openingDate'] != null) {
                _openingDate = (basic['openingDate'] as Timestamp).toDate();
              }
            });
          } else {
            setState(() {
              _siteAddressController.text =
                  data['siteAddress']?.split(' ').first ?? '';
              _detailSiteAddressController.text =
                  data['siteAddress']?.split(' ').skip(1).join(' ') ?? '';
              _recipientController.text = data['recipient'] ?? '';
              _contactNumberController.text = data['contactNumber'] ?? '';
              _shippingMethod = data['shippingMethod'];
              _paymentMethod = data['paymentMethod'];
              _additionalNotesController.text = data['basicNotes'] ?? '';
              if (data['openingDate'] != null) {
                _openingDate = (data['openingDate'] as Timestamp).toDate();
              }
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
          _siteAddressController.text = data['address']?.split(' ').first ?? '';
          _detailSiteAddressController.text =
              data['address']?.split(' ').skip(1).join(' ') ?? '';
          _recipientController.text = data['name'] ?? '';
          _contactNumberController.text = data['phone'] ?? '';
          _shippingMethod = null;
          _paymentMethod = null;
          _additionalNotesController.text = data['note'] ?? '';
        });
      }
    } catch (e) {
      print('이전 데이터 불러오기 오류: $e');
    }
  }

  Widget _buildRadioGroup({
    required String title,
    required List<String> options,
    required String? groupValue,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: AppColor.font1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: options.map((option) {
            return Container(
              margin: const EdgeInsets.only(right: 24),
              child: Row(
                children: [
                  Radio<String>(
                    value: option,
                    groupValue: groupValue,
                    onChanged: onChanged,
                    activeColor: AppColor.main,
                  ),
                  Text(
                    option,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColor.font1,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(UserProvider.userDataProvider);
    return Scaffold(
        body: ResponsiveLayout(
            mobile: const SingleChildScrollView(),
            desktop: Form(
              key: _formKey,
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                            '공간 기본 정보 입력',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColor.font1),
                          ),
                          const SizedBox(
                            height: 32,
                          ),

                          const Text(
                            '기본 정보 입력',
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
                          AddressSearchField(
                            controller: _siteAddressController,
                            detailController: _detailSiteAddressController,
                            labelText: '현장 주소',
                          ),
                          const SizedBox(
                            height: 24,
                          ),
                          const Text(
                            '공간 오픈 일정',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColor.font1,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          InkWell(
                            onTap: () => _selectDate(context),
                            child: Container(
                              width: 640,
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColor.line1),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(left: 12),
                                    child: Text(
                                      _openingDate != null
                                          ? '${_openingDate!.year}년 ${_openingDate!.month}월 ${_openingDate!.day}일'
                                          : '년, 월, 일',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _openingDate != null
                                            ? AppColor.font1
                                            : AppColor.font2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                      margin:
                                          const EdgeInsets.only(right: 15.88),
                                      child: const Icon(Icons.calendar_month)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 40,
                          ),
                          const Text(
                            '수령자 정보 입력',
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
                            '수령자',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColor.font1,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 640,
                            height: 48,
                            margin: const EdgeInsets.only(
                                bottom: 24), // 에러 메시지 공간 확보
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColor.line1),
                            ),
                            child: TextFormField(
                              controller: _recipientController,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: InputBorder.none,
                                hintText: '수령자 이름을 입력해 주세요',
                                hintStyle: TextStyle(
                                    color: AppColor.font2, fontSize: 14),
                              ),
                            ),
                          ),

                          const Text(
                            '연락처',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColor.font1,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 640,
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColor.line1),
                            ),
                            child: TextFormField(
                              controller: _contactNumberController,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: InputBorder.none,
                                hintText: '연락처를 입력해 주세요',
                                hintStyle: TextStyle(
                                    color: AppColor.font2, fontSize: 14),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(
                            height: 40,
                          ),
                          const Text(
                            '배송 정보 입력',
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

                          _buildRadioGroup(
                            title: '배송 방법',
                            options: const ['택배배송', '차량배송', '물류배송'],
                            groupValue: _shippingMethod,
                            onChanged: (value) {
                              setState(() {
                                _shippingMethod = value;
                              });
                            },
                          ),

                          const SizedBox(height: 24),
                          _buildRadioGroup(
                            title: '결제 방법',
                            options: const ['선불', '착불'],
                            groupValue: _paymentMethod,
                            onChanged: (value) {
                              setState(() {
                                _paymentMethod = value;
                              });
                            },
                          ),

                          const SizedBox(
                            height: 48,
                          ),
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  if (isEditMode) {
                                    // 편집 모드일 때는 customer 화면으로 돌아가기
                                    context.go(
                                        '/main/customer/${widget.customerId}');
                                  } else {
                                    // 새로 생성 모드일 때는 메인 화면으로
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
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!isEditMode) ...[
                                InkWell(
                                  onTap: () {
                                    // 임시 저장 처리
                                    _saveTempBasicInfo();
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
                              ],
                              InkWell(
                                onTap: () {
                                  if (isEditMode) {
                                    // 편집 모드일 때는 공간 상세정보로 이동
                                    _saveSpaceBasicInfo();
                                    context.go(
                                        '/main/customer/${widget.customerId}/estimate/${widget.estimateId}/edit/space-detail');
                                  } else {
                                    // 새로 생성 모드일 때는 기존 로직
                                    _saveSpaceBasicInfo();
                                  }
                                },
                                child: Container(
                                  width: 60,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColor.primary,
                                    border: Border.all(color: AppColor.line1),
                                  ),
                                  child: Center(
                                    child: Text(
                                      isEditMode ? '다음' : '다음',
                                      style: const TextStyle(
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
                          )
                          // 사업자등록증 부분을 다음과 같이 변경
                        ]),
                  ),
                ),
              ]),
            )));
  }
}
