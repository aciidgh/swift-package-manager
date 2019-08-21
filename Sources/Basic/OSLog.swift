/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

#if canImport(os)
import os.log
#endif

/// A custom log object that can be passed to logging functions in order to send
/// messages to the logging system.
///
/// This is a thin wrapper for Darwin's log APIs to make them usable without
/// platform and availability checks.
public final class OSLog {

    private let storage: Any?

  #if canImport(os)
    @available(macOS 10.12, *)
    @usableFromInline var log: os.OSLog {
        return storage as! os.OSLog
    }
  #endif

    private init(_ storage: Any? = nil) {
        self.storage = storage
    }

    /// Creates a custom log object.
    public convenience init(subsystem: String, category: String) {
      #if canImport(os)
        if #available(macOS 10.12, *) {
            self.init(os.OSLog(subsystem: subsystem, category: category))
        } else {
            self.init()
        }
      #else
        self.init()
      #endif
    }

    /// The shared default log.
    public static let disabled: OSLog = {
      #if canImport(os)
        if #available(macOS 10.12, *) {
            return OSLog(os.OSLog.disabled)
        } else {
            return OSLog()
        }
      #else
        return OSLog()
      #endif
    }()

    /// The shared default log.
    public static let `default`: OSLog = {
      #if canImport(os)
        if #available(macOS 10.12, *) {
            return OSLog(os.OSLog.default)
        } else {
            return OSLog()
        }
      #else
        return OSLog()
      #endif
    }()
}

/// Logging levels supported by the system.
public struct OSLogType {

    private let storage: Any?

    #if canImport(os)
      @available(macOS 10.12, *)
      @usableFromInline var `type`: os.OSLogType {
          return storage as! os.OSLogType
      }
    #endif

    private init(_ storage: Any? = nil) {
        self.storage = storage
    }

    /// The default log level.
    public static var `default`: OSLogType {
        #if canImport(os)
          if #available(OSX 10.14, *) {
              return self.init(os.OSLogType.default)
          } else {
              return self.init()
          }
        #else
          return self.init()
        #endif
    }

    /// The info log level.
    public static var info: OSLogType {
        #if canImport(os)
          if #available(OSX 10.14, *) {
              return self.init(os.OSLogType.info)
          } else {
              return self.init()
          }
        #else
          return self.init()
        #endif
    }

    /// The debug log level.
    public static var debug: OSLogType {
        #if canImport(os)
          if #available(OSX 10.14, *) {
              return self.init(os.OSLogType.info)
          } else {
              return self.init()
          }
        #else
          return self.init()
        #endif
    }
}

/// Sends a message to the logging system.
///
/// This is a thin wrapper for Darwin's log APIs to make them usable without
/// platform and availability checks.
@inlinable public func os_log(
    _ type: OSLogType = .default,
    log: OSLog = .default,
    _ message: StaticString,
    _ args: CVarArg...
) {
  #if canImport(os)
    if #available(OSX 10.14, *) {
        switch args.count {
        case 1:
            os.os_log(type.type, log: log.log, message, args[0])
        case 2:
            os.os_log(type.type, log: log.log, message, args[0], args[1])
        case 3:
            os.os_log(type.type, log: log.log, message, args[0], args[1], args[2])
        case 4:
            os.os_log(type.type, log: log.log, message, args[0], args[1], args[2], args[3])
        case 5:
            os.os_log(type.type, log: log.log, message, args[0], args[1], args[2], args[3], args[4])
        default:
            assertionFailure("Unsupported number of arguments")
        }
    }
  #endif
}
