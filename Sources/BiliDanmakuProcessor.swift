import Foundation

class BiliDanmakuProcessor:NSObject, DanmakuProcessor, XMLParserDelegate {
    private let positionDict: [String : DanmakuPosition] = [
        "1": .normal,
        "4": .bottom,
        "5": .top,
        "6": .opposite,
        "7": .special
    ]
    
    func parse(rawData: Data) -> [Danmaku] {
        let xmlParser = XMLParser.init(data: rawData)
        xmlParser.delegate = self
        xmlParser.parse()
        print("parsed", danmakuArray.count)
        return danmakuArray
    }
    
    func treatSpecialDanmaku(_ danmaku: Danmaku, videoWidth: Int, videoHeight: Int, sytleId: String) -> String {
        return "\n"
    }
    
    private var danmakuArray = [Danmaku]() // used for store parsed valid danmaku
    
    // temp varibales used during parsing
    private var insideD = false
    private var danmakuContent = ""
    private var danmakuAttribute = ""
    private var danmakuIndex = 0
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        guard
            elementName == "d",
            let attr = attributeDict["p"]
        else {
            return
        }
        self.insideD = true
        self.danmakuAttribute = attr
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideD {
            danmakuContent = string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "d" {
            self.insideD = false
            let attrArray = danmakuAttribute.components(separatedBy: ",")
            guard
                danmakuContent.characters.count > 0,
                attrArray.count >= 5,
                let position = positionDict[attrArray[1]],
                let replayTime = Double(attrArray[0]),
                //let createTime = Int(attrArray[4]),
                let color = Int(attrArray[3]),
                let size = Double(attrArray[2])
            else {
                return
            }
            let lines = danmakuContent.components(separatedBy: "\n")
            let numberOfLines = lines.count
            let length = lines.map({ $0.characters.count }).max() ?? 0
        
            let d = Danmaku.init(replayTime: replayTime, content: danmakuContent, position: position, color: color, rSize: size / 25.0, nLines: numberOfLines, length: length)
            danmakuArray.append(d)
            //let d = Danmaku.init(replayTime: replayTime, createTime: createTime, index: danmakuIndex, content: danmakuContent, position: position, fontcolor: color, fontsize: fontsize)
            //danmakuArray.append(d)
            danmakuIndex += 1 // count parsed danmaku
            
        }
    }
}
