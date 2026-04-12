# Accessibility Standards

Target: **WCAG 2.1 Level AA** on all themes and screens.

## Platform APIs

- iOS: VoiceOver and Dynamic Type
- Android: TalkBack and font scale

## Semantics

- Every interactive widget has a meaningful `Semantics` label
- Decorative images use `ExcludeSemantics`
- Headings are marked via `Semantics(header: true)`
- Custom tappable widgets wrap with `Semantics(button: true, ...)`
- Document structure is reflected in the semantics tree
  (TOC mirrors heading hierarchy)

## Contrast

- Body text: 4.5:1 minimum on background
- Large text and icons: 3:1 minimum
- Code blocks: measured separately for both themes
- Theme tokens are validated in `test/a11y/contrast_test.dart`

## Touch Targets

- Minimum 44×44 pt (iOS) / 48×48 dp (Android)
- Spacing between adjacent targets: ≥ 8 dp

## Font Scaling

- Respect system font scale
- UI must remain usable at 200% scale
- Text must not be clipped or overflow at maximum scale
- Reading surface uses the user-configured app font size **multiplied by**
  the system scale

## Motion

- Respect `MediaQuery.disableAnimations` and the platform reduce-motion flag
- Provide non-animated alternatives for critical feedback

## Color

- Never convey information by color alone
- Error states include an icon and a label, not just a red color

## Keyboard (tablets with hardware keyboards)

- All interactive elements reachable via Tab
- Visible focus indicator
- Common shortcuts: `Cmd+F` for search, `Cmd+,` for settings

## Testing

- Every screen has a `Semantics` test that asserts labels for critical nodes
- Golden tests run at 1× and 2× font scales
- Manual audit with VoiceOver and TalkBack each release
