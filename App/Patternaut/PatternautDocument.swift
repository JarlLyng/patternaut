import SwiftUI
import UniformTypeIdentifiers
import PatternautCore

extension UTType {
    /// Patternaut's own document: the work in progress, not what the device reads.
    static let patternautProject = UTType(exportedAs: "com.iamjarl.patternaut.project")
}

/// The open document. Holds the ``EditorModel`` so editing state and the saved
/// file are the same thing, and converts between the two on open and save.
final class PatternautDocument: ReferenceFileDocument {
    typealias Snapshot = ProjectFile

    static var readableContentTypes: [UTType] { [.patternautProject] }
    static var writableContentTypes: [UTType] { [.patternautProject] }

    let model: EditorModel

    init() {
        model = EditorModel()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw ProjectFile.DocumentError.unreadable
        }
        model = EditorModel(file: try ProjectFile.decoded(from: data))
    }

    /// Taken on the main actor before writing, so the file is a consistent
    /// picture of the document even if editing continues.
    func snapshot(contentType: UTType) throws -> ProjectFile {
        model.projectFile
    }

    func fileWrapper(snapshot: ProjectFile, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try snapshot.data())
    }
}
