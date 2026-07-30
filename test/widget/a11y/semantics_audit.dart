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

  expect(
    undersized,
    isEmpty,
    reason: 'Interactive semantics must meet the 48×48 dp target.',
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
