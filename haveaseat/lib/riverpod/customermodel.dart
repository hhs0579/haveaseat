import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/services.dart' show ByteData, Uint8List, rootBundle;

// 견적서 상태를 관리하기 위한 enum
enum EstimateStatus {
  IN_PROGRESS, // 견적중
  CONTRACTED, // 계약완료
  CANCELED // 취소됨
}

enum CustomerStatus {
  ESTIMATE_IN_PROGRESS('견적진행중'),
  ESTIMATE_COMPLETE('견적완료'),
  CONTRACT_COMPLETE('계약완료'),
  ORDER_START('발주시작'),
  RECEIVING('입고'),
  INSPECTION('검수'),
  DELIVERY('납품'),
  REVIEW('후기'),
  COMPLETE('완료');

  final String label;
  const CustomerStatus(this.label);
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
  final CustomerStatus status;
  final String assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> estimateIds;
  final bool isDraft; // 추가

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.businessLicenseUrl,
    required this.otherDocumentUrls,
    required this.note,
    this.status = CustomerStatus.ESTIMATE_IN_PROGRESS,
    required this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    required this.estimateIds,
    this.isDraft = false, // 기본값 false
  });

  factory Customer.fromJson(String id, Map<String, dynamic> json) {
    String statusStr =
        json['status'] as String? ?? CustomerStatus.ESTIMATE_IN_PROGRESS.name;
    CustomerStatus status;
    try {
      status = CustomerStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => CustomerStatus.ESTIMATE_IN_PROGRESS,
      );
    } catch (e) {
      status = CustomerStatus.ESTIMATE_IN_PROGRESS;
    }

    return Customer(
      id: id,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      businessLicenseUrl: json['businessLicenseUrl'] ?? '',
      otherDocumentUrls: List<String>.from(json['otherDocumentUrls'] ?? []),
      note: json['note'] ?? '',
      status: status, // enum 값 사용
      assignedTo: json['assignedTo'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estimateIds: List<String>.from(json['estimateIds'] ?? []),
      isDraft: json['isDraft'] ?? false, // 추가
    );
  }

  // Customer 클래스의 toJson 메서드도 수정
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'businessLicenseUrl': businessLicenseUrl,
      'otherDocumentUrls': otherDocumentUrls,
      'note': note,
      'status': status.name, // enum의 name을 저장
      'assignedTo': assignedTo,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'estimateIds': estimateIds,
      'isDraft': isDraft, // 추가
    };
  }
}

// 견적서 모델// Estimate 클래스 수정 - memo 필드 추가
class Estimate {
  final String id;
  final String customerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EstimateStatus status;
  final String managerName;
  final String managerPhone;

  // 공간 기본 정보
  final String siteAddress;
  final DateTime openingDate;
  final String recipient;
  final String contactNumber;
  final String shippingMethod;
  final String paymentMethod;
  final String basicNotes;
  // 공간 상세 정보
  final double minBudget;
  final double maxBudget;
  final double spaceArea;
  final List<String> targetAgeGroups;
  final String businessType;
  final List<String> concept;
  final String spaceUnit;
  final String detailNotes;
  final List<String> designFileUrls;
  // 가구 정보
  final List<ExistingFurniture> furnitureList;
  // 메모 필드 추가
  final String memo;

  Estimate({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.managerName,
    required this.managerPhone,
    required this.siteAddress,
    required this.openingDate,
    required this.recipient,
    required this.contactNumber,
    required this.shippingMethod,
    required this.paymentMethod,
    required this.basicNotes,
    required this.minBudget,
    required this.maxBudget,
    required this.spaceArea,
    required this.targetAgeGroups,
    required this.businessType,
    required this.concept,
    required this.spaceUnit,
    required this.detailNotes,
    required this.designFileUrls,
    required this.furnitureList,
    this.memo = '', // memo에 기본값 설정
  });

  factory Estimate.fromJson(String id, Map<String, dynamic> json) {
    return Estimate(
      id: id,
      customerId: json['customerId'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: EstimateStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => EstimateStatus.IN_PROGRESS,
      ),
      managerName: json['managerName'] ?? '',
      managerPhone: json['managerPhone'] ?? '',
      // 공간 기본 정보
      siteAddress: json['siteAddress'] ?? '',
      openingDate:
          (json['openingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recipient: json['recipient'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      shippingMethod: json['shippingMethod'] ?? '',
      paymentMethod: json['paymentMethod'] ?? '',
      basicNotes: json['basicNotes'] ?? '',
      // 공간 상세 정보
      minBudget: (json['minBudget'] ?? 0).toDouble(),
      maxBudget: (json['maxBudget'] ?? 0).toDouble(),
      spaceArea: (json['spaceArea'] ?? 0).toDouble(),
      targetAgeGroups: List<String>.from(json['targetAgeGroups'] ?? []),
      businessType: json['businessType'] ?? '',
      concept: List<String>.from(json['concept'] ?? []),
      spaceUnit: json['spaceUnit'] ?? '평',
      detailNotes: json['detailNotes'] ?? '',
      designFileUrls: List<String>.from(json['designFileUrls'] ?? []),
      // 가구 정보
      furnitureList: (json['furnitureList'] as List<dynamic>?)
              ?.map((e) => ExistingFurniture.fromJson(e))
              .toList() ??
          [],
      // 메모 추가
      memo: json['memo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status.toString(),
      'managerName': managerName,
      'managerPhone': managerPhone,
      // 공간 기본 정보
      'siteAddress': siteAddress,
      'openingDate': Timestamp.fromDate(openingDate),
      'recipient': recipient,
      'contactNumber': contactNumber,
      'shippingMethod': shippingMethod,
      'paymentMethod': paymentMethod,
      'basicNotes': basicNotes,
      // 공간 상세 정보
      'minBudget': minBudget,
      'maxBudget': maxBudget,
      'spaceArea': spaceArea,
      'targetAgeGroups': targetAgeGroups,
      'businessType': businessType,
      'concept': concept,
      'spaceUnit': spaceUnit,
      'detailNotes': detailNotes,
      'designFileUrls': designFileUrls,
      // 가구 정보
      'furnitureList': furnitureList.map((e) => e.toJson()).toList(),
      // 메모 추가
      'memo': memo,
    };
  }

  // 빈 견적 생성을 위한 팩토리 메서드 수정
  factory Estimate.empty(String customerId) {
    return Estimate(
      id: '',
      customerId: customerId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: EstimateStatus.IN_PROGRESS,
      managerName: '',
      managerPhone: '',
      // 공간 기본 정보
      siteAddress: '',
      openingDate: DateTime.now(),
      recipient: '',
      contactNumber: '',
      shippingMethod: '',
      paymentMethod: '',
      basicNotes: '',
      // 공간 상세 정보
      minBudget: 0,
      maxBudget: 0,
      spaceArea: 0,
      targetAgeGroups: [],
      businessType: '',
      concept: [],
      spaceUnit: '',
      detailNotes: '',
      designFileUrls: [],
      // 가구 정보
      furnitureList: [],
      // 메모 추가
      memo: '',
    );
  }

  // copyWith 메서드에 memo 추가
  Estimate copyWith({
    String? id,
    String? customerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    EstimateStatus? status,
    String? managerName,
    String? managerPhone,
    String? siteAddress,
    DateTime? openingDate,
    String? recipient,
    String? contactNumber,
    String? shippingMethod,
    String? paymentMethod,
    String? basicNotes,
    double? minBudget,
    double? maxBudget,
    double? spaceArea,
    List<String>? targetAgeGroups,
    String? businessType,
    List<String>? concept,
    String? spaceUnit,
    String? detailNotes,
    List<String>? designFileUrls,
    List<ExistingFurniture>? furnitureList,
    String? memo,
  }) {
    return Estimate(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      managerName: managerName ?? this.managerName,
      managerPhone: managerPhone ?? this.managerPhone,
      siteAddress: siteAddress ?? this.siteAddress,
      openingDate: openingDate ?? this.openingDate,
      recipient: recipient ?? this.recipient,
      contactNumber: contactNumber ?? this.contactNumber,
      shippingMethod: shippingMethod ?? this.shippingMethod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      basicNotes: basicNotes ?? this.basicNotes,
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      spaceArea: spaceArea ?? this.spaceArea,
      targetAgeGroups: targetAgeGroups ?? this.targetAgeGroups,
      businessType: businessType ?? this.businessType,
      concept: concept ?? this.concept,
      spaceUnit: spaceUnit ?? this.spaceUnit,
      detailNotes: detailNotes ?? this.detailNotes,
      designFileUrls: designFileUrls ?? this.designFileUrls,
      furnitureList: furnitureList ?? this.furnitureList,
      memo: memo ?? this.memo,
    );
  }

  // 전체 견적 금액 계산
  double get totalAmount {
    return furnitureList.fold(
        0, (sum, furniture) => sum + (furniture.price * furniture.quantity));
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

// Estimate Provider
final estimatesProvider =
    StateNotifierProvider<EstimatesNotifier, List<Estimate>>((ref) {
  return EstimatesNotifier();
});

// Estimate Notifier
class EstimatesNotifier extends StateNotifier<List<Estimate>> {
  EstimatesNotifier() : super([]);

  // 고객의 모든 견적 로드
  Future<void> loadCustomerEstimates(String customerId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('estimates')
          .where('customerId', isEqualTo: customerId)
          .get();

      final estimates = snapshot.docs
          .map((doc) => Estimate.fromJson(doc.id, doc.data()))
          .toList();

      state = estimates;
    } catch (e) {
      print('Error loading estimates: $e');
      rethrow;
    }
  }

  // 새 견적 추가
  Future<String> addEstimate(String customerId) async {
    try {
      final now = DateTime.now();
      final estimateRef =
          FirebaseFirestore.instance.collection('estimates').doc();
      final newEstimate = Estimate.empty(customerId);

      final estimateData = {
        ...newEstimate.toJson(),
        'id': estimateRef.id,
        'createdAt': now,
        'updatedAt': now,
      };

      // Firestore에 견적 저장
      await estimateRef.set(estimateData);

      // 고객 문서에 견적 ID 추가
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .update({
        'estimateIds': FieldValue.arrayUnion([estimateRef.id]),
        'updatedAt': now,
      });

      state = [...state, Estimate.fromJson(estimateRef.id, estimateData)];
      return estimateRef.id;
    } catch (e) {
      print('Error adding estimate: $e');
      rethrow;
    }
  }

  // 견적 공간 기본 정보 업데이트
  Future<void> updateSpaceBasicInfo({
    required String estimateId,
    required String siteAddress,
    required DateTime openingDate,
    required String recipient,
    required String contactNumber,
    required String shippingMethod,
    required String paymentMethod,
    required String basicNotes,
  }) async {
    try {
      final index = state.indexWhere((e) => e.id == estimateId);
      if (index == -1) return;

      final updated = state[index].copyWith(
        siteAddress: siteAddress,
        openingDate: openingDate,
        recipient: recipient,
        contactNumber: contactNumber,
        shippingMethod: shippingMethod,
        paymentMethod: paymentMethod,
        basicNotes: basicNotes,
        updatedAt: DateTime.now(),
      );

      await _updateEstimateInFirestore(updated);
      state = [
        ...state.sublist(0, index),
        updated,
        ...state.sublist(index + 1)
      ];
    } catch (e) {
      print('Error updating space basic info: $e');
      rethrow;
    }
  }
  // spacemodel.dart의 EstimatesNotifier 클래스에서 updateSpaceDetailInfo 수정

  Future<void> updateSpaceDetailInfo({
    required String estimateId,
    required double minBudget,
    required double maxBudget,
    required double spaceArea,
    required String spaceUnit, // 단위 추가
    required List<String> targetAgeGroups,
    required String businessType,
    required List<String> concept, // List<String>으로 변경
    required String detailNotes,
    required List<String> designFileUrls,
  }) async {
    try {
      // 기존 데이터 가져오기
      final estimateDoc = await FirebaseFirestore.instance
          .collection('estimates')
          .doc(estimateId)
          .get();

      if (!estimateDoc.exists) {
        throw Exception('견적서를 찾을 수 없습니다');
      }

      // 업데이트할 데이터 준비
      final updateData = {
        'minBudget': minBudget,
        'maxBudget': maxBudget,
        'spaceArea': spaceArea,
        'spaceUnit': spaceUnit, // 단위 저장
        'targetAgeGroups': targetAgeGroups,
        'businessType': businessType,
        'concept': concept,
        'detailNotes': detailNotes,
        'designFileUrls': designFileUrls,
        'status': EstimateStatus.IN_PROGRESS.toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // estimates 컬렉션에 저장 (merge: true로 설정하여 기존 데이터 유지)
      await FirebaseFirestore.instance
          .collection('estimates')
          .doc(estimateId)
          .set(updateData, SetOptions(merge: true));

      // 로컬 상태 업데이트
      final index = state.indexWhere((e) => e.id == estimateId);
      if (index != -1) {
        final updated = state[index].copyWith(
          minBudget: minBudget,
          maxBudget: maxBudget,
          spaceArea: spaceArea,
          spaceUnit: spaceUnit, // 단위 저장
          targetAgeGroups: targetAgeGroups,
          businessType: businessType,
          concept: concept,
          detailNotes: detailNotes,
          designFileUrls: designFileUrls,
        );
        state = [
          ...state.sublist(0, index),
          updated,
          ...state.sublist(index + 1)
        ];
      }
    } catch (e) {
      print('Error updating space detail info: $e');
      rethrow;
    }
    // 견적서 데이터 가져오기
    Future<List<Map<String, dynamic>>> fetchEstimates(String customerId) async {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('estimates')
            .where('customerId', isEqualTo: customerId)
            .get();

        return snapshot.docs.map((doc) {
          final data = doc.data();
          final furnitureList = data['furnitureList'] as List<dynamic>? ?? [];

          if (furnitureList.isEmpty) {
            return {
              'estimateId': doc.id,
              'status': CustomerStatus.values
                  .firstWhere(
                    (e) => e.name == (data['status'] ?? ''),
                    orElse: () => CustomerStatus.ESTIMATE_IN_PROGRESS,
                  )
                  .label,
              'type': data['type'] ?? '견적',
              'productName': '',
              'orderDate': data['createdAt'] ?? Timestamp.now(),
              'amount': 0.0,
              'deliveryAddress': data['siteAddress'] ?? '',
              'managerName': data['managerName'] ?? '',
              'note': data['detailNotes'] ?? ''
            };
          }

          // 총 금액 계산
          double totalAmount = furnitureList.fold(0, (sum, furniture) {
            return sum +
                ((furniture['price'] ?? 0) * (furniture['quantity'] ?? 0));
          });

          // 상품명 표시 로직
          String productName = furnitureList.length > 1
              ? '${furnitureList[0]['name']} 외 ${furnitureList.length - 1}건'
              : furnitureList[0]['name'];

          return {
            'estimateId': doc.id,
            'status': CustomerStatus.values
                .firstWhere(
                  (e) => e.name == (data['status'] ?? ''),
                  orElse: () => CustomerStatus.ESTIMATE_IN_PROGRESS,
                )
                .label,
            'type': data['type'] ?? '견적',
            'productName': productName,
            'orderDate': data['createdAt'] ?? Timestamp.now(),
            'amount': totalAmount,
            'deliveryAddress': data['siteAddress'] ?? '',
            'managerName': data['managerName'] ?? '',
            'note': data['detailNotes'] ?? ''
          };
        }).toList();
      } catch (e) {
        print('Error fetching estimates: $e');
        return [];
      }
    }
  }

  // 견적 가구 정보 업데이트
  Future<void> updateFurnitureList({
    required String estimateId,
    required List<ExistingFurniture> furnitureList,
  }) async {
    try {
      final index = state.indexWhere((e) => e.id == estimateId);
      if (index == -1) return;

      final updated = state[index].copyWith(
        furnitureList: furnitureList,
        updatedAt: DateTime.now(),
      );

      await _updateEstimateInFirestore(updated);
      state = [
        ...state.sublist(0, index),
        updated,
        ...state.sublist(index + 1)
      ];
    } catch (e) {
      print('Error updating furniture list: $e');
      rethrow;
    }
  }

  // 견적 상태 업데이트
  Future<void> updateEstimateStatus(
      String estimateId, EstimateStatus status) async {
    try {
      final index = state.indexWhere((e) => e.id == estimateId);
      if (index == -1) return;

      final updated = state[index].copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );

      await _updateEstimateInFirestore(updated);
      state = [
        ...state.sublist(0, index),
        updated,
        ...state.sublist(index + 1)
      ];
    } catch (e) {
      print('Error updating estimate status: $e');
      rethrow;
    }
  }

  // Firestore 업데이트 유틸리티 메서드
  Future<void> _updateEstimateInFirestore(Estimate estimate) async {
    await FirebaseFirestore.instance
        .collection('estimates')
        .doc(estimate.id)
        .update(estimate.toJson());
  }
}

Future<double> getCustomerTotalAmount(String customerId) async {
  try {
    // 고객의 모든 견적서 가져오기
    final estimatesSnapshot = await FirebaseFirestore.instance
        .collection('estimates')
        .where('customerId', isEqualTo: customerId)
        .get();

    double totalAmount = 0;

    // 각 견적서의 가구 리스트에서 가격 합산
    for (var doc in estimatesSnapshot.docs) {
      final estimate = Estimate.fromJson(doc.id, doc.data());
      totalAmount +=
          estimate.totalAmount; // Estimate 클래스의 totalAmount getter 사용
    }

    return totalAmount;
  } catch (e) {
    print('Error calculating total amount: $e');
    return 0;
  }
}

Future<Map<String, double>> getCustomersTotalAmounts(
    List<String> customerIds) async {
  try {
    Map<String, double> results = {};

    // 모든 견적서를 한 번에 가져오기
    final estimatesSnapshot = await FirebaseFirestore.instance
        .collection('estimates')
        .where('customerId', whereIn: customerIds)
        .get();

    // 고객 ID별로 견적서 그룹화
    Map<String, List<Estimate>> customerEstimates = {};
    for (var doc in estimatesSnapshot.docs) {
      final estimate = Estimate.fromJson(doc.id, doc.data());
      customerEstimates
          .putIfAbsent(estimate.customerId, () => [])
          .add(estimate);
    }

    // 각 고객별 총액 계산
    for (var customerId in customerIds) {
      final estimates = customerEstimates[customerId] ?? [];
      double totalAmount = 0;
      for (var estimate in estimates) {
        totalAmount += estimate.totalAmount;
      }
      results[customerId] = totalAmount;
    }

    return results;
  } catch (e) {
    print('Error calculating total amounts: $e');
    return {};
  }
}

// Customer Provider
final customerDataProvider =
    AsyncNotifierProvider<CustomerNotifier, List<Customer>>(() {
  return CustomerNotifier();
});

// 필터된 고객 Provider
final filteredCustomersProvider = AsyncNotifierProvider.family<
    FilteredCustomersNotifier, List<Customer>, FilterParams>(() {
  return FilteredCustomersNotifier();
});

// 나머지 코드는 동일하게 유지...
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

  Future<void> updateCustomerStatus(
      String customerId, CustomerStatus newStatus) async {
    try {
      state = const AsyncValue.loading();

      // Update the status in Firestore
      // CustomerStatus enum을 올바른 string 값으로 변환
      final statusValue = newStatus.name; // enum의 name 속성 사용

      await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .update({
        'status': statusValue, // enum의 name을 저장
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh the customers list
      state = AsyncValue.data(await _fetchCustomers());
    } catch (e) {
      print('Error updating customer status: $e');
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<Map<String, double>> getCustomersTotalAmounts(
      List<String> customerIds) async {
    try {
      Map<String, double> results = {};

      final estimatesSnapshot = await FirebaseFirestore.instance
          .collection('estimates')
          .where('customerId', whereIn: customerIds)
          .get();

      Map<String, List<Estimate>> customerEstimates = {};
      for (var doc in estimatesSnapshot.docs) {
        final estimate = Estimate.fromJson(doc.id, doc.data());
        customerEstimates
            .putIfAbsent(estimate.customerId, () => [])
            .add(estimate);
      }

      for (var customerId in customerIds) {
        final estimates = customerEstimates[customerId] ?? [];
        double totalAmount = 0;
        for (var estimate in estimates) {
          totalAmount += estimate.totalAmount;
        }
        results[customerId] = totalAmount;
      }

      return results;
    } catch (e) {
      print('Error calculating total amounts: $e');
      return {};
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
    bool isDraft = false, // 추가: 정식저장/임시저장 구분
  }) async {
    try {
      state = const AsyncValue.loading();
      final now = DateTime.now();

      // 1. 고객 문서 생성 (임시/정식 모두 생성)
      final customerRef =
          FirebaseFirestore.instance.collection('customers').doc();
      final estimateRef =
          FirebaseFirestore.instance.collection('estimates').doc();

      final estimateData =
          Estimate.empty(customerRef.id).copyWith(id: estimateRef.id).toJson();

      // 3. 고객 데이터
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
        'estimateIds': [estimateRef.id],
        'isDraft': isDraft, // 추가
      };

      // 임시/정식 모두 customers 문서 생성
      await customerRef.set(customerData);
      // 정식저장일 때만 estimates 문서도 같이 생성
      if (!isDraft) {
        await estimateRef.set(estimateData);
      }

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

      for (final url in customer.otherDocumentUrls) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (e) {
          print('Error deleting other document: $e');
        }
      }

      // 견적 삭제
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

// 필터 파라미터 클래스
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

// 필터된 고객 Notifier
class FilteredCustomersNotifier
    extends FamilyAsyncNotifier<List<Customer>, FilterParams> {
  @override
  Future<List<Customer>> build(FilterParams params) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('customers');

      if (params.assignedToId != null) {
        query = query.where('assignedTo', isEqualTo: params.assignedToId);
      }

      if (params.startDate != null) {
        query = query.where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(params.startDate!));
      }

      if (params.endDate != null) {
        query = query.where('createdAt',
            isLessThan: Timestamp.fromDate(
                params.endDate!.add(const Duration(days: 1))));
      }

      query = query.orderBy('createdAt', descending: true);
      final snapshot = await query.get();
      final customers = snapshot.docs
          .map((doc) => Customer.fromJson(doc.id, doc.data()))
          .toList();

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

  // 필터 업데이트
  Future<void> updateFilter(FilterParams newParams) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await build(newParams));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // 담당 고객 수 조회
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

  // 견적 수 조회
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

  // 계약 수 조회
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
