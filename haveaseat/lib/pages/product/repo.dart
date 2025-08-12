// FILE: lib/product_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:haveaseat/riverpod/customermodel.dart';
import 'package:haveaseat/riverpod/product.dart';
import 'package:haveaseat/riverpod/usermodel.dart';

class ProductRepository {
  final _col = FirebaseFirestore.instance.collection('products');

  Future<List<Product>> fetchAll() async {
    final qs = await _col.orderBy('name').get();
    return qs.docs.map((d) => Product.fromMap(d.data(), id: d.id)).toList();
  }

  /// 병합 업로드: id가 있으면 set(merge), 없으면 새 문서 생성
  Future<void> upsertMany(List<Product> items) async {
    final chunks = _chunk(items, 400);
    for (final part in chunks) {
      final batch = FirebaseFirestore.instance.batch();
      for (final p in part) {
        if (p.id != null && p.id!.isNotEmpty) {
          batch.set(_col.doc(p.id), p.toMap(), SetOptions(merge: true));
        } else {
          batch.set(_col.doc(), p.toMap(), SetOptions(merge: true));
        }
      }
      await batch.commit();
    }
  }

  /// 전체 갈아끼우기: 모든 문서 삭제 후 items로 재작성
  Future<void> replaceAll(List<Product> items) async {
    final snap = await _col.get();
    final delChunks = _chunk(snap.docs, 450);
    for (final part in delChunks) {
      final batch = FirebaseFirestore.instance.batch();
      for (final d in part) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await upsertMany(items);
  }

  Future<Product> addOne(Product p) async {
    final ref = await _col.add(p.toMap());
    return p.copyWith(id: ref.id);
  }

  Future<void> updateOne(Product p) async {
    if (p.id == null) return;
    await _col.doc(p.id).set(p.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteOne(String id) async {
    await _col.doc(id).delete();
  }

  List<List<T>> _chunk<T>(List<T> src, int size) {
    final out = <List<T>>[];
    for (int i = 0; i < src.length; i += size) {
      out.add(src.sublist(i, i + size > src.length ? src.length : i + size));
    }
    return out;
  }
}
