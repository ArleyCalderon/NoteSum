import 'package:intl/intl.dart';

double extractAmountFromLine(String line) {
  final match = RegExp(
    r'\$?\s*\d[\d.,]*(?:\s*[\+\-\*x×\/÷]\s*\$?\s*\d[\d.,]*)*',
  ).firstMatch(line);

  if (match == null) return 0.0;

  final expression = match.group(0)!;
  return _evaluateExpression(expression);
}

double _evaluateExpression(String expression) {
  final cleaned = expression
      .replaceAll('\$', '')
      .replaceAll('x', '*')
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll(' ', '');

  final tokenRegex = RegExp(r'\d[\d.,]*|[\+\-\*\/]');
  final tokens = tokenRegex.allMatches(cleaned).map((m) => m.group(0)!).toList();

  if (tokens.isEmpty) return 0.0;

  final values = <double>[];
  final operators = <String>[];

  for (final token in tokens) {
    if (RegExp(r'[\+\-\*\/]').hasMatch(token)) {
      operators.add(token);
    } else {
      values.add(_parseLocalizedNumber(token));
    }
  }

  if (values.isEmpty) return 0.0;

  // Primero multiplicación y división
  int i = 0;
  while (i < operators.length) {
    final op = operators[i];

    if (op == '*' || op == '/') {
      final left = values[i];
      final right = values[i + 1];

      final result = op == '*'
          ? left * right
          : right == 0
          ? 0.0
          : left / right;

      values[i] = result;
      values.removeAt(i + 1);
      operators.removeAt(i);
    } else {
      i++;
    }
  }

  // Luego suma y resta
  double result = values.first;

  for (int i = 0; i < operators.length; i++) {
    final op = operators[i];
    final value = values[i + 1];

    if (op == '+') {
      result += value;
    } else if (op == '-') {
      result -= value;
    }
  }

  return result;
}

double _parseLocalizedNumber(String raw) {
  raw = raw.trim();

  if (raw.contains(',') && raw.contains('.')) {
    raw = raw.replaceAll('.', '');
    raw = raw.replaceAll(',', '.');
  } else if (raw.contains('.')) {
    final parts = raw.split('.');

    if (parts.length == 2 && (parts[1].length == 1 || parts[1].length == 2)) {
      // Decimal tipo 1200.5 o 1200.50
      raw = raw;
    } else {
      // Miles tipo 1.200
      raw = raw.replaceAll('.', '');
    }
  } else if (raw.contains(',')) {
    final parts = raw.split(',');

    if (parts.length == 2 && (parts[1].length == 1 || parts[1].length == 2)) {
      // Decimal tipo 1200,5 o 1200,50
      raw = raw.replaceAll(',', '.');
    } else {
      // Miles tipo 1,200
      raw = raw.replaceAll(',', '');
    }
  }

  return double.tryParse(raw) ?? 0.0;
}

String formatNumber(double value) {
  if (value % 1 == 0) {
    return NumberFormat('#,###', 'es_CO').format(value);
  }

  return NumberFormat('#,##0.00', 'es_CO').format(value);
}