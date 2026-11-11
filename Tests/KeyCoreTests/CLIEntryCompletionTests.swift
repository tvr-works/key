import Darwin
import Foundation
import Testing
@testable import KeyCore

struct CLIEntryCompletionTests {
    @Test
    func recoveryNamesComeFromOnlyTheSelectedLocalCacheEvenWhenVaultIsOffline() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let manifest = try V3RecoveryRegistrationTestSupport.Fixture().parent.canonicalBytes
        try manifest.write(to: fixture.cache)
        #expect(fixture.suggestions() == ["fixture/secret", "fixture/totp"])
        #expect(fixture.suggestions(folders: true) == ["fixture/", "fixture/secret", "fixture/totp"])
        // Neither the configured provider directory nor any helper is needed.
        #expect(!FileManager.default.fileExists(atPath: fixture.vault.path))
        #expect(try Data(contentsOf: fixture.cache) == manifest)
    }

    @Test
    func permanentProfileNamesIncludeSpacesPunctuationAndUnicode() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let names = ["work/a b", "work/colon:name", "work/quote'$(echo nope)", "個人/メール"]
        let owner = try V3RecoveryRegistrationTestSupport.Owner()
        let candidate = try V3DeviceWrappedGenesisBuilder().buildPublicationCandidate(
            vaultID: Fixture.vaultID,
            authorityTransitionID: V3RecoveryRegistrationTestSupport.transitionID,
            entryIDs: names.map { _ in UUID().uuidString.lowercased() },
            snapshotEntries: names.map { .init(name: $0, type: .secret, plaintext: "synthetic only") },
            vaultKey: V3RecoveryRegistrationTestSupport.oldKey,
            ownerIdentity: owner.publicIdentity
        )
        try candidate.genesis.manifestData.write(to: fixture.cache)
        #expect(fixture.suggestions() == names.sorted())
        #expect(fixture.suggestions(folders: true) == (names + ["work/", "個人/"]).sorted())
    }

    @Test(arguments: ["missing", "malformed", "oversized", "wrong-vault", "wrong-vault-body", "unknown-profile", "symlink", "directory", "fifo"])
    func unavailableOrUnsafeCacheReturnsNoHints(kind: String) throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        switch kind {
        case "malformed": try Data("{}".utf8).write(to: fixture.cache)
        case "oversized": try Data(repeating: 0, count: 2 * 1_024 * 1_024 + 1).write(to: fixture.cache)
        case "wrong-vault":
            try V3RecoveryRegistrationTestSupport.Fixture().parent.canonicalBytes.write(
                to: fixture.cache.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".json")
            )
        case "wrong-vault-body", "unknown-profile":
            let data = try V3RecoveryRegistrationTestSupport.Fixture().parent.canonicalBytes
            let text = String(decoding: data, as: UTF8.self)
            let altered = kind == "wrong-vault-body"
                ? text.replacingOccurrences(of: Fixture.vaultID, with: UUID().uuidString.lowercased())
                : text.replacingOccurrences(of: "\"profileVersion\":3", with: "\"profileVersion\":99")
            try Data(altered.utf8).write(to: fixture.cache)
        case "symlink":
            let target = fixture.home.appendingPathComponent("target.json")
            try V3RecoveryRegistrationTestSupport.Fixture().parent.canonicalBytes.write(to: target)
            try FileManager.default.createSymbolicLink(at: fixture.cache, withDestinationURL: target)
        case "directory": try FileManager.default.createDirectory(at: fixture.cache, withIntermediateDirectories: false)
        case "fifo": #expect(mkfifo(fixture.cache.path, 0o600) == 0)
        default: break
        }
        #expect(fixture.suggestions().isEmpty)
    }

    @Test
    func cacheForAnotherProductIsNotUsedAndMissingConfigIsNotCreated() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try V3RecoveryRegistrationTestSupport.Fixture().parent.canonicalBytes.write(to: fixture.cache)
        let preview = KeyConfigStore(productIdentity: .preview, homeDirectoryURL: fixture.home)
        #expect(CLIEntryCompletion.suggestions(configStore: preview, includeFolders: false).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: preview.initializationConfigFileURL.path))
    }

    @Test
    func missingCurrentCacheNeverFallsBackToProviderFiles() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(at: fixture.vault, withIntermediateDirectories: true)
        try Data().write(to: fixture.vault.appendingPathComponent("not-a-current-entry.secret"))
        #expect(fixture.suggestions().isEmpty)
    }

    @Test
    func olderVaultsRetainNameCompletionWithoutReadingSecretContents() throws {
        let fixture = try Fixture(legacy: true)
        defer { fixture.remove() }
        let folder = fixture.vault.appendingPathComponent("example")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not a valid encrypted record; names do not require its contents".utf8)
            .write(to: folder.appendingPathComponent("entry.secret"))
        #expect(fixture.suggestions() == ["example/entry"])
        #expect(fixture.suggestions(folders: true) == ["example/", "example/entry"])
    }

    @Test
    func legacyNamesPreserveTheirBytesWithoutModernNormalizationRules() throws {
        let fixture = try Fixture(legacy: true)
        defer { fixture.remove() }
        try FileManager.default.createDirectory(at: fixture.vault, withIntermediateDirectories: true)
        let names = ["cafe\u{301}", "old\\name", " colon:name "]
        let store = EntryStore(rootURL: fixture.vault)
        for name in names {
            try store.validateEntryName(name)
            try Data().write(to: store.url(for: name))
        }
        let expected = try store.listEntries().map { Data($0.utf8) }
        #expect(fixture.suggestions().map { Data($0.utf8) } == expected)
    }

    @Test
    func legacyControlCharactersCannotInjectCompletionProtocolLines() throws {
        let fixture = try Fixture(legacy: true)
        defer { fixture.remove() }
        try FileManager.default.createDirectory(at: fixture.vault, withIntermediateDirectories: true)
        let store = EntryStore(rootURL: fixture.vault)
        for name in ["ordinary", "line\nbreak", "tab\tname", "escape\u{1B}name"] {
            try Data().write(to: store.url(for: name))
        }
        #expect(fixture.suggestions() == ["ordinary"])
    }

    private struct Fixture {
        static let vaultID = V3RecoveryRegistrationTestSupport.vaultID
        let home: URL
        let vault: URL
        let cache: URL
        let store: KeyConfigStore

        init(legacy: Bool = false) throws {
            home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            vault = home.appendingPathComponent("offline-vault")
            store = KeyConfigStore(homeDirectoryURL: home)
            let support = store.initializationConfigFileURL.deletingLastPathComponent()
            cache = support.appendingPathComponent("v3-checkpoint-manifests/\(Self.vaultID).json")
            try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
            let selection = legacy ? "keychain_mode = \"local\"\n" : "vault_id = \"\(Self.vaultID)\"\n"
            try Data(("vault_dir = \"\(vault.path)\"\n" + selection).utf8)
                .write(to: store.initializationConfigFileURL)
        }

        func suggestions(folders: Bool = false) -> [String] {
            CLIEntryCompletion.suggestions(configStore: store, includeFolders: folders)
        }

        func remove() { try? FileManager.default.removeItem(at: home) }
    }
}
