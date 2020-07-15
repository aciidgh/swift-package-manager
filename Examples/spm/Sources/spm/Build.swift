// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import ArgumentParser
import GRPC
import Logging
import SPMService
import SPMServiceClient
import SPMServiceProtocol
import TSCUtility

struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Perform the build operation"
    )

    @OptionGroup()
    var options: Options

    func run() throws {
        let log = options.createLogger()

        let provider = ClientProvider(options.group)
        let client = try provider.open(options.getServiceTarget()).wait()

        let request = try SPM_BuildRequest.with {
            $0.packagePath = try options.getPackagePath().pathString
        }

        let stream = client.build(request) { event in
            print(event)
        }

        let status = try stream.status.wait()
        print(status)
    }
}
