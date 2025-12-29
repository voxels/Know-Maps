import CoreML
import Foundation

enum KnowMapsCoreMLResourceError: Error {
    case resourceNotFound(String)
    case modelFileNotFound(String)
}

final class KnowMapsLocalMapsQueryTagger {
    let model: MLModel

    init(configuration: MLModelConfiguration = MLModelConfiguration()) throws {
        let bundle = Self.resourceBundle
        
        // 1. Try to find the compiled model (.mlmodelc)
        if let compiledURL = bundle.url(forResource: "LocalMapsQueryTagger", withExtension: "mlmodelc") {
            model = try MLModel(contentsOf: compiledURL, configuration: configuration)
            return
        }

        // 2. Fallback: Try to find source (.mlmodel) and compile
        if let mlmodelURL = bundle.url(forResource: "LocalMapsQueryTagger", withExtension: "mlmodel") {
            let compiledURL = try MLModel.compileModel(at: mlmodelURL)
            model = try MLModel(contentsOf: compiledURL, configuration: configuration)
            return
        }

        // 3. Fallback: Try to find package (.mlpackage) and compile
        guard let packageURL = bundle.url(forResource: "LocalMapsQueryTagger", withExtension: "mlpackage") else {
            // Debugging: Print bundle path
            print("DEBUG: Bundle path: \(bundle.bundlePath)")
            throw KnowMapsCoreMLResourceError.resourceNotFound("LocalMapsQueryTagger [mlmodelc, mlmodel, mlpackage]")
        }

        let mlmodelURL = try Self.findFirstMLModel(in: packageURL, context: "LocalMapsQueryTagger.mlpackage")
        let compiledURL = try MLModel.compileModel(at: mlmodelURL)
        model = try MLModel(contentsOf: compiledURL, configuration: configuration)
    }
}

struct KnowMapsFoursquareSectionClassifierInput {
    let text: String
}

struct KnowMapsFoursquareSectionClassifierOutput {
    let label: String
}

final class KnowMapsFoursquareSectionClassifier {
    private let model: MLModel

    init(configuration: MLModelConfiguration = MLModelConfiguration()) throws {
        let bundle = Self.resourceBundle
        
        // 1. Try to find the compiled model (.mlmodelc)
        if let compiledURL = bundle.url(forResource: "FoursquareSectionClassifier", withExtension: "mlmodelc") {
            model = try MLModel(contentsOf: compiledURL, configuration: configuration)
            return
        }

        // 2. Fallback: Source model
        guard let mlmodelURL = bundle.url(forResource: "FoursquareSectionClassifier", withExtension: "mlmodel") else {
            throw KnowMapsCoreMLResourceError.resourceNotFound("FoursquareSectionClassifier [mlmodelc, mlmodel]")
        }

        let compiledURL = try MLModel.compileModel(at: mlmodelURL)
        model = try MLModel(contentsOf: compiledURL, configuration: configuration)
    }

    func prediction(input: KnowMapsFoursquareSectionClassifierInput) throws -> KnowMapsFoursquareSectionClassifierOutput {
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "text": MLFeatureValue(string: input.text),
        ])

        let out = try model.prediction(from: provider)
        let label = out.featureValue(for: "label")?.stringValue
            ?? out.featureValue(for: "classLabel")?.stringValue
            ?? ""
        return KnowMapsFoursquareSectionClassifierOutput(label: label)
    }
}

private extension KnowMapsLocalMapsQueryTagger {
    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        let bundle = Bundle(for: Self.self)
        if bundle.url(forResource: "LocalMapsQueryTagger", withExtension: "mlmodel") != nil ||
           bundle.url(forResource: "LocalMapsQueryTagger", withExtension: "mlpackage") != nil {
            return bundle
        }
        return Bundle.main
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

private extension KnowMapsFoursquareSectionClassifier {
    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        let bundle = Bundle(for: Self.self)
        if bundle.url(forResource: "FoursquareSectionClassifier", withExtension: "mlmodel") != nil {
            return bundle
        }
        return Bundle.main
        #endif
    }
}
