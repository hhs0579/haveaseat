import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// 공간 기본 정보 모델
class SpaceBasicInfo {
  final String siteAddress;
  final DateTime openingDate;
  final String recipient;
  final String contactNumber;
  final String deliveryMethod;
  final String additionalNotes;

  SpaceBasicInfo({
    required this.siteAddress,
    required this.openingDate,
    required this.recipient,
    required this.contactNumber,
    required this.deliveryMethod,
    required this.additionalNotes,
  });

  factory SpaceBasicInfo.fromJson(Map<String, dynamic> json) {
    return SpaceBasicInfo(
      siteAddress: json['siteAddress'] ?? '',
      openingDate:
          (json['openingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recipient: json['recipient'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      deliveryMethod: json['deliveryMethod'] ?? '',
      additionalNotes: json['additionalNotes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'siteAddress': siteAddress,
      'openingDate': Timestamp.fromDate(openingDate),
      'recipient': recipient,
      'contactNumber': contactNumber,
      'deliveryMethod': deliveryMethod,
      'additionalNotes': additionalNotes,
    };
  }

  SpaceBasicInfo copyWith({
    String? siteAddress,
    DateTime? openingDate,
    String? recipient,
    String? contactNumber,
    String? deliveryMethod,
    String? additionalNotes,
  }) {
    return SpaceBasicInfo(
      siteAddress: siteAddress ?? this.siteAddress,
      openingDate: openingDate ?? this.openingDate,
      recipient: recipient ?? this.recipient,
      contactNumber: contactNumber ?? this.contactNumber,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      additionalNotes: additionalNotes ?? this.additionalNotes,
    );
  }
}

// 공간 세부 정보 모델
class SpaceDetailInfo {
  final double budget;
  final double spaceArea;
  final List<String> targetAgeGroups;
  final String businessType;
  final String concept;
  final String additionalNotes;
  final List<String> designFileUrls;

  SpaceDetailInfo({
    required this.budget,
    required this.spaceArea,
    required this.targetAgeGroups,
    required this.businessType,
    required this.concept,
    required this.additionalNotes,
    required this.designFileUrls,
  });

  factory SpaceDetailInfo.fromJson(Map<String, dynamic> json) {
    return SpaceDetailInfo(
      budget: (json['budget'] ?? 0).toDouble(),
      spaceArea: (json['spaceArea'] ?? 0).toDouble(),
      targetAgeGroups: List<String>.from(json['targetAgeGroups'] ?? []),
      businessType: json['businessType'] ?? '',
      concept: json['concept'] ?? '',
      additionalNotes: json['additionalNotes'] ?? '',
      designFileUrls: List<String>.from(json['designFileUrls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'budget': budget,
      'spaceArea': spaceArea,
      'targetAgeGroups': targetAgeGroups,
      'businessType': businessType,
      'concept': concept,
      'additionalNotes': additionalNotes,
      'designFileUrls': designFileUrls,
    };
  }

  SpaceDetailInfo copyWith({
    double? budget,
    double? spaceArea,
    List<String>? targetAgeGroups,
    String? businessType,
    String? concept,
    String? additionalNotes,
    List<String>? designFileUrls,
  }) {
    return SpaceDetailInfo(
      budget: budget ?? this.budget,
      spaceArea: spaceArea ?? this.spaceArea,
      targetAgeGroups: targetAgeGroups ?? this.targetAgeGroups,
      businessType: businessType ?? this.businessType,
      concept: concept ?? this.concept,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      designFileUrls: designFileUrls ?? this.designFileUrls,
    );
  }
}

// 고객 정보 모델
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
  final SpaceBasicInfo? spaceBasicInfo;
  final SpaceDetailInfo? spaceDetailInfo;

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
    this.spaceBasicInfo,
    this.spaceDetailInfo,
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
      spaceBasicInfo: json['spaceBasicInfo'] != null
          ? SpaceBasicInfo.fromJson(json['spaceBasicInfo'])
          : null,
      spaceDetailInfo: json['spaceDetailInfo'] != null
          ? SpaceDetailInfo.fromJson(json['spaceDetailInfo'])
          : null,
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
      'spaceBasicInfo': spaceBasicInfo?.toJson(),
      'spaceDetailInfo': spaceDetailInfo?.toJson(),
    };
  }

  Customer copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? businessLicenseUrl,
    List<String>? otherDocumentUrls,
    String? note,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
    SpaceBasicInfo? spaceBasicInfo,
    SpaceDetailInfo? spaceDetailInfo,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      businessLicenseUrl: businessLicenseUrl ?? this.businessLicenseUrl,
      otherDocumentUrls: otherDocumentUrls ?? this.otherDocumentUrls,
      note: note ?? this.note,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      spaceBasicInfo: spaceBasicInfo ?? this.spaceBasicInfo,
      spaceDetailInfo: spaceDetailInfo ?? this.spaceDetailInfo,
    );
  }
}

// Provider 설정
final customerDataProvider =
    AsyncNotifierProvider<CustomerNotifier, List<Customer>>(() {
  return CustomerNotifier();
});

// Customer Notifier
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

  Future<Customer?> getCustomer(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(id)
          .get();

      if (doc.exists) {
        return Customer.fromJson(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting customer: $e');
      rethrow;
    }
  }

  // 고객 삭제
  Future<void> deleteCustomer(String id) async {
    try {
      // 고객 정보 가져오기
      final customer = await getCustomer(id);
      if (customer == null) return;

      // Storage에서 파일 삭제
      if (customer.businessLicenseUrl.isNotEmpty) {
        try {
          final ref =
              FirebaseStorage.instance.refFromURL(customer.businessLicenseUrl);
          await ref.delete();
        } catch (e) {
          print('Error deleting business license: $e');
        }
      }

      // 기타 문서 파일 삭제
      for (final url in customer.otherDocumentUrls) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (e) {
          print('Error deleting other document: $e');
        }
      }

      // Firestore에서 고객 문서 삭제
      await FirebaseFirestore.instance.collection('customers').doc(id).delete();

      // 상태 업데이트
      state = AsyncValue.data(await _fetchCustomers());
    } catch (e) {
      print('Error deleting customer: $e');
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  // 여러 고객 동시 삭제
  Future<void> deleteMultipleCustomers(List<String> ids) async {
    try {
      state = const AsyncValue.loading();

      await Future.wait(
        ids.map((id) => deleteCustomer(id)),
      );

      state = AsyncValue.data(await _fetchCustomers());
    } catch (e) {
      print('Error deleting multiple customers: $e');
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  // 파일 업로드 함수
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

  // 고객 추가
  Future<String> addCustomer({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String businessLicenseUrl,
    required List<String> otherDocumentUrls,
    required String note,
    required String assignedTo,
  }) async {
    try {
      state = const AsyncValue.loading();
      final now = Timestamp.now();

      final customerData = {
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'businessLicenseUrl': businessLicenseUrl,
        'otherDocumentUrls': otherDocumentUrls,
        'note': note,
        'assignedTo': assignedTo,
        'createdAt': now,
        'updatedAt': now,
      };

      final docRef = FirebaseFirestore.instance.collection('customers').doc();
      await docRef.set(customerData);

      state = AsyncValue.data(await _fetchCustomers());

      return docRef.id;
    } catch (e, stack) {
      print('Error in addCustomer: $e');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // 고객 정보 업데이트
  Future<void> updateCustomer(
    String id, {
    required String name,
    required String phone,
    required String email,
    required String address,
    String? businessLicenseUrl,
    List<String>? otherDocumentUrls,
    required String note,
    SpaceBasicInfo? spaceBasicInfo,
    SpaceDetailInfo? spaceDetailInfo,
  }) async {
    try {
      state = const AsyncValue.loading();

      final updateData = {
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (businessLicenseUrl != null) {
        updateData['businessLicenseUrl'] = businessLicenseUrl;
      }

      if (otherDocumentUrls != null) {
        updateData['otherDocumentUrls'] = otherDocumentUrls;
      }

      if (spaceBasicInfo != null) {
        updateData['spaceBasicInfo'] = spaceBasicInfo.toJson();
      }

      if (spaceDetailInfo != null) {
        updateData['spaceDetailInfo'] = spaceDetailInfo.toJson();
      }

      await FirebaseFirestore.instance
          .collection('customers')
          .doc(id)
          .update(updateData);

      state = AsyncValue.data(await _fetchCustomers());
    } catch (e) {
      print('Error in updateCustomer: $e');
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  // 임시 저장 데이터 관리
  Future<void> saveTempCustomer({
    required String assignedTo,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? businessLicenseUrl,
    List<String>? otherDocumentUrls,
    String? note,
    SpaceBasicInfo? spaceBasicInfo,
    SpaceDetailInfo? spaceDetailInfo,
  }) async {
    try {
      final tempData = {
        'assignedTo': assignedTo,
        'name': name ?? '',
        'phone': phone ?? '',
        'email': email ?? '',
        'address': address ?? '',
        'businessLicenseUrl': businessLicenseUrl ?? '',
        'otherDocumentUrls': otherDocumentUrls ?? [],
        'note': note ?? '',
        'spaceBasicInfo': spaceBasicInfo?.toJson(),
        'spaceDetailInfo': spaceDetailInfo?.toJson(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isTemp': true,
      };

      await FirebaseFirestore.instance
          .collection('temp_customers')
          .doc(assignedTo)
          .set(tempData);
    } catch (e) {
      print('Error saving temp customer: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> loadTempCustomer(String assignedTo) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('temp_customers')
          .doc(assignedTo)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error loading temp customer: $e');
      rethrow;
    }
  }

  Future<void> deleteTempCustomer(String assignedTo) async {
    try {
      await FirebaseFirestore.instance
          .collection('temp_customers')
          .doc(assignedTo)
          .delete();
    } catch (e) {
      print('Error deleting temp customer: $e');
      rethrow;
    }
  }
}
