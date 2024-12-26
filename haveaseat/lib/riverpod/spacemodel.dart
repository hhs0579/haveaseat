// import 'dart:io';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:haveaseat/riverpod/customermodel.dart';

// final spaceBasicInfoProvider = StateNotifierProvider<SpaceBasicInfoNotifier,
//     AsyncValue<List<SpaceBasicInfo>>>((ref) {
//   return SpaceBasicInfoNotifier();
// });

// class SpaceBasicInfoNotifier
//     extends StateNotifier<AsyncValue<List<SpaceBasicInfo>>> {
//   SpaceBasicInfoNotifier() : super(const AsyncValue.loading()) {
//     _init();
//   }

//   Future<void> _init() async {
//     try {
//       final spaces = await _fetchSpaceBasicInfos();
//       state = AsyncValue.data(spaces);
//     } catch (e, stack) {
//       state = AsyncValue.error(e, stack);
//     }
//   }
  

//   Future<List<SpaceBasicInfo>> _fetchSpaceBasicInfos() async {
//     try {
//       final snapshot = await FirebaseFirestore.instance
//           .collection('space_basic_infos')
//           .orderBy('createdAt', descending: true)
//           .get();

//       return snapshot.docs.map((doc) {
//         final data = doc.data();
//         return SpaceBasicInfo.fromJson(data);
//       }).toList();
//     } catch (e) {
//       print('Error fetching space basic infos: $e');
//       rethrow;
//     }
//   }

//   Future<void> addSpaceBasicInfo({
//     required String customerId,
//     required String siteAddress,
//     required DateTime openingDate,
//     required String recipient,
//     required String contactNumber,
//     required String shippingMethod, // 변경
//     required String paymentMethod, // 추가
//     // required String additionalNotes,
//   }) async {
//     try {
//       state = const AsyncValue.loading();
//       final now = Timestamp.now();

//       final spaceData = {
//         'customerId': customerId,
//         'siteAddress': siteAddress,
//         'openingDate': Timestamp.fromDate(openingDate),
//         'recipient': recipient,
//         'contactNumber': contactNumber,
//         'shippingMethod': shippingMethod,
//         'paymentMethod': paymentMethod,
//         // 'additionalNotes': additionalNotes,
//         'createdAt': now,
//         'updatedAt': now,
//       };

//       await FirebaseFirestore.instance
//           .collection('space_basic_infos')
//           .doc()
//           .set(spaceData);

//       state = AsyncValue.data(await _fetchSpaceBasicInfos());
//     } catch (e, stack) {
//       print('Error adding space basic info: $e');
//       state = AsyncValue.error(e, stack);
//       rethrow;
//     }
//   }

//   Future<void> updateSpaceBasicInfo({
//     required String id,
//     required String siteAddress,
//     required DateTime openingDate,
//     required String recipient,
//     required String contactNumber,
//     required String shippingMethod, // 변경
//     required String paymentMethod, // 추가
//     // required String additionalNotes,
//   }) async {
//     try {
//       state = const AsyncValue.loading();

//       final updateData = {
//         'siteAddress': siteAddress,
//         'openingDate': Timestamp.fromDate(openingDate),
//         'recipient': recipient,
//         'contactNumber': contactNumber,
//         'shippingMethod': shippingMethod,
//         'paymentMethod': paymentMethod,
//         // 'additionalNotes': additionalNotes,
//         'updatedAt': FieldValue.serverTimestamp(),
//       };

//       await FirebaseFirestore.instance
//           .collection('space_basic_infos')
//           .doc(id)
//           .update(updateData);

//       state = AsyncValue.data(await _fetchSpaceBasicInfos());
//     } catch (e) {
//       print('Error updating space basic info: $e');
//       state = AsyncValue.error(e, StackTrace.current);
//       rethrow;
//     }
//   }
// }

// // Space Detail Info Provider
// final spaceDetailInfoProvider = StateNotifierProvider<SpaceDetailInfoNotifier,
//     AsyncValue<List<SpaceDetailInfo>>>((ref) {
//   return SpaceDetailInfoNotifier();
// });

// class SpaceDetailInfoNotifier
//     extends StateNotifier<AsyncValue<List<SpaceDetailInfo>>> {
//   SpaceDetailInfoNotifier() : super(const AsyncValue.loading()) {
//     _init();
//   }

//   Future<void> _init() async {
//     try {
//       final spaces = await _fetchSpaceDetailInfos();
//       state = AsyncValue.data(spaces);
//     } catch (e, stack) {
//       state = AsyncValue.error(e, stack);
//     }
//   }

//   Future<List<SpaceDetailInfo>> _fetchSpaceDetailInfos() async {
//     try {
//       final snapshot = await FirebaseFirestore.instance
//           .collection('space_detail_infos')
//           .orderBy('createdAt', descending: true)
//           .get();

//       return snapshot.docs.map((doc) {
//         final data = doc.data();
//         return SpaceDetailInfo.fromJson(data);
//       }).toList();
//     } catch (e) {
//       print('Error fetching space detail infos: $e');
//       rethrow;
//     }
//   }

//   Future<void> addSpaceDetailInfo({
//     required String customerId,
//     required double minBudget,  // 변경
//     required double maxBudget,  // 추가
//     required double spaceArea,
//     required List<String> targetAgeGroups,
//     required String businessType,
//     required String concept,
//     required String additionalNotes,
//     required List<String> designFileUrls,
//   }) async {
//     try {
//       state = const AsyncValue.loading();
//       final now = Timestamp.now();

//       final spaceData = {
//         'customerId': customerId,
//         'minBudget': minBudget,  // 변경
//         'maxBudget': maxBudget,  // 추가
//         'spaceArea': spaceArea,
//         'targetAgeGroups': targetAgeGroups,
//         'businessType': businessType,
//         'concept': concept,
//         'additionalNotes': additionalNotes,
//         'designFileUrls': designFileUrls,
//         'createdAt': now,
//         'updatedAt': now,
//       };

//       await FirebaseFirestore.instance
//           .collection('space_detail_infos')
//           .doc()
//           .set(spaceData);

//       state = AsyncValue.data(await _fetchSpaceDetailInfos());
//     } catch (e, stack) {
//       print('Error adding space detail info: $e');
//       state = AsyncValue.error(e, stack);
//       rethrow;
//     }
//   }

 
//   Future<void> updateSpaceDetailInfo({
//     required String id,
//     required double minBudget,  // 변경
//     required double maxBudget,  // 추가
//     required double spaceArea,
//     required List<String> targetAgeGroups,
//     required String businessType,
//     required String concept,
//     required String additionalNotes,
//     required List<String> designFileUrls,
//   }) async {
//     try {
//       state = const AsyncValue.loading();

//       final updateData = {
//         'minBudget': minBudget,  // 변경
//         'maxBudget': maxBudget,  // 추가
//         'spaceArea': spaceArea,
//         'targetAgeGroups': targetAgeGroups,
//         'businessType': businessType,
//         'concept': concept,
//         'additionalNotes': additionalNotes,
//         'designFileUrls': designFileUrls,
//         'updatedAt': FieldValue.serverTimestamp(),
//       };

//       await FirebaseFirestore.instance
//           .collection('space_detail_infos')
//           .doc(id)
//           .update(updateData);

//       state = AsyncValue.data(await _fetchSpaceDetailInfos());
//     } catch (e) {
//       print('Error updating space detail info: $e');
//       state = AsyncValue.error(e, StackTrace.current);
//       rethrow;
//     }
//   }
//   // 설계 파일 업로드 함수
//   Future<String> uploadDesignFile(File file) async {
//     try {
//       final fileName =
//           '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
//       final ref =
//           FirebaseStorage.instance.ref().child('design_files').child(fileName);

//       final uploadTask = ref.putFile(file);
//       final snapshot = await uploadTask;
//       return await snapshot.ref.getDownloadURL();
//     } catch (e) {
//       print('Error uploading design file: $e');
//       rethrow;
//     }
//   }

//   // 임시 저장 기능
//  Future<void> saveTempSpaceDetailInfo({
//     required String customerId,
//     double? minBudget,  // 변경
//     double? maxBudget,  // 추가
//     double? spaceArea,
//     List<String>? targetAgeGroups,
//     String? businessType,
//     String? concept,
//     String? additionalNotes,
//     List<String>? designFileUrls,
//   }) async {
//     try {
//       final tempData = {
//         'customerId': customerId,
//         'minBudget': minBudget,  // 변경
//         'maxBudget': maxBudget,  // 추가
//         'spaceArea': spaceArea,
//         'targetAgeGroups': targetAgeGroups,
//         'businessType': businessType,
//         'concept': concept,
//         'additionalNotes': additionalNotes,
//         'designFileUrls': designFileUrls,
//         'lastUpdated': FieldValue.serverTimestamp(),
//         'isTemp': true,
//       };

//       await FirebaseFirestore.instance
//           .collection('temp_space_detail_infos')
//           .doc(customerId)
//           .set(tempData);
//     } catch (e) {
//       print('Error saving temp space detail info: $e');
//       rethrow;
//     }
//   }
// }
