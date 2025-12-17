//
//  MiniLMTokenizer.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 12/4/25.
//

import Foundation

/// BERT WordPiece tokenizer compatible with MiniLM-L12-v2.
/// Requires `vocab.txt` to be added to your app bundle.
public final class MiniLMTokenizer {

    private let vocab: [String: Int]
    private let unkToken = "[UNK]"
    private let clsToken = "[CLS]"
    private let sepToken = "[SEP]"
    private let padToken = "[PAD]"
    private let doLowerCase: Bool = true

    public init() {
        let url = Bundle.main.url(forResource: "vocab", withExtension: "txt")!
        let contents = try! String(contentsOf: url, encoding: .utf8)
        let lines = contents.split(separator: "\n").map(String.init)

        var v = [String: Int]()
        for (i, t) in lines.enumerated() { v[t] = i }
        vocab = v
    }

    public func encode(_ text: String, maxLength: Int = 256) -> (ids: [Int], mask: [Int]) {
        let tokens = tokenize(text)
        let wp = wordpiece(tokens)

        var ids = [vocab[clsToken]!]
        ids += wp.map { vocab[$0] ?? vocab[unkToken]! }
        ids.append(vocab[sepToken]!)

        if ids.count > maxLength {
            ids = Array(ids.prefix(maxLength))
        }

        var mask = Array(repeating: 1, count: ids.count)

        if ids.count < maxLength {
            let pad = vocab[padToken]!
            let padCount = maxLength - ids.count
            ids += Array(repeating: pad, count: padCount)
            mask += Array(repeating: 0, count: padCount)
        }

        return (ids, mask)
    }

    private func tokenize(_ text: String) -> [String] {
        let cleaned = doLowerCase ? text.lowercased() : text
        return cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    private func wordpiece(_ tokens: [String]) -> [String] {
        var result: [String] = []
        for token in tokens {
            if vocab[token] != nil {
                result.append(token)
                continue
            }
            var chars = Array(token)
            var i = 0
            while i < chars.count {
                var j = chars.count
                var sub: String? = nil
                while i < j {
                    let piece = (i > 0 ? "##" : "") + String(chars[i..<j])
                    if vocab[piece] != nil {
                        sub = piece
                        break
                    }
                    j -= 1
                }
                if let s = sub {
                    result.append(s)
                    i = j
                } else {
                    result.append(unkToken)
                    break
                }
            }
        }
        return result
    }
}
