//
//  ViewController.swift
//  NeonJSON
//
//  Created by Kaunteya Suryawanshi on 26/08/22.
//

import Cocoa
import Neon
import SwiftTreeSitter
import TreeSitterJSON
import TreeSitterClient

class ViewController: NSViewController {

    @IBOutlet var textView: NSTextView!

    var highlighter: Highlighter!

    var treeSitterClient: TreeSitterClient!
    var query: Query!

    var scrollObserver: NSObjectProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.textStorage?.delegate = self

        initialiseHighlighter()
        initialiseTreeSitterClient()
        addScrollObserver()
    }

    private func initialiseHighlighter() {
        guard let textContainer = textView.textContainer else {
            preconditionFailure()
        }

        let textInterface = TextContainerSystemInterface(textContainer: textContainer, attributeProvider: attributeProvider)

        self.highlighter = Highlighter(textInterface: textInterface, tokenProvider: self.tokenProvider)
    }

    private func initialiseTreeSitterClient() {
        let language = Language(language: tree_sitter_json())

        let url = Bundle.main
            .resourceURL?
            .appendingPathComponent("TreeSitterJSON_TreeSitterJSON.bundle")
            .appendingPathComponent("Contents/Resources/queries/highlights.scm")

        query = try! language.query(contentsOf: url!)

        treeSitterClient = try! TreeSitterClient(language: language, transformer: { index in
            return Point.zero
        })

        treeSitterClient.invalidationHandler = { indexSet in
            DispatchQueue.main.async {
                self.highlighter.invalidate(.set(indexSet))
            }
        }
    }

    private func addScrollObserver() {
        textView.enclosingScrollView?.contentView.postsFrameChangedNotifications = true

        scrollObserver = NotificationCenter.default
            .addObserver(forName: NSView.boundsDidChangeNotification, object: textView.enclosingScrollView?.contentView, queue: nil) { _ in
                self.highlighter.visibleContentDidChange()
            }
    }

    private func attributeProvider(_ token: Token) -> [NSAttributedString.Key: Any]? {
        switch token.name {
        case "punctuation.bracket":
            return [.foregroundColor: NSColor.systemPurple]
        case "punctuation.delimiter":
            return [.foregroundColor: NSColor.secondaryLabelColor]
        case "keyword":
            return [.foregroundColor: NSColor.systemYellow]
        case "value.string":
            return [.foregroundColor: NSColor.systemGreen]
        case "value.bool":
            return [.foregroundColor: NSColor.systemRed]
        case "value.number":
            return [.foregroundColor: NSColor.systemBlue]
        case "value.null":
            return [.foregroundColor: NSColor.systemTeal]
        default:
            return [.foregroundColor: NSColor.systemGray, .backgroundColor: NSColor.systemRed]
        }
    }

    private func tokenProvider(_ range: NSRange, completionHandler: @escaping (Result<TokenApplication, Error>) -> Void) {
        print(#function, range.location, range.length)
        guard let _ = textView.textStorage?.string[range] else {
            return
        }

        treeSitterClient.executeHighlightsQuery(query, in: range) { result in
            switch result {
            case .success(let tokenList):
                completionHandler(.success(TokenApplication(tokens: tokenList)))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
}

extension ViewController: NSTextStorageDelegate {
    func textStorage(_ textStorage: NSTextStorage, willProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        treeSitterClient.willChangeContent(in: editedRange)
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        let adjustedRange = NSRange(location: editedRange.location, length: editedRange.length - delta)
        self.highlighter.didChangeContent(in: adjustedRange, delta: delta)
        treeSitterClient.didChangeContent(to: textStorage.string, in: adjustedRange, delta: delta, limit: textStorage.string.count)
    }
}


extension String {
    func lineNumber(for location: Int) -> (Int, Int) {
        var lineCount = 0
        var charCount = 0
        for (i, c) in enumerated() where i < location {
            charCount += 1
            if c.isNewline {
                lineCount += 1
                charCount = 0
            }
        }
        return (lineCount, charCount)
    }
}

