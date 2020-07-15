// This source file is part of the Swift.org open source project
// 
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// 
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import TSCBasic
import TSCUtility
import Workspace

struct ActivePackage {
    /// The shared context.
    let ctx: Context

    /// The package path on disk.
    let path: AbsolutePath

    /// Reference to the workspace for the package.
    ///
    /// Technically, it's cheap to just re-create the workspace object on-demand
    /// but it does support being long-lived.
    let workspace: Workspace

    /// If the package is busy performing an operation.
    ///
    /// Only one package operation can be performed at a time.
    var isBusy: Bool = false

    public init(
        path: AbsolutePath,
        workspace: Workspace,
        _ ctx: Context
    ) {
        self.path = path
        self.ctx = ctx
        self.workspace = workspace
    }

    static func open(
        packagePath: AbsolutePath,
        _ ctx: Context
    ) -> ActivePackage {
        let workspace = Workspace.createWorkspace(forPackagePath: packagePath, ctx)
        let activePackage = ActivePackage(path: packagePath, workspace: workspace, ctx)
        return activePackage
    }

    var root: PackageGraphRootInput {
        PackageGraphRootInput(packages: [path])
    }
}
