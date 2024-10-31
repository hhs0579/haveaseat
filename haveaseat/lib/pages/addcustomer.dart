import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:haveaseat/components/screensize.dart';
import 'package:go_router/go_router.dart'; // 이 줄 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:haveaseat/riverpod/usermodel.dart';
import 'package:haveaseat/widget/address.dart';

class addCustomerPage extends ConsumerStatefulWidget {
  // ConsumerWidget을 ConsumerStatefulWidget으로 변경
  const addCustomerPage({super.key});

  @override
  ConsumerState<addCustomerPage> createState() => _addCustomerPageState();
}

class _addCustomerPageState extends ConsumerState<addCustomerPage> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailAddressController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _directDomainController = TextEditingController();
  String? selectedDomain = 'gmail.com';
  bool isDirectInput = false;

  @override
  void dispose() {
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
                        height: MediaQuery.of(context).size.height,
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
                                    hintText: '이메일 입력',
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
                        ]),
                  ),
                ]))));
  }
}
