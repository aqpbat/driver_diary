import '../error/failure.dart';

/// What to tell the driver when loading failed.
String describeFailure(Failure failure) => switch (failure) {
  NetworkFailure() => 'Нет связи с сервером. Проверьте интернет и повторите.',
  ValidationFailure() => 'Сервер не принял данные.',
  ConflictFailure() => 'Такая запись уже есть на сервере с другими данными.',
  UnknownFailure() => 'Что-то пошло не так. Попробуйте ещё раз.',
};
