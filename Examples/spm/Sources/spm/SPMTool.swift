// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import ArgumentParser
import Logging
import SPMService
import SPMServiceClient
import SPMServiceProtocol

struct SPMTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        subcommands: [
            Service.self,
            Build.self,
            Resolve.self,
        ] + platformSubcommands
    )

    #if canImport(Darwin)
    static var platformSubcommands: [ParsableCommand.Type] = [Launchd.self]
    #else
    static var platformSubcommands: [ParsableCommand.Type] = []
    #endif
}
