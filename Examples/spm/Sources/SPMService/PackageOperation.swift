// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Dispatch
import Foundation
import GRPC
import Logging
import NIO
import NIOConcurrencyHelpers
import PackageGraph
import PackageLoading
import PackageModel
import SPMServiceProtocol
import SourceControl
import SwiftProtobuf
import TSCBasic
import TSCUtility
import Workspace

struct PackageOperation {
    enum OperationKind {
        case resolve(_ context: StreamingResponseCallContext<SPM_RawLogEvent>)
        case build(_ context: StreamingResponseCallContext<SPM_RawLogEvent>)
    }

    let activePackage: ActivePackage
    let op: OperationKind

    /// The diagnostics engine.
    private(set) var diagnostics: DiagnosticsEngine!

    init(activePackage: ActivePackage, op: OperationKind) {
        self.activePackage = activePackage
        self.op = op
        self.diagnostics = DiagnosticsEngine(
            handlers: [diagnosticsHandler]
        )
    }

    private func diagnosticsHandler(_ diagnostic: Diagnostic) {
        sendRawLog(diagnostic.localizedDescription)
    }

    func perform() {
        let workspace = activePackage.workspace
        switch op {
        case .build: break
        case .resolve:
            workspace.delegate = PackageOperationWorkspaceDelegate(operation: self)
            self.activePackage.workspace.resolve(root: activePackage.root, diagnostics: self.diagnostics)
            workspace.delegate = nil
        }
    }

    func sendRawLog(_ log: String) {
        var message = SPM_RawLogEvent()
        message.log = log
        _ = context.sendResponse(message)
    }

    private var context: StreamingResponseCallContext<SPM_RawLogEvent> {
        switch op {
        case .build(let context): return context
        case .resolve(let context): return context
        }
    }
}

final class PackageOperationWorkspaceDelegate: WorkspaceDelegate {

    let operation: PackageOperation

    init(operation: PackageOperation) {
        self.operation = operation
    }

    func fetchingWillBegin(repository: String) {
        operation.sendRawLog("Fetching \(repository)")
    }

    func fetchingDidFinish(repository: String, diagnostic: Diagnostic?) {
        print(#function, repository)
    }

    func repositoryWillUpdate(_ repository: String) {
        operation.sendRawLog("Updating \(repository)")
    }

    func repositoryDidUpdate(_ repository: String) {
        print(#function, repository)
    }

    func dependenciesUpToDate() {
        operation.sendRawLog("Everything up-to-date.")
    }

    func cloning(repository: String) {
        operation.sendRawLog("Cloning \(repository)")
    }

    func checkingOut(repository: String, atReference reference: String, to path: AbsolutePath) {
        operation.sendRawLog("Checking out \(repository) at \(reference)")
    }

    func removing(repository: String) {
        operation.sendRawLog("Removing \(repository)")
    }

    func willResolveDependencies(reason: WorkspaceResolveReason) {
        operation.sendRawLog("Will resolve dependencies \(reason)")
    }

    func resolvedFileChanged() {}

    func downloadingBinaryArtifact(from url: String, bytesDownloaded: Int64, totalBytesToDownload: Int64?) {}

    func didDownloadBinaryArtifacts() {}
}
