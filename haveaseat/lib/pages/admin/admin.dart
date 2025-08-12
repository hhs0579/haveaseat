import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haveaseat/components/colors.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String _query = '';
  String _filter = 'all';

  Future<void> _setApproval(String uid, bool value) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'approved': value,
    }, SetOptions(merge: true));
  }

  Future<void> _setRole(String uid, String role) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'role': role,
    }, SetOptions(merge: true));
  }

  bool _applyFilter(Map<String, dynamic> d) {
    final approved = (d['approved'] as bool?) ?? false;
    final role = (d['role'] as String?) ?? 'user';
    switch (_filter) {
      case 'pending':
        return role != 'admin' && !approved;
      case 'approved':
        return role != 'admin' && approved;
      case 'admin':
        return role == 'admin';
      default:
        return true;
    }
  }

  bool _applySearch(String uid, Map<String, dynamic> d) {
    if (_query.trim().isEmpty) return true;
    final q = _query.trim().toLowerCase();
    return ((d['email'] as String? ?? '').toLowerCase().contains(q)) ||
        ((d['name'] as String? ?? '').toLowerCase().contains(q)) ||
        ((d['phoneNumber'] as String? ?? '').toLowerCase().contains(q)) ||
        uid.toLowerCase().contains(q);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColor.main,
        title: Row(
          children: [
            const Text('관리자 페이지', style: TextStyle(color: Colors.white)),
            const SizedBox(width: 30),
            TextButton(
              onPressed: () => context.pushNamed('productExcel'),
              child: const Text('제품수정', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => context.go('/main'),
              child: const Text('메인으로', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _logout,
              child: const Text('로그아웃', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColor.main.withOpacity(0.05),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '이름/이메일/전화/UID 검색',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColor.main),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filter,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black),
                  underline: Container(height: 2, color: AppColor.main),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('전체')),
                    DropdownMenuItem(value: 'pending', child: Text('승인대기')),
                    DropdownMenuItem(value: 'approved', child: Text('승인완료')),
                    DropdownMenuItem(value: 'admin', child: Text('관리자')),
                  ],
                  onChanged: (v) => setState(() => _filter = v ?? 'all'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColor.main),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('오류: ${snap.error}'));
                }
                final docs = snap.data?.docs ?? [];
                final filtered = docs
                    .where((e) =>
                        _applyFilter(e.data()) && _applySearch(e.id, e.data()))
                    .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('표시할 사용자가 없습니다.'));
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColor.main),
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final uid = doc.id;
                    final d = doc.data();
                    final name = (d['name'] as String?) ?? '';
                    final email = (d['email'] as String?) ?? '';
                    final phone = (d['phoneNumber'] as String?) ?? '';
                    final role = (d['role'] as String?) ?? 'user';
                    final approved = (d['approved'] as bool?) ?? false;

                    return ListTile(
                      tileColor:
                          i % 2 == 0 ? AppColor.main.withOpacity(0.02) : null,
                      title: Text(name.isEmpty ? email : '$name · $email',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('uid: $uid\n전화: $phone'),
                      isThreeLine: true,
                      leading: CircleAvatar(
                        backgroundColor: AppColor.main,
                        child: Text(role == 'admin' ? 'A' : 'U',
                            style: const TextStyle(color: Colors.white)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(role == 'admin'
                                  ? '관리자'
                                  : (approved ? '승인됨' : '대기중')),
                              const SizedBox(height: 6),
                              if (role != 'admin')
                                SizedBox(
                                  height: 24,
                                  child: FittedBox(
                                    child: Switch(
                                      activeColor: AppColor.main,
                                      value: approved,
                                      onChanged: (v) => _setApproval(uid, v),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            color: Colors.white,
                            tooltip: '역할 변경',
                            onSelected: (v) async {
                              if (v == 'toAdmin') {
                                await _setRole(uid, 'admin');
                              } else if (v == 'toUser') {
                                await _setRole(uid, 'user');
                              }
                            },
                            itemBuilder: (_) => [
                              if (role != 'admin')
                                const PopupMenuItem(
                                    value: 'toAdmin', child: Text('관리자로 지정')),
                              if (role == 'admin')
                                const PopupMenuItem(
                                    value: 'toUser', child: Text('관리자 해제')),
                            ],
                            icon: const Icon(Icons.more_vert,
                                color: AppColor.main),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
