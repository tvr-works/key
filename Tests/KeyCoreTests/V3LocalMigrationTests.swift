import Foundation
import Testing
@testable import KeyCore

/// Selection and helper routing for the shipping device-wrapped migration.
@Suite
struct V3LocalMigrationTests {
    private static let operationID = try! VaultTransactionOperationID(
        validating: "018f4d38-7d5a-7b20-b0f1-97d6e96c44c0"
    )
    private static let vaultID = "018f4d38-7d5a-7b20-b0f1-97d6e96c44b3"

    @Test
    func configSelectionIsGuardedAndNotGenerallySettable() throws {
        let home = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        let root = home.appendingPathComponent("Vault", isDirectory: true)
        let configStore = KeyConfigStore(homeDirectoryURL: home)
        try writeLegacyTestConfiguration(home: home, root: root)
        let rootHandle = try VaultRootDirectoryHandle(opening: root)

        let selected = try configStore.selectV3Vault(
            vaultID: Self.vaultID,
            expectedRootHandle: rootHandle,
            expectedKeychainMode: .local
        )

        #expect(selected.vaultID == Self.vaultID)
        #expect(try configStore.load().vaultID == Self.vaultID)
        #expect(throws: AppError.self) {
            try configStore.selectV3Vault(
                vaultID:
                    "018f4d38-7d5a-7b20-b0f1-97d6e96c44c9",
                expectedRootHandle: rootHandle,
                expectedKeychainMode: .local
            )
        }

        let otherHome = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: otherHome) }
        let otherRoot = otherHome.appendingPathComponent(
            "Vault",
            isDirectory: true
        )
        let changedStore = KeyConfigStore(homeDirectoryURL: otherHome)
        try writeLegacyTestConfiguration(home: otherHome, root: otherRoot)
        _ = try changedStore.setValue("icloud", for: .keychainMode)
        let changedRootHandle = try VaultRootDirectoryHandle(
            opening: otherRoot
        )

        #expect(throws: AppError.self) {
            try changedStore.selectV3Vault(
                vaultID: Self.vaultID,
                expectedRootHandle: changedRootHandle,
                expectedKeychainMode: .local
            )
        }
        #expect(try changedStore.load().vaultID == nil)

        let replacedHome = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: replacedHome) }
        let replacedRoot = replacedHome.appendingPathComponent(
            "Vault",
            isDirectory: true
        )
        let movedRoot = replacedHome.appendingPathComponent(
            "Original Vault",
            isDirectory: true
        )
        let replacedStore = KeyConfigStore(
            homeDirectoryURL: replacedHome
        )
        try writeLegacyTestConfiguration(home: replacedHome, root: replacedRoot)
        let originalRootHandle = try VaultRootDirectoryHandle(
            opening: replacedRoot
        )
        try FileManager.default.moveItem(
            at: replacedRoot,
            to: movedRoot
        )
        try FileManager.default.createDirectory(
            at: replacedRoot,
            withIntermediateDirectories: false
        )

        #expect(throws: VaultRootDirectoryHandleError.configuredRootChanged(
            path: replacedRoot.path(percentEncoded: false)
        )) {
            try replacedStore.selectV3Vault(
                vaultID: Self.vaultID,
                expectedRootHandle: originalRootHandle,
                expectedKeychainMode: .local
            )
        }
        #expect(try replacedStore.load().vaultID == nil)
    }

    @Test
    func helperSerializesMigrationAndRequiresRestartAfterSelection() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let migration = RecordingMigrationService()
        let owner = RecordingMigrationMutationOwner()
        let handler = KeyServiceHandler(
            keyStore: MemoryVaultKeyStore(),
            entryStore: EntryStore(rootURL: root),
            mutationOwner: owner,
            migrationService: migration
        )

        let response = handler.handle(.migrationApply)

        #expect(response.exitCode == EXIT_SUCCESS)
        #expect(response.value?.contains("Migration completed.") == true)
        #expect(owner.kinds == [.migrateToV3])
        #expect(migration.operationIDs == [Self.operationID])
        #expect(handler.handle(.list).exitCode == EXIT_FAILURE)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

}

private final class RecordingMigrationService:
    V3LocalMigrationServicing,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var recorded: [VaultTransactionOperationID] = []

    var operationIDs: [VaultTransactionOperationID] {
        lock.withLock { recorded }
    }

    func migrate(
        operationID: VaultTransactionOperationID
    ) throws -> V3LocalMigrationReport {
        lock.withLock {
            recorded.append(operationID)
        }
        return V3LocalMigrationReport(
            vaultID:
                "018f4d38-7d5a-7b20-b0f1-97d6e96c44b3",
            entryCount: 0,
            secretCount: 0,
            totpCount: 0
        )
    }
}

private final class RecordingMigrationMutationOwner:
    VaultTransactionMutationOwning,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var recordedKinds: [VaultTransactionMutationKind] = []

    var kinds: [VaultTransactionMutationKind] {
        lock.withLock { recordedKinds }
    }

    func perform<Result>(
        _ kind: VaultTransactionMutationKind,
        _ mutation: (VaultTransactionMutationContext) throws -> Result
    ) throws -> Result {
        lock.withLock {
            recordedKinds.append(kind)
        }
        return try mutation(VaultTransactionMutationContext(
            operationID: try VaultTransactionOperationID(
                validating:
                    "018f4d38-7d5a-7b20-b0f1-97d6e96c44c0"
            ),
            kind: kind
        ))
    }
}
