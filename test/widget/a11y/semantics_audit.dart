import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [body] with semantics enabled and always releases the handle.
///
/// Flutter verifies that semantics handles are released before ordinary test
/// tear-down callbacks, so the handle must be scoped with `try`/`finally`.
Future<T> withSemanticsAudit<T>(
  WidgetTester tester,
  Future<T> Function() body,
) async {
  final semantics = tester.ensureSemantics();
  try {
    return await body();
  } finally {
    semantics.dispose();
  }
}

/// Fails when an exposed tap target has neither a label nor a value.
void expectEveryTapTargetLabeled(WidgetTester tester) {
  final unlabeled = <String>[];
  for (final node in _semanticsNodes(tester)) {
    final data = node.getSemanticsData();
    if (node.isMergedIntoParent ||
        !data.hasAction(SemanticsAction.tap) ||
        data.flagsCollection.isHidden ||
        data.label.trim().isNotEmpty ||
        data.value.trim().isNotEmpty) {
      continue;
    }
    unlabeled.add(
      'id=${node.id} rect=${node.rect} '
      'flags=${data.flagsCollection.toStrings()} '
      'actions=${data.actions}',
    );
  }

  expect(
    unlabeled,
    isEmpty,
    reason: 'Every exposed tap target must have an accessible name.',
  );
}

/// Fails when an exposed tap target is smaller than [minimum] logical pixels.
void expectTapTargetsAtLeast(WidgetTester tester, {double minimum = 48}) {
  final undersized = <String>[];
  for (final node in _semanticsNodes(tester)) {
    final data = node.getSemanticsData();
    if (node.isMergedIntoParent ||
        !data.hasAction(SemanticsAction.tap) ||
        data.flagsCollection.isHidden) {
      continue;
    }
    if (node.rect.width + 0.001 < minimum ||
        node.rect.height + 0.001 < minimum) {
      undersized.add(
        'label="${data.label}" size=${node.rect.width}×${node.rect.height}',
      );
    }
  }
  for (final entry in _globalSemanticsNodes(tester)) {
    final data = entry.node.getSemanticsData();
    if (entry.node.isMergedIntoParent ||
        !data.hasAction(SemanticsAction.tap) ||
        data.flagsCollection.isHidden ||
        entry.rect.isEmpty) {
      continue;
    }
    final centerHandlers = _tapHandlersAt(tester, entry.rect.center);
    final inset = math.min(2.0, entry.rect.shortestSide / 4);
    final samplePoints = <Offset>[
      entry.rect.topCenter + Offset(0, inset),
      entry.rect.centerLeft + Offset(inset, 0),
      entry.rect.centerRight + Offset(-inset, 0),
      entry.rect.bottomCenter + Offset(0, -inset),
    ];
    final sampleCoverage = [
      for (final point in samplePoints)
        _tapHandlersAt(tester, point).intersection(centerHandlers).isNotEmpty,
    ];
    final uncovered = sampleCoverage.any((covered) => !covered);
    if (centerHandlers.isEmpty || uncovered) {
      undersized.add(
        'label="${data.label}" semantics=${entry.rect} '
        'handlers=${centerHandlers.length} coverage=$sampleCoverage',
      );
    }
  }

  expect(
    undersized,
    isEmpty,
    reason:
        'Interactive semantics and physical pointer targets must meet the '
        '48×48 dp target.',
  );
}

/// Returns all current semantics nodes in traversal order.
List<SemanticsNode> semanticsNodes(WidgetTester tester) =>
    _semanticsNodes(tester);

List<SemanticsNode> _semanticsNodes(WidgetTester tester) {
  // The test binding's active view pipeline owns the semantics tree exposed by
  // WidgetTester. The root pipeline can have no SemanticsOwner in multi-view
  // tests even while this active child pipeline has one.
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  expect(root, isNotNull, reason: 'Call withSemanticsAudit before auditing.');
  final nodes = <SemanticsNode>[];

  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root!);
  return nodes;
}

List<({SemanticsNode node, Rect rect})> _globalSemanticsNodes(
  WidgetTester tester,
) {
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
  final entries = <({SemanticsNode node, Rect rect})>[];

  void visit(SemanticsNode node, Matrix4 parentTransform) {
    final transform = parentTransform.clone();
    final localTransform = node.transform;
    if (localTransform != null) transform.multiply(localTransform);
    entries.add((
      node: node,
      rect: MatrixUtils.transformRect(transform, node.rect),
    ));
    node.visitChildren((child) {
      visit(child, transform);
      return true;
    });
  }

  final logicalPixelScale = 1 / tester.view.devicePixelRatio;
  visit(root, Matrix4.diagonal3Values(logicalPixelScale, logicalPixelScale, 1));
  return entries;
}

Set<RenderPointerListener> _tapHandlersAt(WidgetTester tester, Offset point) =>
    tester
        .hitTestOnBinding(point)
        .path
        .map((entry) => entry.target)
        .whereType<RenderPointerListener>()
        .where((target) => target.onPointerDown != null)
        .toSet();
