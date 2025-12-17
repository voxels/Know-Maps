import Foundation
import CoreML

@MainActor
final class MiniLMEmbeddingClient {

    static let shared = MiniLMEmbeddingClient()

    private let model: MLModel
    private let tokenizer: MiniLMTokenizer

    private init() {
        tokenizer = MiniLMTokenizer()

        print("Bundle path:", Bundle.main.bundlePath)
        print("mlpackage URLs:", Bundle.main.urls(forResourcesWithExtension: "mlpackage", subdirectory: nil) ?? [])
        print("mlmodelc URLs:", Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil) ?? [])

        // Load the ML model (support both .mlpackage and compiled .mlmodelc)
        let modelURL = Bundle.main.url(forResource: "MiniLM-L12-Embedding", withExtension: "mlpackage") ??
                       Bundle.main.url(forResource: "MiniLM-L12-Embedding", withExtension: "mlmodelc")

        guard let url = modelURL else {
            let foundMLPackages = Bundle.main.urls(forResourcesWithExtension: "mlpackage", subdirectory: nil) ?? []
            let foundMLModelc   = Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil) ?? []
            fatalError("Could not locate MiniLM model in bundle. Looked for MiniLM-L12-Embedding.mlpackage and .mlmodelc. Found mlpackage: \(foundMLPackages), mlmodelc: \(foundMLModelc)")
        }

        do {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .all
            model = try MLModel(contentsOf: url, configuration: cfg)
        } catch {
            fatalError("Could not load ML model: \(error)")
        }
    }

    // MARK: - Public API

    @discardableResult
    public func embed(_ text: String) async throws -> [Double] {
        try _embed(text)
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
