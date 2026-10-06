import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/app_config.dart';

void main() {
  runApp(DriverDiaryApp(config: AppConfig.fromEnvironment()));
}
