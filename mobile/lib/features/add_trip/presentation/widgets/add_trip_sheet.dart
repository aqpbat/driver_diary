import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/local_date.dart';
import '../../../../core/domain/trip.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/format/dates.dart';
import '../../domain/entities/trip_form.dart';
import '../../domain/trip_form_validator.dart';
import '../cubit/add_trip_cubit.dart';
import 'time_input_formatter.dart';

/// The add-trip form as a bottom sheet. Expects an [AddTripCubit] above it
/// and pops with the day of the saved trip (a `LocalDate`).
class AddTripSheet extends StatefulWidget {
  const AddTripSheet({super.key});

  @override
  State<AddTripSheet> createState() => _AddTripSheetState();
}

class _AddTripSheetState extends State<AddTripSheet> {
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _amount = TextEditingController();
  final _commission = TextEditingController();

  final _endFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _commissionFocus = FocusNode();

  AddTripCubit get _cubit => context.read<AddTripCubit>();

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _amount.dispose();
    _commission.dispose();
    _endFocus.dispose();
    _amountFocus.dispose();
    _commissionFocus.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, AddTripState state) {
    if (state is AddTripSuccess) {
      Navigator.of(context).pop(state.trip.day);
      return;
    }
    // The cubit suggests a commission while the amount is being typed.
    final suggested = state.form.commissionText;
    if (!state.commissionEdited && _commission.text != suggested) {
      _commission.text = suggested;
    }
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    _cubit.submit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return AppSheet(
      title: 'Новая поездка',
      child: BlocConsumer<AddTripCubit, AddTripState>(
        listener: _onState,
        builder: (context, state) {
          final form = state.form;
          final busy = state is! AddTripEditing;
          final failure = state is AddTripEditing ? state.failure : null;
          final duration = _durationHint(form);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DayStepper(
                form: form,
                onChanged: busy ? null : _cubit.dateChanged,
              ),
              const SizedBox(height: AppSpace.x4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      key: const ValueKey('add-trip-start'),
                      label: 'Начало',
                      hint: '08:10',
                      controller: _start,
                      enabled: !busy,
                      error: _errorText(TripField.start, state),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: const [TimeInputFormatter()],
                      onChanged: (text) {
                        _cubit.startChanged(text);
                        if (text.length == 5) _endFocus.requestFocus();
                      },
                      onSubmitted: (_) => _endFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: AppSpace.x3),
                  Expanded(
                    child: AppTextField(
                      key: const ValueKey('add-trip-end'),
                      label: 'Конец',
                      hint: '08:42',
                      controller: _end,
                      focusNode: _endFocus,
                      enabled: !busy,
                      error: _errorText(TripField.end, state),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: const [TimeInputFormatter()],
                      onChanged: (text) {
                        _cubit.endChanged(text);
                        if (text.length == 5) _amountFocus.requestFocus();
                      },
                      onSubmitted: (_) => _amountFocus.requestFocus(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.x1),
              AppCheckbox(
                value: form.endsNextDay,
                label: 'Закончилась на следующий день',
                onChanged: busy ? null : _cubit.endsNextDayChanged,
              ),
              if (duration != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.x1),
                  child: AppText(
                    'В пути $duration',
                    style: AppTextStyle.caption,
                    color: colors.textMuted,
                  ),
                ),
              const SizedBox(height: AppSpace.x3),
              AppTextField(
                key: const ValueKey('add-trip-amount'),
                label: 'Сумма',
                hint: '2400',
                suffix: '₸',
                controller: _amount,
                focusNode: _amountFocus,
                enabled: !busy,
                error: _errorText(TripField.amount, state),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                onChanged: _cubit.amountChanged,
                onSubmitted: (_) => _commissionFocus.requestFocus(),
              ),
              const SizedBox(height: AppSpace.x4),
              ExcludeSemantics(
                child: AppText(
                  'Оплата',
                  style: AppTextStyle.label,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpace.x1 + 2),
              SegmentedControl<Payment>(
                value: form.payment,
                onChanged: busy ? null : _cubit.paymentChanged,
                segments: [
                  Segment(
                    value: Payment.cash,
                    label: 'Наличные',
                    icon: AppIcons.cash,
                    color: colors.cash,
                  ),
                  Segment(
                    value: Payment.card,
                    label: 'Карта',
                    icon: AppIcons.card,
                    color: colors.card,
                  ),
                ],
              ),
              if (_errorText(TripField.payment, state) case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.x1 + 2),
                  child: AppText(
                    error,
                    style: AppTextStyle.caption,
                    color: colors.error,
                  ),
                ),
              const SizedBox(height: AppSpace.x4),
              AppTextField(
                key: const ValueKey('add-trip-commission'),
                label: 'Комиссия',
                hint: '0',
                suffix: '₸',
                controller: _commission,
                focusNode: _commissionFocus,
                enabled: !busy,
                error: _errorText(TripField.commission, state),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                onChanged: _cubit.commissionChanged,
                onSubmitted: (_) => _submit(),
              ),
              if (!state.commissionEdited)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.x1 + 2),
                  child: AppText(
                    'Подставляется $commissionPercent % от суммы — можно '
                    'исправить',
                    style: AppTextStyle.caption,
                    color: colors.textMuted,
                  ),
                ),
              const SizedBox(height: AppSpace.x5),
              if (failure != null) ...[
                AppBanner(
                  kind: AppBannerKind.error,
                  message: _failureText(failure),
                ),
                const SizedBox(height: AppSpace.x3),
              ],
              AppButton(
                label: failure is NetworkFailure ? 'Повторить' : 'Сохранить',
                loading: state is AddTripSubmitting,
                // Locked while the request is in flight: no double sends.
                onPressed: busy ? null : _submit,
              ),
            ],
          );
        },
      ),
    );
  }

  /// `32 мин` once both times make sense, otherwise nothing.
  String? _durationHint(TripForm form) {
    final start = parseClock(form.startText);
    final end = parseClock(form.endText);
    if (start == null || end == null) return null;
    final minutes =
        (end.hour * 60 + end.minute) -
        (start.hour * 60 + start.minute) +
        (form.endsNextDay ? 24 * 60 : 0);
    return minutes > 0 ? formatDuration(Duration(minutes: minutes)) : null;
  }

  String? _errorText(TripField field, AddTripState state) {
    final error = state.errors[field];
    if (error == null) return null;
    return switch (error) {
      TripFieldError.required => 'Заполните поле',
      TripFieldError.invalidTime => 'Время в формате ЧЧ:ММ',
      TripFieldError.invalidNumber => 'Целое число, без копеек',
      TripFieldError.endNotAfterStart =>
        state.form.endsNextDay
            ? 'Конец должен быть позже начала'
            : 'Не позже начала. Если поездка закончилась после полуночи, '
                  'отметьте это ниже',
      TripFieldError.notPositive => 'Сумма должна быть больше нуля',
      TripFieldError.negative => 'Не может быть меньше нуля',
      TripFieldError.exceedsAmount => 'Не может быть больше суммы',
      TripFieldError.rejectedByServer => 'Сервер не принял это значение',
    };
  }

  String _failureText(Failure failure) => switch (failure) {
    NetworkFailure() =>
      'Нет связи с сервером. Нажмите «Повторить» — если поездка уже '
          'дошла, второй раз она не запишется.',
    ValidationFailure() => 'Сервер не принял поездку. Проверьте поля.',
    ConflictFailure() =>
      'Эта поездка уже сохранена с другими данными. Закройте форму и '
          'проверьте день.',
    UnknownFailure() => 'Не удалось сохранить. Попробуйте ещё раз.',
  };
}

/// Picks the day the trip started on, one step at a time.
class _DayStepper extends StatelessWidget {
  const _DayStepper({required this.form, required this.onChanged});

  final TripForm form;
  final ValueChanged<LocalDate>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    final change = onChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('День', style: AppTextStyle.label, color: colors.textMuted),
        const SizedBox(height: AppSpace.x1 + 2),
        Container(
          height: AppSizes.control,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x1),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              AppIconButton(
                icon: AppIcons.chevronLeft,
                semanticLabel: 'День раньше',
                filled: false,
                onPressed: change == null
                    ? null
                    : () => change(form.date.addDays(-1)),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: AppText(
                    formatDayTitle(form.date),
                    style: AppTextStyle.bodyStrong,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
              AppIconButton(
                icon: AppIcons.chevronRight,
                semanticLabel: 'День позже',
                filled: false,
                onPressed: change == null
                    ? null
                    : () => change(form.date.addDays(1)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
