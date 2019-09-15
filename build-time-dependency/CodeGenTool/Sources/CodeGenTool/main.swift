import Foundation

let outputPath = CommandLine.arguments[1]
let inputFile = CommandLine.arguments[2]

let version = try String(contentsOfFile: inputFile)
let contents = "public let codegenToolVersion = \(version)"
try contents.write(toFile: outputPath, atomically: true, encoding: .utf8)
