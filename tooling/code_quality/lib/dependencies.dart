import 'metrics.dart';

String? resolveDependency(String owner, String uri) {
  if (uri.startsWith('package:builds_and_bosses_flame/')) {
    return 'app/lib/${uri.substring('package:builds_and_bosses_flame/'.length)}';
  }
  if (uri.startsWith('package:builds_and_bosses_quality/')) {
    return 'tooling/code_quality/lib/${uri.substring('package:builds_and_bosses_quality/'.length)}';
  }
  if (!uri.contains(':')) return Uri.parse(owner).resolve(uri).path;
  return null;
}

bool _forbiddenCore(String owner, String uri) {
  if (uri == 'dart:ui') return true;
  if (uri.startsWith('package:flutter/'))
    return uri != 'package:flutter/foundation.dart';
  if (uri.startsWith('package:flame/'))
    return uri != 'package:flame/extensions.dart';
  final dependency = resolveDependency(owner, uri);
  return [
    'game',
    'ui',
    'platform',
  ].any((layer) => dependency?.startsWith('app/lib/$layer/') ?? false);
}

List<String> dependencyViolations(Map<String, SourceMetrics> sources) {
  final errors = <String>[];
  final graph = <String, Set<String>>{};
  for (final entry in sources.entries) {
    graph[entry.key] = {};
    for (final uri in entry.value.imports) {
      if (entry.key.startsWith('app/lib/core/') &&
          _forbiddenCore(entry.key, uri)) {
        errors.add('${entry.key}: forbidden core dependency $uri');
      }
      if (entry.key.startsWith('app/lib/ui/') &&
          (uri.endsWith('combat_engine.dart') || uri.endsWith('/dice.dart'))) {
        errors.add('${entry.key}: forbidden UI rule dependency $uri');
      }
      final dependency = resolveDependency(entry.key, uri);
      if (dependency != null && sources.containsKey(dependency))
        graph[entry.key]!.add(dependency);
    }
  }
  final visited = <String>{};
  final active = <String>{};
  void walk(String node) {
    if (active.contains(node)) {
      errors.add('Import cycle: ${active.join(' -> ')} -> $node');
      return;
    }
    if (!visited.add(node)) return;
    active.add(node);
    for (final next in graph[node]!) {
      walk(next);
    }
    active.remove(node);
  }

  for (final node in graph.keys) {
    walk(node);
  }
  return errors;
}
