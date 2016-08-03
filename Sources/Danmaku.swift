import Foundation

enum DanmakuPosition: Int {
    case normal = 0// 0
    case top // 1
    case bottom  // 2
    case opposite  // 3
    case special //4
}

struct Danmaku {
    let replayTime: Double // 0
    let content: String //3
    var validContent: String {
        return self.content.characters.reduce("", {(accu, c) -> String in
            switch c {
            case " " : return accu + "\u{2007}"
            case "\n" : return accu + "\\N"
            case "\\" : return accu + "\\\\"
            case "{" : return accu + "\\{"
            case "}" : return accu + "\\}"
            default : return accu + "\(c)"
            }
        })
    }
    let position: DanmakuPosition //4
    let color: Int //5
    let rSize: Double // relative size, actual size = rSize * fontsize sepcified by user
    let nLines: Int // number of lines
    let length: Int // the maximum of characters in a line
}
