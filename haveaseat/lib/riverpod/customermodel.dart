import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String businessLicenseUrl;
  final List<String> otherDocumentUrls;
  final String note;
  final String assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.businessLicenseUrl,
    required this.otherDocumentUrls,
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
      otherDocumentUrls: List<String>.from(json['otherDocumentUrls'] ?? []),
      note: json['note'] ?? '',
      assignedTo: json['assignedTo'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'businessLicenseUrl': businessLicenseUrl,
      'otherDocumentUrls': otherDocumentUrls,
      'note': note,
      'assignedTo': assignedTo,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

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
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('customers')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Customer.fromJson(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error in _fetchCustomers: $e');
      rethrow;
    }
  }

// 파일 업로드 함수도 로그 추가
  static Future<String> uploadFile(File file, String path) async {
    try {
      print('Uploading file to path: $path');
      final ref = FirebaseStorage.instance.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('File uploaded successfully. URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  Future<void> addCustomer({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String businessLicenseUrl, // URL로 받음
    required List<String> otherDocumentUrls, // URL 리스트로 받음
    required String note,
    required String assignedTo,
  }) async {
    try {
      state = const AsyncValue.loading();
      final now = Timestamp.now();

      // Firestore에 고객 정보 저장
      final customerData = {
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'businessLicenseUrl': businessLicenseUrl, // 받은 URL 사용
        'otherDocumentUrls': otherDocumentUrls, // 받은 URL 리스트 사용
        'note': note,
        'assignedTo': assignedTo,
        'createdAt': now,
        'updatedAt': now,
      };

      print('Customer Data to save: $customerData');

      final docRef = FirebaseFirestore.instance.collection('customers').doc();
      await docRef.set(customerData);

      print('Document saved successfully');

      // 약간의 지연 후 상태 업데이트
      await Future.delayed(const Duration(milliseconds: 500));
      state = AsyncValue.data(await _fetchCustomers());
    } catch (e, stack) {
      print('Error in addCustomer: $e');
      print('Stack trace: $stack');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

// 파일 업로드
  Future<void> updateCustomer(
    String id, {
    required String name,
    required String phone,
    required String email,
    required String address,
    File? businessLicenseFile,
    List<File?>? otherDocumentFiles,
    required String note,
  }) async {
    try {
      state = const AsyncValue.loading();

      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(id)
          .get();

      if (!doc.exists) throw Exception('Customer not found');

      final existingCustomer = Customer.fromJson(id, doc.data()!);
      String businessLicenseUrl = existingCustomer.businessLicenseUrl;
      List<String> otherDocumentUrls =
          List.from(existingCustomer.otherDocumentUrls);

      if (businessLicenseFile != null) {
        businessLicenseUrl = await uploadFile(
          businessLicenseFile,
          'business_licenses/${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      if (otherDocumentFiles != null) {
        otherDocumentUrls = [];
        for (final file in otherDocumentFiles) {
          if (file != null) {
            final url = await uploadFile(
              file,
              'other_documents/${DateTime.now().millisecondsSinceEpoch}_${otherDocumentUrls.length}',
            );
            otherDocumentUrls.add(url);
          }
        }
      }

      await FirebaseFirestore.instance.collection('customers').doc(id).update({
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'businessLicenseUrl': businessLicenseUrl,
        'otherDocumentUrls': otherDocumentUrls,
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state = AsyncValue.data(await _fetchCustomers());
    } catch (e) {
      print('Error in updateCustomer: $e');
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}
