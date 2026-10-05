import 'metrics.dart';

final _snakeCaseFilePattern = RegExp(r'^[a-z0-9_]+\.dart$');
final _lowerCamelCaseFunctionPattern = RegExp(r'^_?[a-z][a-zA-Z0-9]*$');

const _allowedUiSuffixes = [
  '_overlay.dart',
  '_screen.dart',
  '_hud.dart',
  '_card.dart',
  '_widget.dart',
];

const _allowedComponentSuffixes = [
  '_component.dart',
  '_controller.dart',
  '_animator.dart',
  '_profile.dart',
  '_text.dart',
];

/// Validates file and function/method naming conventions across the project.
List<String> namingViolations(Map<String, SourceMetrics> measured) {
  final errors = <String>[];
  for (final entry in measured.entries) {
    _checkFile(entry.key, errors);
    _checkSymbols(entry.key, entry.value.symbols.keys, errors);
  }
  return errors;
}

void _checkFile(String filePath, List<String> errors) {
  final fileName = filePath.split('/').last;
  if (!_snakeCaseFilePattern.hasMatch(fileName)) {
    errors.add(
      '$filePath: file name "$fileName" must use lowercase snake_case',
    );
  }
  if (filePath.startsWith('app/lib/ui/') &&
      !_allowedUiSuffixes.any(fileName.endsWith)) {
    errors.add(
      '$filePath: UI file "$fileName" must end with one of: ${_allowedUiSuffixes.join(', ')}',
    );
  }
  if (filePath.startsWith('app/lib/game/components/') &&
      !_allowedComponentSuffixes.any(fileName.endsWith)) {
    errors.add(
      '$filePath: game component file "$fileName" must end with one of: ${_allowedComponentSuffixes.join(', ')}',
    );
  }
}

void _checkSymbols(
  String filePath,
  Iterable<String> symbols,
  List<String> errors,
) {
  for (final symbol in symbols) {
    _validateSymbol(filePath, symbol, errors);
  }
}

void _validateSymbol(String filePath, String symbol, List<String> errors) {
  final baseSymbol = symbol.contains('#') ? symbol.split('#').first : symbol;
  final memberName = baseSymbol.split('.').last;

  if (memberName.startsWith('constructor:')) {
    final constructorName = memberName.substring('constructor:'.length);
    if (constructorName != 'new' &&
        !_lowerCamelCaseFunctionPattern.hasMatch(constructorName)) {
      errors.add(
        '$filePath:$symbol: constructor name "$constructorName" must use lowerCamelCase',
      );
    }
    return;
  }

  if (!_lowerCamelCaseFunctionPattern.hasMatch(memberName)) {
    errors.add(
      '$filePath:$symbol: function/method name "$memberName" must use lowerCamelCase',
    );
  }
}
