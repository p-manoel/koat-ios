import Foundation
import Vision
import ImageIO

// Run against screenshots and sampled video frames. OCR supplements visual review.
for filename in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: filename)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["pt-BR", "en-US"]
    request.usesLanguageCorrection = false
    do {
        try VNImageRequestHandler(url: url).perform([request])
        print("\nFILE: \(filename)")
        for result in request.results ?? [] {
            if let text = result.topCandidates(1).first?.string { print(text) }
        }
    } catch {
        fputs("OCR failed for \(filename): \(error)\n", stderr)
        exit(1)
    }
}
