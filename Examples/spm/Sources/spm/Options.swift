// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import ArgumentParser
import Foundation
import GRPC
import Logging
import NIO
import TSCBasic

struct Options: ParsableArguments {
    @Option()
    var packagePath: String?

    @Option()
    var serviceURL: String?

    static var fs: FileSystem = localFileSystem
}

extension Options {

    /// The log label for swiftpm.
    public static let logLabel = "com.swift.swiftpm"

    var fs: FileSystem { Self.fs }

    public static let group = MultiThreadedEventLoopGroup(numberOfThreads: ProcessInfo.processInfo.activeProcessorCount)
    public var group: MultiThreadedEventLoopGroup { Self.group }

    /// Create the logger object for swiftpm.
    func createLogger() -> Logger {
        return Logger(label: Options.logLabel)
    }

    /// The path to the current binary.
    func selfBinaryPath(
        cwd: AbsolutePath? = localFileSystem.currentWorkingDirectory
    ) throws -> AbsolutePath {
        guard let cwd = cwd else {
            return try AbsolutePath(validating: CommandLine.arguments[0])
        }
        return AbsolutePath(CommandLine.arguments[0], relativeTo: cwd)
    }

    /// The path to the unix sock file.
    var sockPath: AbsolutePath {
        swiftpmdWorkingDir().appending(component: "swiftpmd.sock")
    }

    /// Path to the working directory for the service.
    func swiftpmdWorkingDir() -> AbsolutePath {
        return Options.fs.homeDirectory.appending(components: ".swiftpm", "service")
    }

    func cwd() throws -> AbsolutePath {
        if let cwd = Options.fs.currentWorkingDirectory {
            return cwd
        }
        throw StringError("unable to determine the current working directory")
    }

    func getServiceTarget() throws -> ConnectionTarget {
        if let serviceURL = serviceURL, let url = URL(string: serviceURL) {
            switch url.scheme {
            case "http":
                guard let host = url.host, let port = url.port else {
                    throw StringError("expected port and host in the service url \(serviceURL)")
                }
                return .hostAndPort(host, port)
            case "unix":
                return .unixDomainSocket(url.path)
            default:
                throw StringError("expected scheme in the service url \(serviceURL)")
            }
        }

        #if os(macOS)
        return .unixDomainSocket(sockPath.pathString)
        #else
        return .hostAndPort("127.0.0.1", 7777)
        #endif
    }

    func getPackagePath() throws -> AbsolutePath {
        let cwd = try self.cwd()
        if let packagePath = packagePath {
            return AbsolutePath(packagePath, relativeTo: cwd)
        }
        return cwd
    }

    /// Create the launchd service object for swiftpm service.
    func launchdService() throws -> LaunchdHelper.Service {
        let workingDir = self.swiftpmdWorkingDir()
        try fs.createDirectory(workingDir, recursive: true)

        let executable = try self.selfBinaryPath()
        let sockPath = self.sockPath
        return .swiftpm(
            executable: executable,
            sockPath: sockPath,
            workingDir: workingDir
        )
    }
}

extension LaunchdHelper.Service {
    static func swiftpm(
        executable: AbsolutePath,
        sockPath: AbsolutePath,
        workingDir: AbsolutePath
    ) -> LaunchdHelper.Service {
        let service = LaunchdHelper.Service(
            label: "org.swift.swiftpmd",
            programArguments: [
                executable.pathString,
                "service",
                "start",
                "--launchd",
                "--stop-on-bin-mod",
            ],
            workingDirectory: workingDir.pathString,
            standardOutPath: workingDir.appending(component: "stdout.txt").pathString,
            standardErrorPath: workingDir.appending(component: "stderr.txt").pathString,
            sockets: [
                "Listeners": [
                    "SockPathName": sockPath.pathString
                ]
            ]
        )

        return service
    }
}
