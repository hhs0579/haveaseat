import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'package:haveaseat/widget/address.dart';
import 'package:haveaseat/widget/fileupload.dart';

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
  int _fileFieldCounter = 0;

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
                      // URL 저장
                      if (_uploadedUrls.length > currentIndex) {
                        _uploadedUrls[currentIndex] = url;
                      } else {
                        _uploadedUrls.add(url);
                      }
                      print('추가 파일 $currentIndex URL: $url');
                    },
                  ),
                ),
                // 선택적: 삭제 버튼 추가
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColor.font2),
                  onPressed: () {
                    setState(() {
                      _additionalFiles.removeAt(currentIndex);
                      if (_uploadedUrls.length > currentIndex) {
                        _uploadedUrls.removeAt(currentIndex);
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

  List<String> getAllUploadedUrls() {
    return _uploadedUrls;
  }

  @override
  void initState() {
    super.initState();
    _noteController.addListener(() {
      setState(() {
        _textLength = _noteController.text.length;
      });
    });
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
                                      const SizedBox(height: 4),
                                      Text(
                                        UserProvider.getDepartment(data),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColor.font4),
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
                          const SizedBox(height: 24),
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
                            isAllFileTypes: false, // 기본값이라 생략 가능
                            onFileUploaded: (String url) {
                              print('사업자등록증 URL: $url');
                            },
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
                            isAllFileTypes: true, // 모든 파일 타입 허용
                            onFileUploaded: (String url) {
                              print('기타 서류 URL: $url');
                            },
                          ),
                          ..._additionalFiles,
                          const SizedBox(
                            height: 12,
                          ),
                          InkWell(
                            onTap: _addFileUploadField,
                            child: Container(
                              height: 36,
                              width: 720,
                              decoration: BoxDecoration(
                                  border: Border.all(color: AppColor.line1)),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('파일 추가',
                                      style: TextStyle(
                                          color: AppColor.font1,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  SizedBox(width: 8),
                                  Icon(Icons.add,
                                      color: AppColor.font1, size: 16)
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
                                onTap: () {
                                  // 고객 추가 처리
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
                ]))));
  }
}
