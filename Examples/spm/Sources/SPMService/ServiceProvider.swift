// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import GRPC
import Logging
import NIO
import NIOConcurrencyHelpers
import SPMServiceProtocol
import SwiftProtobuf
import TSCBasic
import TSCUtility

final class ServiceProvider: SPM_ServiceProvider {

    /// The shared context.
    let ctx: Context

    /// The currently active packages.
    private var _activePackages: [AbsolutePath: ActivePackage] = [:]
    private let activePackageLock = NIOConcurrencyHelpers.Lock()

    public init(_ ctx: Context) {
        self.ctx = ctx
    }

    func getActivePackage(_ packagePath: AbsolutePath) -> EventLoopFuture<ActivePackage> {
        ctx.group.next().submit {
            try self.activePackageLock.withLock {
                if let activePackage = self._activePackages[packagePath] {
                    if activePackage.isBusy {
                        throw GRPCStatus(code: .unavailable, message: "busy")
                    }
                    return activePackage
                }
                var activePackage = ActivePackage.open(packagePath: packagePath, self.ctx)
                activePackage.isBusy = true
                self._activePackages[packagePath] = activePackage
                return activePackage
            }
        }
    }

    func markFree(activePackagePath packagePath: AbsolutePath) {
        self.activePackageLock.withLock {
            self._activePackages[packagePath]?.isBusy = false
        }
    }

    func resolve(
        request: SPM_ResolveRequest,
        context: StreamingResponseCallContext<SPM_RawLogEvent>
    ) -> EventLoopFuture<GRPCStatus> {
        // We're expected to get properly formed absolute paths from the client.
        let packagePath = AbsolutePath(request.packagePath)
        let activePackage = getActivePackage(packagePath)

        let result = activePackage.map {
            PackageOperation(activePackage: $0, op: .resolve(context))
        }.flatMap { operation in
            self.ctx.group.next().flatMapBlocking(on: .global(qos: .userInteractive)) {
                operation.perform()
                self.markFree(activePackagePath: packagePath)
            }
        }.map {
            GRPCStatus(code: .ok, message: nil)
        }.flatMapErrorThrowing { error in
            // Propagate any error we encountered to the client.
            throw GRPCStatus(code: .unknown, message: "\(error)")
        }

        return result
    }

    func build(
        request: SPM_BuildRequest,
        context: StreamingResponseCallContext<SPM_RawLogEvent>
    ) -> EventLoopFuture<GRPCStatus> {
        ctx.group.next().makeFailedFuture(StringError("unimplemented iok \(request)")).flatMapErrorThrowing { error in
            // Propagate any error we encountered to the client.
            throw GRPCStatus(code: .unknown, message: "\(error)")
        }
    }
}
