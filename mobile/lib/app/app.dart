import 'package:flutter/cupertino.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/design/design.dart';
import '../core/domain/local_date.dart';
import '../core/network/api_client.dart';
import '../features/add_trip/data/datasources/add_trip_remote_data_source.dart';
import '../features/add_trip/data/repositories/add_trip_repository_impl.dart';
import '../features/add_trip/domain/repositories/add_trip_repository.dart';
import '../features/add_trip/domain/usecases/add_trip.dart';
import '../features/add_trip/presentation/cubit/add_trip_cubit.dart';
import '../features/add_trip/presentation/widgets/add_trip_sheet.dart';
import '../features/day/data/datasources/day_remote_data_source.dart';
import '../features/day/data/repositories/day_repository_impl.dart';
import '../features/day/domain/repositories/day_repository.dart';
import '../features/day/domain/usecases/get_day.dart';
import '../features/day/domain/usecases/get_days.dart';
import '../features/day/presentation/bloc/day_bloc.dart';
import '../features/day/presentation/pages/day_page.dart';
import 'app_config.dart';
import 'gallery_page.dart';

/// The composition root: the only place that knows every layer of every
/// feature. It builds the dependencies once and hands them down.
class DriverDiaryApp extends StatefulWidget {
  const DriverDiaryApp({super.key, required this.config, this.httpClient});

  final AppConfig config;

  /// For tests; by default the app creates and closes its own client.
  final http.Client? httpClient;

  @override
  State<DriverDiaryApp> createState() => _DriverDiaryAppState();
}

class _DriverDiaryAppState extends State<DriverDiaryApp> {
  late final http.Client _http = widget.httpClient ?? http.Client();
  late final ApiClient _api = ApiClient(
    baseUrl: widget.config.apiBaseUrl,
    httpClient: _http,
  );
  late final DayRepository _dayRepository = DayRepositoryImpl(
    DayRemoteDataSource(_api),
  );
  late final AddTripRepository _addTripRepository = AddTripRepositoryImpl(
    AddTripRemoteDataSource(_api),
  );

  static const _uuid = Uuid();

  @override
  void dispose() {
    if (widget.httpClient == null) _http.close();
    super.dispose();
  }

  /// Today on the driver's clock, wherever the device is.
  LocalDate _today() =>
      LocalDate.at(DateTime.now(), widget.config.driverOffset);

  /// Connects the two features: the day screen asks for this, the add-trip
  /// form answers with the day of the saved trip.
  Future<LocalDate?> _openAddTrip(BuildContext context, LocalDate date) =>
      showAppSheet<LocalDate>(
        context,
        builder: (context) => BlocProvider(
          create: (context) => AddTripCubit(
            addTrip: AddTrip(context.read<AddTripRepository>()),
            newId: _uuid.v4,
            date: date,
            offset: widget.config.driverOffset,
          ),
          child: const AddTripSheet(),
        ),
      );

  void _openGallery(BuildContext context) => Navigator.of(
    context,
  ).push(PageRouteBuilder<void>(pageBuilder: (_, _, _) => const GalleryPage()));

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DayRepository>.value(value: _dayRepository),
        RepositoryProvider<AddTripRepository>.value(value: _addTripRepository),
      ],
      child: WidgetsApp(
        title: 'Дневник смен',
        color: AppColors.light.accent,
        debugShowCheckedModeBanner: false,
        // The text-selection menu of the input fields needs these.
        localizationsDelegates: const [
          DefaultCupertinoLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        builder: (context, child) {
          final theme = AppThemeData.of(
            MediaQuery.platformBrightnessOf(context),
          );
          final dark = theme.colors.brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: AppTheme(
              data: theme,
              child: DefaultTextStyle(
                style: theme.type.body.copyWith(color: theme.colors.text),
                child: child!,
              ),
            ),
          );
        },
        home: BlocProvider(
          create: (context) => DayBloc(
            getDays: GetDays(context.read<DayRepository>()),
            getDay: GetDay(context.read<DayRepository>()),
            today: _today,
          )..add(const DayStarted()),
          child: Builder(
            builder: (context) => DayPage(
              onAddTrip: _openAddTrip,
              onTitleLongPress: kDebugMode ? () => _openGallery(context) : null,
            ),
          ),
        ),
      ),
    );
  }
}
