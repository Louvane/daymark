import XCTest

// 票 01 冒烟测试:验证测试通道(xcodebuild test)可用
final class SmokeTests: XCTestCase {
    func testSmoke() {
        XCTAssertTrue(true)
    }
}
