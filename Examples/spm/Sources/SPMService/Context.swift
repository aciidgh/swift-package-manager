// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Logging
import NIO
import PackageGraph
import PackageLoading
import PackageModel
import SourceControl
import TSCBasic
import TSCUtility
import Workspace

/// The shared context in this module. These must remain internal to this module.
extension Context {
    var group: EventLoopGroup {
        get {
            self.get()
        }
        set {
            self.set(newValue)
        }
    }

    var fs: FileSystem {
        get {
            self.get()
        }
        set {
            self.set(newValue)
        }
    }

    var log: Logger {
        get {
            self.get()
        }
        set {
            self.set(newValue)
        }
    }

    var processSet: ProcessSet {
        get {
            self.get()
        }
        set {
            self.set(newValue)
        }
    }

    var core: Core {
        get {
            self.get()
        }
        set {
            self.set(newValue)
        }
    }
}

/// Shared set of objects that are configured during service startup.
struct Core {
    let sharedCacheDirectory: AbsolutePath
    let repositoryProvider: GitRepositoryProvider
    let destination: Destination
    let toolchain: UserToolchain
    let repositoryManager: RepositoryManager
    let manifestLoader: ManifestLoader

    static func create(_ ctx: Context) throws -> Core {
        // FIXME: This should be customizable.
        let sharedCacheDirectory = ctx.fs.homeDirectory.appending(component: ".swiftpm")

        let provider = GitRepositoryProvider(processSet: ctx.processSet)
        let destination = try Destination.hostDestination(swiftCompiler.parentDirectory)
        let toolchain = try UserToolchain(destination: destination)

        let repositoriesPath = sharedCacheDirectory.appending(component: "repositories")
        let repositoryManager = RepositoryManager(
            path: repositoriesPath,
            provider: provider,
            delegate: nil,
            fileSystem: ctx.fs)

        let manifestLoader = ManifestLoader(
            manifestResources: toolchain.manifestResources,
            isManifestSandboxEnabled: false,
            cacheDir: sharedCacheDirectory.appending(component: "ManifestCache")
        )

        return Core(
            sharedCacheDirectory: sharedCacheDirectory,
            repositoryProvider: provider,
            destination: destination,
            toolchain: toolchain,
            repositoryManager: repositoryManager,
            manifestLoader: manifestLoader
        )
    }
}
