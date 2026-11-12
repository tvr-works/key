import CryptoKit
import Darwin
import Foundation
import Testing
@testable import KeyCore

struct ConfigCompatibilityTests {
    @Test
    func migrationArchivesAnOmittedLegacyModeWithoutInventingOne() throws {
        let fixture = try ConfigFixture(storedMode: "omitted", isV3: false)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL)
        #expect(try fixture.store.load().authority == .v2(keychainMode: .local))
        _ = try fixture.store.selectV3Vault(vaultID: ConfigFixture.vaultID,
                                         expectedRootHandle: VaultRootDirectoryHandle(opening: fixture.root), expectedKeychainMode: .local)
        #expect(try Data(contentsOf: fixture.archiveURL(original)) == original)
        #expect(!String(decoding: original, as: UTF8.self).contains("keychain_mode"))
        #expect(try fixture.store.load().keychainMode == nil)
    }

    @Test(arguments: ["local", "icloud", "omitted"])
    func shorteningRetainsExactPrivateConfigAndReadsIgnoreArchives(storedMode: String) throws {
        let fixture = try ConfigFixture(storedMode: storedMode, isV3: true)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL)
        _ = try fixture.store.setValue(fixture.root.path, for: .vaultDir)
        let selected = try fixture.store.load()
        #expect(selected.vaultID == ConfigFixture.vaultID)
        #expect(selected.keychainMode == nil)
        #expect(!String(decoding: try Data(contentsOf: fixture.configURL), as: UTF8.self).contains("keychain_mode"))
        if storedMode == "omitted" {
            #expect(try fixture.snapshots().isEmpty)
        } else {
            let archive = fixture.archiveURL(original)
            #expect(try Data(contentsOf: archive) == original)
            let attributes = try FileManager.default.attributesOfItem(atPath: archive.path)
            #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
            let directoryAttributes = try FileManager.default.attributesOfItem(atPath: archive.deletingLastPathComponent().path)
            #expect((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
            _ = try fixture.store.setValue(fixture.root.path, for: .vaultDir)
            #expect(try fixture.snapshots().count == 1)
            try Data("damaged archive".utf8).write(to: archive)
            #expect(try fixture.store.load() == selected)
            try FileManager.default.removeItem(at: archive)
            #expect(try fixture.store.load() == selected)
        }
    }

    @Test(arguments: ["local", "icloud", "omitted"])
    func storeRefusesModeGetterAndSetterForEveryEnrolledConfig(storedMode: String) throws {
        let fixture = try ConfigFixture(storedMode: storedMode, isV3: true)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL)
        #expect(throws: AppError.self) { try fixture.store.getValue(for: .keychainMode) }
        #expect(throws: AppError.self) { try fixture.store.setValue("local", for: .keychainMode) }
        #expect(try Data(contentsOf: fixture.configURL) == original)
        #expect(try fixture.snapshots().isEmpty)
    }

    @Test(arguments: ["archive", "config", "published"])
    func interruptedSaveCanRetryFromActualSelection(stage: String) throws {
        let fixture = try ConfigFixture(storedMode: "icloud", isV3: true)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL)
        let store = KeyConfigStore(homeDirectoryURL: fixture.home, writeObserver: ConfigWriteObserver { phase in
            switch phase {
            case let .temporaryFileSynchronized(path):
                if (stage == "archive" && path != "config.toml") || (stage == "config" && path == "config.toml") {
                    throw ConfigSaveInterruption.stopped
                }
            case .replacementPublished:
                if stage == "published" { throw ConfigSaveInterruption.stopped }
            }
        })
        #expect(throws: AppError.self) { try store.setValue(fixture.root.path, for: .vaultDir) }
        if stage == "published" {
            #expect(try fixture.store.load().keychainMode == nil)
        } else {
            #expect(try Data(contentsOf: fixture.configURL) == original)
        }
        _ = try fixture.store.setValue(fixture.root.path, for: .vaultDir)
        #expect(try fixture.store.load().keychainMode == nil)
        #expect(try fixture.snapshots().count == 1)
        #expect(try Data(contentsOf: fixture.archiveURL(original)) == original)
    }

    @Test(arguments: ["directory", "symlink", "fifo", "wrong-bytes", "public-file", "public-directory", "hardlink", "parent-symlink"])
    func unsafeArchiveRefusesWithoutReplacingConfig(kind: String) throws {
        let fixture = try ConfigFixture(storedMode: "icloud", isV3: true)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL)
        let archive = fixture.archiveURL(original)
        let parent = archive.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let outside = fixture.home.appendingPathComponent("outside")
        try original.write(to: outside)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: outside.path)
        switch kind {
        case "directory": try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: false)
        case "symlink": try FileManager.default.createSymbolicLink(at: archive, withDestinationURL: outside)
        case "fifo": #expect(mkfifo(archive.path, 0o600) == 0)
        case "wrong-bytes": try Data("wrong".utf8).write(to: archive)
        case "public-file":
            try original.write(to: archive)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: archive.path)
        case "public-directory":
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: parent.path)
        case "hardlink": try FileManager.default.linkItem(at: outside, to: archive)
        default:
            try FileManager.default.removeItem(at: parent)
            try FileManager.default.createDirectory(at: outside.appendingPathExtension("directory"), withIntermediateDirectories: false)
            try FileManager.default.createSymbolicLink(at: parent, withDestinationURL: outside.appendingPathExtension("directory"))
        }
        do {
            _ = try fixture.store.setValue(fixture.root.path, for: .vaultDir)
            Issue.record("An unsafe archive must block the save")
        } catch {
            #expect(error.localizedDescription.contains("did not replace the active config"))
            #expect(error.localizedDescription.contains("config list"))
        }
        #expect(try Data(contentsOf: fixture.configURL) == original)
        #expect(try Data(contentsOf: outside) == original)
    }

    @Test(arguments: ["bytes", "file", "parent"])
    func changedConfigOrParentIsNotOverwritten(kind: String) throws {
        let fixture = try ConfigFixture(storedMode: "icloud", isV3: true)
        defer { fixture.remove() }
        let url = fixture.configURL
        let original = try Data(contentsOf: url)
        let changed = original + Data("\n# external edit".utf8)
        let store = KeyConfigStore(homeDirectoryURL: fixture.home, writeObserver: ConfigWriteObserver { phase in
            guard case let .temporaryFileSynchronized(path) = phase, path == "config.toml" else { return }
            if kind == "parent" {
                let parent = url.deletingLastPathComponent()
                try FileManager.default.moveItem(at: parent, to: parent.appendingPathExtension("previous"))
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
            }
            try (kind == "file" ? original : changed).write(to: url, options: kind == "bytes" ? [] : .atomic)
        })
        #expect(throws: AppError.self) { try store.setValue(fixture.root.path, for: .vaultDir) }
        #expect(try Data(contentsOf: url) == (kind == "file" ? original : changed))
    }

    @Test
    func oversizedConfigCanBeReadButCannotBeShortened() throws {
        let fixture = try ConfigFixture(storedMode: "icloud", isV3: true)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL) + Data(("\n#" + String(repeating: "x", count: 1_048_576)).utf8)
        try original.write(to: fixture.configURL)
        #expect(try fixture.store.load().keychainMode == .icloud)
        #expect(throws: AppError.self) { try fixture.store.setValue(fixture.root.path, for: .vaultDir) }
        #expect(try Data(contentsOf: fixture.configURL) == original)
        #expect(try fixture.snapshots().isEmpty)
    }

    @Test(arguments: ["remove", "replace", "permissions"])
    func archiveMustRemainExactAndPrivateUntilConfigPublication(change: String) throws {
        let fixture = try ConfigFixture(storedMode: "icloud", isV3: true)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL)
        let archive = fixture.archiveURL(original)
        let store = KeyConfigStore(homeDirectoryURL: fixture.home, writeObserver: ConfigWriteObserver { phase in
            guard case let .temporaryFileSynchronized(path) = phase, path == "config.toml" else { return }
            switch change {
            case "remove": try FileManager.default.removeItem(at: archive)
            case "replace": try Data("changed copy".utf8).write(to: archive)
            default: try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: archive.path)
            }
        })
        #expect(throws: AppError.self) { try store.setValue(fixture.root.path, for: .vaultDir) }
        #expect(try Data(contentsOf: fixture.configURL) == original)
    }

    @Test
    func oldWriterDefaultCannotEraseOriginalICloudSnapshot() throws {
        let fixture = try ConfigFixture(storedMode: "icloud", isV3: false)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL)
        _ = try fixture.store.selectV3Vault(vaultID: ConfigFixture.vaultID,
                                         expectedRootHandle: VaultRootDirectoryHandle(opening: fixture.root), expectedKeychainMode: .icloud)
        // The 0.4.1 codec defaults missing mode to local and writes this shape.
        // A separate released-source probe qualifies the real old writer.
        let oldWriter = Data("# key configuration\nvault_dir = \"\(fixture.root.path)\"\nkeychain_mode = \"local\"\nvault_id = \"\(ConfigFixture.vaultID)\"".utf8)
        try oldWriter.write(to: fixture.configURL, options: .atomic)
        _ = try fixture.store.setValue(fixture.root.path, for: .vaultDir)
        #expect(try fixture.snapshots().count == 2)
        #expect(try Data(contentsOf: fixture.archiveURL(original)) == original)
        #expect(try Data(contentsOf: fixture.archiveURL(oldWriter)) == oldWriter)
        #expect(try fixture.store.load().vaultID == ConfigFixture.vaultID)
        #expect(try fixture.store.load().keychainMode == nil)
    }

    @Test(arguments: ["local", "icloud", "omitted"], ["local", "icloud", "omitted"])
    func changedRetainedFieldStillInvalidatesSession(before: String, after: String) throws {
        guard before != after else { return }
        let fixture = try ConfigFixture(storedMode: before, isV3: true)
        defer { fixture.remove() }
        let keys = MemoryVaultKeyStore()
        let handler = KeyServiceHandler(keyStore: keys, entryStore: EntryStore(rootURL: fixture.root),
                                        keychainMode: try fixture.store.load().keychainMode, configStore: fixture.store,
                                        mutationOwner: VaultTransactionMutationOwner(), configuredVaultID: ConfigFixture.vaultID)
        let modeLine = after == "omitted" ? "" : "keychain_mode = \"\(after)\"\n"
        try Data("vault_dir = \"\(fixture.root.path)\"\n\(modeLine)vault_id = \"\(ConfigFixture.vaultID)\"".utf8).write(to: fixture.configURL)
        #expect(handler.handle(.status).errorCode == .operationRefused)
        #expect(keys.invalidateCount == 1)
    }

    @Test(arguments: ["local", "icloud", "omitted"], [false, true])
    func terminalConfigListWarnsOnlyForV2(storedMode: String, isV3: Bool) throws {
        let fixture = try ConfigFixture(storedMode: storedMode, isV3: isV3)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL)
        let io = MemoryIO(stdinIsTTY: false, stdoutIsTTY: true)
        let transport = MemoryTransport { _ in
            Issue.record("Config warnings must not contact the helper")
            return .success()
        }
        let app = KeyCLIApplication(
            transport: transport,
            io: io,
            clipboard: MemoryClipboard(),
            configStore: fixture.store
        )
        #expect(app.run(arguments: ["config", "list"]) == EXIT_SUCCESS)
        let mode = storedMode == "icloud" ? "icloud" : "local"
        let legacyLine = isV3 ? "" : "keychain-mode=\(mode)\n"
        #expect(io.stdout == "vault-dir=\(fixture.root.path(percentEncoded: false))\n" + legacyLine)
        if isV3 {
            #expect(io.stderr.isEmpty)
        } else {
            #expect(io.stderr.components(separatedBy: "Warning:").count == 2)
            #expect(io.stderr.contains("deprecated but still supported"))
            #expect(io.stderr.contains("key migrate --check"))
            #expect(io.stderr.contains("key migrate --help"))
        }
        #expect(transport.requests.isEmpty)
        #expect(try Data(contentsOf: fixture.configURL) == original)
    }

    @Test(arguments: ["local", "icloud", "omitted"], [false, true])
    func configReadsPreserveStableFilesAndExposeOnlyActiveSettings(
        storedMode: String,
        isV3: Bool
    ) throws {
        let fixture = try ConfigFixture(storedMode: storedMode, isV3: isV3)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL)
        let mode: KeychainMode = storedMode == "icloud" ? .icloud : .local
        let configuration = try fixture.store.load()
        let expectedPath = fixture.root.path(percentEncoded: false)
        let expectedAuthority: ConfiguredVaultAuthority = isV3
            ? .v3(vaultID: ConfigFixture.vaultID)
            : .v2(keychainMode: mode)
        #expect(configuration.authority == expectedAuthority)
        #expect(configuration.keychainMode == (isV3 && storedMode == "omitted" ? nil : mode))
        #expect(
            try fixture.store.configuredVaultRuntimeSelection().authority
                == expectedAuthority
        )

        let transport = MemoryTransport { _ in
            Issue.record("Config reads must not contact the helper")
            return .success()
        }
        for arguments in [
            ["config", "list"],
            ["config", "get", "vault-dir"],
            ["config", "get", "keychain-mode"]
        ] {
            let io = MemoryIO(stdinIsTTY: false)
            let app = KeyCLIApplication(
                transport: transport,
                io: io,
                clipboard: MemoryClipboard(),
                configStore: fixture.store
            )
            let exit = app.run(arguments: arguments)
            if isV3, arguments.last == "keychain-mode" {
                #expect(exit == KeyServiceErrorCode.operationRefused.exitCode.rawValue)
                #expect(io.stdout.isEmpty)
                #expect(io.stderr.contains("applies only to legacy vaults"))
                continue
            }
            #expect(exit == EXIT_SUCCESS)
            if arguments == ["config", "list"] {
                let legacyLine = isV3 ? "" : "keychain-mode=\(mode.rawValue)\n"
                #expect(io.stdout == "vault-dir=\(expectedPath)\n" + legacyLine)
                #expect(io.stderr.isEmpty)
            } else if arguments.last == "vault-dir" {
                #expect(io.stdout == "\(expectedPath)\n")
                #expect(io.stderr.isEmpty)
            } else {
                #expect(io.stdout == "\(mode.rawValue)\n")
                #expect(io.stderr.isEmpty)
            }
        }
        #expect(transport.requests.isEmpty)
        #expect(try Data(contentsOf: fixture.configURL) == original)
    }

    @Test(arguments: KeychainMode.allCases)
    func migrationPreservesOriginalConfigBeforeRootUpdate(mode: KeychainMode) throws {
        let fixture = try ConfigFixture(storedMode: mode.rawValue, isV3: false)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.configURL)
        let rootHandle = try VaultRootDirectoryHandle(opening: fixture.root)
        let selected = try fixture.store.selectV3Vault(
            vaultID: ConfigFixture.vaultID,
            expectedRootHandle: rootHandle,
            expectedKeychainMode: mode
        )
        #expect(selected.authority == .v3(vaultID: ConfigFixture.vaultID))
        #expect(selected.keychainMode == nil)
        let newRoot = fixture.home.appendingPathComponent("Moved Vault")
        try FileManager.default.createDirectory(at: newRoot, withIntermediateDirectories: false)
        let updated = try fixture.store.setValue(newRoot.path, for: .vaultDir)
        #expect(updated.authority == selected.authority)
        #expect(updated.keychainMode == nil)
        #expect(!String(decoding: try Data(contentsOf: fixture.configURL), as: UTF8.self).contains("keychain_mode"))
        #expect(try fixture.snapshots().count == 1)
        #expect(try Data(contentsOf: fixture.archiveURL(original)) == original)
    }

    @Test(arguments: [false, true])
    func externalLegacyModeChangeStillInvalidatesHelper(isV3: Bool) throws {
        let fixture = try ConfigFixture(storedMode: "icloud", isV3: isV3)
        defer { fixture.remove() }
        let keys = MemoryVaultKeyStore()
        let handler = KeyServiceHandler(
            keyStore: keys,
            entryStore: EntryStore(rootURL: fixture.root),
            keychainMode: .icloud,
            configStore: fixture.store,
            mutationOwner: VaultTransactionMutationOwner(),
            configuredVaultID: isV3 ? ConfigFixture.vaultID : nil
        )
        // An old writer or manual edit can still alter retained metadata.
        let text = try String(contentsOf: fixture.configURL, encoding: .utf8)
        try text.replacingOccurrences(of: "\"icloud\"", with: "\"local\"")
            .write(to: fixture.configURL, atomically: true, encoding: .utf8)
        let response = handler.handle(.status)
        #expect(response.errorCode == .operationRefused)
        #expect(response.errorMessage?.contains("key lock") == true)
        #expect(keys.invalidateCount == 1)
    }

    @Test(arguments: [
        "keychain_mode = \"unsupported\"",
        "keychain_mode = \"local\"\nkeychain_mode = \"icloud\"",
        "vault_id = \"not-a-uuid\"",
        "vault_id = \"\(ConfigFixture.vaultID)\"\nvault_id = \"\(ConfigFixture.vaultID)\""
    ])
    func malformedConfigProducesNoPartialCLIOutput(extra: String) throws {
        let fixture = try ConfigFixture(storedMode: "omitted", isV3: false)
        defer { fixture.remove() }
        let contents = "vault_dir = \"\(fixture.root.path)\"\n\(extra)\n"
        try contents.write(to: fixture.configURL, atomically: true, encoding: .utf8)
        let io = MemoryIO(stdinIsTTY: false, stdoutIsTTY: true)
        let app = KeyCLIApplication(
            transport: MemoryTransport { _ in
                Issue.record("Malformed config must not contact the helper")
                return .success()
            },
            io: io,
            clipboard: MemoryClipboard(),
            configStore: fixture.store
        )
        #expect(
            app.run(arguments: ["config", "list"])
                == KeyExitCode.configurationFailure.rawValue
        )
        #expect(io.stdout.isEmpty)
        #expect(!io.stderr.isEmpty)
        #expect(!io.stderr.contains("deprecated"))
        #expect(try String(contentsOf: fixture.configURL, encoding: .utf8) == contents)
    }
}

private enum ConfigSaveInterruption: Error { case stopped }

private struct ConfigWriteObserver: V3AtomicStagedObjectWriteObserving {
    let action: @Sendable (V3AtomicStagedObjectWritePhase) throws -> Void
    func didReach(_ phase: V3AtomicStagedObjectWritePhase) throws { try action(phase) }
}

private struct ConfigFixture {
    static let vaultID = "018f4d38-7d5a-7b20-b0f1-97d6e96c44b3"
    let home: URL
    let root: URL
    let store: KeyConfigStore
    let configURL: URL

    init(storedMode: String, isV3: Bool) throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .standardizedFileURL
        root = home.appendingPathComponent("Vault", isDirectory: true)
        store = KeyConfigStore(homeDirectoryURL: home)
        configURL = try writeLegacyTestConfiguration(home: home, root: root).configFileURL
        var contents = "# Stable-compatible fixture\nvault_dir = \"\(root.path)\"\n"
        if storedMode != "omitted" {
            contents += "keychain_mode = \"\(storedMode)\"\n"
        }
        if isV3 {
            contents += "vault_id = \"\(Self.vaultID)\"\n"
        }
        contents += "unknown_setting = \"preserve on reads\"\n"
        try contents.write(to: configURL, atomically: true, encoding: .utf8)
    }

    func remove() {
        try? FileManager.default.removeItem(at: home)
    }

    func archiveURL(_ bytes: Data) -> URL {
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        return configURL.deletingLastPathComponent().appendingPathComponent("legacy-configs")
            .appendingPathComponent(Self.vaultID).appendingPathComponent(digest + ".toml")
    }

    func snapshots() throws -> [URL] {
        let directory = configURL.deletingLastPathComponent().appendingPathComponent("legacy-configs").appendingPathComponent(Self.vaultID)
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "toml" }
    }
}
