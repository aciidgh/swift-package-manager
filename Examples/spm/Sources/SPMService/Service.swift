// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation
import GRPC
import Logging
import NIO
import SPMServiceProtocol
import SwiftProtobuf
import TSCBasic
import TSCUtility

public final class Service {
    /// The grpc server.
    private var server: EventLoopFuture<GRPC.Server>?

    /// The server channel which is used when we use a bound socket.
    private var channel: EventLoopFuture<Channel>?

    let ctx: Context

    public init(
        group: EventLoopGroup,
        fs: FileSystem = localFileSystem,
        log: Logger,
        stopServiceOnBinMod: Bool = false
    ) throws {
        var ctx = Context()
        ctx.group = group
        ctx.fs = fs
        ctx.log = log
        ctx.processSet = ProcessSet()
        ctx.core = try Core.create(ctx)
        self.ctx = ctx

        if stopServiceOnBinMod {
            try self.stopServiceOnBinMod()
        }
    }

    public func stop() throws {
        ctx.log.trace("stopping swiftpm service...")
        // Terminate any in-flight processes.
        ctx.processSet.terminate()
        if let server = server {
            _ = server.flatMap { $0.close() }
        } else if let channel = channel {
            _ = channel.flatMap { $0.close() }
        }

        try waitForClose()
    }

    public func waitForClose() throws {
        if let server = server {
            try server.flatMap { $0.onClose }.wait()
        } else if let channel = channel {
            try channel.flatMap { $0.closeFuture }.wait()
        }
    }

    /// Start the server with a bound socket.
    public func start(withBoundSocket fd: CInt) -> EventLoopFuture<Bool> {
        ctx.log.trace("starting swiftpm service via bound socket \(fd)...")

        // FIXME: The connection target here doesn't really matter here but we
        // have to supply something as swift-grpc doesn't have a facility for
        // configuring a bound socket.
        let config = makeConfig(.hostAndPort("127.0.0.1", 0))

        let bootstrap = Server.makeBootstrap(configuration: config) as! ServerBootstrap
        let channel = bootstrap.withBoundSocket(descriptor: fd)
        self.channel = channel
        return channel.map { $0.isActive }
    }

    /// Start the service with the specified connection target.
    public func start(_ target: ConnectionTarget) -> EventLoopFuture<Int?> {
        ctx.log.trace("starting swiftpm service...")
        let config = makeConfig(target)

        let server = Server.start(configuration: config)
        self.server = server

        return server.map {
            $0.channel.localAddress
        }.map {
            $0!.port
        }
    }

    private func makeConfig(_ target: ConnectionTarget) -> Server.Configuration {
        Server.Configuration(
            target: target,
            eventLoopGroup: ctx.group,
            serviceProviders: [
                ServiceProvider(ctx)
            ]
        )
    }

    #if os(macOS)
    var _fsEventStream: FSEventStream?
    #endif

    /// Stop the service if the service binary is modified.
    ///
    /// Useful for development.
    private func stopServiceOnBinMod() throws {
        #if os(macOS)
        let selfBinaryPath = try self.selfBinaryPath()
        let delegate = EventStreamDelegate { _ in
            self.ctx.log.info("Service executable modified, stopping service...")
            try? self.stop()
        }
        let fsEventStream = FSEventStream(
            paths: [selfBinaryPath],
            latency: 1,
            delegate: delegate,
            flags: FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )
        self._fsEventStream = fsEventStream
        try fsEventStream.start()
        #endif
    }

    func selfBinaryPath() throws -> AbsolutePath {
        guard let cwd = ctx.fs.currentWorkingDirectory else {
            return try AbsolutePath(validating: CommandLine.arguments[0])
        }
        return AbsolutePath(CommandLine.arguments[0], relativeTo: cwd)
    }
}

#if os(macOS)
struct EventStreamDelegate: FSEventStreamDelegate {
    let block: FSWatch.EventReceivedBlock

    func pathsDidReceiveEvent(_ paths: [AbsolutePath]) {
        block(paths)
    }
}
#endif
