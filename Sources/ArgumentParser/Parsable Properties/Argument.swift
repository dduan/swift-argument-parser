//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

/// A wrapper that represents a positional command-line argument.
///
/// Positional arguments are specified without a label and must appear in
/// the command-line arguments in declaration order.
///
///     struct Options: ParsableArguments {
///         @Argument var name: String
///         @Argument var greeting: String?
///     }
///
/// This program has two positional arguments; `name` is required, while
/// `greeting` is optional. It can be evoked as either `command Joseph Hello`
/// or simply `command Joseph`.
@propertyWrapper
public struct Argument<Value>:
  Decodable, ParsedWrapper
{
  internal var _parsedValue: Parsed<Value>
  
  internal init(_parsedValue: Parsed<Value>) {
    self._parsedValue = _parsedValue
  }
  
  public init(from decoder: Decoder) throws {
    try self.init(_decoder: decoder)
  }
  
  /// The value presented by this property wrapper.
  public var wrappedValue: Value {
    get {
      switch _parsedValue {
      case .value(let v):
        return v
      case .definition:
        fatalError("Trying to read value from definition.")
      }
    }
    set {
      _parsedValue = .value(newValue)
    }
  }
}

extension Argument: CustomStringConvertible {
  public var description: String {
    switch _parsedValue {
    case .value(let v):
      return String(describing: v)
    case .definition:
      return "Argument(*definition*)"
    }
  }
}

extension Argument: DecodableParsedWrapper where Value: Decodable {}

// MARK: Property Wrapper Initializers

extension Argument where Value: ExpressibleByArgument {
  /// Creates a property that reads its value from an argument.
  ///
  /// If the property has an `Optional` type, the argument is optional and
  /// defaults to `nil`.
  ///
  /// - Parameter help: Information about how to use this argument.
  public init(
    help: ArgumentHelp? = nil
  ) {
    self.init(_parsedValue: .init { key in
      ArgumentSet(key: key, kind: .positional, parseType: Value.self, name: NameSpecification.long, default: nil, help: help)
      })
  }
}

extension Argument {
  /// Creates a property that reads its value from an argument, parsing with
  /// the given closure.
  ///
  /// - Parameters:
  ///   - help: Information about how to use this argument.
  ///   - transform: A closure that converts a string into this property's
  ///     type or throws an error.
  public init(
    help: ArgumentHelp? = nil,
    transform: @escaping (String) throws -> Value
  ) {
    self.init(_parsedValue: .init { key in
      let help = ArgumentDefinition.Help(options: [], help: help, key: key)
      let arg = ArgumentDefinition(kind: .positional, help: help, update: .unary({
        (origin, _, valueString, parsedValues) in
        parsedValues.set(try transform(valueString), forKey: key, inputOrigin: origin)
      }))
      return ArgumentSet(alternatives: [arg])
      })
  }
  
  /// Creates a property that reads an array from zero or more arguments.
  ///
  /// The property has an empty array as its default value.
  ///
  /// - Parameter help: Information about how to use this argument.
  public init<Element>(
    help: ArgumentHelp? = nil
  )
    where Element: ExpressibleByArgument, Value == Array<Element>
  {
    self.init(_parsedValue: .init { key in
      let help = ArgumentDefinition.Help(options: [.isOptional, .isRepeating], help: help, key: key)
      let arg = ArgumentDefinition(kind: .positional, help: help, update: .appendToArray(forType: Element.self, key: key), initial: { origin, values in
        values.set([], forKey: key, inputOrigin: origin)
      })
      return ArgumentSet(alternatives: [arg])
      })
  }
  
  /// Creates a property that reads an array from zero or more arguments,
  /// parsing each element with the given closure.
  ///
  /// The property has an empty array as its default value.
  ///
  /// - Parameters:
  ///   - help: Information about how to use this argument.
  ///   - transform: A closure that converts a string into this property's
  ///     element type or throws an error.
  public init<Element>(
    help: ArgumentHelp? = nil,
    transform: @escaping (String) throws -> Element
  )
    where Value == Array<Element>
  {
    self.init(_parsedValue: .init { key in
      let help = ArgumentDefinition.Help(options: [.isOptional, .isRepeating], help: help, key: key)
      let arg = ArgumentDefinition(kind: .positional, help: help, update: .unary({
        (origin, name, valueString, parsedValues) in
        let element = try transform(valueString)
        parsedValues.update(forKey: key, inputOrigin: origin, initial: [Element](), closure: {
          $0.append(element)
        })
      }),
                                   initial: { origin, values in
                                    values.set([], forKey: key, inputOrigin: origin)
      })
      return ArgumentSet(alternatives: [arg])
      })
  }
}
