/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import TSCBasic
import Workspace

struct WorkspaceGenerator {
    let workspace: Workspace
    let root: PackageGraphRootInput

    init(
        root: PackageGraphRootInput,
        workspace: Workspace
    ) {
        self.workspace = workspace
        self.root = root
    }

    func generate() throws {
        let stream = BufferedOutputByteStream()

        stream <<< """
            <?xml version="1.0" encoding="UTF-8"?>
            <Workspace
               version = "1.0">

            """

        for package in root.packages {
            stream <<< """
                <FileRef
                   location = "group:\(package.pathString)">
                </FileRef>

                """
        }

        for dependency in workspace.state.dependencies {
            let dependencyPath = workspace.path(for: dependency)
            stream <<< """
                <FileRef
                   location = "group:\(dependencyPath.pathString)">
                </FileRef>

                """
        }

        stream <<< "</Workspace>\n"

        let rootPackageBasename = workspace.dataPath.parentDirectory.basename
        let wsPath = workspace.checkoutsPath.appending(
            components: rootPackageBasename + "-ws.xcworkspace", "contents.xcworkspacedata"
        )
        try localFileSystem.writeIfChanged(path: wsPath, bytes: stream.bytes)
    }
}
