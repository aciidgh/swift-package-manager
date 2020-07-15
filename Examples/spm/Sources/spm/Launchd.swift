// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import ArgumentParser
import Foundation
import TSCBasic
import TSCUtility

#if canImport(launch)
import launch
#endif

struct Launchd: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Perform launchd operations on the swiftpm service",
        subcommands: [
            Load.self
        ]
    )

    struct Load: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Install and load the swiftpm service plist"
        )

        @OptionGroup()
        var options: Options

        func run() throws {
            let launchdHelper = LaunchdHelper(try options.launchdService())

            print("Installing plist at \(launchdHelper.plistPath)")
            try launchdHelper.installPlist()

            print("Loading plist \(launchdHelper.plistPath)")
            try? launchdHelper.stop()
            try launchdHelper.unload()
            try launchdHelper.load()
        }
    }
}

public struct LaunchdHelper {
    public struct Service {
        public var label: String
        public var programArguments: [String]
        public var workingDirectory: String
        public var standardOutPath: String
        public var standardErrorPath: String
        public var sockets: [String: [String: Any]]

        public init(
            label: String,
            programArguments: [String],
            workingDirectory: String,
            standardOutPath: String,
            standardErrorPath: String,
            sockets: [String: [String: Any]]
        ) {
            self.label = label
            self.programArguments = programArguments
            self.workingDirectory = workingDirectory
            self.standardOutPath = standardOutPath
            self.standardErrorPath = standardErrorPath
            self.sockets = sockets
        }
    }

    var service: Service
    let fs: FileSystem
    var homeDirectory: AbsolutePath { fs.homeDirectory }

    public init(_ service: Service, fs: FileSystem = localFileSystem) {
        self.service = service
        self.fs = fs
    }

    /// The path to the plist in the launch agents directory.
    var plistPath: AbsolutePath {
        let launchAgentsPath = homeDirectory.appending(components: "Library", "LaunchAgents")
        return launchAgentsPath.appending(component: service.label + ".plist")
    }

    /// Installs the plist for the service.
    /// 
    /// This method currently only installs in the user's launch agent directory
    /// (`~/Library/LaunchAgents`).
    func installPlist() throws {
        _ = service.toDict().write(toFile: plistPath.pathString, atomically: true)
    }

    /// Load the service.
    func load() throws {
        try Process.checkNonZeroExit(arguments: [
            "launchctl", "load", "-w", plistPath.pathString,
        ])
    }

    /// Unload the service.
    func unload() throws {
        try Process.checkNonZeroExit(arguments: [
            "launchctl", "unload", "-w", plistPath.pathString,
        ])
    }

    /// Start the service.
    func start() throws {
        try Process.checkNonZeroExit(arguments: [
            "launchctl", "start", service.label,
        ])
    }

    /// Stop the service if it's running.
    func stop() throws {
        try Process.checkNonZeroExit(arguments: [
            "launchctl", "stop", service.label,
        ])
    }

    static func getFDFromLaunchd(socketName: String) throws -> CInt {
        #if canImport(launch)
        let fds = UnsafeMutablePointer<UnsafeMutablePointer<CInt>>.allocate(capacity: 1)
        defer {
            fds.deallocate()
        }

        var count: Int = 0
        let ret = launch_activate_socket(socketName, fds, &count)

        // Check the return code.
        guard ret == 0 else {
            throw StringError("launch_activate_socket returned with a non-zero exit code \(ret)")
        }

        // launchd allows arbitary number of listeners but we only expect one in this example.
        guard count == 1 else {
            throw StringError("expected launch_activate_socket to return exactly one file descriptor")
        }

        // This is safe because we already checked that we have exactly one result.
        let fd = fds.pointee.pointee

        defer {
            free(&fds.pointee.pointee)
        }

        return fd
        #else
        throw StringError("unable to get FD from launchd on non-Darwin platforms")
        #endif
    }
}

extension LaunchdHelper.Service {
    func toDict() -> NSDictionary {
        var dict: [String: Any] = [:]

        dict["Label"] = self.label
        dict["ProgramArguments"] = self.programArguments
        dict["WorkingDirectory"] = self.workingDirectory
        dict["Sockets"] = self.sockets
        dict["StandardOutPath"] = self.standardOutPath
        dict["StandardErrorPath"] = self.standardErrorPath

        return NSDictionary(dictionary: dict)
    }
}
