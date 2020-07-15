// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import ArgumentParser
import Foundation
import Logging
import SPMService
import SPMServiceClient
import SPMServiceProtocol
import TSCBasic
import TSCLibc
import TSCUtility

struct Service: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Perform operations on the swiftpm service",
        subcommands: [
            Start.self
        ]
    )

    struct Start: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Start the service"
        )

        @OptionGroup()
        var options: Options

        @Flag()
        var launchd: Bool = false

        @Flag(help: "Stop the service if the service binary is modified (only macOS)")
        var stopOnBinMod: Bool = false

        func run() throws {
            let log = options.createLogger()
            let service = try SPMService.Service(
                group: options.group,
                fs: Options.fs,
                log: log,
                stopServiceOnBinMod: stopOnBinMod
            )

            if launchd {
                let fd = try LaunchdHelper.getFDFromLaunchd(socketName: "Listeners")
                _ = try service.start(withBoundSocket: fd).wait()
                log.info("SwiftPM service started via launchd \(fd)")
                try service.waitForClose()
            } else {
                let port = try service.start(options.getServiceTarget()).wait()
                log.info("SwiftPM service started on port \(port)")
                try service.waitForClose()
            }
        }
    }
}
