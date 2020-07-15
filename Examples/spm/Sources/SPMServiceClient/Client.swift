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
import SPMServiceProtocol
import SwiftProtobuf
import TSCBasic
import TSCUtility

public struct ClientProvider {
    /// The event loop group.
    public let group: EventLoopGroup

    /// Create a new provider.
    public init(
        _ group: EventLoopGroup
    ) {
        self.group = group
    }

    public func open(_ target: ConnectionTarget) -> EventLoopFuture<SPM_ServiceClient> {
        let config = ClientConnection.Configuration(
            target: target,
            eventLoopGroup: group
        )
        let connection = ClientConnection(configuration: config)

        let client = SPM_ServiceClient(channel: connection)
        return group.next().makeSucceededFuture(client)
    }
}
