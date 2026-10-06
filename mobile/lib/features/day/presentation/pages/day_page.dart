import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/local_date.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/format/failure_text.dart';
import '../bloc/day_bloc.dart';
import '../widgets/date_strip.dart';
import '../widgets/day_header.dart';
import '../widgets/day_placeholders.dart';
import '../widgets/payment_split.dart';
import '../widgets/summary_card.dart';
import '../widgets/trip_tile.dart';

/// Opens the add-trip form for [date] and completes with the day of the trip
/// that was saved, or null if the form was closed without saving.
///
/// The form belongs to another feature; the app wires it in, so this feature
/// knows only this signature.
typedef AddTripLauncher = Future<LocalDate?> Function(
  BuildContext context,
  LocalDate date,
);

/// The diary screen: the summary and the trips of one day, with ways to move
/// between days and to add a trip. Expects a [DayBloc] above it.
class DayPage extends StatefulWidget {
  const DayPage({super.key, required this.onAddTrip, this.onTitleLongPress});

  final AddTripLauncher onAddTrip;

  /// A debug hook (the component gallery).
  final VoidCallback? onTitleLongPress;

  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> {
  static const _savedNoticeTime = Duration(seconds: 3);

  bool _showSaved = false;
  Timer? _savedTimer;

  DayBloc get _bloc => context.read<DayBloc>();

  @override
  void dispose() {
    _savedTimer?.cancel();
    super.dispose();
  }

  void _select(LocalDate date) => _bloc.add(DaySelected(date));

  void _step(int days) {
    final date = _bloc.state.date;
    if (date != null) _select(date.addDays(days));
  }

  Future<void> _refresh() {
    final bloc = _bloc..add(const DayRefreshed());
    // Completes when the reload is over, whatever its outcome; that is what
    // keeps the pull-to-refresh indicator on screen.
    return bloc.stream
        .firstWhere(
          (state) => state is! DayLoaded || !state.isRefreshing,
          orElse: () => bloc.state,
        )
        .then((_) {});
  }

  Future<void> _addTrip(LocalDate date) async {
    final bloc = _bloc;
    final savedDay = await widget.onAddTrip(context, date);
    if (savedDay == null || !mounted) return;
    bloc.add(DayTripAdded(savedDay));
    _savedTimer?.cancel();
    setState(() => _showSaved = true);
    _savedTimer = Timer(_savedNoticeTime, () {
      if (mounted) setState(() => _showSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.contentMaxWidth,
            ),
            child: BlocBuilder<DayBloc, DayState>(
              builder: (context, state) {
                final date = state.date;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DayHeader(
                      date: date,
                      refreshing: state is DayLoaded && state.isRefreshing,
                      onPrevious: date == null ? null : () => _step(-1),
                      onNext: date == null ? null : () => _step(1),
                      onRefresh: state is DayLoaded ? _refresh : null,
                      onTitleLongPress: widget.onTitleLongPress,
                    ),
                    if (date != null)
                      DateStrip(
                        selected: date,
                        days: state.days,
                        onSelected: _select,
                      )
                    else
                      const SizedBox(height: 68),
                    const SizedBox(height: AppSpace.x2),
                    Expanded(
                      // A horizontal fling anywhere on the day flips it.
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity.abs() < 250) return;
                          _step(velocity < 0 ? 1 : -1);
                        },
                        child: AnimatedSwitcher(
                          duration: AppDuration.normal,
                          child: KeyedSubtree(
                            key: ValueKey((state.runtimeType, date)),
                            child: switch (state) {
                              DayLoading() => const DaySkeleton(),
                              DayFailed(:final failure) => DayError(
                                failure: failure,
                                onRetry: () => _bloc.add(const DayRefreshed()),
                              ),
                              DayLoaded() => _DayContent(
                                state: state,
                                onRefresh: _refresh,
                              ),
                            },
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.x5,
                        AppSpace.x2,
                        AppSpace.x5,
                        AppSpace.x4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_showSaved) ...[
                            const AppBanner(
                              kind: AppBannerKind.success,
                              message: 'Поездка сохранена',
                            ),
                            const SizedBox(height: AppSpace.x2),
                          ],
                          AppButton(
                            label: 'Добавить поездку',
                            icon: AppIcons.plus,
                            onPressed: date == null
                                ? null
                                : () => _addTrip(date),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DayContent extends StatelessWidget {
  const _DayContent({required this.state, required this.onRefresh});

  final DayLoaded state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    final overview = state.overview;
    final trips = overview.trips;
    final refreshFailure = state.refreshFailure;

    return CustomScrollView(
      // Bouncing everywhere: the pull-to-refresh gesture needs overscroll.
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        AppRefreshSliver(onRefresh: onRefresh),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.x5,
            AppSpace.x1,
            AppSpace.x5,
            AppSpace.x5,
          ),
          sliver: SliverList.list(
            children: [
              if (refreshFailure != null) ...[
                AppBanner(
                  kind: AppBannerKind.error,
                  message:
                      'Не удалось обновить. ${describeFailure(refreshFailure)}',
                  actionLabel: 'Повторить',
                  onAction: onRefresh,
                ),
                const SizedBox(height: AppSpace.x3),
              ],
              if (trips.isEmpty)
                const EmptyDay()
              else ...[
                SummaryCard(total: overview.summary.total),
                const SizedBox(height: AppSpace.x3),
                PaymentSplit(
                  cash: overview.summary.cash,
                  card: overview.summary.card,
                ),
                const SizedBox(height: AppSpace.x6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.x1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: const AppText(
                            'Поездки',
                            style: AppTextStyle.headline,
                          ),
                        ),
                      ),
                      AppText(
                        formatTripsCount(trips.length),
                        style: AppTextStyle.caption,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.x3),
                for (final trip in trips) ...[
                  TripTile(key: ValueKey(trip.id), trip: trip),
                  const SizedBox(height: AppSpace.x2),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
