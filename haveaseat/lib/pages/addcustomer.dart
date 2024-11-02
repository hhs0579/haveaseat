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

  Future<void> _loadTempSavedData() async {
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) return;

      final tempDoc = await FirebaseFirestore.instance
          .collection('temp_customers')
          .where('assignedTo', isEqualTo: user.uid)
          .where('isTemp', isEqualTo: true)
          .get();

      if (tempDoc.docs.isNotEmpty) {
        final data = tempDoc.docs.first.data();
        setState(() {
          _tempSaveDocId = tempDoc.docs.first.id;
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';

          // 이메일 처리
          if (data['email'] != null) {
            final emailParts = data['email'].split('@');
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
          if (data['address'] != null) {
            final addressParts = data['address'].split(' ');
            _addressController.text =
                addressParts.take(addressParts.length - 1).join(' ');
            _detailAddressController.text = addressParts.last;
          }

          _noteController.text = data['note'] ?? '';
          _businessLicenseUrl = data['businessLicenseUrl'];
          _otherDocumentUrls =
              List<String>.from(data['otherDocumentUrls'] ?? []);
        });
      }
    } catch (e) {
      print('임시 저장 데이터 로드 중 오류: $e');
    }
  }

  // 임시 저장 함수
  Future<void> _saveTempCustomer() async {
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      final tempCustomerData = {
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
        'isTemp': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (_tempSaveDocId != null) {
        // 기존 임시 저장 문서 업데이트
        await FirebaseFirestore.instance
            .collection('temp_customers')
            .doc(_tempSaveDocId)
            .update(tempCustomerData);
      } else {
        // 새로운 임시 저장 문서 생성
        final docRef = await FirebaseFirestore.instance
            .collection('temp_customers')
            .add(tempCustomerData);
        _tempSaveDocId = docRef.id;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('임시 저장되었습니다')),
        );
      }
    } catch (e) {
      print('임시 저장 중 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('임시 저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  List<String> getAllUploadedUrls() {
    return _uploadedUrls;
  }

  Future<void> _saveCustomer() async {
    // 유효성 검사
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('고객명을 입력해주세요')),
      );
      return;
    }

    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연락처를 입력해주세요')),
      );
      return;
    }

    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 입력해주세요')),
      );
      return;
    }

    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소를 입력해주세요')),
      );
      return;
    }
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

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

      // 저장 성공 시 임시 저장 문서 삭제
      if (_tempSaveDocId != null) {
        await FirebaseFirestore.instance
            .collection('temp_customers')
            .doc(_tempSaveDocId)
            .delete();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다')),
        );
        context.go('/main');
      }
    } catch (e) {
      print('저장 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
      );
    }
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

    super.dispose();
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
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SingleChildScrollView(
                  child: SizedBox(
                    width: 240,
                    child: Container(
                      height: 1420,
                      constraints: const BoxConstraints(maxWidth: 240),
                      decoration: const BoxDecoration(
                          border:
                              Border(right: BorderSide(color: AppColor.line1))),
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
                                    const SizedBox(height: 4),
                                    Text(
                                      UserProvider.getDepartment(data),
                                      style: const TextStyle(
                                          fontSize: 14, color: AppColor.font4),
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
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 17.87,
                                    ),
                                    Icon(
                                      Icons.search_outlined,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    SizedBox(
                                      width: 3.85,
                                    ),
                                    Text(
                                      '대시보드',
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
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 17.87,
                                    ),
                                    Icon(
                                      Icons.person_outline_sharp,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    SizedBox(
                                      width: 3.85,
                                    ),
                                    Text(
                                      '고객 정보',
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
                          '고객 추가',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColor.font1),
                        ),
                        const SizedBox(
                          height: 32,
                        ),
                        const Text(
                          '고객명',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColor.font1,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 720,
                          height: 48,
                          margin:
                              const EdgeInsets.only(bottom: 24), // 에러 메시지 공간 확보
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColor.line1),
                          ),
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              border: InputBorder.none,
                              hintText: '고객명을 입력해 주세요',
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
                          width: 720,
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColor.line1),
                          ),
                          child: TextFormField(
                            controller: _phoneController,
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
                              width: 341.5,
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColor.line1),
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  border: InputBorder.none,
                                  hintText: '이메일 주소를 입력해주세요',
                                  hintStyle: TextStyle(
                                      color: AppColor.font2, fontSize: 14),
                                ),
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
                                width: 341.5,
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColor.line1),
                                ),
                                child: isDirectInput
                                    ? TextFormField(
                                        controller: _directDomainController,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          border: InputBorder.none,
                                          hintText: '직접 입력',
                                          hintStyle: TextStyle(
                                              color: AppColor.font2,
                                              fontSize: 14),
                                        ),
                                      )
                                    : DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedDomain,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
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
                          height: 24,
                        ),
                        AddressSearchField(
                          controller: _addressController,
                          detailController: _detailAddressController,
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
                          width: 720,
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
                          height: 24,
                        ),
                        FileUploadField(
                          label: '',
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
                            width: 720,
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

                        // 사업자등록증 부분을 다음과 같이 변경
                      ]),
                ),
              ]),
            ))));
  }
}
