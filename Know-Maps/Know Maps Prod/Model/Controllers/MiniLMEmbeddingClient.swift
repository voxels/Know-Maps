import Foundation
import CoreML
import NaturalLanguage

@MainActor
public final class MiniLMEmbeddingClient {

    public static let shared = MiniLMEmbeddingClient()

    private let model: MLModel
    private let tokenizer: MiniLMTokenizer

    private init() {
        tokenizer = MiniLMTokenizer()

        let bundle = Self.resourceBundle

        // SwiftPM ships the raw .mlmodel from inside the .mlpackage (named `model.mlmodel`).
        // Xcode/framework builds may instead include the full .mlpackage or a compiled .mlmodelc.
        let rawMLModelURL = bundle.url(forResource: "model", withExtension: "mlmodel")
        let mlpackageURL = bundle.url(forResource: "MiniLM-L12-Embedding", withExtension: "mlpackage")
        let compiledURL = bundle.url(forResource: "MiniLM-L12-Embedding", withExtension: "mlmodelc")

        guard rawMLModelURL != nil || mlpackageURL != nil || compiledURL != nil else {
            // If we can't find the heavy model, we might be in a constrained target where it was intentionally omitted
            // We'll allow initialization and rely on the fallback logic in embed()
            print("MiniLM-L12-Embedding model not found. MiniLMEmbeddingClient will use NLEmbedding fallback.")
            model = try! MLModel(contentsOf: URL(fileURLWithPath: "/dev/null"), configuration: MLModelConfiguration()) // Placeholder
            return
        }

        do {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .all
            if let rawMLModelURL {
                let compiled = try MLModel.compileModel(at: rawMLModelURL)
                model = try MLModel(contentsOf: compiled, configuration: cfg)
            } else if let compiledURL {
                model = try MLModel(contentsOf: compiledURL, configuration: cfg)
            } else if let mlpackageURL {
                let inner = try Self.findFirstMLModel(in: mlpackageURL, context: "MiniLM-L12-Embedding.mlpackage")
                let compiled = try MLModel.compileModel(at: inner)
                model = try MLModel(contentsOf: compiled, configuration: cfg)
            } else {
                model = try MLModel(contentsOf: URL(fileURLWithPath: "/dev/null"), configuration: cfg)
            }
        } catch {
            fatalError("Could not load ML model: \(error)")
        }
    }

    // MARK: - Public API

    @discardableResult
    public func embed(_ text: String) async throws -> [Double] {
        // Hybrid Fallback: Use NLEmbedding in resource-constrained App Extensions
        if isExtensionTarget() {
            return try _embedFallback(text)
        }
        
        do {
            return try _embed(text)
        } catch {
            print("MiniLM embedding failed, falling back to NLEmbedding: \(error)")
            return try _embedFallback(text)
        }
    }
    
    private func _embedFallback(_ text: String) throws -> [Double] {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            throw NSError(domain: "MiniLMEmbeddingClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "NLEmbedding not available"])
        }
        guard let vector = embedding.vector(for: text) else {
            throw NSError(domain: "MiniLMEmbeddingClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "NLEmbedding failed for text"])
        }
        return vector
    }
    
    private func isExtensionTarget() -> Bool {
        return Self.resourceBundle.bundlePath.hasSuffix(".appex")
    }

    // MARK: - Internal

    private func _embed(_ text: String) throws -> [Double] {

        let key = "text::" + text.lowercased()

        // 1. Check embedding cache
        if let cached = EmbeddingCache.shared.get(key) {
            return cached
        }

        // 2. Tokenize
        let (ids, mask) = tokenizer.encode(text, maxLength: 256)
        let idsArray = try makeInputArray(ids)
        let maskArray = try makeInputArray(mask)

        // 3. Build CoreML input
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: idsArray),
            "attention_mask": MLFeatureValue(multiArray: maskArray)
        ])

        // 4. Run inference
        let output = try model.prediction(from: input)

        guard let embeddingArray = output.featureValue(for: "var_842")?.multiArrayValue else {
            throw NSError(domain: "MiniLMEmbeddingClient", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing embedding output var_842"])
        }

        let raw = toDoubleArray(embeddingArray)
        let normalized = normalize(raw)

        // 5. Store in cache
        EmbeddingCache.shared.set(key, vector: normalized)

        return normalized
    }

    // MARK: - Helpers

    private func makeInputArray(_ ints: [Int]) throws -> MLMultiArray {
        // CoreML expects shape [1, seq_len]
        let shape: [NSNumber] = [1, NSNumber(value: ints.count)]
        let arr = try MLMultiArray(shape: shape, dataType: .int32)

        for (i, v) in ints.enumerated() {
            arr[i] = NSNumber(value: v)
        }
        return arr
    }

    private func normalize(_ vector: [Double]) -> [Double] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
    
    private func toDoubleArray(_ array: MLMultiArray) -> [Double] {
        let count = array.count
        var result = [Double](repeating: 0, count: count)

        switch array.dataType {
        case .double:
            for i in 0..<count { result[i] = array[i].doubleValue }
        case .float32:
            for i in 0..<count { result[i] = Double(array[i].floatValue) }
        case .float64:
            for i in 0..<count { result[i] = array[i].doubleValue }
        case .int32:
            for i in 0..<count { result[i] = Double(truncating: array[i]) }
        default:
            // Fallback for any other numeric types (e.g., .int8, .int16, .int64 on newer SDKs)
            for i in 0..<count { result[i] = array[i].doubleValue }
        }

        return result
    }
}

private extension MiniLMEmbeddingClient {
    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: MiniLMEmbeddingClient.self)
        #endif
    }

    static func findFirstMLModel(in directoryURL: URL, context: String) throws -> URL {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: nil) else {
            throw KnowMapsCoreMLResourceError.modelFileNotFound(context)
        }

        for case let url as URL in enumerator {
            if url.pathExtension == "mlmodel" {
                return url
            }
        }

        throw KnowMapsCoreMLResourceError.modelFileNotFound(context)
    }
}
