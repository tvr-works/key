import Foundation
import Testing

@testable import KeyCore

struct RecoveryRegistrationCLITests {
  private static let recipient = Base64URL.encode(Data(repeating: 7, count: 32))
  private static let vault = "018f4d38-7d5a-7b20-b0f1-97d6e96c84d1"

  @Test(arguments: [false, true])
  func confirmationExplainsOnlyTheSelectedStepBeforeConsent(finish: Bool) {
    let io = MemoryIO(stdinIsTTY: true, lineInput: "cancel")
    io.onReadLine = { [unowned io] in
      #expect(io.stderr.contains("Older apps will lose access") == !finish)
      #expect(io.stderr.contains("does not register a key") == !finish)
      #expect(io.stderr.contains("PIN only in macOS") == finish)
    }
    let transport = MemoryTransport { _ in
      Issue.record("Declined confirmation must not dispatch")
      return .success()
    }
    let args = finish
      ? ["recovery", "register", "finish", "--token", "fixture-token", "--recipient", Self.recipient]
      : ["recovery", "adopt"]
    #expect(KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard()).run(arguments: args) != EXIT_SUCCESS)
    #expect(transport.requests.isEmpty)
  }

  @Test(arguments: [["recovery", "register", "status"], ["recovery", "pending"]])
  func readOnlyFailureDoesNotSuggestSetupOrResume(arguments: [String]) {
    let io = MemoryIO(stdinIsTTY: false)
    let transport = MemoryTransport { _ in .failure("Fixture: approval cancelled.") }
    #expect(KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard()).run(arguments: arguments) != EXIT_SUCCESS)
    #expect(io.stderr == "Fixture: approval cancelled.\n")
    #expect(transport.requests.count == 1)
  }

  @Test(arguments: [false, true], [false, true])
  func completionDistinguishesFormatUpdateFromRegistration(finish: Bool, pending: Bool) {
    let io = MemoryIO(stdinIsTTY: true, lineInput: finish ? "REGISTER" : "ADOPT")
    let transport = MemoryTransport { _ in
      .init(exitCode: EXIT_SUCCESS, value: nil, errorMessage: nil,
        recoveryRegistration: .completed(vaultID: Self.vault,
          manifestDigest: Base64URL.encode(Data(repeating: 8, count: 32)), cleanupPending: pending))
    }
    let args = finish
      ? ["recovery", "register", "finish", "--token", "fixture-token", "--recipient", Self.recipient]
      : ["recovery", "adopt"]
    #expect(KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard()).run(arguments: args) == EXIT_SUCCESS)
    #expect(io.stdout.contains("Recovery key registered.") == finish)
    #expect(io.stdout.contains("No recovery key added.") == !finish)
    #expect(io.stderr.contains("One step remains") == pending)
    #expect(io.stderr.contains("recovery register finish") == (pending && finish))
    #expect(io.stderr.contains("adopt --resume") == (pending && !finish))
    #expect(transport.requests.count == 1)
  }

  @Test(arguments: [false, true])
  func registrationStatusProvidesCompleteIDsWithoutChangingJSON(json: Bool) throws {
    let result = KeyRecoveryRegistrationResult.status(state: .registered, vaultID: Self.vault,
      recipients: [Self.recipient], activationCommitted: false)
    let io = MemoryIO(stdinIsTTY: false)
    let transport = MemoryTransport { _ in
      .init(exitCode: EXIT_SUCCESS, value: nil, errorMessage: nil, recoveryRegistration: result)
    }
    let args = ["recovery", "register", "status"] + (json ? ["--json"] : [])
    #expect(KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard()).run(arguments: args) == EXIT_SUCCESS)
    if json {
      #expect(try JSONDecoder().decode(KeyRecoveryRegistrationResult.self, from: Data(io.stdout.utf8)) == result)
    } else {
      #expect(io.stdout.contains("Recovery key ID: \(Self.recipient)"))
      #expect(io.stdout.contains("It does not test recovery or confirm that all files have arrived"))
    }
  }

  @Test(arguments: [false, true])
  func adoptionAbandonmentRequiresConfirmationAndExactReply(mismatched: Bool) throws {
    let operation = VaultTransactionOperationID().rawValue
    let args = ["recovery", "adopt", "--abandon", operation]
    let action = KeyRecoveryRegistrationRequest.abandonAdoption(operationID: operation)
    #expect(try CLIParser.parse(arguments: args) == .recoveryRegistration(action, exportPath: nil, json: false))
    #expect(throws: AppError.self) { try CLIParser.parse(arguments: args + ["--resume", operation]) }
    #expect(throws: AppError.self) { try CLIParser.parse(arguments: ["recovery", "adopt", "--abandon", "short"]) }
    let io = MemoryIO(stdinIsTTY: true, lineInput: "ABANDON", secureInput: "must-not-read")
    let transport = MemoryTransport { _ in
      .init(exitCode: EXIT_SUCCESS, value: nil, errorMessage: nil,
        recoveryRegistration: .adoptionAbandoned(vaultID: Self.vault,
          operationID: mismatched ? VaultTransactionOperationID().rawValue : operation))
    }
    let app = KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard())
    #expect(app.run(arguments: args) == (mismatched ? EXIT_FAILURE : EXIT_SUCCESS))
    #expect(transport.requests == [.recoveryRegistration(action)])
    #expect(!io.stdout.contains("must-not-read"))
    if !mismatched { #expect(io.stdout.contains("history and files preserved")) }
    else { #expect(io.stdout.isEmpty) }
    for interactive in [false, true] {
      let declined = MemoryTransport { _ in Issue.record("No request without ABANDON confirmation"); return .success() }
      let declinedIO = MemoryIO(stdinIsTTY: interactive, lineInput: "ADOPT")
      #expect(KeyCLIApplication(transport: declined, io: declinedIO, clipboard: MemoryClipboard()).run(arguments: args) != EXIT_SUCCESS)
      #expect(declined.requests.isEmpty)
    }
  }

  @Test(arguments: [false, true])
  func registrationAbandonmentRequiresConfirmationAndExactReply(mismatched: Bool) throws {
    let operation = VaultTransactionOperationID().rawValue
    let args = ["recovery", "register", "abandon", operation]
    let action = KeyRecoveryRegistrationRequest.abandonRegistration(operationID: operation)
    #expect(try CLIParser.parse(arguments: args) == .recoveryRegistration(action, exportPath: nil, json: false))
    #expect(throws: AppError.self) { try CLIParser.parse(arguments: args + ["--resume", operation]) }
    #expect(throws: AppError.self) { try CLIParser.parse(arguments: ["recovery", "register", "abandon", "short"]) }
    let io = MemoryIO(stdinIsTTY: true, lineInput: "ABANDON", secureInput: "must-not-read")
    let transport = MemoryTransport { _ in
      .init(exitCode: EXIT_SUCCESS, value: nil, errorMessage: nil,
        recoveryRegistration: .registrationAbandoned(vaultID: Self.vault,
          operationID: mismatched ? VaultTransactionOperationID().rawValue : operation))
    }
    let app = KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard())
    #expect(app.run(arguments: args) == (mismatched ? EXIT_FAILURE : EXIT_SUCCESS))
    #expect(transport.requests == [.recoveryRegistration(action)])
    #expect(!io.stdout.contains("must-not-read"))
    if !mismatched { #expect(io.stdout.contains("history and files preserved")) }
    else { #expect(io.stdout.isEmpty) }
    for interactive in [false, true] {
      let declined = MemoryTransport { _ in Issue.record("No request without ABANDON confirmation"); return .success() }
      let declinedIO = MemoryIO(stdinIsTTY: interactive, lineInput: "ADOPT")
      #expect(KeyCLIApplication(transport: declined, io: declinedIO, clipboard: MemoryClipboard()).run(arguments: args) != EXIT_SUCCESS)
      #expect(declined.requests.isEmpty)
    }
  }

  @Test(arguments: [false, true])
  func parserRequiresExplicitCredentialAndNewExportPath(resume: Bool) throws {
    let input = arguments(resume: resume)
    let action: KeyRecoveryRegistrationRequest =
      resume
      ? .resumeExport(tokenID: "token", recipientID: Self.recipient)
      : .prepare(tokenID: "token", recipientID: Self.recipient)
    #expect(
      try CLIParser.parse(arguments: input)
        == .recoveryRegistration(action, exportPath: "anchor.json", json: false))
    for option in ["--token", "--recipient", "--export-anchor"] {
      var missing = input
      let offset = try #require(missing.firstIndex(of: option))
      let value = missing[offset + 1]
      missing.removeSubrange(offset ... (offset + 1))
      #expect(throws: AppError.self) { try CLIParser.parse(arguments: missing) }
      #expect(throws: AppError.self) { try CLIParser.parse(arguments: input + [option, value]) }
    }
    for option in ["--pin", "--puk", "--management-key", "--force", "--yes"] {
      #expect(throws: AppError.self) { try CLIParser.parse(arguments: input + [option, "no"]) }
    }
  }

  @Test(arguments: [false, true])
  func noInteractiveConsentMeansNoPreparationRequest(noninteractive: Bool) {
    let io = MemoryIO(stdinIsTTY: !noninteractive, lineInput: "wrong")
    let transport = MemoryTransport { _ in
      Issue.record("Cancelled setup reached service")
      return .success()
    }
    let app = KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard())
    #expect(app.run(arguments: arguments()) != EXIT_SUCCESS)
    #expect(transport.requests.isEmpty && io.stdout.isEmpty)
  }

  @Test(arguments: 0 ..< 3)
  func exportWritesExactPublicBytesButNeverReplacesExistingFilesOrLinks(existing: Int) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let output = directory.appendingPathComponent("anchor.json")
    let target = directory.appendingPathComponent("other.json")
    let sentinel = Data("keep existing output".utf8)
    if existing == 1 { try sentinel.write(to: output) }
    if existing == 2 {
      try sentinel.write(to: target)
      try FileManager.default.createSymbolicLink(at: output, withDestinationURL: target)
    }
    let anchor = try V3RecoveryAnchor(
      floor: .init(vaultID: Self.vault, envelopeDigest: Data(repeating: 9, count: 32)),
      recipientID: .init(rawValue: Self.recipient), registrationID: UUID().uuidString.lowercased(),
      slot: .keyManagement)
    let io = MemoryIO(stdinIsTTY: true, lineInput: "PREPARE", secureInput: "must-not-read")
    let transport = MemoryTransport { _ in
      .init(
        exitCode: EXIT_SUCCESS, value: nil, errorMessage: nil,
        recoveryRegistration: .export(
          operationID: VaultTransactionOperationID().rawValue, vaultID: Self.vault,
          recipientID: Self.recipient, anchor: Base64URL.encode(anchor.canonicalBytes)))
    }
    let app = KeyCLIApplication(
      transport: transport, io: io, clipboard: MemoryClipboard(), currentDirectory: { directory })
    #expect(app.run(arguments: arguments()) == (existing == 0 ? EXIT_SUCCESS : EXIT_FAILURE))
    #expect(transport.requests.count == 1)
    #expect(try Data(contentsOf: output) == (existing == 0 ? anchor.canonicalBytes : sentinel))
    #expect(!io.stdout.contains("must-not-read"))
    if existing != 0 { #expect(io.stderr.contains("same saved preparation")) }
  }

  @Test func mismatchedPayloadCannotCreateAnExportAndNeverRetries() {
    let io = MemoryIO(stdinIsTTY: true, lineInput: "PREPARE")
    let transport = MemoryTransport { _ in
      .init(
        exitCode: EXIT_SUCCESS, value: nil, errorMessage: nil,
        recoveryRegistration: .completed(
          vaultID: Self.vault, manifestDigest: "wrong", cleanupPending: false))
    }
    let app = KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard())
    #expect(app.run(arguments: arguments()) != EXIT_SUCCESS)
    #expect(transport.requests.count == 1 && io.stdout.isEmpty)
    #expect(io.stderr.contains("Could not confirm setup finished"))
  }

  @Test func statusHasNoCredentialInputAndAttentionIsNotSuccess() {
    let io = MemoryIO(
      stdinIsTTY: false, onReadLine: { Issue.record("Status must not collect approval") })
    let transport = MemoryTransport { _ in
      .init(
        exitCode: EXIT_SUCCESS, value: nil, errorMessage: nil,
        recoveryRegistration: .status(
          state: .attentionRequired, vaultID: Self.vault, recipients: [], activationCommitted: false
        ))
    }
    #expect(
      KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard()).run(arguments: [
        "recovery", "register", "status", "--json",
      ]) == EXIT_FAILURE)
    #expect(transport.requests == [.recoveryRegistration(.status)])
    #expect(io.stdout.contains("attentionRequired"))
  }

  @Test(arguments: [false, true])
  func rotationRequiresConsentAndTransportsNoTokenSelector(resume: Bool) throws {
    let operation = VaultTransactionOperationID().rawValue
    let action: KeyRecoveryRotationRequest = resume ? .resume(operationID: operation) : .rotate
    let input = ["recovery", "rotate"] + (resume ? ["--resume", operation] : [])
    #expect(try CLIParser.parse(arguments: input) == .recoveryRotation(action))
    let io = MemoryIO(stdinIsTTY: true, lineInput: "ROTATE", secureInput: "must-not-read")
    let transport = MemoryTransport { _ in
      .init(
        exitCode: EXIT_SUCCESS, value: nil, errorMessage: nil,
        recoveryRotation: .completed(
          vaultID: Self.vault,
          manifestDigest: Base64URL.encode(Data(repeating: 8, count: 32)), cleanupPending: false))
    }
    #expect(
      KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard()).run(
        arguments: input) == EXIT_SUCCESS)
    #expect(transport.requests == [.recoveryRotation(action)])
    #expect(io.stdout.contains("encryption key was changed") && !io.stdout.contains("must-not-read"))
    let cancelled = MemoryTransport { _ in
      Issue.record("Cancelled rotation dispatched")
      return .success()
    }
    #expect(
      KeyCLIApplication(
        transport: cancelled,
        io: MemoryIO(stdinIsTTY: true, lineInput: "wrong"), clipboard: MemoryClipboard()
      ).run(arguments: input) != EXIT_SUCCESS)
    #expect(cancelled.requests.isEmpty)
    #expect(throws: AppError.self) { try CLIParser.parse(arguments: input + ["--token", "key"]) }
    #expect(throws: AppError.self) {
      try CLIParser.parse(arguments: ["recovery", "rotate", "--resume", "prefix"])
    }
  }

  @Test func pendingSelectorsNeedNoApprovalAndReportOriginalOperationIDs() throws {
    #expect(
      try CLIParser.parse(arguments: ["recovery", "pending", "--json"])
        == .recoveryRegistration(.pending, exportPath: nil, json: true))
    let operation = VaultTransactionOperationID().rawValue
    let transport = MemoryTransport { _ in
      .init(
        exitCode: EXIT_SUCCESS, value: nil, errorMessage: nil,
        recoveryRegistration: .pending(
          vaultID: Self.vault,
          operations: [.init(namespace: .adoption, operationID: operation)]))
    }
    let io = MemoryIO(
      stdinIsTTY: false, onReadLine: { Issue.record("Pending must not ask approval") })
    #expect(
      KeyCLIApplication(transport: transport, io: io, clipboard: MemoryClipboard())
        .run(arguments: ["recovery", "pending"]) == EXIT_SUCCESS)
    #expect(io.stdout.contains(operation) && io.stdout.contains("Not checked for completion or ability to resume"))
    #expect(transport.requests == [.recoveryRegistration(.pending)])
  }

  private func arguments(resume: Bool = false) -> [String] {
    [
      "recovery", "register", resume ? "resume-export" : "prepare", "--token", "token",
      "--recipient", Self.recipient, "--export-anchor", "anchor.json",
    ]
  }
}
