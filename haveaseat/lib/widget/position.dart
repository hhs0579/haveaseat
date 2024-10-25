// 직급 provider
import 'package:flutter/material.dart';
import 'package:haveaseat/components/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final positionProvider = StateProvider<String?>((ref) => null);
final isPositionExpandedProvider = StateProvider<bool>((ref) => false);

class PositionSelector extends ConsumerWidget {
  const PositionSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPosition = ref.watch(positionProvider);
    final isExpanded = ref.watch(isPositionExpandedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            ref.read(isPositionExpandedProvider.notifier).state = !isExpanded;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedPosition ?? '직급을 선택해주세요',
                  style: TextStyle(
                    color: selectedPosition != null
                        ? AppColor.font1
                        : AppColor.font1,
                    fontSize: 14,
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_sharp
                      : Icons.keyboard_arrow_down_sharp,
                  color: AppColor.font2,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              children: [
                const Divider(height: 1, color: AppColor.line1),
                _buildPositionItem(ref, '사원'),
                const Divider(height: 1, color: AppColor.line1),
                _buildPositionItem(ref, '대리'),
                const Divider(height: 1, color: AppColor.line1),
                _buildPositionItem(ref, '과장'),
                const Divider(height: 1, color: AppColor.line1),
                _buildPositionItem(ref, '차장'),
                const Divider(height: 1, color: AppColor.line1),
                _buildPositionItem(ref, '부장'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPositionItem(WidgetRef ref, String position) {
    final selectedPosition = ref.watch(positionProvider);

    return InkWell(
      onTap: () {
        ref.read(positionProvider.notifier).state = position;
        ref.read(isPositionExpandedProvider.notifier).state = false;
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: selectedPosition == position
            ? AppColor.primary.withOpacity(0.1)
            : null,
        child: Text(
          position,
          style: TextStyle(
            color: selectedPosition == position
                ? AppColor.primary
                : AppColor.font1,
            fontSize: 14,
            fontWeight: selectedPosition == position
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
