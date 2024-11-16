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

class SpaceAddPage extends ConsumerStatefulWidget {
  // ConsumerWidget을 ConsumerStatefulWidget으로 변경
  final String customerId; // 고객 ID를 받아옴

  const SpaceAddPage({
    super.key,
    required this.customerId,
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
  final _formKey = GlobalKey<FormState>(); // Form Key 추가
  final int _textLength = 0;
  // 상태 변수들
  DateTime? _openingDate;
  String? _deliveryMethod;
  String? _tempSaveDocId;
  int _notesLength = 0;

  // 배송 방법 옵션
  final List<String> _deliveryMethods = ['직접 배송', '택배', '용달', '기타'];

  @override
  void initState() {
    super.initState();
    _additionalNotesController.addListener(() {
      setState(() {
        _notesLength = _additionalNotesController.text.length;
      });
    });
    _loadTempSavedData();
  }

  @override
  void dispose() {
    _siteAddressController.dispose();
    _detailSiteAddressController.dispose();
    _recipientController.dispose();
    _contactNumberController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  // 임시 저장 데이터 불러오기
  Future<void> _loadTempSavedData() async {
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) return;

      final tempDoc = await FirebaseFirestore.instance
          .collection('temp_space_basic_infos')
          .where('assignedTo', isEqualTo: user.uid)
          .where('customerId', isEqualTo: widget.customerId)
          .where('isTemp', isEqualTo: true)
          .get();

      if (tempDoc.docs.isNotEmpty) {
        final data = tempDoc.docs.first.data();
        setState(() {
          _tempSaveDocId = tempDoc.docs.first.id;

          // 주소 처리
          if (data['siteAddress'] != null) {
            final addressParts = data['siteAddress'].split(' ');
            _siteAddressController.text =
                addressParts.take(addressParts.length - 1).join(' ');
            _detailSiteAddressController.text = addressParts.last;
          }

          // 날짜 처리
          if (data['openingDate'] != null) {
            _openingDate = (data['openingDate'] as Timestamp).toDate();
          }

          _recipientController.text = data['recipient'] ?? '';
          _contactNumberController.text = data['contactNumber'] ?? '';
          _deliveryMethod = data['deliveryMethod'];
          _additionalNotesController.text = data['additionalNotes'] ?? '';
        });
      }
    } catch (e) {
      print('임시 저장 데이터 로드 중 오류: $e');
    }
  }

  // 임시 저장
  Future<void> _saveTempBasicInfo() async {
    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      final tempData = {
        'customerId': widget.customerId,
        'assignedTo': user.uid,
        'siteAddress':
            '${_siteAddressController.text} ${_detailSiteAddressController.text}',
        'openingDate':
            _openingDate != null ? Timestamp.fromDate(_openingDate!) : null,
        'recipient': _recipientController.text,
        'contactNumber': _contactNumberController.text,
        'deliveryMethod': _deliveryMethod,
        'additionalNotes': _additionalNotesController.text,
        'isTemp': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (_tempSaveDocId != null) {
        await FirebaseFirestore.instance
            .collection('temp_space_basic_infos')
            .doc(_tempSaveDocId)
            .update(tempData);
      } else {
        final docRef = await FirebaseFirestore.instance
            .collection('temp_space_basic_infos')
            .add(tempData);
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

  // 최종 저장
  Future<void> _saveSpaceBasicInfo() async {
    // 유효성 검사
    if (_siteAddressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현장 주소를 입력해주세요')),
      );
      return;
    }

    if (_openingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공간 오픈 일정을 선택해주세요')),
      );
      return;
    }

    if (_recipientController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수령자를 입력해주세요')),
      );
      return;
    }

    if (_contactNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연락처를 입력해주세요')),
      );
      return;
    }

    try {
      final user = ref.read(UserProvider.currentUserProvider).value;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      await ref.read(spaceBasicInfoProvider.notifier).addSpaceBasicInfo(
            customerId: widget.customerId,
            siteAddress:
                '${_siteAddressController.text} ${_detailSiteAddressController.text}',
            openingDate: _openingDate!,
            recipient: _recipientController.text,
            contactNumber: _contactNumberController.text,
            deliveryMethod: _deliveryMethod ?? '',
            additionalNotes: _additionalNotesController.text,
          );

      // 저장 성공 시 임시 저장 문서 삭제
      if (_tempSaveDocId != null) {
        await FirebaseFirestore.instance
            .collection('temp_space_basic_infos')
            .doc(_tempSaveDocId)
            .delete();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다')),
        );
        // 다음 페이지로 이동
        context.go('/customer/${widget.customerId}/space-detail');
      }
    } catch (e) {
      print('저장 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spaceBasicInfo = ref.watch(spaceBasicInfoProvider);
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
                          '공간 기본 정보 입력',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColor.font1),
                        ),
                        const SizedBox(
                          height: 32,
                        ),
                        AddressSearchField(
                          controller: _siteAddressController,
                          detailController: _detailSiteAddressController,
                          labelText: '현장 주소',
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
                          width: 720,
                          height: 48,
                          margin:
                              const EdgeInsets.only(bottom: 24), // 에러 메시지 공간 확보
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
                          width: 720,
                          height: 48,
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
                                controller: _additionalNotesController,
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
