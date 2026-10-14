import Foundation
import ImageIO
import Vision

struct InputFile: Decodable {
    let path: String
}

struct RecognizedText: Encodable {
    let text: String
    let confidence: Double
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

let manifestPath = CommandLine.arguments[1]
let manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
let files = try JSONDecoder().decode([InputFile].self, from: manifestData)
var output: [String: [RecognizedText]] = [:]

for file in files {
    let url = URL(fileURLWithPath: file.path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        output[file.path] = []
        continue
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    let handler = VNImageRequestHandler(cgImage: image)
    try handler.perform([request])
    output[file.path] = (request.results ?? []).compactMap { result in
        guard let text = result.topCandidates(1).first?.string else { return nil }
        let box = result.boundingBox
        return RecognizedText(
            text: text,
            confidence: Double(result.topCandidates(1).first?.confidence ?? 0),
            x: box.origin.x,
            y: 1.0 - box.origin.y - box.height,
            width: box.width,
            height: box.height
        )
    }
}

let encoded = try JSONEncoder().encode(output)
FileHandle.standardOutput.write(encoded)
