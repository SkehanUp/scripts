import AppKit
import Vision

struct Options {
    var imagePath: String
    var copyToClipboard: Bool = true
}

enum ImgtextError: Error, LocalizedError {
    case missingImage
    case unreadableImage(String)
    case emptySelection
    case ocrFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingImage:
            return "Image path is required."
        case .unreadableImage(let path):
            return "Could not load image: \(path)"
        case .emptySelection:
            return "Selection is too small. Drag a larger region."
        case .ocrFailed(let message):
            return "OCR failed: \(message)"
        }
    }
}

func parseArgs(_ args: [String]) throws -> Options {
    var copyToClipboard = true
    var imagePath: String?

    var index = 1
    while index < args.count {
        let arg = args[index]
        switch arg {
        case "-h", "--help":
            print("""
            imgtext — select a region in an image and read its text.

            Usage: imgtext <image> [--no-copy]

            Controls:
              Drag       Select a region
              Enter      OCR the current selection
              Esc        Quit without output
            """)
            exit(0)
        case "--no-copy":
            copyToClipboard = false
        default:
            if arg.hasPrefix("-") {
                throw ImgtextError.ocrFailed("Unknown option: \(arg)")
            }
            if imagePath != nil {
                throw ImgtextError.ocrFailed("Unexpected argument: \(arg)")
            }
            imagePath = arg
        }
        index += 1
    }

    guard let imagePath else {
        throw ImgtextError.missingImage
    }
    return Options(imagePath: imagePath, copyToClipboard: copyToClipboard)
}

func loadCGImage(from path: String) throws -> CGImage {
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw ImgtextError.unreadableImage(path)
    }
    return image
}

func ocr(cgImage: CGImage) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        throw ImgtextError.ocrFailed(error.localizedDescription)
    }

    let lines = (request.results ?? [])
        .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
        .compactMap { $0.topCandidates(1).first?.string }

    return lines.joined(separator: "\n")
}

func crop(cgImage: CGImage, rect: CGRect) -> CGImage? {
    let bounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
    let clipped = rect.intersection(bounds)
    guard clipped.width >= 2, clipped.height >= 2 else { return nil }
    return cgImage.cropping(to: clipped.integral)
}

final class ImageSelectionView: NSView {
    var cgImage: CGImage
    var onComplete: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private var dragStart: NSPoint?
    private var selection = NSRect.zero
    private var imageRect = NSRect.zero

    init(cgImage: CGImage) {
        self.cgImage = cgImage
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        imageRect = fittedImageRect(in: bounds.size)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        nsImage.draw(in: imageRect)

        if selection.width > 0, selection.height > 0 {
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(2)
            context.stroke(selection)
            context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.15).cgColor)
            context.fill(selection)
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        selection = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = rect(from: dragStart, to: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = rect(from: start, to: point)
        dragStart = nil
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36: // Return
            runOCR()
        case 53: // Escape
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    private func fittedImageRect(in viewSize: NSSize) -> NSRect {
        let imageSize = NSSize(width: cgImage.width, height: cgImage.height)
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let x = (viewSize.width - width) / 2
        let y = (viewSize.height - height) / 2
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func rect(from start: NSPoint, to end: NSPoint) -> NSRect {
        NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func selectionInImagePixels() -> CGRect? {
        guard selection.width >= 4, selection.height >= 4 else { return nil }
        let intersection = selection.intersection(imageRect)
        guard intersection.width >= 4, intersection.height >= 4 else { return nil }

        let scaleX = CGFloat(cgImage.width) / imageRect.width
        let scaleY = CGFloat(cgImage.height) / imageRect.height

        let x = (intersection.origin.x - imageRect.origin.x) * scaleX
        let width = intersection.width * scaleX
        let height = intersection.height * scaleY
        // View is flipped (top-left origin); CGImage uses bottom-left.
        let y = CGFloat(cgImage.height) - (intersection.origin.y - imageRect.origin.y + intersection.height) * scaleY

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func runOCR() {
        guard let pixelRect = selectionInImagePixels(),
              let cropped = crop(cgImage: cgImage, rect: pixelRect)
        else {
            let alert = NSAlert()
            alert.messageText = "Selection too small"
            alert.informativeText = "Drag a box around the text, then press Enter."
            alert.runModal()
            return
        }

        do {
            let text = try ocr(cgImage: cropped)
            onComplete?(text)
        } catch {
            let alert = NSAlert()
            alert.messageText = "OCR failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

@main
struct ImgtextApp {
    static func main() {
        do {
            let options = try parseArgs(CommandLine.arguments)
            let cgImage = try loadCGImage(from: options.imagePath)

            let app = NSApplication.shared
            app.setActivationPolicy(.regular)

            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
            let maxWidth = min(screenFrame.width * 0.9, 1400)
            let maxHeight = min(screenFrame.height * 0.9, 1000)
            let aspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
            var width = maxWidth
            var height = width / aspect
            if height > maxHeight {
                height = maxHeight
                width = height * aspect
            }

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "imgtext — drag to select, Enter to read, Esc to quit"
            window.center()

            let view = ImageSelectionView(cgImage: cgImage)
            view.frame = window.contentView!.bounds
            view.autoresizingMask = [.width, .height]
            window.contentView = view
            window.makeFirstResponder(view)

            view.onComplete = { text in
                if !text.isEmpty {
                    print(text)
                    if options.copyToClipboard {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                }
                app.terminate(nil)
            }
            view.onCancel = {
                app.terminate(nil)
            }

            window.makeKeyAndOrderFront(nil)
            app.activate(ignoringOtherApps: true)
            app.run()
        } catch ImgtextError.missingImage {
            fputs("Usage: imgtext <image> [--no-copy]\n", stderr)
            exit(1)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
