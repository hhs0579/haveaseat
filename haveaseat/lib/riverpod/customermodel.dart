import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show ByteData, Uint8List, rootBundle;

// 견적서 상태를 관리하기 위한 enum
enum EstimateStatus {
  IN_PROGRESS, // 견적중
  CONTRACTED, // 계약완료
  CANCELED // 취소됨
}

// 가구 종류를 구분하는 enum
enum FurnitureType {
  EXISTING, // 기존 가구
  CUSTOM // 제작 가구
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
  final List<String> estimateIds;

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
    required this.estimateIds,
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
      estimateIds: List<String>.from(json['estimateIds'] ?? []),
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
      'estimateIds': estimateIds,
    };
  }
}

// 견적서 모델
class Estimate {
  final String id;
  final String customerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EstimateStatus status;
  final SpaceBasicInfo? spaceBasicInfo;
  final SpaceDetailInfo? spaceDetailInfo;
  final FurnitureType? furnitureType;
  final List<ExistingFurniture>? existingFurniture;
  final List<CustomFurniture>? customFurniture;

  Estimate({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.spaceBasicInfo,
    this.spaceDetailInfo,
    this.furnitureType,
    this.existingFurniture,
    this.customFurniture,
  });

  factory Estimate.fromJson(String id, Map<String, dynamic> json) {
    final typeStr = json['furnitureType'] as String?;
    final type = typeStr != null
        ? FurnitureType.values.firstWhere(
            (e) => e.toString() == typeStr,
            orElse: () => FurnitureType.EXISTING,
          )
        : null;

    return Estimate(
      id: id,
      customerId: json['customerId'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: EstimateStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => EstimateStatus.IN_PROGRESS,
      ),
      spaceBasicInfo: json['spaceBasicInfo'] != null
          ? SpaceBasicInfo.fromJson(json['spaceBasicInfo'])
          : null,
      spaceDetailInfo: json['spaceDetailInfo'] != null
          ? SpaceDetailInfo.fromJson(json['spaceDetailInfo'])
          : null,
      furnitureType: type,
      existingFurniture: type == FurnitureType.EXISTING
          ? (json['furniture'] as List<dynamic>?)
              ?.map((e) => ExistingFurniture.fromJson(e))
              .toList()
          : null,
      customFurniture: type == FurnitureType.CUSTOM
          ? (json['furniture'] as List<dynamic>?)
              ?.map((e) => CustomFurniture.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status.toString(),
      'spaceBasicInfo': spaceBasicInfo?.toJson(),
      'spaceDetailInfo': spaceDetailInfo?.toJson(),
      'furnitureType': furnitureType?.toString(),
      'furniture': furnitureType == FurnitureType.EXISTING
          ? existingFurniture?.map((e) => e.toJson()).toList()
          : customFurniture?.map((e) => e.toJson()).toList(),
    };
  }
}

// 공간 기본 정보 모델
class SpaceBasicInfo {
  final String siteAddress;
  final DateTime openingDate;
  final String recipient;
  final String contactNumber;
  final String shippingMethod;
  final String paymentMethod;
  final String additionalNotes;

  SpaceBasicInfo({
    required this.siteAddress,
    required this.openingDate,
    required this.recipient,
    required this.contactNumber,
    required this.shippingMethod,
    required this.paymentMethod,
    required this.additionalNotes,
  });

  factory SpaceBasicInfo.fromJson(Map<String, dynamic> json) {
    return SpaceBasicInfo(
      siteAddress: json['siteAddress'] ?? '',
      openingDate:
          (json['openingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recipient: json['recipient'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      shippingMethod: json['shippingMethod'] ?? '',
      paymentMethod: json['paymentMethod'] ?? '',
      additionalNotes: json['additionalNotes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'siteAddress': siteAddress,
      'openingDate': Timestamp.fromDate(openingDate),
      'recipient': recipient,
      'contactNumber': contactNumber,
      'shippingMethod': shippingMethod,
      'paymentMethod': paymentMethod,
      'additionalNotes': additionalNotes,
    };
  }
}

// 공간 세부 정보 모델
class SpaceDetailInfo {
  final double minBudget;
  final double maxBudget;
  final double spaceArea;
  final List<String> targetAgeGroups;
  final String businessType;
  final String concept;
  final String additionalNotes;
  final List<String> designFileUrls;

  SpaceDetailInfo({
    required this.minBudget,
    required this.maxBudget,
    required this.spaceArea,
    required this.targetAgeGroups,
    required this.businessType,
    required this.concept,
    required this.additionalNotes,
    required this.designFileUrls,
  });

  factory SpaceDetailInfo.fromJson(Map<String, dynamic> json) {
    return SpaceDetailInfo(
      minBudget: (json['minBudget'] ?? 0).toDouble(),
      maxBudget: (json['maxBudget'] ?? 0).toDouble(),
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
      'minBudget': minBudget,
      'maxBudget': maxBudget,
      'spaceArea': spaceArea,
      'targetAgeGroups': targetAgeGroups,
      'businessType': businessType,
      'concept': concept,
      'additionalNotes': additionalNotes,
      'designFileUrls': designFileUrls,
    };
  }
}

// 기존 가구 모델
class ExistingFurniture {
  final String id;
  final String name;
  final int quantity;
  final double price;

  ExistingFurniture({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory ExistingFurniture.fromJson(Map<String, dynamic> json) {
    return ExistingFurniture(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }
}

// 제작 가구 모델
class CustomFurniture {
  final String id;
  final String category;
  final int quantity;
  final TopBoard topBoard;
  final BottomBoard bottomBoard;
  final double price;

  CustomFurniture({
    required this.id,
    required this.category,
    required this.quantity,
    required this.topBoard,
    required this.bottomBoard,
    required this.price,
  });

  factory CustomFurniture.fromJson(Map<String, dynamic> json) {
    return CustomFurniture(
      id: json['id'] ?? '',
      category: json['category'] ?? '',
      quantity: json['quantity'] ?? 0,
      topBoard: TopBoard.fromJson(json['topBoard'] ?? {}),
      bottomBoard: BottomBoard.fromJson(json['bottomBoard'] ?? {}),
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'quantity': quantity,
      'topBoard': topBoard.toJson(),
      'bottomBoard': bottomBoard.toJson(),
      'price': price,
    };
  }
}

// 상판 정보
class TopBoard {
  final String type;
  final String material;
  final Size size;

  TopBoard({
    required this.type,
    required this.material,
    required this.size,
  });

  factory TopBoard.fromJson(Map<String, dynamic> json) {
    return TopBoard(
      type: json['type'] ?? '',
      material: json['material'] ?? '',
      size: Size.fromJson(json['size'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'material': material,
      'size': size.toJson(),
    };
  }
}

// 하판 정보
class BottomBoard {
  final String color;

  BottomBoard({
    required this.color,
  });

  factory BottomBoard.fromJson(Map<String, dynamic> json) {
    return BottomBoard(
      color: json['color'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color,
    };
  }
}

// 사이즈 정보
class Size {
  final double width;
  final double height;
  final double depth;

  Size({
    required this.width,
    required this.height,
    required this.depth,
  });

  factory Size.fromJson(Map<String, dynamic> json) {
    return Size(
      width: (json['width'] ?? 0).toDouble(),
      height: (json['height'] ?? 0).toDouble(),
      depth: (json['depth'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'depth': depth,
    };
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

      // 1. 먼저 고객 문서 생성
      final customerRef =
          FirebaseFirestore.instance.collection('customers').doc();
      // 2. 기본 견적 문서 생성
      final estimateRef =
          FirebaseFirestore.instance.collection('estimates').doc();
      final estimateData = {
        'customerId': customerRef.id,
        'createdAt': now,
        'updatedAt': now,
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'spaceBasicInfo': null,
        'spaceDetailInfo': null,
        'furnitureType': null, // 아직 선택되지 않음
        'furniture': null,
      };

      // 3. 고객 데이터에 견적 ID 포함
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
        'estimateIds': [estimateRef.id], // 첫 견적 ID 추가
      };

      // 4. 트랜잭션으로 두 문서 동시 생성
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(customerRef, customerData);
        transaction.set(estimateRef, estimateData);
      });

      state = AsyncValue.data(await _fetchCustomers());
      return customerRef.id;
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

      // 고객의 모든 견적 삭제
      for (final estimateId in customer.estimateIds) {
        try {
          await FirebaseFirestore.instance
              .collection('estimates')
              .doc(estimateId)
              .delete();
        } catch (e) {
          print('Error deleting estimate: $e');
        }
      }

      // Firestore에서 고객 문서 삭제
      await FirebaseFirestore.instance.collection('customers').doc(id).delete();

      state = AsyncValue.data(await _fetchCustomers());
    } catch (e) {
      print('Error in deleteCustomer: $e');
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  // 고객 조회
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

  // 고객에 새로운 견적 추가
  Future<String> addEstimate(String customerId) async {
    try {
      final now = Timestamp.now();

      // 1. 새 견적 문서 생성
      final estimateRef =
          FirebaseFirestore.instance.collection('estimates').doc();
      final estimateData = {
        'customerId': customerId,
        'createdAt': now,
        'updatedAt': now,
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'spaceBasicInfo': null,
        'spaceDetailInfo': null,
        'furnitureType': null,
        'furniture': null,
      };

      // 2. 고객 문서의 estimateIds 배열에 새 견적 ID 추가
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final customerDoc = await transaction.get(
            FirebaseFirestore.instance.collection('customers').doc(customerId));

        final currentEstimateIds =
            List<String>.from(customerDoc.data()?['estimateIds'] ?? []);
        currentEstimateIds.add(estimateRef.id);

        transaction.update(
            FirebaseFirestore.instance.collection('customers').doc(customerId),
            {
              'estimateIds': currentEstimateIds,
              'updatedAt': now,
            });
        transaction.set(estimateRef, estimateData);
      });

      state = AsyncValue.data(await _fetchCustomers());
      return estimateRef.id;
    } catch (e) {
      print('Error in addEstimate: $e');
      rethrow;
    }
  }

  // 견적 조회
  Future<Estimate?> getEstimate(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('estimates')
          .doc(id)
          .get();

      if (doc.exists) {
        return Estimate.fromJson(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting estimate: $e');
      rethrow;
    }
  }

  // 견적 업데이트
  Future<void> updateEstimate(String id, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection('estimates').doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state = AsyncValue.data(await _fetchCustomers());
    } catch (e) {
      print('Error updating estimate: $e');
      rethrow;
    }
  }

  // 파일 업로드 유틸리티 함수
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
}

// 필터 파라미터를 위한 클래스
class FilterParams {
  final String? searchTerm;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? assignedToId;

  FilterParams({
    this.searchTerm,
    this.startDate,
    this.endDate,
    this.assignedToId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterParams &&
          runtimeType == other.runtimeType &&
          searchTerm == other.searchTerm &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          assignedToId == other.assignedToId;

  @override
  int get hashCode =>
      searchTerm.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      assignedToId.hashCode;
}

// 필터된 고객 Provider
final filteredCustomersProvider = AsyncNotifierProvider.family<
    FilteredCustomersNotifier, List<Customer>, FilterParams>(() {
  return FilteredCustomersNotifier();
});

// 필터된 고객 Notifier
class FilteredCustomersNotifier
    extends FamilyAsyncNotifier<List<Customer>, FilterParams> {
  @override
  Future<List<Customer>> build(FilterParams params) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('customers');

      // 담당자 필터링
      if (params.assignedToId != null) {
        query = query.where('assignedTo', isEqualTo: params.assignedToId);
      }

      // 날짜 필터링
      if (params.startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(params.startDate!));
      }
      if (params.endDate != null) {
        query = query.where('createdAt',
            isLessThan: Timestamp.fromDate(
                params.endDate!.add(const Duration(days: 1))));
      }

      // 생성일 기준으로 정렬
      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      final customers = snapshot.docs
          .map((doc) => Customer.fromJson(doc.id, doc.data()))
          .toList();

      // 검색어 필터링
      if (params.searchTerm?.isNotEmpty == true) {
        final term = params.searchTerm!.toLowerCase();
        return customers
            .where((customer) =>
                customer.name.toLowerCase().contains(term) ||
                customer.address.toLowerCase().contains(term) ||
                customer.email.toLowerCase().contains(term) ||
                customer.note.toLowerCase().contains(term))
            .toList();
      }

      return customers;
    } catch (e) {
      print('Error in FilteredCustomersNotifier: $e');
      rethrow;
    }
  }

  // 필터 업데이트 메서드
  Future<void> updateFilter(FilterParams newParams) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await build(newParams));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // 담당 고객 수 가져오기
  Future<int?> getAssignedCustomerCount(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('assignedTo', isEqualTo: userId)
          .count()
          .get();

      return snapshot.count;
    } catch (e) {
      print('Error getting assigned customer count: $e');
      rethrow;
    }
  }

  // 견적 수 가져오기
  Future<int> getEstimatesCount(String userId) async {
    try {
      final customerSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('assignedTo', isEqualTo: userId)
          .get();

      int totalEstimates = 0;
      for (var doc in customerSnapshot.docs) {
        final customer = Customer.fromJson(doc.id, doc.data());
        totalEstimates += customer.estimateIds.length;
      }

      return totalEstimates;
    } catch (e) {
      print('Error getting estimates count: $e');
      rethrow;
    }
  }

  // 계약 수 가져오기
  Future<int?> getContractsCount(String userId) async {
    try {
      final estimatesSnapshot = await FirebaseFirestore.instance
          .collection('estimates')
          .where('status', isEqualTo: EstimateStatus.CONTRACTED.toString())
          .get();

      final customerIds = estimatesSnapshot.docs
          .map((doc) => doc.data()['customerId'] as String)
          .toSet();

      if (customerIds.isEmpty) return 0;

      final customerSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('assignedTo', isEqualTo: userId)
          .where(FieldPath.documentId, whereIn: customerIds.toList())
          .count()
          .get();

      return customerSnapshot.count;
    } catch (e) {
      print('Error getting contracts count: $e');
      rethrow;
    }
  }
}

// Product 모델 추가
