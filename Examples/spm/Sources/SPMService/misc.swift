// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Dispatch
import NIO
import SourceControl
import TSCBasic
import Workspace

extension Workspace {
    static func createWorkspace(
        forPackagePath packagePath: AbsolutePath,
        _ ctx: Context
    ) -> Workspace {
        let buildPath = packagePath.appending(component: ".build")
        let editablesPath = packagePath.appending(component: "Packages")
        let pinsFile = packagePath.appending(component: "Package.resolved")
        let configPath = packagePath.appending(components: ".swiftpm", "config")
        let config = SwiftPMConfig(path: configPath)
        let core = ctx.core

        let workspace = Workspace(
            dataPath: buildPath,
            editablesPath: editablesPath,
            pinsFile: pinsFile,
            manifestLoader: core.manifestLoader,
            repositoryManager: core.repositoryManager,
            config: config,
            repositoryProvider: core.repositoryProvider,
            isResolverPrefetchingEnabled: true,
            skipUpdate: false,
            enableResolverTrace: true
        )
        return workspace
    }
}

let swiftCompiler: AbsolutePath = {
    let path = try! Process.checkNonZeroExit(
        args: "xcrun", "--sdk", "macosx", "-f", "swiftc"
    ).spm_chomp()
    return AbsolutePath(path)
}()

let sdkRoot: AbsolutePath = {
    let string = try! Process.checkNonZeroExit(
        arguments: [
            "xcrun", "--sdk", "macosx", "--show-sdk-path",
        ]
    ).spm_chomp()
    return AbsolutePath(string)
}()

extension EventLoop {
    /// Execute the given work on the given queue and notify the future on completion.
    public func flatMapBlocking<T>(
        on queue: DispatchQueue,
        _ work: @escaping () throws -> T
    ) -> EventLoopFuture<T> {
        let promise = self.makePromise(of: T.self)
        queue.async {
            do {
                let result = try work()
                promise.succeed(result)
            } catch {
                promise.fail(error)
            }
        }
        return promise.futureResult
    }
}
