import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/onboarding/application/onboarding_providers.dart';
import 'package:markdown_viewer/features/onboarding/domain/repositories/onboarding_store.dart';
import 'package:markdown_viewer/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

import 'semantics_audit.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Widget harness() {
    return ProviderScope(
      overrides: [
        onboardingStoreProvider.overrideWithValue(_OnboardingStore()),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder:
              (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const OnboardingScreen(),
              ),
        ),
      ),
    );
  }

  testWidgets(
    'should expose OnboardingScreen page headers controls and position when the widget is exercised',
    (tester) async {
      await withSemanticsAudit(tester, () async {
        await tester.pumpWidget(harness());
        await tester.pump();

        var header =
            tester
                .getSemantics(
                  find.bySemanticsLabel(l10n.onboardingWelcomeTitle),
                )
                .getSemanticsData();
        expect(header.flagsCollection.isHeader, isTrue);

        for (final label in [l10n.onboardingSkip, l10n.onboardingNext]) {
          final data =
              tester
                  .getSemantics(find.bySemanticsLabel(label))
                  .getSemanticsData();
          expect(data.label, label);
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
        }
        expect(
          find.bySemanticsLabel(
            l10n.onboardingPageIndicator(1, currentOnboardingVersion),
          ),
          findsOneWidget,
        );

        await tester.tap(find.bySemanticsLabel(l10n.onboardingNext));
        await tester.pump();
        header =
            tester
                .getSemantics(
                  find.bySemanticsLabel(l10n.onboardingSourcesTitle),
                )
                .getSemanticsData();
        expect(header.flagsCollection.isHeader, isTrue);
        expect(
          find.bySemanticsLabel(
            l10n.onboardingPageIndicator(2, currentOnboardingVersion),
          ),
          findsOneWidget,
        );

        await tester.tap(find.bySemanticsLabel(l10n.onboardingNext));
        await tester.pump();
        header =
            tester
                .getSemantics(
                  find.bySemanticsLabel(l10n.onboardingDefaultTitle),
                )
                .getSemanticsData();
        expect(header.flagsCollection.isHeader, isTrue);
        expect(
          find.bySemanticsLabel(
            l10n.onboardingPageIndicator(3, currentOnboardingVersion),
          ),
          findsOneWidget,
        );
        for (final label in [
          l10n.onboardingDefaultOpenSettings,
          l10n.onboardingGetStarted,
        ]) {
          final data =
              tester
                  .getSemantics(find.bySemanticsLabel(label))
                  .getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
        }

        expectEveryTapTargetLabeled(tester);
        expectTapTargetsAtLeast(tester);
      });
    },
  );
}

final class _OnboardingStore implements OnboardingStore {
  int seenVersion = 0;

  @override
  int readSeenVersion() => seenVersion;

  @override
  Future<void> writeSeenVersion(int version) async {
    seenVersion = version;
  }
}
