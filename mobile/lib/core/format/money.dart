const _nbsp = ' ';

/// `2400` → `2 400 ₸`. Groups are joined with no-break spaces so the sum
/// never wraps in the middle.
String formatMoney(int amount) => '${formatNumber(amount)}$_nbsp₸';

/// `12345` → `12 345`, `-500` → `−500`.
String formatNumber(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '−' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(_nbsp);
    out.write(digits[i]);
  }
  return out.toString();
}
