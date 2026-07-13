import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/tree.dart';
import '../../data/repositories/tree_repository.dart';

/// Category keys for the map (same API filters as Explore, minus "near me").
const mapCategoryKeys = [
  'all',
  'oak',
  'flowering',
  'autumn',
  'rare',
  'native',
];

const mapCategoryLabels = [
  'All',
  'Oaks',
  'Flowering',
  'Autumn colour',
  'Rare',
  'Native',
];

/// Responsive bottom sheet for map pin filters.
class MapFilterSheet extends StatefulWidget {
  const MapFilterSheet({super.key, required this.initial});

  final MapFilters initial;

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  late MapFilters _draft = widget.initial;

  void _apply() => Navigator.pop(context, _draft);

  void _clear() => Navigator.pop(context, const MapFilters());

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Filter pins',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Species filters load from the server for this map area.',
                        style: TextStyle(fontSize: 12, color: earth.ink3),
                      ),
                      const SizedBox(height: 16),
                      _sectionLabel(context, 'Species'),
                      const SizedBox(height: 8),
                      _CategoryGrid(
                        selected: _draft.category,
                        onSelected: (key) =>
                            setState(() => _draft = _draft.copyWith(category: key)),
                      ),
                      const SizedBox(height: 18),
                      _sectionLabel(context, 'Health'),
                      const SizedBox(height: 8),
                      _HealthPicker(
                        selected: _draft.health,
                        onSelected: (h) => setState(
                          () => _draft = h == null
                              ? _draft.copyWith(clearHealth: true)
                              : _draft.copyWith(health: h),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Verified ID only'),
                        subtitle: const Text(
                          'Community-confirmed identifications',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _draft.verifiedOnly,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(verifiedOnly: v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 340;
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: _apply,
                            child: const Text('Apply filters'),
                          ),
                          TextButton(onPressed: _clear, child: const Text('Clear all')),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        TextButton(onPressed: _clear, child: const Text('Clear all')),
                        const Spacer(),
                        FilledButton(
                          onPressed: _apply,
                          child: const Text('Apply'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.earth.ink3,
        ),
      );
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on narrow phones; three on wider screens.
        final cols = constraints.maxWidth < 360 ? 2 : 3;
        const gap = 8.0;
        final cellW = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < mapCategoryKeys.length; i++)
              SizedBox(
                width: cellW,
                child: _FilterTile(
                  label: mapCategoryLabels[i],
                  selected: selected == mapCategoryKeys[i],
                  onTap: () => onSelected(mapCategoryKeys[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HealthPicker extends StatelessWidget {
  const _HealthPicker({required this.selected, required this.onSelected});

  final TreeHealth? selected;
  final ValueChanged<TreeHealth?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Any'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final h in TreeHealth.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(h.label),
                selected: selected == h,
                onSelected: (_) => onSelected(h),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? Palette.green700 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Palette.green700 : context.earth.line,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.earth.ink2,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Opens the map filter sheet and returns the chosen [MapFilters], or null.
Future<MapFilters?> showMapFilterSheet(
  BuildContext context, {
  required MapFilters initial,
}) =>
    showModalBottomSheet<MapFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => MapFilterSheet(initial: initial),
    );
