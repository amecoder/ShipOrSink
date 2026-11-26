// Per-function cyclomatic complexity and length gate (dev-standards).
//
// Usage (pre-commit hook `dart-metrics`):
//   dart --packages=tool/quality_metrics/.dart_tool/package_config.json \
//     tool/quality_metrics/bin/quality_metrics.dart \
//     --max-complexity 15 --max-lines 50 lib/a.dart lib/b.dart
//
// complexity: 1 + one per if / for / while / do / case / catch / ?: /
//   && / || / ?? — closures are measured on their own.
// lines: physical lines from the declaration (doc comments and annotations
//   excluded) to its last line, blank and comment lines included.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

void main(List<String> args) {
  final options = _Options.parse(args);
  var failed = false;
  for (final path in options.files) {
    if (!File(path).existsSync()) {
      stdout.writeln('FAIL: $path: file not found');
      failed = true;
      continue;
    }
    final result = parseFile(
      path: File(path).absolute.path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    if (result.errors.isNotEmpty) {
      final first = result.errors.first;
      final line = result.lineInfo.getLocation(first.offset).lineNumber;
      stdout.writeln('FAIL: $path:$line syntax error: ${first.message}');
      failed = true;
      continue;
    }
    final unit = result.unit;
    final finder = _UnitFinder();
    unit.accept(finder);
    for (final found in finder.found) {
      failed = _check(path, unit.lineInfo, found, options) || failed;
    }
  }
  exit(failed ? 1 : 0);
}

bool _check(String path, LineInfo info, _Unit unit, _Options options) {
  final first = info.getLocation(unit.start).lineNumber;
  final last = info.getLocation(unit.node.end - 1).lineNumber;
  final lines = last - first + 1;
  final branches = _Branches();
  for (final part in unit.parts) {
    part.accept(branches);
  }
  var failed = false;
  if (branches.count > options.maxComplexity) {
    stdout.writeln(
      'FAIL: $path:$first ${unit.name} '
      '(complexity ${branches.count}, max ${options.maxComplexity})',
    );
    failed = true;
  }
  if (lines > options.maxLines) {
    stdout.writeln(
      'FAIL: $path:$first ${unit.name} '
      '($lines lines, max ${options.maxLines})',
    );
    failed = true;
  }
  return failed;
}

class _Options {
  _Options(this.maxComplexity, this.maxLines, this.files);

  factory _Options.parse(List<String> args) {
    var complexity = 15;
    var lines = 50;
    final files = <String>[];
    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--max-complexity':
          complexity = int.parse(args[++i]);
        case '--max-lines':
          lines = int.parse(args[++i]);
        default:
          files.add(args[i]);
      }
    }
    return _Options(complexity, lines, files);
  }

  final int maxComplexity;
  final int maxLines;
  final List<String> files;
}

class _Unit {
  _Unit(this.name, this.node, this.parts)
    : start = node is AnnotatedNode
          ? node.firstTokenAfterCommentAndMetadata.offset
          : node.offset;

  final String name;
  final AstNode node;
  final int start;

  /// Nodes whose branches count: the body, plus constructor initializers.
  final List<AstNode> parts;
}

class _UnitFinder extends RecursiveAstVisitor<void> {
  final List<_Unit> found = [];

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    found.add(_Unit(node.name.lexeme, node, [node.body]));
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final name = node.name?.lexeme ?? 'constructor';
    found.add(_Unit(name, node, [...node.initializers, node.body]));
    super.visitConstructorDeclaration(node);
  }

  // `this : … { … }` of a primary constructor (class P(int x) { this … }).
  @override
  void visitPrimaryConstructorBody(PrimaryConstructorBody node) {
    found.add(_Unit('this', node, [...node.initializers, node.body]));
    super.visitPrimaryConstructorBody(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final body = node.functionExpression.body;
    found.add(_Unit(node.name.lexeme, node, [body]));
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is! FunctionDeclaration) {
      found.add(_Unit('<closure>', node, [node.body]));
    }
    super.visitFunctionExpression(node);
  }
}

class _Branches extends RecursiveAstVisitor<void> {
  int count = 1;

  void _branch(AstNode node) {
    count++;
    node.visitChildren(this);
  }

  // A closure inside the body is a unit of its own.
  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitIfStatement(IfStatement node) => _branch(node);

  @override
  void visitIfElement(IfElement node) => _branch(node);

  @override
  void visitForStatement(ForStatement node) => _branch(node);

  @override
  void visitForElement(ForElement node) => _branch(node);

  @override
  void visitWhileStatement(WhileStatement node) => _branch(node);

  @override
  void visitDoStatement(DoStatement node) => _branch(node);

  @override
  void visitSwitchCase(SwitchCase node) => _branch(node);

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) => _branch(node);

  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) => _branch(node);

  @override
  void visitCatchClause(CatchClause node) => _branch(node);

  @override
  void visitConditionalExpression(ConditionalExpression node) => _branch(node);

  @override
  void visitBinaryExpression(BinaryExpression node) {
    const logical = {'&&', '||', '??'};
    if (logical.contains(node.operator.lexeme)) {
      count++;
    }
    node.visitChildren(this);
  }
}
