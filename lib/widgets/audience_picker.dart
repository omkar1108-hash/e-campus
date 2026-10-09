import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/campus.dart';

/// Chooses who a notice or alert is for: which branches (or all) and which
/// groups of people (or everybody).
class AudiencePicker extends StatelessWidget {
  const AudiencePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Audience value;
  final ValueChanged<Audience> onChanged;

  void _toggle(List<String> list, String item, bool on, bool isDept) {
    final next = on ? [...list, item] : (list.where((x) => x != item).toList());
    onChanged(
      isDept
          ? Audience(departments: next, groups: value.groups)
          : Audience(departments: value.departments, groups: next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Branch', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('dept-all'),
              label: const Text('All branches'),
              selected: value.departments.isEmpty,
              onSelected: (_) => onChanged(Audience(groups: value.groups)),
            ),
            for (final d in AppConfig.departments)
              FilterChip(
                key: ValueKey('dept-$d'),
                label: Text(d),
                selected: value.departments.contains(d),
                onSelected: (on) => _toggle(value.departments, d, on, true),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('For', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('group-all'),
              label: const Text('Everyone'),
              selected: value.groups.isEmpty,
              onSelected: (_) =>
                  onChanged(Audience(departments: value.departments)),
            ),
            for (final g in Audience.groupLabels.entries)
              FilterChip(
                key: ValueKey('group-${g.key}'),
                label: Text(g.value),
                selected: value.groups.contains(g.key),
                onSelected: (on) => _toggle(value.groups, g.key, on, false),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Goes to: ${value.describe()}',
          key: const ValueKey('audience-summary'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
