// lib/models/customer.dart

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// lib/models/customer.dart
class Customer {
  final String id;
  final String name; // 고객명
  final String phone; // 연락처
  final String email; // 이메일 주소
  final String address; // 배송지 주소
  final String businessLicenseUrl; // 사업자등록증 파일 URL
  final String otherDocumentUrl; // 기타서류 파일 URL
  final String note; // 기타 입력사항
  final String assignedTo; // 담당자 ID
  final DateTime createdAt; // 생성일
  final DateTime updatedAt; // 수정일

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.businessLicenseUrl,
    required this.otherDocumentUrl,
    required this.note,
    required this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromJson(String id, Map<String, dynamic> json) {
    return Customer(
      id: id,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      businessLicenseUrl: json['businessLicenseUrl'] ?? '',
      otherDocumentUrl: json['otherDocumentUrl'] ?? '',
      note: json['note'] ?? '',
      assignedTo: json['assignedTo'] ?? '',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'businessLicenseUrl': businessLicenseUrl,
      'otherDocumentUrl': otherDocumentUrl,
      'note': note,
      'assignedTo': assignedTo,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// lib/riverpod/customer_notifier.dart
final customerDataProvider =
    AsyncNotifierProvider<CustomerNotifier, List<Customer>>(() {
  return CustomerNotifier();
});

class CustomerNotifier extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() async {
    return _fetchCustomers();
  }

  Future<List<Customer>> _fetchCustomers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('customers')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Customer.fromJson(doc.id, doc.data()))
        .toList();
  }

  // 파일 업로드 함수
  Future<String> _uploadFile(File file, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // 고객 추가 (파일 업로드 포함)
  Future<void> addCustomer({
    required String name,
    required String phone,
    required String email,
    required String address,
    required File? businessLicenseFile,
    required File? otherDocumentFile,
    required String note,
    required String assignedTo,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      String businessLicenseUrl = '';
      String otherDocumentUrl = '';

      // 사업자등록증 파일 업로드
      if (businessLicenseFile != null) {
        businessLicenseUrl = await _uploadFile(
          businessLicenseFile,
          'business_licenses/${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      // 기타서류 파일 업로드
      if (otherDocumentFile != null) {
        otherDocumentUrl = await _uploadFile(
          otherDocumentFile,
          'other_documents/${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      final customer = Customer(
        id: '',
        name: name,
        phone: phone,
        email: email,
        address: address,
        businessLicenseUrl: businessLicenseUrl,
        otherDocumentUrl: otherDocumentUrl,
        note: note,
        assignedTo: assignedTo,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('customers')
          .add(customer.toJson());

      return _fetchCustomers();
    });
  }

  // 고객 정보 수정
  Future<void> updateCustomer(
    String id, {
    required String name,
    required String phone,
    required String email,
    required String address,
    File? businessLicenseFile,
    File? otherDocumentFile,
    required String note,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(id)
          .get();
      final existingCustomer = Customer.fromJson(id, doc.data()!);

      String businessLicenseUrl = existingCustomer.businessLicenseUrl;
      String otherDocumentUrl = existingCustomer.otherDocumentUrl;

      // 새 사업자등록증 파일이 있으면 업로드
      if (businessLicenseFile != null) {
        businessLicenseUrl = await _uploadFile(
          businessLicenseFile,
          'business_licenses/${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      // 새 기타서류 파일이 있으면 업로드
      if (otherDocumentFile != null) {
        otherDocumentUrl = await _uploadFile(
          otherDocumentFile,
          'other_documents/${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      final updatedCustomer = Customer(
        id: id,
        name: name,
        phone: phone,
        email: email,
        address: address,
        businessLicenseUrl: businessLicenseUrl,
        otherDocumentUrl: otherDocumentUrl,
        note: note,
        assignedTo: existingCustomer.assignedTo,
        createdAt: existingCustomer.createdAt,
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('customers')
          .doc(id)
          .update(updatedCustomer.toJson());

      return _fetchCustomers();
    });
  }
}

// // lib/pages/my_customers_page.dart
// class MyCustomersPage extends ConsumerWidget {
//   const MyCustomersPage({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final currentUser = ref.watch(UserProvider.currentUserProvider);

//     return currentUser.when(
//       data: (user) {
//         if (user == null) return const Center(child: Text('로그인이 필요합니다'));

//         return FutureBuilder<List<Customer>>(
//           future:
//               ref.read(customerDataProvider.notifier).getMyCustomers(user.uid),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(child: CircularProgressIndicator());
//             }

//             if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             }

//             final customers = snapshot.data ?? [];

//             return ListView.builder(
//               itemCount: customers.length,
//               itemBuilder: (context, index) {
//                 final customer = customers[index];
//                 return Card(
//                   margin: const EdgeInsets.all(8),
//                   child: ListTile(
//                     title: Text(customer.name),
//                     subtitle: Text(customer.company),
//                     trailing: Text(customer.department),
//                     onTap: () {
//                       // 상세 정보 페이지로 이동
//                     },
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//       loading: () => const Center(child: CircularProgressIndicator()),
//       error: (error, stack) => Center(child: Text('Error: $error')),
//     );
//   }
// }

// // lib/pages/all_customers_page.dart
// class AllCustomersPage extends ConsumerWidget {
//   const AllCustomersPage({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final customersAsync = ref.watch(customerDataProvider);

//     return customersAsync.when(
//       data: (customers) {
//         return ListView.builder(
//           itemCount: customers.length,
//           itemBuilder: (context, index) {
//             final customer = customers[index];
//             return Card(
//               margin: const EdgeInsets.all(8),
//               child: ListTile(
//                 title: Text(customer.name),
//                 subtitle: Text(customer.company),
//                 trailing: Text(customer.department),
//                 onTap: () {
//                   // 상세 정보 페이지로 이동
//                 },
//               ),
//             );
//           },
//         );
//       },
//       loading: () => const Center(child: CircularProgressIndicator()),
//       error: (error, stack) => Center(child: Text('Error: $error')),
//     );
//   }
// }
//검색기능
// final searchQueryProvider = StateProvider<String>((ref) => '');

// // CustomerNotifier에 추가
// Future<List<Customer>> searchCustomers(String query) async {
//   if (query.isEmpty) return _fetchCustomers();
  
//   final snapshot = await FirebaseFirestore.instance
//       .collection('customers')
//       .where('name', isGreaterThanOrEqualTo: query)
//       .where('name', isLessThan: query + 'z')
//       .get();

//   return snapshot.docs
//       .map((doc) => Customer.fromJson(doc.id, doc.data()))
//       .toList();
// }
//정렬 기능
// final sortByProvider = StateProvider<String>((ref) => 'name');

// // CustomerNotifier에 추가
// Future<List<Customer>> getSortedCustomers(String sortBy) async {
//   final snapshot = await FirebaseFirestore.instance
//       .collection('customers')
//       .orderBy(sortBy)
//       .get();

//   return snapshot.docs
//       .map((doc) => Customer.fromJson(doc.id, doc.data()))
//       .toList();
// }