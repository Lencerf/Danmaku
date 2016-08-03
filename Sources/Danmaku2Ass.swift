import Foundation

typealias StageArrage = [Danmaku?]

protocol DanmakuProcessor {
    func parse(rawData: Data) -> [Danmaku]
    func treatSpecialDanmaku(_ danmaku: Danmaku, videoWidth: Int, videoHeight: Int, sytleId: String) -> String
}

class Danmaku2Ass {
    private let processor: DanmakuProcessor
    private let rawData: Data
    private let videoWidth:Int
    private let videoHeight:Int
    // optional args that can be specified by user
    var fontface = "PingFangSC-Regular"
    var fontsize = 25.0
    var alpha = 1.0
    var durationMarquee = 5.0
    var durationStill = 5.0
    var reduceComments = true
    var reservedBottomBlank = 0

    init(rawData data: Data, videoSize: (Int, Int), processor: DanmakuProcessor) {
        (self.videoWidth, self.videoHeight) = videoSize
        self.processor = processor
        self.rawData = data
    }
    
    private func rowsNeeded(_ d: Danmaku) -> Int {
        return Int(Double(d.nLines) * fontsize * d.rSize) + 1
    }
    
    private func dWidth(_ d: Danmaku) -> Double {
        return Double(d.length) * fontsize * d.rSize
    }

    private func mark(stageRows rows: inout [StageArrage], withDanmaku danmaku: Danmaku, fromRow row: Int) {
        for i in row..<min(rows[danmaku.position.rawValue].count, row + rowsNeeded(danmaku)) {
            rows[danmaku.position.rawValue][i] = danmaku
        }
    }

    private func findAlternativeRow(for d: Danmaku, on arrages: [StageArrage]) -> Int {
        // find the first row with nil, or find the row with min rowindex
        let arrage = arrages[d.position.rawValue]
        var result = 0
        for rowIndex in 0..<(videoHeight - reservedBottomBlank - rowsNeeded(d)) {
            if let targetRow = arrage[rowIndex] {
                if targetRow.replayTime < arrage[result]!.replayTime {
                    result = rowIndex
                }
            } else {
                return rowIndex
            }
        }
        return result
    }
    
    //this function count how many free rows there are behind rowStarted
    private func testFreeRows(on arrages: [StageArrage], for d: Danmaku, fromRow rowStarted: Int) -> Int {
        let rowUpbound = self.videoHeight - self.reservedBottomBlank
        let rowExtentedToExpected = rowStarted + rowsNeeded(d) - 1 // = rowStarted + d.height.ceil() - 1
        guard rowUpbound > rowExtentedToExpected else {
            // although all left rows are not certain to be free, but we do not need to check them.
            return rowUpbound - rowStarted
        }
        for r in rowStarted...rowExtentedToExpected {
            if let danInTargetRow = arrages[d.position.rawValue][r] {
                switch d.position {
                case .top, .bottom :
                    if danInTargetRow.replayTime + durationStill > d.replayTime {
                        return r - rowStarted
                    }
                case .normal, .opposite :
                    let threshholdTime = d.replayTime - durationMarquee * ( 1.0 - Double(videoWidth) / (dWidth(d) + Double(videoWidth)))
                    if danInTargetRow.replayTime > threshholdTime || danInTargetRow.replayTime + dWidth(danInTargetRow) * durationMarquee / (dWidth(danInTargetRow) + Double(videoWidth)) > d.replayTime {
                        return r - rowStarted
                    }
                default: // no .special actually
                    break
                }
            }
        }
        return rowsNeeded(d)
    }
    
    private func convertColor(RGB:Int, width: Int = 1280, height: Int = 576) -> String {
        if RGB == 0x000000 {
            return "000000"
        } else if RGB == 0xffffff {
            return "FFFFFF"
        }
        let R = (RGB >> 16) & 0xff
        let G = (RGB >> 8) & 0xff
        let B = RGB & 0xff
        if width < 1280 && height < 576 {
            return String(format: "%02X%02X%02X", B, G, R)
        } else {
            func clipByte(_ x: Double) -> Int {
                if x > 255.0 {
                    return 255
                } else if x < 0.0 {
                    return 0
                } else {
                    return Int(round(x))
                }
            }
            let a = clipByte(R * 0.00956384088080656 + G * 0.03217254540203729 + B * 0.95826361371715607)
            let b = clipByte(R * -0.10493933142075390 + G * 1.17231478191855154 + B * -0.06737545049779757)
            let c = clipByte(R * 0.91348912373987645 + G * 0.07858536372532510 + B * 0.00792551253479842)
            return String(format: "%02X%02X%02X", a, b, c)
            
        }
    }
    
    private func convertTimestamp(_ timestamp: Double) -> String {
        let h = Int(timestamp / 3600.0)
        let m = Int((timestamp - h * 3600.0) / 60.0)
        let s = Int(timestamp - h * 3600.0 - m * 60.0)
        let cs = Int((timestamp - floor(timestamp)) * 100.0)
        return String(format: "%d:%02d:%02d.%02d", h, m, s, cs)
    }

    private func genAssDialogueFrom(danmaku: Danmaku, atRow row:Int = 0, styleId: String) -> String {
        let negLen = -Int(dWidth(danmaku)) - 1
        var styles = ""
        var duration = 0.0
        switch danmaku.position {
        case .special:
            // call processor to treate special danmaku
            return processor.treatSpecialDanmaku(danmaku, videoWidth: videoWidth, videoHeight: videoHeight, sytleId: styleId) ?? "\n"
        case .normal:
            styles = "\\move(\(videoWidth), \(row), \(negLen), \(row))"
            duration = self.durationMarquee
        case .opposite:
            styles = "\\move(\(negLen), \(row), \(videoWidth), \(row))"
            duration = self.durationMarquee
        case .top:
            styles = "\\an8\\pos(\(videoWidth / 2), \(row))"
            duration = self.durationStill
        case .bottom:
            styles = "\\an8\\pos(\(videoWidth / 2), \(videoHeight - reservedBottomBlank - row))"
            duration = self.durationStill
        }
        if fabs(danmaku.rSize * fontsize - fontsize) > 1.0 {
            // specify special fonts
            styles += String(format:"\\fs%.0f", danmaku.rSize * fontsize)
        }
        if danmaku.color != 0xffffff {
            let d = convertColor(RGB: danmaku.color)
            let a = "\\c&H\(d)&"
            styles += a
            if danmaku.color == 0x000000 {
                styles += "\\c&HFFFFFF&"
            }
        }
        let startTime = convertTimestamp(danmaku.replayTime)
        let endTime = convertTimestamp(danmaku.replayTime + duration)
        return "Dialogue: 2,\(startTime),\(endTime),\(styleId),,0000,0000,0000,,{\(styles)}\(danmaku.validContent)\n"
    }
    
    func convert(toAss assPath: String) throws {
        let styleId = "Danmaku2Ass_\(arc4random())"
        let assHead =
            "[Script Info]" + "\n" +
                "Script Updated By: bilicli.Danmaku2Ass with \(self.processor)" + "\n" +
                "ScriptType: v4.00+" + "\n" +
                "PlayResX: \(self.videoWidth)" + "\n" +
                "PlayResY: \(self.videoHeight)" + "\n" +
                "Aspect Ratio: \(self.videoWidth):\(self.videoHeight)" + "\n" +
                "Collisions: Normal" + "\n" +
                "WrapStyle: 2" + "\n" +
                "ScaledBorderAndShadow: yes" + "\n" +
                "YCbCr Matrix: TV.601" + "\n" +
                "\n" +
                "[V4+ Styles]" + "\n" +
                "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding" + "\n" +
                "Style: " + String(format: "%@, %@, %.0f, &H%02XFFFFFF, &H%02XFFFFFF, &H02X000000, &H02X000000, ", styleId, self.fontface, self.fontsize, self.alpha, self.alpha, self.alpha, self.alpha) + "0, 0, 0, 0, 100, 100, 0.00, 0.00, 1, \(max(Int(fontsize/25.0),1)), 0, 7, 0, 0, 0, 0" +
                "\n" +
                "[Events]" + "\n" +
                "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text" + "\n"
        //do {
        //    try assHead.write(toFile: assPath, atomically: true, encoding: .utf8)
        //} catch let error as NSError {
        //    throw error
        //}
        
        //guard let handle = FileHandle.init(forWritingAtPath: assPath) else {
        // need change
        //    throw NSError.init()
        //}
        
        var dialogs = [assHead]
        
        var danmakuArray = processor.parse(rawData: self.rawData)
        
        danmakuArray.sort { (l, r) -> Bool in l.replayTime < r.replayTime }
        
        var stageArranges = [StageArrage].init(repeating: StageArrage.init(repeating :nil, count: videoHeight - reservedBottomBlank + 1), count: 4)
        
        // rowsArray -> stageArrages
        
        for d in danmakuArray {
            //print("treating: \(d.content)")
            //handle.seekToEndOfFile()
            if d.position != .special {
                var row = 0
                let rowMax = videoHeight - reservedBottomBlank - rowsNeeded(d)
                while row <= rowMax {
                    let freeRows = testFreeRows(on: stageArranges, for: d, fromRow: row)
                    if freeRows >= rowsNeeded(d) {
                        mark(stageRows: &stageArranges, withDanmaku: d, fromRow: row)
                        dialogs.append(genAssDialogueFrom(danmaku: d, atRow: row, styleId: styleId))
                        break
                    } else {
                        row += max(freeRows, 1)
                    }
                }
                if row > rowMax && !reduceComments {
                    row = findAlternativeRow(for: d, on: stageArranges)
                    mark(stageRows: &stageArranges, withDanmaku: d, fromRow: row)
                    dialogs.append(genAssDialogueFrom(danmaku: d, atRow: row, styleId: styleId))
                }
            } else {// treate speial danmaku
                dialogs.append(processor.treatSpecialDanmaku(d, videoWidth: videoWidth, videoHeight: videoHeight, sytleId: styleId))
            }
        }
        //handle.closeFile()
        let assContent = dialogs.joined(separator: "")
        do {
            try assContent.write(toFile: assPath, atomically: true, encoding: .utf8)
        } catch let error as NSError {
            throw error
        }
    }
}

private func *(left: Int, right: Double) -> Double {
    return Double(left) * right
}
