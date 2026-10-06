import 'package:flutter/widgets.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/local_date.dart';
import '../../../../core/format/dates.dart';
import '../../domain/entities/day_ref.dart';

/// A horizontal ribbon of consecutive dates. Days that have trips carry a
/// dot; the selected day is highlighted and kept in view.
class DateStrip extends StatefulWidget {
  const DateStrip({
    super.key,
    required this.selected,
    required this.days,
    required this.onSelected,
  });

  final LocalDate selected;

  /// Days that have trips, oldest first.
  final List<DayRef> days;
  final ValueChanged<LocalDate> onSelected;

  @override
  State<DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<DateStrip> {
  static const double _chipWidth = 48;
  static const double _gap = AppSpace.x2;
  static const double _extent = _chipWidth + _gap;

  /// Empty days shown before the first and after the last day of interest,
  /// so the driver can see there is somewhere to go.
  static const _margin = 3;

  final _controller = ScrollController();
  double _viewport = 0;

  LocalDate get _first {
    final selected = widget.selected;
    final days = widget.days;
    final first = days.isEmpty || selected.isBefore(days.first.date)
        ? selected
        : days.first.date;
    return first.addDays(-_margin);
  }

  LocalDate get _last {
    final selected = widget.selected;
    final days = widget.days;
    final last = days.isEmpty || selected.isAfter(days.last.date)
        ? selected
        : days.last.date;
    return last.addDays(_margin);
  }

  @override
  void didUpdateWidget(DateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        oldWidget.days != widget.days) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _offsetFor(LocalDate date) {
    final index = date.differenceInDays(_first);
    final centered =
        AppSpace.x5 + index * _extent - (_viewport - _chipWidth) / 2;
    final count = _last.differenceInDays(_first) + 1;
    final max = AppSpace.x5 * 2 + count * _extent - _gap - _viewport;
    return centered.clamp(0.0, max < 0 ? 0.0 : max);
  }

  void _reveal() {
    if (!mounted || !_controller.hasClients) return;
    _controller.animateTo(
      _offsetFor(widget.selected),
      duration: AppDuration.normal,
      curve: AppCurves.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = _first;
    final count = _last.differenceInDays(first) + 1;
    final withTrips = {for (final day in widget.days) day.date};

    return SizedBox(
      height: 68,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_viewport != constraints.maxWidth) {
            _viewport = constraints.maxWidth;
            // No animation when the strip appears or the window resizes.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_controller.hasClients) return;
              _controller.jumpTo(_offsetFor(widget.selected));
            });
          }
          return ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x5),
            itemExtent: _extent,
            itemCount: count,
            itemBuilder: (context, index) {
              final date = first.addDays(index);
              return Padding(
                padding: const EdgeInsets.only(right: _gap),
                child: _DateChip(
                  date: date,
                  selected: date == widget.selected,
                  hasTrips: withTrips.contains(date),
                  onTap: () => widget.onSelected(date),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.selected,
    required this.hasTrips,
    required this.onTap,
  });

  final LocalDate date;
  final bool selected;
  final bool hasTrips;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final foreground = selected
        ? colors.onAccent
        : (hasTrips ? colors.text : colors.textFaint);

    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel:
          '${formatDayTitle(date)}, ${hasTrips ? 'есть поездки' : 'нет поездок'}',
      builder: (context, pressed) => AnimatedContainer(
        duration: AppDuration.normal,
        curve: AppCurves.standard,
        decoration: BoxDecoration(
          color: selected
              ? colors.accent
              : (pressed ? colors.surfaceMuted : colors.surface),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formatWeekdayShort(date),
                style: theme.type.label.copyWith(
                  color: selected ? colors.onAccent : colors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day}',
                style: theme.type.numeric.copyWith(color: foreground),
              ),
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasTrips
                      ? (selected ? colors.onAccent : colors.cash)
                      : const Color(0x00000000),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
