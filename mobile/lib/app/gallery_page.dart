import 'package:flutter/widgets.dart';

import '../core/design/design.dart';

/// Every component of the design system on one page, in its states. A debug
/// aid: opened by a long press on the day screen's title, in debug builds
/// only.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  String _segment = 'cash';
  bool _checked = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    final swatches = <(String, Color)>[
      ('background', colors.background),
      ('surface', colors.surface),
      ('surfaceMuted', colors.surfaceMuted),
      ('text', colors.text),
      ('textMuted', colors.textMuted),
      ('accent', colors.accent),
      ('hero', colors.hero),
      ('cash', colors.cash),
      ('card', colors.card),
      ('error', colors.error),
    ];

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.x5),
              children: [
                Row(
                  children: [
                    AppIconButton(
                      icon: AppIcons.chevronLeft,
                      semanticLabel: 'Назад',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: AppSpace.x3),
                    const AppText('Компоненты', style: AppTextStyle.title),
                  ],
                ),
                const _Section('Цвета'),
                Wrap(
                  spacing: AppSpace.x2,
                  runSpacing: AppSpace.x2,
                  children: [
                    for (final (name, color) in swatches)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(
                                AppRadius.small,
                              ),
                              border: Border.all(color: colors.border),
                            ),
                          ),
                          const SizedBox(height: 2),
                          AppText(name, style: AppTextStyle.label),
                        ],
                      ),
                  ],
                ),
                const _Section('Типографика'),
                for (final style in AppTextStyle.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.x2),
                    child: AppText('${style.name} 2 400 ₸', style: style),
                  ),
                const _Section('Иконки'),
                Wrap(
                  spacing: AppSpace.x3,
                  children: [
                    for (final icon in AppIcons.values)
                      AppIcon(icon, color: colors.text),
                  ],
                ),
                const _Section('Кнопки'),
                AppButton(
                  label: 'Основная',
                  icon: AppIcons.plus,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpace.x2),
                AppButton(
                  label: 'Вторичная',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpace.x2),
                AppButton(label: 'Загрузка', loading: true, onPressed: () {}),
                const SizedBox(height: AppSpace.x2),
                const AppButton(label: 'Выключена', onPressed: null),
                const SizedBox(height: AppSpace.x2),
                Row(
                  children: [
                    AppIconButton(
                      icon: AppIcons.refresh,
                      semanticLabel: 'Обновить',
                      onPressed: () {},
                    ),
                    const SizedBox(width: AppSpace.x2),
                    const AppIconButton(
                      icon: AppIcons.close,
                      semanticLabel: 'Выключена',
                      onPressed: null,
                    ),
                    const SizedBox(width: AppSpace.x4),
                    AppSpinner(color: colors.text),
                  ],
                ),
                const _Section('Поля и выбор'),
                const AppTextField(label: 'Сумма', hint: '2400', suffix: '₸'),
                const SizedBox(height: AppSpace.x3),
                const AppTextField(
                  label: 'С ошибкой',
                  hint: '08:10',
                  error: 'Время в формате ЧЧ:ММ',
                ),
                const SizedBox(height: AppSpace.x3),
                SegmentedControl<String>(
                  value: _segment,
                  onChanged: (value) => setState(() => _segment = value),
                  segments: [
                    Segment(
                      value: 'cash',
                      label: 'Наличные',
                      icon: AppIcons.cash,
                      color: colors.cash,
                    ),
                    Segment(
                      value: 'card',
                      label: 'Карта',
                      icon: AppIcons.card,
                      color: colors.card,
                    ),
                  ],
                ),
                AppCheckbox(
                  value: _checked,
                  label: 'Закончилась на следующий день',
                  onChanged: (value) => setState(() => _checked = value),
                ),
                const _Section('Сообщения'),
                AppBanner(
                  kind: AppBannerKind.error,
                  message: 'Нет связи с сервером.',
                  actionLabel: 'Повторить',
                  onAction: () {},
                ),
                const SizedBox(height: AppSpace.x2),
                const AppBanner(
                  kind: AppBannerKind.success,
                  message: 'Поездка сохранена',
                ),
                const _Section('Карточка, скелетон, лист'),
                const AppCard(child: AppText('Карточка')),
                const SizedBox(height: AppSpace.x2),
                const Skeleton(height: 66, radius: AppRadius.large),
                const SizedBox(height: AppSpace.x2),
                AppButton(
                  label: 'Открыть лист',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => showAppSheet<void>(
                    context,
                    builder: (context) => const AppSheet(
                      title: 'Нижний лист',
                      child: AppText('Содержимое листа.'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.x8, bottom: AppSpace.x3),
    child: AppText(
      title,
      style: AppTextStyle.headline,
      color: AppTheme.of(context).colors.textMuted,
    ),
  );
}
