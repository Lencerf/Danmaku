import XCTest
@testable import Danmaku

class DanmakuTests: XCTestCase {
    func testExample() {
        let data = try! Data.init(contentsOf: URL(string: "http://comment.bilibili.com/6525029.xml")!)
        // Hyouka 19
        let processor = BiliDanmakuProcessor.init()
        let d2a = Danmaku2Ass.init(rawData: data, videoSize: (1920,1080), processor: processor)
        try! d2a.convert(toAss: "/Users/Lenserf/Downloads/bilidan-download/6525029-4.ass")
    }


    static var allTests : [(String, (DanmakuTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
