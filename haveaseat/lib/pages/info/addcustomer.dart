import 'dart:io';
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

class addCustomerPage extends ConsumerStatefulWidget {
  // ConsumerWidget을 ConsumerStatefulWidget으로 변경
  const addCustomerPage({super.key});

  @override
  ConsumerState<addCustomerPage> createState() => _addCustomerPageState();
}

class _addCustomerPageState extends ConsumerState<addCustomerPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailAddressController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _directDomainController = TextEditingController();
  String? selectedDomain = 'gmail.com';
  bool isDirectInput = false;
  final TextEditingController _noteController = TextEditingController();
  int _textLength = 0;
  final List<Widget> _additionalFiles = [];
  final List<String> _uploadedUrls = []; // URL 저장용 리스트
  File? _businessLicenseFile; // 추가
  List<File?> otherDocumentFiles = []; // 추가
  final List<File> _otherDocumentFiles = [];
  int _fileFieldCounter = 0;
  final _formKey = GlobalKey<FormState>(); // Form Key 추가
  List<String> _otherDocumentUrls = []; // URL 저장용 리스트 추가
  String? _businessLicenseUrl; // URL 저장용 변수 추가
  String? _tempSaveDocId;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _domainFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _detailAddressFocus = FocusNode();
  final FocusNode _noteFocus = FocusNode();
  void onBusinessLicenseUploaded(File file) {
    setState(() {
      _businessLicenseFile = file;
    });
  }

  void onOtherDocumentUploaded(File file) {
    setState(() {
      otherDocumentFiles.add(file);
    });
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
              ],
            ),
          ],
        ),
      );
    });
    print('파일 필드 추가됨. 현재 개수: ${_additionalFiles.length}');
  }

  // 임시 저장 함수

  List<String> getAllUploadedUrls() {
    return _uploadedUrls;
  }

  // 임시 저장 함수
  Future<void> _saveTempCustomer() async {
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 새로운 견적 ID 생성
      final estimateRef =
          FirebaseFirestore.instance.collection('estimates').doc();

      // 임시 저장 데이터 생성
      final tempData = {
        'estimateId': estimateRef.id,
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isTemp': true,
        // 고객 정보
        'customerInfo': {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'email':
              '${_emailController.text}@${selectedDomain ?? _directDomainController.text}',
          'address':
              '${_addressController.text} ${_detailAddressController.text}',
          'businessLicenseUrl': _businessLicenseUrl,
          'otherDocumentUrls': _otherDocumentUrls,
          'note': _noteController.text,
          'assignedTo': user.uid,
        }
      };

      // temp_estimates 컬렉션에 저장
      await FirebaseFirestore.instance
          .collection('temp_estimates')
          .doc(estimateRef.id)
          .set(tempData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('임시 저장되었습니다')),
        );
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

// 임시 저장 데이터 불러오기
  Future<void> _loadTempSavedData() async {
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) return;

      final tempDoc = await FirebaseFirestore.instance
          .collection('temp_estimates')
          .where('customerInfo.assignedTo', isEqualTo: user.uid)
          .where('isTemp', isEqualTo: true)
          .get();

      if (tempDoc.docs.isNotEmpty) {
        final data = tempDoc.docs.first.data();
        final customerInfo = data['customerInfo'] as Map<String, dynamic>;

        setState(() {
          _nameController.text = customerInfo['name'] ?? '';
          _phoneController.text = customerInfo['phone'] ?? '';

          // 이메일 처리
          if (customerInfo['email'] != null) {
            final emailParts = customerInfo['email'].split('@');
            if (emailParts.length == 2) {
              _emailController.text = emailParts[0];
              final domain = emailParts[1];
              if ([
                'gmail.com',
                'naver.com',
                'kakao.com',
                'nate.com',
                'hanmail.net',
                'daum.net'
              ].contains(domain)) {
                selectedDomain = domain;
                isDirectInput = false;
              } else {
                _directDomainController.text = domain;
                selectedDomain = null;
                isDirectInput = true;
              }
            }
          }

          // 주소 처리
          if (customerInfo['address'] != null) {
            final addressParts = customerInfo['address'].split(' ');
            _addressController.text =
                addressParts.take(addressParts.length - 1).join(' ');
            _detailAddressController.text = addressParts.last;
          }

          _noteController.text = customerInfo['note'] ?? '';
          _businessLicenseUrl = customerInfo['businessLicenseUrl'];
          _otherDocumentUrls =
              List<String>.from(customerInfo['otherDocumentUrls'] ?? []);
        });
      }
    } catch (e) {
      print('임시 저장 데이터 로드 중 오류: $e');
    }
  }

// 고객 정보 최종 저장
  Future<void> _saveCustomer() async {
    if (!_validateInputs()) return;

    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 고객 정보 저장 및 ID 반환 받기
      final customerId =
          await ref.read(customerDataProvider.notifier).addCustomer(
                name: _nameController.text,
                phone: _phoneController.text,
                email:
                    '${_emailController.text}@${selectedDomain ?? _directDomainController.text}',
                address:
                    '${_addressController.text} ${_detailAddressController.text}',
                businessLicenseUrl: _businessLicenseUrl ?? '',
                otherDocumentUrls: _otherDocumentUrls,
                note: _noteController.text,
                assignedTo: user.uid,
              );

      // 임시 저장 데이터 삭제
      if (_tempSaveDocId != null) {
        await FirebaseFirestore.instance
            .collection('temp_estimates')
            .doc(_tempSaveDocId)
            .delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('고객 정보가 저장되었습니다')),
        );
        // 공간 기본정보 페이지로 이동
        context.go('/main/addpage/spaceadd/$customerId');
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
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('고객명을 입력해주세요')),
      );
      return false;
    }

    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연락처를 입력해주세요')),
      );
      return false;
    }

    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 입력해주세요')),
      );
      return false;
    }

    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소를 입력해주세요')),
      );
      return false;
    }

    return true;
  }

  @override
  void initState() {
    super.initState();
    _noteController.addListener(() {
      setState(() {
        _textLength = _noteController.text.length;
      });
    });
    // 컴포넌트가 마운트될 때 임시 저장 데이터 불러오기
    _loadTempSavedData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    _emailController.dispose();
    _directDomainController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _domainFocus.dispose();
    _addressFocus.dispose();
    _detailAddressFocus.dispose();
    _noteFocus.dispose();

    super.dispose();
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
                ],
              ),
            ),
                const SizedBox(
                  width: 48,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(0),
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
                              '고객 정보 입력',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.font1),
                            ),
                            const SizedBox(
                              height: 32,
                            ),
                            const Text(
                              '기본 정보',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: AppColor.font1,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Container(
                              width: 640,
                              height: 2,
                              color: AppColor.primary,
                            ),
                            const SizedBox(
                              height: 24,
                            ),
                            const Text(
                              '회사명',
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
                                controller: _nameController,
                                focusNode: _nameFocus,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  border: InputBorder.none,
                                  hintText: '고객명을 입력해 주세요',
                                  hintStyle: TextStyle(
                                      color: AppColor.font2, fontSize: 14),
                                ),
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context)
                                      .requestFocus(_phoneFocus);
                                },
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
                                controller: _phoneController,
                                focusNode: _phoneFocus,
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
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context)
                                      .requestFocus(_emailFocus);
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              '이메일 주소',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColor.font1,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 301.5,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColor.line1),
                                  ),
                                  child: TextFormField(
                                    controller: _emailController,
                                    focusNode: _emailFocus,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      border: InputBorder.none,
                                      hintText: '이메일 주소를 입력해주세요',
                                      hintStyle: TextStyle(
                                          color: AppColor.font2, fontSize: 14),
                                    ),
                                    onFieldSubmitted: (_) {
                                      FocusScope.of(context)
                                          .requestFocus(_domainFocus);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  '@',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColor.font1,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                    width: 301.5,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColor.line1),
                                    ),
                                    child: isDirectInput
                                        ? TextFormField(
                                            controller: _directDomainController,
                                            focusNode: _domainFocus,
                                            textInputAction:
                                                TextInputAction.next,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 14),
                                              border: InputBorder.none,
                                              hintText: '직접 입력',
                                              hintStyle: TextStyle(
                                                  color: AppColor.font2,
                                                  fontSize: 14),
                                            ),
                                            onFieldSubmitted: (_) {
                                              FocusScope.of(context)
                                                  .requestFocus(_addressFocus);
                                            },
                                          )
                                        : DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: selectedDomain,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 14),
                                              items: [
                                                'gmail.com',
                                                'naver.com',
                                                'kakao.com',
                                                'nate.com',
                                                'hanmail.net',
                                                'daum.net',
                                                '직접 입력'
                                              ].map((String value) {
                                                return DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Text(
                                                    value,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: AppColor.font1,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (String? newValue) {
                                                setState(() {
                                                  if (newValue == '직접 입력') {
                                                    isDirectInput = true;
                                                    selectedDomain = null;
                                                  } else {
                                                    isDirectInput = false;
                                                    selectedDomain = newValue;
                                                  }
                                                });
                                              },
                                            ),
                                          )),
                              ],
                            ),
                            const SizedBox(
                              height: 40,
                            ),
                            const Text(
                              '배송 정보',
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
                              controller: _addressController,
                              detailController: _detailAddressController,
                            ),
                            const SizedBox(
                              height: 40,
                            ),
                            const Text(
                              '사업자 정보',
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
                            FileUploadField(
                              label: '사업자등록증',
                              uploadPath: 'business_licenses',
                              isAllFileTypes: false,
                              onFileUploaded: (String url) {
                                print('사업자등록증 업로드 전 URL: $_businessLicenseUrl');
                                setState(() {
                                  _businessLicenseUrl = url;
                                });
                                print('사업자등록증 업로드 후 URL: $_businessLicenseUrl');
                              },
                              onFileSelected: (_) {}, // 웹에서는 필요없음
                            ),
                            const SizedBox(
                              height: 24,
                            ),

                            FileUploadField(
                              label: '기타 서류',
                              uploadPath: 'other_documents',
                              isAllFileTypes: true,
                              onFileUploaded: (String url) {
                                print('기타 서류 업로드 전 URLs: $_otherDocumentUrls');
                                setState(() {
                                  _otherDocumentUrls.add(url);
                                });
                                print('기타 서류 업로드 후 URLs: $_otherDocumentUrls');
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
                              '기타 정보',
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
                                    focusNode: _noteFocus,
                                    textInputAction: TextInputAction.done,
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
                                  onTap: _saveTempCustomer,
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
                                    _saveCustomer();
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
                            )
                            // 사업자등록증 부분을 다음과 같이 변경
                          ]),
                    ),
                  ),
                ),
              ]),
            )));
  }
}
