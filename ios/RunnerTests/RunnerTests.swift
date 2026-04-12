import Flutter
import UIKit
import XCTest

// Native iOS unit tests are intentionally minimal — the project has no
// native iOS code beyond the default `AppDelegate`, and all behaviour is
// implemented in Dart with `flutter_test` / `integration_test`. This file
// exists so the `RunnerTests` Xcode target compiles and runs at least one
// assertion in CI; expand it only if and when native iOS code is added.
class RunnerTests: XCTestCase {

  func testRunnerHostBootsAndExposesFlutterAppDelegate() {
    let appDelegate = AppDelegate()
    XCTAssertNotNil(appDelegate, "AppDelegate must instantiate")
  }

}
