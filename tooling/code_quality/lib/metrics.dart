import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class SourceMetrics {
  final int lines;
  final Map<String, Map<String, int>> symbols = {};
  final List<String> imports = [];
  final Map<String, String> fingerprints = {};
  String sourceHash = '';

  SourceMetrics(this.lines);

  Map<String, Object> toJson() => {
    'lines': lines,
    'symbols': symbols,
    'fingerprints': fingerprints,
    'sourceHash': sourceHash,
  };
}

SourceMetrics measure(String source, String path) {
  final parsed = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
  );
  if (parsed.errors.isNotEmpty) {
    throw FormatException('$path: ${parsed.errors.join('\n')}');
  }
  final result = SourceMetrics(
    source.isEmpty
        ? 0
        : '\n'.allMatches(source).length + (source.endsWith('\n') ? 0 : 1),
  );
  result.sourceHash = sha256
      .convert(utf8.encode(source.replaceAll('\r\n', '\n')))
      .toString();
  for (final directive in parsed.unit.directives) {
    if (directive is PartDirective || directive is PartOfDirective) {
      throw FormatException('$path: part splitting is not permitted');
    }
    result.imports.addAll(_directiveUris(directive));
  }
  parsed.unit.accept(_Declarations(result, source));
  return result;
}

Iterable<String> _directiveUris(Directive directive) sync* {
  if (directive is! UriBasedDirective) return;
  final uri = directive.uri.stringValue;
  if (uri != null) yield uri;
  final configurations = switch (directive) {
    ImportDirective() => directive.configurations,
    ExportDirective() => directive.configurations,
    _ => const <Configuration>[],
  };
  for (final config in configurations) {
    final alternate = config.uri.stringValue;
    if (alternate != null) yield alternate;
  }
}

class _Declarations extends RecursiveAstVisitor<void> {
  final SourceMetrics result;
  final String source;
  final Map<String, int> occurrences = {};

  _Declarations(this.result, this.source);

  String _owner(AstNode node) {
    final names = <String>[];
    for (
      AstNode? parent = node.parent;
      parent != null;
      parent = parent.parent
    ) {
      if (parent is ClassDeclaration)
        names.add(parent.namePart.typeName.lexeme);
      if (parent is ExtensionDeclaration)
        names.add(parent.name?.lexeme ?? 'extension');
      if (parent is MethodDeclaration) names.add(parent.name.lexeme);
      if (parent is FunctionDeclaration) names.add(parent.name.lexeme);
    }
    return names.reversed.join('.');
  }

  void _record(AstNode node, FunctionBody body, int parameters, String name) {
    final owner = _owner(node);
    final base = owner.isEmpty ? name : '$owner.$name';
    final ordinal = occurrences.update(base, (n) => n + 1, ifAbsent: () => 1);
    final key = ordinal == 1 ? base : '$base#$ordinal';
    final visitor = _Complexity();
    body.accept(visitor);
    result.symbols[key] = {
      'lines':
          '\n'.allMatches(source.substring(node.offset, node.end)).length + 1,
      'cyclomatic': visitor.cyclomatic,
      'cognitive': visitor.cognitive,
      'nesting': visitor.maxNesting,
      'parameters': parameters,
    };
    final tokens = <String>[];
    for (
      var token = body.beginToken;
      token.offset < body.end;
      token = token.next!
    ) {
      tokens.add(token.lexeme);
      if (token == body.endToken) break;
    }
    result.fingerprints[key] = sha256
        .convert(utf8.encode(tokens.join(' ')))
        .toString();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _record(
      node,
      node.body,
      node.parameters?.parameters.length ?? 0,
      node.name.lexeme,
    );
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _record(
      node,
      node.body,
      node.parameters.parameters.length,
      'constructor:${node.name?.lexeme ?? 'new'}',
    );
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _record(
      node,
      node.functionExpression.body,
      node.functionExpression.parameters?.parameters.length ?? 0,
      node.name.lexeme,
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is! FunctionDeclaration) {
      _record(
        node,
        node.body,
        node.parameters?.parameters.length ?? 0,
        'closure',
      );
    }
    super.visitFunctionExpression(node);
  }
}

class _Complexity extends RecursiveAstVisitor<void> {
  int cyclomatic = 1;
  int cognitive = 0;
  int nesting = 0;
  int maxNesting = 0;

  void _branch(AstNode node) {
    cyclomatic++;
    cognitive += 1 + nesting;
    nesting++;
    if (nesting > maxNesting) maxNesting = nesting;
    node.visitChildren(this);
    nesting--;
  }

  @override
  void visitIfStatement(IfStatement node) => _branch(node);
  @override
  void visitForStatement(ForStatement node) => _branch(node);
  @override
  void visitWhileStatement(WhileStatement node) => _branch(node);
  @override
  void visitDoStatement(DoStatement node) => _branch(node);
  @override
  void visitConditionalExpression(ConditionalExpression node) => _branch(node);
  @override
  void visitCatchClause(CatchClause node) => _branch(node);
  @override
  void visitSwitchStatement(SwitchStatement node) => _branch(node);
  @override
  void visitSwitchExpression(SwitchExpression node) => _branch(node);
  @override
  void visitSwitchCase(SwitchCase node) {
    cyclomatic++;
    super.visitSwitchCase(node);
  }

  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    cyclomatic++;
    super.visitSwitchExpressionCase(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (['&&', '||', '??'].contains(node.operator.lexeme)) {
      cyclomatic++;
      cognitive++;
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {}
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}
}
