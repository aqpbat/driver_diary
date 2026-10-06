import 'package:flutter/services.dart';

/// Shapes typed digits into `HH:MM`: `0810` → `08:10`, and `810` → `08:10`
/// because an hour cannot start with 3–9.
class TimeInputFormatter extends TextInputFormatter {
  const TimeInputFormatter();

  static final _nonDigits = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(_nonDigits, '');
    if (digits.isNotEmpty && digits.codeUnitAt(0) > 0x32) digits = '0$digits';
    if (digits.length > 4) digits = digits.substring(0, 4);

    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}:${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
