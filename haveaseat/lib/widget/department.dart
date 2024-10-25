// 부서 목록을 관리하는 provider
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final departmentProvider = StateProvider<String?>((ref) => null);
// 드롭다운 열림/닫힘 상태 관리
final isExpandedProvider = StateProvider<bool>((ref) => false);

// 부서 선택 위젯
// DepartmentSelector 위젯 수정
class DepartmentSelector extends ConsumerWidget {
  const DepartmentSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDepartment = ref.watch(departmentProvider);
    final isExpanded = ref.watch(isExpandedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 선택 버튼 - 보더 제거
        InkWell(
          onTap: () {
            ref.read(isExpandedProvider.notifier).state = !isExpanded;
          },
          child: Padding(
            // Container를 Padding으로 변경
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDepartment ?? '소속부서를 선택해주세요',
                  style: TextStyle(
                    color: selectedDepartment != null
                        ? AppColor.font1
                        : AppColor.font1,
                    fontSize: 14,
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_outlined
                      : Icons.keyboard_arrow_down_outlined,
                  color: AppColor.font2,
                ),
              ],
            ),
          ),
        ),
        // 드롭다운 리스트
        if (isExpanded)
          Padding(
            // Container를 Padding으로 변경
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              children: [
                const Divider(height: 1, color: AppColor.line1),
                _buildDepartmentItem(ref, '경영지원팀'),
                const Divider(height: 1, color: AppColor.line1),
                _buildDepartmentItem(ref, '인사팀'),
                const Divider(height: 1, color: AppColor.line1),
                _buildDepartmentItem(ref, '개발팀'),
                const Divider(height: 1, color: AppColor.line1),
                _buildDepartmentItem(ref, '디자인팀'),
                const Divider(height: 1, color: AppColor.line1),
                _buildDepartmentItem(ref, '마케팅팀'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDepartmentItem(WidgetRef ref, String department) {
    final selectedDepartment = ref.watch(departmentProvider);

    return InkWell(
      onTap: () {
        ref.read(departmentProvider.notifier).state = department;
        ref.read(isExpandedProvider.notifier).state = false;
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: selectedDepartment == department
            ? AppColor.primary.withOpacity(0.1)
            : null,
        child: Text(
          department,
          style: TextStyle(
            color: selectedDepartment == department
                ? AppColor.primary
                : AppColor.font1,
            fontSize: 14,
            fontWeight: selectedDepartment == department
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

Widget _buildDepartmentItem(WidgetRef ref, String department) {
  final selectedDepartment = ref.watch(departmentProvider);

  return InkWell(
    onTap: () {
      ref.read(departmentProvider.notifier).state = department;
      ref.read(isExpandedProvider.notifier).state = false; // 선택 후 닫기
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: selectedDepartment == department
          ? AppColor.primary.withOpacity(0.1)
          : null,
      child: Text(
        department,
        style: TextStyle(
          color: selectedDepartment == department
              ? AppColor.primary
              : AppColor.font1,
          fontSize: 14,
          fontWeight: selectedDepartment == department
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
    ),
  );
}
