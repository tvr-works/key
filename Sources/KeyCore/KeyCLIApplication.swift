import Foundation

public final class KeyCLIApplication {
    private let transport: KeyServiceTransport
    private let io: InputOutput
    private let clipboard: ClipboardWriting
    private let configStore: KeyConfigStore
    private let version: KeyVersionInfo
    private let currentDirectory: () -> URL

    public init(
        transport: KeyServiceTransport,
        io: InputOutput,
        clipboard: ClipboardWriting,
        configStore: KeyConfigStore = KeyConfigStore(),
        version: KeyVersionInfo = KeyVersionInfo.currentProcess(),
        currentDirectory: @escaping () -> URL = {
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        }
    ) {
        self.transport = transport
        self.io = io
        self.clipboard = clipboard
        self.configStore = configStore
        self.version = version
        self.currentDirectory = currentDirectory
    }

    @discardableResult
    public func run(arguments: [String]) -> Int32 {
        do {
            let parsed = try CLIParser.parseWithWarnings(arguments: arguments)
            for warning in parsed.warnings {
                io.writeStderr(warning + "\n")
            }
            return try execute(parsed.command)
        } catch let error as AppError {
            io.writeStderr("\(error.localizedDescription)\n")
            return error.exitCode.rawValue
        } catch {
            io.writeStderr("\(error.localizedDescription)\n")
            return EXIT_FAILURE
        }
    }

    private func execute(_ command: Command) throws -> Int32 {
        let response: KeyServiceResponse

        switch command {
        case let .help(text):
            io.writeStdout(text + "\n")
            return EXIT_SUCCESS
        case let .version(json):
            writeVersion(json: json)
            return EXIT_SUCCESS
        case let .config(configCommand):
            return try executeConfigCommand(configCommand)
        case let .initializeVault(path):
            let directory = path.map {
                URL(fileURLWithPath: $0, isDirectory: true, relativeTo: currentDirectory())
            } ?? currentDirectory()
            io.writeStderr("Creating vault: '\(directory.standardizedFileURL.path)'\nFor an existing vault, use `\(KeyProductIdentity.currentProcess.cliExecutableName) share`.\nKeep another Mac enrolled. This vault has no recovery key; files alone cannot restore access.\n")
            response = try transport.send(.initializeVault(path: directory.standardizedFileURL.path))
            return try handle(response, for: command)
        case .migrationPreflight:
            response = try transport.send(.migrationPreflight)
            return try handle(response, for: command)
        case .migrationApply:
            response = try transport.send(.migrationApply)
            return try handle(response, for: command)
        case let .status(json, verbose):
            response = try transport.send(.vaultStatus)
            if response.vaultStatus == nil,
               response.errorMessage != nil {
                return try handle(response, for: command)
            }
            let status = try requiredServicePayload(
                response.vaultStatus,
                operation: "vault status"
            )
            try writeStatus(status, json: json, verbose: verbose)
            return response.exitCode
        case let .conflict(conflictCommand):
            return try executeConflictCommand(conflictCommand)
        case let .share(shareCommand, vaultDirectory):
            return try executeShareCommand(shareCommand, vaultDirectory: vaultDirectory)
        case let .recovery(request):
            return try executeRecovery(request)
        case let .recoveryReview(request, json):
            return try executeRecoveryReview(request, json: json)
        case let .recoveryRegistration(request, exportPath, json):
            return try executeRecoveryRegistration(request, exportPath: exportPath, json: json)
        case let .recoveryRotation(request):
            return try executeRecoveryRotation(request)
        case let .recoveryRecipientRemoval(recipient):
            return try executeRecoveryRecipientRemoval(recipient)
        case .unlock:
            response = try transport.send(.unlock)
            return try handle(response, for: command)
        case .lock:
            response = try transport.send(.lock)
            return try handle(response, for: command)
        case .list:
            response = try transport.send(.list)
            return try handle(response, for: command)
        case let .get(name, allowStale):
            response = try transport.send(
                .get(name: name, allowStale: allowStale)
            )
            return try handle(response, for: command)
        case let .getTOTPSecret(name, allowStale):
            response = try transport.send(.getTOTPSecret(name: name, allowStale: allowStale))
            return try handle(response, for: command)
        case let .copy(name, allowStale), let .copyTOTPSecret(name, allowStale):
            let request: KeyServiceRequest = if case .copyTOTPSecret = command {
                .getTOTPSecret(name: name, allowStale: allowStale)
            } else {
                .get(name: name, allowStale: allowStale)
            }
            response = try transport.send(request)
            let exitCode = try handle(response, for: command)
            guard exitCode == EXIT_SUCCESS, let value = response.value else {
                return exitCode
            }
            try clipboard.copy(value)
            return EXIT_SUCCESS
        case let .add(name, type):
            let secret = try readSecretFromInput(type: type)
            response = try transport.send(.addManual(name: name, secret: secret, type: type))
            return try handle(response, for: command)
        case let .edit(name, type):
            let secret = try readSecretFromInput(type: type)
            response = try transport.send(.editManual(name: name, secret: secret, type: type))
            return try handle(response, for: command)
        case let .duplicate(source, destination, force):
            response = try transport.send(.copyEntry(source: source, destination: destination, force: force))
            return try handle(response, for: command)
        case let .rename(source, destination, force):
            response = try transport.send(.moveEntry(source: source, destination: destination, force: force))
            return try handle(response, for: command)
        case let .remove(name, force):
            try confirmRemovalIfNeeded(name: name, force: force)
            response = try transport.send(.removeEntry(name: name))
            return try handle(response, for: command)
        }
    }

    private func handle(_ response: KeyServiceResponse, for command: Command) throws -> Int32 {
        if response.exitCode != EXIT_SUCCESS {
            if let errorMessage = response.errorMessage {
                io.writeStderr("\(errorMessage)\n")
            }
            return response.exitCode
        }

        switch command {
        case .help:
            break
        case .version(json: _):
            break
        case .config:
            break
        case .initializeVault, .migrationPreflight, .migrationApply, .share, .recovery,
            .unlock, .lock, .list:
            if let value = response.value, !value.isEmpty {
                io.writeStdout(value)
            }
        case .get, .getTOTPSecret:
            if let value = response.value {
                io.writeStdout(formattedGetOutput(value))
            }
        case .status, .conflict, .recoveryReview, .recoveryRegistration, .recoveryRotation, .recoveryRecipientRemoval:
            break
        case .copy, .copyTOTPSecret, .add, .edit, .duplicate,
            .rename, .remove:
            break
        }

        return response.exitCode
    }

    private func executeRecoveryReview(_ request: KeyRecoveryReviewRequest, json: Bool) throws -> Int32 {
        let resolved: KeyRecoveryReviewRequest
        switch request {
        case .tokens:
            resolved = .tokens
        case .credential:
            resolved = request
        case .source(let path, let token):
            let base = URL(fileURLWithPath: currentDirectory().path, isDirectory: true)
            resolved = .source(
                path: URL(fileURLWithPath: path, isDirectory: true, relativeTo: base).standardizedFileURL.path,
                tokenID: token
            )
        }
        try resolved.validate()
        let response = try transport.send(.recoveryReview(resolved))
        guard response.exitCode == EXIT_SUCCESS else {
            return try handle(response, for: .recoveryReview(resolved, json: json))
        }
        let result = try requiredServicePayload(response.recoveryReview, operation: "public recovery review")
        switch (resolved, result) {
        case (.tokens, .tokens): break
        case let (.credential(token), .credential(credential)) where credential.token.tokenID == token: break
        case let (.source(path, token), .source(source))
            where source.path == path && source.token.tokenID == token: break
        default:
            throw AppError.service("Key service returned a mismatched public recovery review response.")
        }
        if json {
            try writeJSON(result)
        } else {
            writeRecoveryReview(result)
        }
        return response.exitCode
    }

    private func writeRecoveryReview(_ result: KeyRecoveryReviewResult) {
        switch result {
        case .credential(let credential):
            io.writeStdout("Recovery key setup (public check):\nToken ID: \(credential.token.tokenID)\nReader: \(credential.token.readerSlotName)\nRecovery key ID: \(credential.recipientID)\nReported: PIV 9d; P-256 generated on key; PIN/touch always.\nRecovery setup record (anchor): \(credential.anchorState.rawValue)\nRead-only; no PIN or touch requested.\nThis check cannot prove recovery works, PIN and touch are enforced, or key administration is protected.\n")
        case .tokens(let tokens):
            var lines = [tokens.isEmpty ? "No connected security keys found." : "Connected security keys:"]
            for token in tokens {
                lines.append("Token ID: \(token.tokenID)")
                lines.append("  Reader: \(token.readerSlotName)")
            }
            lines.append("Connected keys only; recovery setup and registration not checked.")
            io.writeStdout(lines.joined(separator: "\n") + "\n")
        case .source(let source):
            io.writeStdout("""
            Recovery source (public check):
            Source: \(String(reflecting: source.path))
            Token ID: \(source.token.tokenID)
            Reader: \(source.token.readerSlotName)
            Recovery key ID: \(source.recipientID)
            Slot: 9d; P-256; reported PIN \(source.reportedPINPolicy), touch \(source.reportedTouchPolicy), origin \(source.reportedKeyOrigin).
            Vault ID: \(source.vaultID)
            Registration ID: \(source.registrationID)
            Vault version at registration: \(source.registrationManifestDigest)
            Latest visible version: \(source.observedHeadDigest)
            Listed entries (not content-verified): \(source.listedEntryCount)
            History records checked: \(source.observedManifestCount)
            Public history matches this key. Secret contents were not checked.
            This check cannot prove recovery works, PIN and touch are enforced, or key administration is protected.
            It cannot confirm that all files have arrived.
            No restore started.

            """)
        }
    }

    private func executeRecoveryRecipientRemoval(_ recipientID: String) throws -> Int32 {
        guard io.stdinIsTTY else {
            throw AppError.operationRefused("Recovery key removal requires interactive review and confirmation. No request was sent.")
        }
        let reviewResponse = try transport.send(.recoveryRecipientRemoval(.review(recipientID: recipientID)))
        guard reviewResponse.exitCode == EXIT_SUCCESS else {
            return try handle(reviewResponse, for: .recoveryRecipientRemoval(recipientID: recipientID))
        }
        let reviewed = try requiredServicePayload(reviewResponse.recoveryRecipientRemoval, operation: "recovery key removal review")
        switch reviewed {
        case .completed:
            return try writeRecoveryRecipientRemoval(reviewed, recipientID: recipientID)
        case .review(let review):
            try review.validate(for: recipientID)
            io.writeStderr("Remove recovery key from this vault:\nVault ID: \(review.vaultID)\nRecovery key ID: \(review.recipientID)\nRecovery keys remaining: \(review.remainingRecipientIDs.count)\nThe physical key stays unchanged. The removed key can still open older vault copies.\n")
            if let operation = review.pendingOperationID {
                io.writeStderr("Continuing saved removal: \(operation)\n")
            }
            let phrase = review.removesLastRecoveryKey ? "REMOVE LAST RECOVERY KEY" : "REMOVE"
            if review.removesLastRecoveryKey {
                io.writeStderr("This removes your LAST recovery key. If all enrolled Macs are lost before you register another, access is permanently lost.\n")
            }
            guard try io.readLine(prompt: "Type \(phrase) to confirm: ").trimmingCharacters(in: .whitespacesAndNewlines) == phrase else {
                throw AppError.operationRefused("Recovery key removal cancelled. No removal request was sent.")
            }
            do {
                let response = try transport.send(.recoveryRecipientRemoval(.remove(recipientID: recipientID,
                    confirmationToken: review.confirmationToken, pendingOperationID: review.pendingOperationID,
                    acknowledgesProtectionLoss: review.removesLastRecoveryKey)))
                guard response.exitCode == EXIT_SUCCESS else {
                    io.writeStderr("Could not confirm removal finished. Keep vault files and saved records.\nRun this command again to review and finish the same removal. No automatic retry was made.\n")
                    return try handle(response, for: .recoveryRecipientRemoval(recipientID: recipientID))
                }
                return try writeRecoveryRecipientRemoval(requiredServicePayload(response.recoveryRecipientRemoval,
                    operation: "recovery key removal"), recipientID: recipientID)
            } catch {
                io.writeStderr("Could not confirm removal finished. Keep vault files and saved records.\nRun this command again to review and finish the same removal. No automatic retry was made.\n")
                throw error
            }
        }
    }

    private func writeRecoveryRecipientRemoval(_ result: KeyRecoveryRecipientRemovalResult, recipientID: String) throws -> Int32 {
        guard case .completed(let vault, let removed, let digest, let pending, let already) = result,
              isValidV3UUID(vault), removed == recipientID, isRecoveryRemovalDigest(digest) else {
            throw AppError.service("Invalid recovery key removal completion response.")
        }
        io.writeStdout("Recovery key \(already ? "is already removed in the verified current vault" : "removed from future vault versions").\nVault ID: \(vault)\nRecovery key ID: \(removed)\nVault version: \(digest)\n")
        if pending {
            io.writeStderr("Key removed. Keep saved records and run this command again to finish on this Mac.\n")
        }
        return EXIT_SUCCESS
    }

    private func executeRecoveryRotation(_ request: KeyRecoveryRotationRequest) throws -> Int32 {
        try request.validate()
        guard io.stdinIsTTY else {
            throw AppError.operationRefused("Explicit key rotation requires an interactive terminal. No request was sent.")
        }
        io.writeStderr("Change the vault encryption key. Macs and recovery keys keep access.\nBack up first. Hardware keys can stay disconnected.\n")
        guard try io.readLine(prompt: "Type ROTATE to continue: ").trimmingCharacters(in: .whitespacesAndNewlines) == "ROTATE" else {
            throw AppError.operationRefused("Key rotation cancelled. No request was sent.")
        }
        do {
            let response = try transport.send(.recoveryRotation(request))
            guard response.exitCode == EXIT_SUCCESS else {
                if let message = response.errorMessage { io.writeStderr(message + "\n") }
                writeRotationFailureGuidance()
                return response.exitCode
            }
            let result = try requiredServicePayload(response.recoveryRotation, operation: "vault-key rotation")
            switch result {
            case .completed(let vault, let digest, let pending):
                guard isValidV3UUID(vault), Base64URL.decodeCanonical(digest)?.count == 32 else {
                    throw AppError.service("Invalid key rotation completion response.")
                }
                if pending {
                    io.writeStderr("One step remains on this Mac. Keep saved records. After the background service restarts:\n  \(KeyProductIdentity.currentProcess.cliExecutableName) recovery pending\n  \(KeyProductIdentity.currentProcess.cliExecutableName) recovery rotate --resume <original-operation-id>\n")
                }
                io.writeStdout("The vault's encryption key was changed.\nVault ID: \(vault)\nVault version: \(digest)\nNext: \(KeyProductIdentity.currentProcess.cliExecutableName) status after the background service restarts.\n")
            case .abandoned(let vault):
                guard case .resume = request, isValidV3UUID(vault) else {
                    throw AppError.service("Invalid key rotation abandonment response.")
                }
                io.writeStdout("Incomplete key change abandoned. No new rotation started.\nNext: \(KeyProductIdentity.currentProcess.cliExecutableName) status after the background service restarts.\n")
            }
            return EXIT_SUCCESS
        } catch {
            writeRotationFailureGuidance()
            throw error
        }
    }

    private func writeRotationFailureGuidance() {
        io.writeStderr("Could not confirm rotation finished. Keep vault files and saved records; do not start another rotation.\nAfter the background service restarts, find the original ID with `\(KeyProductIdentity.currentProcess.cliExecutableName) recovery pending`, then use `\(KeyProductIdentity.currentProcess.cliExecutableName) recovery rotate --resume <operation-id>`. No automatic retry was made.\n")
    }

    private func executeRecoveryRegistration(
        _ request: KeyRecoveryRegistrationRequest, exportPath: String?, json: Bool
    ) throws -> Int32 {
        try request.validate()
        let confirmation: String?
        switch request {
        case .prepare: confirmation = "PREPARE"
        case .finish: confirmation = "REGISTER"
        case .adopt, .resumeAdoption: confirmation = "ADOPT"
        case .abandonAdoption, .abandonRegistration: confirmation = "ABANDON"
        case .status, .pending, .resumeExport: confirmation = nil
        }
        if let confirmation {
            guard io.stdinIsTTY else {
                throw AppError.operationRefused("Recovery setup requires an interactive terminal. No setup request was sent.")
            }
            writeRegistrationConfirmationGuidance(for: request)
            guard try io.readLine(prompt: "Type \(confirmation) to continue: ").trimmingCharacters(in: .whitespacesAndNewlines) == confirmation else {
                throw AppError.operationRefused("Recovery setup cancelled. No request was sent.")
            }
        }
        do {
            let serviceRequest = KeyServiceRequest.recoveryRegistration(request)
            let response = try sendRecovery(serviceRequest)
            guard response.exitCode == EXIT_SUCCESS else {
                if let message = response.errorMessage { io.writeStderr(message + "\n") }
                writeRegistrationFailureGuidance(for: request)
                return response.exitCode
            }
            let result = try requiredServicePayload(response.recoveryRegistration, operation: "recovery registration")
            switch (request, result) {
            case (.abandonAdoption(let requested), .adoptionAbandoned(let vault, let operation)):
                guard isValidV3UUID(vault), operation == requested else {
                    throw AppError.service("Invalid adoption abandonment response.")
                }
                io.writeStdout("Incomplete format update abandoned.\nOperation ID: \(operation)\nVault format, verified history and files preserved. No recovery key changed.\n")
                return EXIT_SUCCESS
            case (.abandonRegistration(let requested), .registrationAbandoned(let vault, let operation)):
                guard isValidV3UUID(vault), operation == requested else {
                    throw AppError.service("Invalid registration abandonment response.")
                }
                io.writeStdout("Incomplete recovery registration abandoned.\nOperation ID: \(operation)\nVerified history and files preserved. No recovery key changed.\n")
                return EXIT_SUCCESS
            case (.pending, .pending(let vault, let operations)):
                guard isValidV3UUID(vault), operations.count <= 3,
                      Set(operations.map(\.namespace)).count == operations.count,
                      operations.allSatisfy({ (try? VaultTransactionOperationID(validating: $0.operationID)) != nil }) else {
                    throw AppError.service("Invalid saved recovery selector response.")
                }
                if json { try writeJSON(result) }
                else {
                    io.writeStdout("Vault ID: \(vault)\n")
                    for operation in operations { io.writeStdout("\(operation.namespace.rawValue): \(operation.operationID)\n") }
                    io.writeStdout("Saved operations: \(operations.count). Not checked for completion or ability to resume.\nKeep these records; follow the matching command's resume instructions.\n")
                }
                return EXIT_SUCCESS
            case (.status, .status(let state, let vaultID, let recipients, let committed)):
                guard isValidV3UUID(vaultID), recipients.count <= 64,
                      recipients.allSatisfy({ (try? V3RecoveryRecipientID(rawValue: $0)) != nil }) else {
                    throw AppError.service("Invalid recovery registration status response.")
                }
                if json { try writeJSON(result) }
                else {
                    let description = switch state {
                    case .unregistered: "No recovery key registered"
                    case .registered: "Recovery keys registered"
                    case .pending: "Setup has an unfinished step"
                    case .attentionRequired: "Setup needs attention"
                    }
                    io.writeStdout("Recovery setup: \(description)\nVault ID: \(vaultID)\nRegistered recovery keys: \(recipients.count)\n")
                    for recipient in recipients { io.writeStdout("Recovery key ID: \(recipient)\n") }
                    if committed { io.writeStdout("Registration saved; this Mac may still need to finish setup.\n") }
                    io.writeStdout("This checks saved registration only. It does not test recovery or confirm that all files have arrived.\n")
                }
                return state == .attentionRequired ? EXIT_FAILURE : EXIT_SUCCESS
            case (.prepare(_, let expected), .export(let operation, let vault, let recipient, let encoded)),
                 (.resumeExport(_, let expected), .export(let operation, let vault, let recipient, let encoded)):
                guard let exportPath, recipient == expected, isValidV3UUID(vault),
                      (try? VaultTransactionOperationID(validating: operation)) != nil,
                      encoded.utf8.count <= 1_368, let bytes = Base64URL.decodeCanonical(encoded),
                      let anchor = try? V3RecoveryAnchorCodec().parseCanonical(bytes),
                      anchor.floor.vaultID == vault, anchor.recipientID.rawValue == recipient else {
                    throw AppError.service("Invalid or mismatched recovery anchor export response.")
                }
                let base = URL(fileURLWithPath: currentDirectory().path, isDirectory: true)
                let url = URL(fileURLWithPath: exportPath, relativeTo: base).standardizedFileURL
                // Insert only: existing files and links are never replaced. If
                // this fails, the locally owned preparation remains resumable.
                try bytes.write(to: url, options: .withoutOverwriting)
                io.writeStdout("Setup file saved: '\(url.path)'\nOperation ID: \(operation)\nRecovery key ID: \(recipient)\nRecovery is not active yet. Install this exact file on the selected key.\nSetup guide: \(CLIHelp.recoveryGuideURL)\nNext: \(KeyProductIdentity.currentProcess.cliExecutableName) recovery register finish with the same --token and --recipient.\n")
                return EXIT_SUCCESS
            case (.finish, .completed(let vault, let digest, let pending)),
                 (.adopt, .completed(let vault, let digest, let pending)),
                 (.resumeAdoption, .completed(let vault, let digest, let pending)):
                guard isValidV3UUID(vault), Base64URL.decodeCanonical(digest)?.count == 32 else {
                    throw AppError.service("Invalid recovery setup completion response.")
                }
                let outcome: String
                if case .finish = request {
                    outcome = "Recovery key registered."
                } else {
                    outcome = "Vault format updated. No recovery key added."
                }
                io.writeStdout("\(outcome)\nVault ID: \(vault)\nVault version: \(digest)\n")
                if pending {
                    io.writeStderr("One step remains on this Mac. Keep saved records.\n")
                    if case .finish = request {
                        io.writeStderr("After the background service restarts, repeat \(KeyProductIdentity.currentProcess.cliExecutableName) recovery register finish with the same --token and --recipient.\n")
                    } else {
                        io.writeStderr("After the background service restarts: \(KeyProductIdentity.currentProcess.cliExecutableName) recovery pending\nThen: \(KeyProductIdentity.currentProcess.cliExecutableName) recovery adopt --resume <original-operation-id>\n")
                    }
                } else if case .finish = request {
                    io.writeStdout("After the background service restarts: \(KeyProductIdentity.currentProcess.cliExecutableName) recovery register status\n")
                } else {
                    io.writeStdout("Next: \(KeyProductIdentity.currentProcess.cliExecutableName) recovery register --help\n")
                }
                return EXIT_SUCCESS
            default: throw AppError.service("Mismatched recovery setup response.")
            }
        } catch {
            writeRegistrationFailureGuidance(for: request)
            throw error
        }
    }

    private func writeRegistrationConfirmationGuidance(for request: KeyRecoveryRegistrationRequest) {
        let message: String
        switch request {
        case .adopt:
            message = "Update the vault format for recovery keys. Older apps will lose access.\nBack up first and upgrade every Mac. This step does not register a key."
        case .resumeAdoption(let operation):
            message = "Resume saved format update: \(operation).\nKeep vault files and saved records intact."
        case .prepare:
            message = "Prepare recovery key registration. Recovery stays inactive until registration finishes.\nSet up and secure the physical key first; see \(KeyProductIdentity.currentProcess.cliExecutableName) recovery register --help."
        case .finish:
            message = "Register this recovery key. Approve Mac prompts, enter its PIN only in macOS, and touch when it flashes."
        case .abandonAdoption:
            message = "Release this early format-update attempt. Saved files stay intact.\nCompleted format changes cannot be undone here."
        case .abandonRegistration:
            message = "Release this early registration attempt. Saved files and active recovery keys stay intact.\nThe physical key stays unchanged."
        case .status, .pending, .resumeExport:
            return
        }
        io.writeStderr(message + "\n")
    }

    private func writeRegistrationFailureGuidance(for request: KeyRecoveryRegistrationRequest) {
        let command = KeyProductIdentity.currentProcess.cliExecutableName
        let next: String
        switch request {
        case .status, .pending:
            // Read-only failures have their own error; they do not imply that
            // setup was attempted or needs to be resumed.
            return
        case .prepare, .resumeExport:
            next = "For the same saved preparation, use resume-export with the original IDs and a new filename.\nHelp: \(command) recovery register --help"
        case .finish:
            next = "After the background service restarts, repeat \(command) recovery register finish with the same --token and --recipient."
        case .adopt, .resumeAdoption:
            next = "After the background service restarts: \(command) recovery pending\nResume instructions: \(command) recovery adopt --help"
        case .abandonAdoption, .abandonRegistration:
            next = "Check the saved attempt before continuing: \(command) recovery pending"
        }
        io.writeStderr("Could not confirm setup finished. Keep vault files, saved records and hardware setup unchanged. Do not start replacement setup.\n\(next)\n")
    }

    private func executeRecovery(_ request: KeyRecoveryRequest) throws -> Int32 {
        // Resolve both explicit paths against one captured working directory.
        // Configuration and provider files cannot supply a missing selector.
        let base = URL(fileURLWithPath: currentDirectory().path, isDirectory: true)
        func path(_ value: String) -> String {
            URL(fileURLWithPath: value, isDirectory: true, relativeTo: base).standardizedFileURL.path
        }
        let resolved: KeyRecoveryRequest
        switch request {
        case .restore(let source, let destination, let token, let recipient, let name):
            resolved = .restore(
                source: path(source), destination: path(destination), tokenID: token,
                recipientID: recipient, deviceName: name
            )
        case .resume(let source, let destination, let token, let recipient):
            resolved = .resume(
                source: path(source), destination: path(destination), tokenID: token,
                recipientID: recipient
            )
        case .abandon(let source, let destination, let vault, let operation):
            resolved = .abandon(source: path(source), destination: path(destination),
                sourceVaultID: vault, operationID: operation)
        }
        try resolved.validate()
        if resolved.isAbandonment {
            io.writeStderr("Releasing the early restore attempt. Files and Mac credentials will be kept.\n")
        } else {
            io.writeStderr("Enter the key's PIN only in the macOS dialog, touch when it flashes, then approve the Mac prompts.\n")
        }
        do {
            let response = try sendRecovery(.recovery(resolved))
            let result = try handle(response, for: .recovery(resolved))
            if result != EXIT_SUCCESS { writeRecoveryFailureGuidance(abandonment: resolved.isAbandonment) }
            return result
        } catch {
            writeRecoveryFailureGuidance(abandonment: resolved.isAbandonment)
            throw error
        }
    }

    private func writeRecoveryFailureGuidance(abandonment: Bool = false) {
        if abandonment {
            io.writeStderr("Could not confirm the attempt was released. Keep the source, destination and saved records.\nInspect the original attempt before continuing. No new restore started.\n")
            return
        }
        io.writeStderr("Could not confirm recovery finished. Keep the source, destination, saved records and configuration.\nDo not start another restore or delete files to retry.\nNext: `\(KeyProductIdentity.currentProcess.cliExecutableName) recovery resume --help`. Use the original paths and IDs; if the attempt cannot resume, follow its error instructions.\n")
    }

    private func sendRecovery(_ request: KeyServiceRequest) throws -> KeyServiceResponse {
        guard request.supportsRecoveryProgress else { return try transport.send(request) }
        return try transport.send(request, progress: { [io] stage in
            io.writeStderr(stage.instruction + "\n")
        })
    }

    private func executeShareCommand(
        _ command: ShareCommand,
        vaultDirectory: String?
    ) throws -> Int32 {
        switch command {
        case let .revoke(deviceID):
            return try executeDeviceRevocation(deviceID: deviceID)
        case let .devices(json):
            let response = try transport.send(.share(.devices))
            guard response.exitCode == EXIT_SUCCESS else {
                return try handle(response, for: .share(command))
            }
            let inventory = try requiredServicePayload(
                response.deviceInventory,
                operation: "device inventory"
            )
            if json {
                try writeJSON(inventory)
            } else {
                writeDeviceInventory(inventory)
            }
            return response.exitCode
        case .invitations:
            return try executeSimpleShareCommand(command, request: .invitations, vaultDirectory: vaultDirectory)
        case let .invite(deviceName):
            return try executeSimpleShareCommand(
                command,
                request: .invite(deviceName: deviceName)
            )
        case let .join(invitationID, deviceName):
            return try executeJoin(
                invitationID: invitationID,
                deviceName: deviceName,
                vaultDirectory: vaultDirectory
            )
        case let .requests(invitationID):
            return try executeSimpleShareCommand(
                command,
                request: .requests(invitationID: invitationID)
            )
        case let .compare(vaultID, invitationID, joinRequestID):
            return try executeSimpleShareCommand(
                command,
                request: .compare(
                    vaultID: vaultID,
                    invitationID: invitationID,
                    joinRequestID: joinRequestID
                ),
                vaultDirectory: vaultDirectory
            )
        case let .approve(vaultID, invitationID, comparisonCode):
            return try executeSimpleShareCommand(
                command,
                request: .approve(
                    vaultID: vaultID,
                    invitationID: invitationID,
                    comparisonCode: comparisonCode
                )
            )
        case let .accept(vaultID, invitationID, comparisonCode):
            return try executeSimpleShareCommand(
                command,
                request: .accept(
                    vaultID: vaultID,
                    invitationID: invitationID,
                    comparisonCode: comparisonCode
                ),
                vaultDirectory: vaultDirectory
            )
        }
    }

    private func executeSimpleShareCommand(
        _ command: ShareCommand,
        request: KeyShareRequest,
        vaultDirectory: String? = nil
    ) throws -> Int32 {
        try handle(
            transport.send(shareServiceRequest(request, vaultDirectory: vaultDirectory)),
            for: .share(command)
        )
    }

    private func shareServiceRequest(
        _ request: KeyShareRequest,
        vaultDirectory: String?
    ) throws -> KeyServiceRequest {
        guard request.supportsDirectorySelection else { return .share(request) }
        let directory: URL
        if let vaultDirectory {
            let base = URL(fileURLWithPath: currentDirectory().path, isDirectory: true)
            directory = URL(fileURLWithPath: vaultDirectory, isDirectory: true, relativeTo: base)
        } else if try configStore.hasConfiguration() {
            directory = try configStore.load().vaultDirectoryURL
        } else {
            directory = currentDirectory()
        }
        let path = directory.standardizedFileURL.path
        io.writeStderr("Vault folder: '\(path)'.\n")
        if case .join = request {
            io.writeStderr("Requesting access for this Mac. No new vault or hardware key changes.\n")
        }
        return .shareInDirectory(request: request, path: path)
    }

    private func executeDeviceRevocation(deviceID: String) throws -> Int32 {
        guard io.stdinIsTTY else {
            throw AppError.operationRefused(
                "Device revocation requires interactive confirmation."
            )
        }
        let reviewResponse = try transport.send(.share(
            .reviewRevocation(deviceID: deviceID)
        ))
        guard reviewResponse.exitCode == EXIT_SUCCESS else {
            return try handle(
                reviewResponse,
                for: .share(.revoke(deviceID: deviceID))
            )
        }
        let review = try requiredServicePayload(
            reviewResponse.deviceRevocationReview,
            operation: "device revocation review"
        )
        writeDeviceRevocationReview(review)
        try confirmDeviceRevocation()

        let response = try transport.send(.share(.revoke(
            deviceID: deviceID,
            confirmationToken: review.confirmationToken
        )))
        return try handle(
            response,
            for: .share(.revoke(deviceID: deviceID))
        )
    }

    private func writeDeviceRevocationReview(
        _ review: V3VaultDeviceRevocationReview
    ) {
        var lines = [
            "Review removal of vault access:",
            "Device: \(review.revokedDevice.displayName)",
            "  ID: \(review.revokedDevice.deviceID)",
            "Authorized by: \(review.authorizingDevice.displayName)",
            "",
            "This removes the Mac's access to the current vault and future changes. It cannot erase secrets or older vault data the Mac already obtained.",
            "Key will change the encryption key and encrypt the vault again for the Macs that keep access.",
            "Remaining active devices: \(review.remainingActiveDevices.count)"
        ]
        lines.append(contentsOf: review.remainingActiveDevices.map {
            "  \($0.displayName)"
        })
        if review.remainingActiveDevices.count == 1,
           let remainingDevice = review.remainingActiveDevices.first
        {
            lines.append("")
            lines.append(
                "WARNING: This will leave \(remainingDevice.displayName) as the vault's only active device."
            )
            lines.append(
                "If that Mac is lost, a backup of the vault folder alone cannot restore access."
            )
        }
        io.writeStdout(lines.joined(separator: "\n") + "\n")
    }

    private func confirmDeviceRevocation() throws {
        let answer = try io.readLine(
            prompt: "Type REVOKE to remove the selected Mac's access: "
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard answer == "REVOKE" else {
            throw AppError.operationRefused("Device revocation cancelled.")
        }
    }

    private func executeJoin(
        invitationID: String,
        deviceName: String,
        vaultDirectory: String?
    ) throws -> Int32 {
        let command = ShareCommand.join(
            invitationID: invitationID,
            deviceName: deviceName
        )
        let request = KeyShareRequest.join(
            invitationID: invitationID,
            deviceName: deviceName
        )
        let serviceRequest = try shareServiceRequest(request, vaultDirectory: vaultDirectory)
        let initialResponse = try transport.send(serviceRequest)
        guard let review = initialResponse.deviceReplacementReview else {
            return try handle(initialResponse, for: .share(command))
        }
        guard io.stdinIsTTY else {
            throw AppError.operationRefused(
                "Rejoining a revoked Mac requires interactive confirmation."
            )
        }

        writeDeviceRejoinReview(review)
        try confirmDeviceRejoin()

        let revalidationResponse = try transport.send(serviceRequest)
        guard revalidationResponse.exitCode == EXIT_SUCCESS else {
            return try handle(
                revalidationResponse,
                for: .share(command)
            )
        }
        let currentReview = try requiredServicePayload(
            revalidationResponse.deviceReplacementReview,
            operation: "device rejoin revalidation"
        )
        guard currentReview == review else {
            throw AppError.operationRefused(
                "The vault's replacement state changed while awaiting confirmation. Review the current state by running the join command again."
            )
        }

        let cleanupResponse = try transport.send(.share(.replaceCurrentDevice(
            invitationID: invitationID,
            confirmationToken: currentReview.confirmationToken
        )))
        let cleanupExitCode = try handle(
            cleanupResponse,
            for: .share(command)
        )
        guard cleanupExitCode == EXIT_SUCCESS else {
            return cleanupExitCode
        }

        return try handle(
            transport.send(serviceRequest),
            for: .share(command)
        )
    }

    private func writeDeviceRejoinReview(
        _ review: V3VaultDeviceReplacementReview
    ) {
        var lines = [
            "This Mac previously had access to this vault, but its access was removed.",
            "Review rejoin:",
            "Vault ID: \(review.vaultID)",
            "Previous identity: \(review.replacedDevice.displayName)",
            "  ID: \(review.replacedDevice.deviceID)"
        ]
        switch review.authorityKind {
        case .trustedCheckpoint:
            lines.append(
                "Confirmed by: this Mac's last verified vault record"
            )
        case .survivingDevice:
            if let authorizingDevice = review.authorizingDevice {
                lines.append(
                    "Revoked by: \(authorizingDevice.displayName)"
                )
            }
        }
        lines.append(contentsOf: [
            "",
            "Rejoining replaces this Mac's old access credentials and local vault record. Key creates new credentials for this invitation.",
            "Synchronized vault files will not be changed.",
            "The other Mac must still compare the code and approve this Mac's new access."
        ])
        io.writeStdout(lines.joined(separator: "\n") + "\n")
    }

    private func confirmDeviceRejoin() throws {
        let answer = try io.readLine(
            prompt: "Type REJOIN to replace this Mac's credentials: "
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard answer == "REJOIN" else {
            throw AppError.operationRefused("Device rejoin cancelled.")
        }
    }

    private func formattedGetOutput(_ value: String) -> String {
        guard io.stdoutIsTTY, !value.hasSuffix("\n") else {
            return value
        }

        return value + "\n"
    }

    private func readSecretFromInput(type: SecretEntryType) throws -> String {
        let prompt = type == .totp ? "Authenticator setup secret (Base32): " : "Secret: "
        let secret: String
        if io.stdinIsTTY {
            secret = try io.readSecureLine(prompt: prompt)
        } else {
            secret = try io.readPipedInput()
        }

        switch type {
        case .secret:
            return secret
        case .totp:
            return try TOTPGenerator.normalizeBase32Seed(secret)
        }
    }

    private func confirmRemovalIfNeeded(name: String, force: Bool) throws {
        guard !force else {
            return
        }

        guard io.stdinIsTTY else {
            throw AppError.operationRefused("Refusing to remove '\(name)' without --force in non-interactive mode.")
        }

        let answer = try io.readLine(prompt: "Remove '\(name)'? [y/N]: ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard answer == "y" || answer == "yes" else {
            throw AppError.operationRefused("Removal cancelled.")
        }
    }

    private func writeVersion(json: Bool) {
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            if let data = try? encoder.encode(version),
               let string = String(data: data, encoding: .utf8) {
                io.writeStdout(string + "\n")
                return
            }
        }

        io.writeStdout(version.displayString + "\n")
    }

    private func executeConflictCommand(
        _ command: ConflictCommand
    ) throws -> Int32 {
        switch command {
        case let .list(json):
            let response = try transport.send(.listConflicts)
            guard response.exitCode == EXIT_SUCCESS else {
                return try handle(response, for: .conflict(command))
            }
            let conflicts = try requiredServicePayload(
                response.conflicts,
                operation: "conflict list"
            )
            if json {
                try writeJSON(conflicts)
            } else {
                writeConflictList(conflicts)
            }
            return response.exitCode
        case let .show(id, json):
            let response = try transport.send(.showConflict(id: id))
            guard response.exitCode == EXIT_SUCCESS else {
                return try handle(response, for: .conflict(command))
            }
            let conflict = try requiredServicePayload(
                response.conflict,
                operation: "conflict show"
            )
            if json {
                try writeJSON(conflict)
            } else {
                writeConflict(conflict)
            }
            return response.exitCode
        case let .get(id, versionID):
            let response = try transport.send(
                .getConflictValue(id: id, versionID: versionID)
            )
            guard response.exitCode == EXIT_SUCCESS else {
                return try handle(response, for: .conflict(command))
            }
            let value = try requiredServicePayload(
                response.value,
                operation: "conflict get"
            )
            io.writeStdout(formattedGetOutput(value))
            return response.exitCode
        case let .copy(id, versionID):
            let response = try transport.send(
                .getConflictValue(id: id, versionID: versionID)
            )
            guard response.exitCode == EXIT_SUCCESS else {
                return try handle(response, for: .conflict(command))
            }
            let value = try requiredServicePayload(
                response.value,
                operation: "conflict copy"
            )
            try clipboard.copy(value)
            return response.exitCode
        case let .resolve(resolutions):
            let response = try transport.send(
                .resolveConflicts(resolutions)
            )
            return try handle(response, for: .conflict(command))
        }
    }

    private func writeStatus(
        _ status: VaultStatus,
        json: Bool,
        verbose: Bool
    ) throws {
        if json {
            try writeJSON(status)
            return
        }

        let headline = switch status.health {
        case .ready:
            "Vault is ready."
        case .incomplete:
            "Some required vault files are unavailable on this Mac."
        case .contentConflicted:
            "Some entries have conflicting changes. Choose which versions to keep."
        case .securityConflicted:
            "Vault history contains conflicting changes to device access or encryption keys."
        case .rollbackDetected:
            "Vault history includes an older entry revision. Key has blocked the rollback."
        case .recoveryRequired:
            "Key could not verify that this vault is safe to use."
        }
        let entryLabel = switch status.entries.basis {
        case .effective:
            "Entries"
        case .lastTrusted:
            "Entries (last verified on this Mac)"
        }
        var lines = [
            headline,
            "\(entryLabel): \(status.entries.count)"
        ]
        if verbose {
            lines.append("Storage format: \(status.format == .version2 ? "version 2" : "version 3")")
        }
        if status.conflictCount > 0 {
            lines.append("Conflicts: \(status.conflictCount)")
            switch status.health {
            case .contentConflicted:
                lines.append("Next: run `\(KeyProductIdentity.currentProcess.cliExecutableName) conflict list`.")
            case .rollbackDetected:
                lines.append(
                    "Next: inspect with `\(KeyProductIdentity.currentProcess.cliExecutableName) conflict list`. Keep vault files and local records intact; ordinary conflict resolution cannot accept this rollback.\nTroubleshooting: \(CLIHelp.troubleshootingURL)"
                )
            case .ready, .incomplete, .securityConflicted,
                .recoveryRequired:
                break
            }
        }
        switch status.health {
        case .incomplete:
            lines.append("Next: check that your sync provider has downloaded the vault files, then run `\(KeyProductIdentity.currentProcess.cliExecutableName) status` again.")
        case .securityConflicted, .recoveryRequired:
            lines.append("Keep vault files and local records intact. Do not delete them or run init to bypass this check.\nTroubleshooting: \(CLIHelp.troubleshootingURL)")
        case .ready, .contentConflicted, .rollbackDetected:
            break
        }
        if verbose, let trustedVersionID = status.trustedVersionID {
            lines.append(
                "Previously trusted on this Mac: \(trustedVersionID)"
            )
        }
        lines.append(contentsOf: status.issues.map {
            "Attention: \($0.message)"
        })
        io.writeStdout(lines.joined(separator: "\n") + "\n")
        if status.format == .version2 {
            writeV2DeprecationWarning()
        }
    }

    /// Warn only on explicit, terminal-facing inspection. Never probe config
    /// or contact the helper just to add a warning to an ordinary command.
    private func writeV2DeprecationWarning() {
        guard io.stdoutIsTTY else { return }
        io.writeStderr(
            "Warning: older vault format, deprecated but still supported.\nCheck migration readiness: \(KeyProductIdentity.currentProcess.cliExecutableName) migrate --check\nMigration steps and limits: \(KeyProductIdentity.currentProcess.cliExecutableName) migrate --help\n"
        )
    }

    private func writeConflictList(
        _ conflicts: [VaultConflictSummary]
    ) {
        guard !conflicts.isEmpty else {
            io.writeStdout("No unresolved content conflicts.\n")
            return
        }

        let lines = conflicts.map { conflict in
            let name = conflict.entryName ?? "(deleted or renamed)"
            return "\(conflict.id)  \(name)  \(humanConflictKind(conflict.kind))  \(conflict.versionCount) versions"
        }
        io.writeStdout(lines.joined(separator: "\n") + "\n")
    }

    private func writeDeviceInventory(
        _ inventory: V3VaultDeviceInventory
    ) {
        guard inventory.mode == .shared else {
            io.writeStdout("This vault does not have an enrolled-device list yet.\n")
            return
        }

        var lines = ["Macs recorded for this vault:"]
        for device in inventory.devices {
            let current = device.deviceID == inventory.currentDeviceID
                ? " (this Mac)"
                : ""
            lines.append(
                "\(device.displayName) — \(device.status.rawValue)\(current)"
            )
            lines.append("  ID: \(device.deviceID)")
        }
        lines.append("")
        if inventory.activeDeviceCount == 1 {
            lines.append("Only one Mac currently has access.")
            lines.append(
                "Attention: add another Mac. If the only Mac with access is lost, the vault folder alone cannot restore access."
            )
        } else {
            lines.append(
                "Macs with access: \(inventory.activeDeviceCount)."
            )
            lines.append(
                "A Mac that still has access can add a replacement if another is lost."
            )
        }
        if let currentDeviceID = inventory.currentDeviceID,
           !inventory.devices.contains(where: {
               $0.deviceID == currentDeviceID
           }) {
            lines.append(
                "Attention: this Mac's access credentials are not recognized by the current vault."
            )
        } else if inventory.currentDeviceID == nil {
            lines.append(
                "Attention: this Mac has no saved access credentials for this vault."
            )
        }
        io.writeStdout(lines.joined(separator: "\n") + "\n")
    }

    private func writeConflict(_ conflict: VaultConflictDetail) {
        var lines = [
            "Conflict: \(conflict.summary.id)",
            "Entry: \(conflict.summary.entryName ?? "(deleted or renamed)")",
            "Reason: \(humanConflictKind(conflict.summary.kind))",
            "Verified versions:"
        ]
        for version in conflict.versions {
            var description = "  \(version.id)  "
            if let name = version.entryName {
                description += name
                if let revision = version.revision {
                    description += "  revision \(revision)"
                }
            } else {
                description += "(deleted)"
            }
            if version.previouslyTrustedOnThisMac {
                description += "  previously trusted on this Mac"
            }
            lines.append(description)
        }
        switch conflict.summary.kind.resolutionPolicy {
        case .chooseVersion:
            lines.append(
                "Resolve only after reviewing every conflict shown by `\(KeyProductIdentity.currentProcess.cliExecutableName) conflict list`."
            )
        case .recoveryRequired:
            lines.append(
                "This older revision cannot be accepted with `\(KeyProductIdentity.currentProcess.cliExecutableName) conflict resolve`. Keep vault files and local records intact. Do not delete them or run init to bypass this check.\nTroubleshooting: \(CLIHelp.troubleshootingURL)"
            )
        }
        io.writeStdout(lines.joined(separator: "\n") + "\n")
    }

    private func writeJSON<Value: Encodable>(_ value: Value) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw AppError.io("Failed to encode JSON output.")
        }
        io.writeStdout(string + "\n")
    }

    private func requiredServicePayload<Value>(
        _ value: Value?,
        operation: String
    ) throws -> Value {
        guard let value else {
            throw AppError.service(
                "Key service returned an invalid \(operation) response."
            )
        }
        return value
    }

    private func humanConflictKind(_ kind: VaultConflictKind) -> String {
        switch kind {
        case .concurrentCreation:
            "created differently"
        case .editEdit:
            "edited differently"
        case .deleteEdit:
            "deleted on one version and edited on another"
        case .renameEdit:
            "renamed on one version and edited on another"
        case .conflictingRename:
            "renamed differently"
        case .destinationCollision:
            "multiple entries use the same name"
        case .revisionRollback:
            "an older entry revision reappeared"
        case .conflictingRevision:
            "same revision contains different content"
        }
    }

    private func executeConfigCommand(_ command: ConfigCommand) throws -> Int32 {
        switch command {
        case let .get(key):
            let configuration = try configStore.load()
            io.writeStdout(configuration.value(for: key) + "\n")
            if key == .keychainMode, case .v3 = configuration.authority {
                io.writeStderr(
                    "keychain-mode does not control access or file synchronization for this vault. Key retains it for compatibility. vault-dir specifies the folder used to store and synchronize vault files.\n"
                )
            }
        case let .set(key, value):
            switch key {
            case .vaultDir:
                let response = try transport.send(
                    .setVaultDirectory(path: value)
                )
                return try handle(response, for: .config(command))
            case .keychainMode:
                guard let mode = KeychainMode(rawValue: value) else {
                    throw AppError.invalidConfiguration("Unsupported keychain mode '\(value)'. Expected 'local' or 'icloud'.")
                }
                let response = try transport.send(.setKeychainMode(mode))
                return try handle(response, for: .config(command))
            }
        case .list:
            let configuration = try configStore.load()
            let output = configuration.listedValues
                .map { "\($0.key.rawValue)=\($0.value)" }
                .joined(separator: "\n")
            if !output.isEmpty {
                io.writeStdout(output + "\n")
            }
            if case .v2 = configuration.authority {
                writeV2DeprecationWarning()
            }
        }

        return EXIT_SUCCESS
    }
}
