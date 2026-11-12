import CryptoKit
import Darwin
import Foundation

public enum VaultPathSource: Equatable, Sendable {
    case appSupportConfigDefault
    case appSupportConfigCustom

    public var displayString: String {
        switch self {
        case .appSupportConfigDefault:
            return "App Support config (default)"
        case .appSupportConfigCustom:
            return "App Support config (custom)"
        }
    }
}

/// Active key authority, distinct from the mode retained in the legacy file.
enum ConfiguredVaultAuthority: Equatable, Sendable {
    case v2(keychainMode: KeychainMode)
    case v3(vaultID: String)

    init(keychainMode: KeychainMode?, vaultID: String?) {
        if let vaultID {
            self = .v3(vaultID: vaultID)
        } else {
            self = .v2(keychainMode: keychainMode ?? .local)
        }
    }

    var vaultID: String? {
        guard case let .v3(vaultID) = self else { return nil }
        return vaultID
    }
}

public struct KeyConfiguration: Equatable, Sendable {
    public let configFileURL: URL
    public let vaultDirectoryURL: URL
    public let vaultPathSource: VaultPathSource
    /// Active for v2; optional retained metadata in older v3 configurations.
    public let keychainMode: KeychainMode?
    /// The exact device-local v3 vault selection. A missing value means v2.
    public var vaultID: String? { authority.vaultID }
    let authority: ConfiguredVaultAuthority

    public init(
        configFileURL: URL,
        vaultDirectoryURL: URL,
        vaultPathSource: VaultPathSource,
        keychainMode: KeychainMode?,
        vaultID: String? = nil
    ) {
        self.configFileURL = configFileURL
        self.vaultDirectoryURL = vaultDirectoryURL
        self.vaultPathSource = vaultPathSource
        self.keychainMode = vaultID == nil ? (keychainMode ?? .local) : keychainMode
        self.authority = ConfiguredVaultAuthority(
            keychainMode: keychainMode,
            vaultID: vaultID
        )
    }

    func value(for key: ConfigKey) throws -> String {
        switch key {
        case .vaultDir:
            return vaultDirectoryURL.path(percentEncoded: false)
        case .keychainMode:
            guard case let .v2(mode) = authority else {
                throw Self.legacyModeUnavailable
            }
            return mode.rawValue
        }
    }

    var listedValues: [KeyConfigValue] {
        var values = [KeyConfigValue(key: .vaultDir, value: vaultDirectoryURL.path(percentEncoded: false))]
        if case let .v2(mode) = authority {
            values.append(KeyConfigValue(
                key: .keychainMode,
                value: mode.rawValue
            ))
        }
        return values
    }

    static var legacyModeUnavailable: AppError {
        .operationRefused("This vault uses device enrollment. keychain-mode applies only to legacy vaults. Use vault-dir to change its folder.")
    }

    /// Historical enrollment adapters may use a stored mode, but must never
    /// invent one when the selected configuration contains no legacy key choice.
    func requireStoredKeychainMode() throws -> KeychainMode {
        guard let keychainMode else { throw Self.legacyModeUnavailable }
        return keychainMode
    }
}

public struct KeyConfigValue: Equatable, Sendable {
    public let key: ConfigKey
    public let value: String

    public init(key: ConfigKey, value: String) {
        self.key = key
        self.value = value
    }
}

public struct VaultLocation: Equatable, Sendable {
    public let rootURL: URL
    public let configFileURL: URL
    public let pathSource: VaultPathSource

    public init(rootURL: URL, configFileURL: URL, pathSource: VaultPathSource) {
        self.rootURL = rootURL
        self.configFileURL = configFileURL
        self.pathSource = pathSource
    }
}

struct ConfiguredVaultRuntimeSelection: Equatable, Sendable {
    let rootURL: URL
    // Compare retained metadata too, preserving the helper's fail-closed guard.
    let keychainMode: KeychainMode?
    let authority: ConfiguredVaultAuthority
    var vaultID: String? { authority.vaultID }

    init(rootURL: URL, keychainMode: KeychainMode?, vaultID: String?) {
        self.rootURL = rootURL
        self.keychainMode = vaultID == nil ? (keychainMode ?? .local) : keychainMode
        self.authority = ConfiguredVaultAuthority(
            keychainMode: keychainMode,
            vaultID: vaultID
        )
    }
}

public struct KeyConfigStore {
    private let fileManager: FileManager
    private let homeDirectoryURL: URL
    private let productIdentity: KeyProductIdentity
    private let writeObserver: any V3AtomicStagedObjectWriteObserving

    public init(
        productIdentity: KeyProductIdentity = .stable,
        fileManager: FileManager = .default,
        homeDirectoryURL: URL? = nil
    ) {
        self.init(productIdentity: productIdentity, fileManager: fileManager,
                  homeDirectoryURL: homeDirectoryURL, writeObserver: V3NoopAtomicStagedObjectWriteObserver())
    }

    init(
        productIdentity: KeyProductIdentity = .stable,
        fileManager: FileManager = .default,
        homeDirectoryURL: URL? = nil,
        writeObserver: any V3AtomicStagedObjectWriteObserving
    ) {
        self.productIdentity = productIdentity
        self.fileManager = fileManager
        self.homeDirectoryURL = homeDirectoryURL ?? fileManager.homeDirectoryForCurrentUser
        self.writeObserver = writeObserver
    }

    public func load() throws -> KeyConfiguration {
        guard try hasConfiguration() else {
            throw Self.notInitializedError
        }
        let paths = configurationPaths()
        try ensurePathIsNotDirectory(
            at: paths.configFileURL,
            failureMessage: "Key config file '\(paths.configFileURL.path)' exists but is a directory."
        )
        let configuration = try loadConfigurationFile(from: paths.configFileURL)
        try requireExistingVaultDirectory(configuration.vaultDirectoryURL)
        return KeyConfiguration(
            configFileURL: paths.configFileURL,
            vaultDirectoryURL: configuration.vaultDirectoryURL,
            vaultPathSource: configuration.vaultDirectoryURL.standardizedFileURL == paths.defaultVaultURL.standardizedFileURL
                ? .appSupportConfigDefault : .appSupportConfigCustom,
            keychainMode: configuration.keychainMode,
            vaultID: configuration.vaultID
        )
    }

    static var notInitializedError: AppError {
        .operationRefused("No vault is configured on this Mac. To create a new vault, run `\(KeyProductIdentity.currentProcess.cliExecutableName) init [directory]`. To join one from another Mac, run `\(KeyProductIdentity.currentProcess.cliExecutableName) help share` for instructions. Do not use init for an existing vault.")
    }

    /// A fresh filesystem reader for cross-queue selection checks. Capture only
    /// immutable identity/path values, not this store's FileManager instance.
    func selectionValidator(expected: KeyConfiguration) -> @Sendable () throws -> Void {
        let home = homeDirectoryURL
        let product = productIdentity
        return {
            let reader = KeyConfigStore(productIdentity: product, fileManager: FileManager(), homeDirectoryURL: home)
            guard try reader.load() == expected else {
                throw AppError.operationRefused("Configured vault selection changed during recovery setup. Preserve the saved attempt; no replacement was authorized.")
            }
        }
    }

    @discardableResult
    private func requireExistingVaultDirectory(_ url: URL) throws -> VaultRootDirectoryHandle {
        do {
            return try VaultRootDirectoryHandle(opening: url)
        } catch {
            throw AppError.invalidConfiguration("The configured vault directory is unavailable: \(error.localizedDescription) Restore the existing vault or correct its configured path; Key will not create a replacement.")
        }
    }

    public func getValue(for key: ConfigKey) throws -> String {
        try load().value(for: key)
    }

    /// Presence is intentionally not validity. Even a malformed file, directory,
    /// or dangling link must prevent init from replacing an existing selection.
    func hasConfiguration() throws -> Bool {
        var metadata = stat()
        if lstat(configurationPaths().configFileURL.path, &metadata) == 0 { return true }
        guard errno == ENOENT else {
            throw AppError.io("Could not inspect the existing Key configuration.")
        }
        return false
    }

    func requireUnconfigured() throws {
        guard try !hasConfiguration() else {
            throw AppError.operationRefused("Key already has a configuration on this Mac. Init never replaces it. Run `\(KeyProductIdentity.currentProcess.cliExecutableName) status` to check the vault. For an older vault, `\(KeyProductIdentity.currentProcess.cliExecutableName) migrate --check` checks migration readiness without changing it.")
        }
    }

    var initializationConfigFileURL: URL { configurationPaths().configFileURL }

    /// Internal restore preparation only. Never replaces a configuration or
    /// selects a vault. The caller retains this physical root for later checks.
    func unconfiguredRestoreRoot() throws -> VaultRootDirectoryHandle {
        try requireUnconfigured()
        let paths = configurationPaths()
        let root = try VaultRootDirectoryHandle(opening: paths.configDirectoryURL)
        try requireUnconfigured()
        return root
    }

    /// Completion may inspect an existing selection, but never bootstrap or
    /// replace it. The restore environment checks exact bytes through this root.
    func restoreCompletionRoot() throws -> VaultRootDirectoryHandle {
        try VaultRootDirectoryHandle(opening: configurationPaths().configDirectoryURL)
    }

    /// Explicit initial restore may create local scaffolding, never a vault,
    /// config selection, ownership record or credential. Resume opens only the
    /// existing roots. All creation is bounded and relative to retained parents.
    func restoreMetadataRoots(
        source: VaultRootDirectoryHandle, parent: VaultRootDirectoryHandle, name: String,
        create: Bool, validateScope: () throws -> Void
    ) throws -> (configuration: VaultRootDirectoryHandle, cache: VaultRootDirectoryHandle) {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.utf8.contains(0) else {
            throw V3RecoveryRestoreError.invalidIntent
        }
        func recheck() throws {
            try validateScope()
            try source.requireConfiguredRootIdentity()
            try parent.requireConfiguredRootIdentity()
            if create { try requireUnconfigured() }
        }
        try recheck()
        let root: VaultRootDirectoryHandle
        if create {
            var current = try VaultRootDirectoryHandle(opening: homeDirectoryURL)
            for component in ["Library", "Application Support", productIdentity.applicationSupportDirectoryName] {
                try recheck()
                guard try !V3RecoveryRestoreEnvironment.contains(source, current),
                      !(current.identity == parent.identity && component.caseInsensitiveCompare(name) == .orderedSame)
                else { throw V3RecoveryRestoreError.overlappingDirectories }
                current = try restoreMetadataDirectory(in: current, name: component, create: true, validateScope: recheck)
            }
            root = current
        } else {
            root = try restoreCompletionRoot()
        }
        try recheck()
        guard try !V3RecoveryRestoreEnvironment.contains(source, root),
              try !V3RecoveryRestoreEnvironment.contains(root, source),
              try !V3RecoveryRestoreEnvironment.contains(root, parent)
        else { throw V3RecoveryRestoreError.overlappingDirectories }
        let cache = try restoreMetadataDirectory(
            in: root, name: "v3-checkpoint-manifests", create: create, validateScope: recheck)
        try recheck()
        try root.requireConfiguredRootIdentity()
        try cache.requireConfiguredRootIdentity()
        return (root, cache)
    }

    private func restoreMetadataDirectory(
        in parent: VaultRootDirectoryHandle, name: String, create: Bool,
        validateScope: () throws -> Void
    ) throws -> VaultRootDirectoryHandle {
        // Product identity is supplied by composition, not a path from a record.
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.utf8.contains(0) else {
            throw AppError.invalidConfiguration("Invalid local recovery directory name.")
        }
        try validateScope()
        if create {
            try parent.withFileDescriptor { descriptor in
                try validateScope()
                if mkdirat(descriptor, name, mode_t(0o700)) == 0 {
                    guard fsync(descriptor) == 0 else {
                        throw AppError.io("Could not synchronize local recovery scaffolding. Leave it intact for inspection.")
                    }
                } else if errno != EEXIST {
                    throw AppError.io("Could not prepare local recovery scaffolding (POSIX error \(errno)).")
                }
            }
        }
        let child = try VaultRootDirectoryHandle(
            opening: parent.rootURL.appendingPathComponent(name, isDirectory: true))
        try parent.withResolvedDescriptor(at: name, expecting: .directory) { descriptor in
            var metadata = stat()
            guard fstat(descriptor.rawValue, &metadata) == 0,
                  child.identity == VaultRootDirectoryIdentity(
                    deviceID: UInt64(metadata.st_dev), fileID: UInt64(metadata.st_ino))
            else { throw V3RecoveryRestoreError.locationChanged }
        }
        try validateScope()
        try parent.requireConfiguredRootIdentity()
        try child.requireConfiguredRootIdentity()
        return child
    }

    func restoredVaultConfigurationData(root: URL, vaultID: String, includingLegacyMode: Bool = false) throws -> Data {
        guard isValidV3UUID(vaultID) else {
            throw AppError.invalidConfiguration("Key cannot configure a vault with an invalid ID.")
        }
        return configurationData(KeyConfigurationFile(
            vaultDirectoryURL: root.standardizedFileURL, keychainMode: nil, vaultID: vaultID
        ), includingLegacyMode: includingLegacyMode)
    }

    /// Reserves this destination before any device identity is created. Records
    /// are local, contain no keys, and survive process failure. A later attempt
    /// at this path must be inspected, never silently initialized again.
    func reserveNewVaultSelection(
        rootHandle: VaultRootDirectoryHandle,
        operationID: VaultTransactionOperationID
    ) throws -> (String) throws -> Void {
        try requireUnconfigured()
        let paths = try bootstrapPaths()
        let configRoot = try VaultRootDirectoryHandle(opening: paths.configDirectoryURL)
        let rootPath = rootHandle.rootURL.standardizedFileURL.path
        // Directory identity also catches a retry through a renamed path or
        // a different spelling of a symlinked ancestor.
        let recordPath = "v3-init-attempts/\(rootHandle.identity.deviceID)-\(rootHandle.identity.fileID).json"
        let record = NewVaultInitializationRecord(
            operationID: operationID.rawValue,
            vaultDirectory: rootPath,
            deviceID: rootHandle.identity.deviceID,
            fileID: rootHandle.identity.fileID
        )
        let bytes = try JSONEncoder().encode(record)
        let writer = V3AtomicStagedObjectWriter(rootHandle: configRoot)
        do {
            try writer.install(bytes, at: recordPath)
        } catch {
            throw AppError.operationRefused("Cannot reserve initialization. An earlier attempt may need inspection at '\(paths.configDirectoryURL.appendingPathComponent(recordPath).path)'. Leave its files and device identity intact; init will not automatically retry or clean it up. \(error.localizedDescription)")
        }
        return { vaultID in
            guard isValidV3UUID(vaultID) else {
                throw AppError.invalidConfiguration("Key cannot configure a vault with an invalid ID.")
            }
            try requireUnconfigured()
            try rootHandle.requireConfiguredRootIdentity()
            try configRoot.requireConfiguredRootIdentity()
            // Recheck that our durable reservation was not replaced.
            let observed = try configRoot.withResolvedDescriptor(at: recordPath, expecting: .regularFile) {
                readObjectData(descriptor: $0.rawValue, maximumBytes: bytes.count)
            }
            guard case let .available(data) = observed, data == bytes else {
                throw AppError.operationRefused("The local record for this setup attempt changed. Leave the vault folder and setup record intact for investigation.")
            }
            let configuration = KeyConfigurationFile(
                vaultDirectoryURL: rootHandle.rootURL,
                keychainMode: nil,
                vaultID: vaultID
            )
            // Atomic, durable publication without replacing another writer's
            // config. Retain the attempt record as an inspection receipt.
            try writer.install(configurationData(configuration), at: paths.configFileURL.lastPathComponent)
        }
    }

    /// Binds an explicit joining ceremony to a root without selecting a vault.
    /// Call with `create` only after authenticating the selected invitation.
    func prepareEnrollmentSelection(
        rootHandle: VaultRootDirectoryHandle,
        invitationDigest: Data,
        vaultID: String,
        create: Bool
    ) throws -> (String) throws -> Void {
        try requireUnconfigured()
        guard invitationDigest.count == 32, isValidV3UUID(vaultID) else {
            throw AppError.invalidConfiguration("Invalid enrollment invitation or vault ID.")
        }
        try rootHandle.requireConfiguredRootIdentity()
        let paths = create ? try bootstrapPaths() : configurationPaths()
        let configRoot: VaultRootDirectoryHandle
        do {
            configRoot = try VaultRootDirectoryHandle(opening: paths.configDirectoryURL)
        } catch {
            throw AppError.operationRefused("Cannot open the local enrollment records: \(error.localizedDescription) Start with `\(KeyProductIdentity.currentProcess.cliExecutableName) share join` in the existing vault folder. Do not use init for an existing vault.")
        }
        let recordPath = "v3-enrollment-roots/\(v3LowercaseHex(invitationDigest)).json"
        let record = EnrollmentRootRecord(
            version: 1, vaultID: vaultID,
            invitationID: v3LowercaseHex(invitationDigest),
            vaultDirectory: rootHandle.rootURL.standardizedFileURL.path,
            deviceID: rootHandle.identity.deviceID,
            fileID: rootHandle.identity.fileID
        )
        let writer = V3AtomicStagedObjectWriter(rootHandle: configRoot)
        if create {
            do {
                try writer.install(JSONEncoder().encode(record), at: recordPath)
            } catch {
                // An exact retry may reuse the durable record, never replace it.
                try requireEnrollmentRoot(record, at: recordPath, in: configRoot)
            }
        }
        try requireEnrollmentRoot(record, at: recordPath, in: configRoot)
        return { selectedID in
            guard selectedID == vaultID else {
                throw AppError.operationRefused("The verified vault does not match the invitation you used. Key has stopped joining.")
            }
            try requireUnconfigured()
            try rootHandle.requireConfiguredRootIdentity()
            try configRoot.requireConfiguredRootIdentity()
            try requireEnrollmentRoot(record, at: recordPath, in: configRoot)
            let configuration = KeyConfigurationFile(
                vaultDirectoryURL: rootHandle.rootURL,
                keychainMode: nil,
                vaultID: vaultID
            )
            try writer.install(configurationData(configuration), at: paths.configFileURL.lastPathComponent)
        }
    }

    private func requireEnrollmentRoot(
        _ expected: EnrollmentRootRecord,
        at path: String,
        in root: VaultRootDirectoryHandle
    ) throws {
        let observed = try root.withResolvedDescriptor(at: path, expecting: .regularFile) {
            readObjectData(descriptor: $0.rawValue, maximumBytes: 16_384)
        }
        guard case let .available(bytes) = observed,
              let record = try? JSONDecoder().decode(EnrollmentRootRecord.self, from: bytes),
              record == expected
        else {
            throw AppError.operationRefused("This joining attempt does not match the saved folder record. Use the same folder and invitation as the join request; leave existing records intact for investigation.")
        }
    }

    public func setValue(_ value: String, for key: ConfigKey) throws -> KeyConfiguration {
        guard try hasConfiguration() else { throw Self.notInitializedError }
        let paths = configurationPaths()
        let snapshot = try loadConfigurationSnapshot(from: paths.configFileURL)
        let current = snapshot.configuration
        let updatedFile: KeyConfigurationFile
        let selectedRoot: VaultRootDirectoryHandle

        switch key {
        case .vaultDir:
            let resolvedURL = try resolveConfiguredPath(value, configFileURL: paths.configFileURL)
            selectedRoot = try requireExistingVaultDirectory(resolvedURL)
            updatedFile = KeyConfigurationFile(
                vaultDirectoryURL: resolvedURL,
                keychainMode: current.vaultID == nil ? current.keychainMode : nil,
                vaultID: current.vaultID
            )
        case .keychainMode:
            guard current.vaultID == nil else { throw KeyConfiguration.legacyModeUnavailable }
            selectedRoot = try requireExistingVaultDirectory(current.vaultDirectoryURL)
            guard let mode = KeychainMode(rawValue: value) else {
                throw AppError.invalidConfiguration("Unsupported keychain mode '\(value)'. Expected 'local' or 'icloud'.")
            }
            updatedFile = KeyConfigurationFile(
                vaultDirectoryURL: current.vaultDirectoryURL,
                keychainMode: mode,
                vaultID: current.vaultID
            )
        }

        try writeConfigurationFile(updatedFile, replacing: snapshot) {
            try selectedRoot.requireConfiguredRootIdentity()
        }
        return try load()
    }

    public func listValues() throws -> [KeyConfigValue] {
        try load().listedValues
    }

    /// Reads the existing configured root without creating config or vault
    /// state. The running helper uses this as a fail-closed consistency check.
    func configuredVaultDirectoryURL() throws -> URL {
        try configuredVaultRuntimeSelection().rootURL
    }

    /// Reads the running helper's complete storage selection without creating
    /// configuration, directories, checkpoints, or vault files.
    func configuredVaultRuntimeSelection()
        throws -> ConfiguredVaultRuntimeSelection
    {
        let paths = configurationPaths()
        let configPath = paths.configFileURL.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: configPath) else {
            throw AppError.invalidConfiguration(
                "Key config file '\(paths.configFileURL.path)' does not exist."
            )
        }
        try ensurePathIsNotDirectory(
            at: paths.configFileURL,
            failureMessage: "Key config file '\(paths.configFileURL.path)' exists but is a directory."
        )
        let configuration = try loadConfigurationFile(
            from: paths.configFileURL
        )
        return ConfiguredVaultRuntimeSelection(
            rootURL: configuration.vaultDirectoryURL,
            keychainMode: configuration.keychainMode,
            vaultID: configuration.vaultID
        )
    }

    /// Selects one fully verified v3 vault without exposing `vault_id` as a
    /// general-purpose configuration mutation.
    ///
    /// Migration calls this last and supplies the exact v2 runtime selection
    /// under which it began. A changed root, key mode, or existing v3
    /// selection fails rather than being overwritten.
    func selectV3Vault(
        vaultID: String,
        expectedRootHandle: VaultRootDirectoryHandle,
        expectedKeychainMode: KeychainMode
    ) throws -> KeyConfiguration {
        guard isValidV3UUID(vaultID) else {
            throw AppError.invalidConfiguration(
                "Key cannot configure a vault with an invalid ID."
            )
        }
        let paths = configurationPaths()
        let snapshot = try loadConfigurationSnapshot(from: paths.configFileURL)
        let current = snapshot.configuration
        guard current.vaultID == nil else {
            throw AppError.operationRefused(
                "This Mac is already configured to use a device-enrolled vault."
            )
        }
        guard current.vaultDirectoryURL.standardizedFileURL
                == expectedRootHandle.rootURL.standardizedFileURL,
              current.keychainMode == expectedKeychainMode
        else {
            throw AppError.operationRefused(
                "The vault configuration changed during migration. Key did not replace it. Check the current configuration before trying again."
            )
        }
        try expectedRootHandle.requireConfiguredRootIdentity()

        try writeConfigurationFile(
            KeyConfigurationFile(
                vaultDirectoryURL: current.vaultDirectoryURL,
                keychainMode: nil,
                vaultID: vaultID
            ),
            replacing: snapshot,
            validateSelection: { try expectedRootHandle.requireConfiguredRootIdentity() }
        )
        let pathSource: VaultPathSource =
            current.vaultDirectoryURL.standardizedFileURL
                == paths.defaultVaultURL.standardizedFileURL
            ? .appSupportConfigDefault
            : .appSupportConfigCustom
        return KeyConfiguration(
            configFileURL: paths.configFileURL,
            vaultDirectoryURL: current.vaultDirectoryURL,
            vaultPathSource: pathSource,
            keychainMode: nil,
            vaultID: vaultID
        )
    }

    private func bootstrapPaths() throws -> BootstrapPaths {
        let paths = configurationPaths()

        try ensureDirectoryExists(
            at: paths.configDirectoryURL,
            failureMessage: "Key config directory '\(paths.configDirectoryURL.path)' exists but is not a directory."
        )

        return paths
    }

    private func configurationPaths() -> BootstrapPaths {
        let configDirectoryURL = homeDirectoryURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(
                productIdentity.applicationSupportDirectoryName,
                isDirectory: true
            )
        let configFileURL = configDirectoryURL
            .appendingPathComponent("config.toml", isDirectory: false)
        let defaultVaultURL = homeDirectoryURL
            .appendingPathComponent(
                productIdentity.defaultVaultDirectoryName,
                isDirectory: true
            )

        return BootstrapPaths(
            configDirectoryURL: configDirectoryURL,
            configFileURL: configFileURL,
            defaultVaultURL: defaultVaultURL
        )
    }

    private func loadConfigurationFile(from configFileURL: URL) throws -> KeyConfigurationFile {
        // Preserve read compatibility with existing dotfile links. Updates use
        // a retained, nonsymlink snapshot instead of following a redirected path.
        let data: Data
        do {
            data = try Data(contentsOf: configFileURL)
        } catch {
            throw AppError.io("Failed to read vault configuration at '\(configFileURL.path)': \(error.localizedDescription)")
        }
        return try parseConfigurationFile(data, from: configFileURL)
    }

    private func loadConfigurationSnapshot(from url: URL) throws -> KeyConfigurationSnapshot {
        let root: VaultRootDirectoryHandle
        let data: Data
        let identity: KeyConfigurationFileIdentity
        do {
            root = try VaultRootDirectoryHandle(opening: url.deletingLastPathComponent())
            (data, identity) = try readConfigurationBytes(in: root, maximumBytes: Int.max)
            try root.requireConfiguredRootIdentity()
        } catch {
            throw AppError.operationRefused("Key cannot safely update this configuration. Updates require a regular config.toml in a real directory. Keep the existing config and inspect its path before retrying. \(error.localizedDescription)")
        }
        return try KeyConfigurationSnapshot(
            configuration: parseConfigurationFile(data, from: url), data: data,
            root: root, identity: identity
        )
    }

    private func readConfigurationBytes(
        in root: VaultRootDirectoryHandle, maximumBytes: Int
    ) throws -> (Data, KeyConfigurationFileIdentity) {
        try root.withResolvedDescriptor(at: "config.toml", expecting: .regularFile) { descriptor in
            var metadata = stat()
            guard fstat(descriptor.rawValue, &metadata) == 0,
                  case let .available(data) = readObjectData(
                    descriptor: descriptor.rawValue, maximumBytes: maximumBytes
                  )
            else { throw AppError.io("Could not read the saved Key configuration.") }
            return (data, KeyConfigurationFileIdentity(
                device: UInt64(truncatingIfNeeded: metadata.st_dev), file: UInt64(metadata.st_ino)
            ))
        }
    }

    private func requireUnchanged(_ snapshot: KeyConfigurationSnapshot) throws {
        try snapshot.root.requireConfiguredRootIdentity()
        let (data, identity) = try readConfigurationBytes(in: snapshot.root, maximumBytes: snapshot.data.count)
        guard identity == snapshot.identity, data == snapshot.data else {
            throw AppError.operationRefused("The configuration changed before it could be saved. Check the current settings before trying again.")
        }
    }

    private func preserveConfiguration(_ snapshot: KeyConfigurationSnapshot, vaultID: String) throws -> () throws -> Void {
        let parent = snapshot.root
        let archiveURL = parent.rootURL.appendingPathComponent("legacy-configs").appendingPathComponent(vaultID)
        do {
            guard snapshot.data.count <= 1_048_576 else {
                throw AppError.operationRefused("The existing config exceeds the 1 MiB preservation limit. Inspect and back it up before reducing its size.")
            }
            try requireUnchanged(snapshot)
            let archives = try restoreMetadataDirectory(in: parent, name: "legacy-configs", create: true) {
                try requireUnchanged(snapshot)
            }
            try requirePrivateArchiveDirectory(archives)
            let destination = try restoreMetadataDirectory(in: archives, name: vaultID, create: true) {
                try requireUnchanged(snapshot)
                try archives.requireConfiguredRootIdentity()
            }
            try requirePrivateArchiveDirectory(destination)
            let name = SHA256.hash(data: snapshot.data).map { String(format: "%02x", $0) }.joined() + ".toml"
            try V3AtomicStagedObjectWriter(rootHandle: destination, observer: writeObserver).install(snapshot.data, at: name) {
                try requireUnchanged(snapshot)
                try archives.requireConfiguredRootIdentity()
                try destination.requireConfiguredRootIdentity()
            }
            let validateArchive = {
                try requirePrivateArchiveDirectory(archives)
                try requirePrivateArchiveDirectory(destination)
                try destination.withResolvedDescriptor(at: name, expecting: .regularFile) { descriptor in
                    var metadata = stat()
                    guard fstat(descriptor.rawValue, &metadata) == 0,
                          metadata.st_uid == geteuid(), metadata.st_mode & 0o077 == 0,
                          metadata.st_nlink == 1,
                          case let .available(data) = readObjectData(
                            descriptor: descriptor.rawValue, maximumBytes: snapshot.data.count
                          ), data == snapshot.data
                    else { throw AppError.io("The retained config is not an exact, private copy.") }
                    // An exact preexisting object may be left by an interrupted
                    // install. Synchronize it too before discarding old fields.
                    try synchronizeFile(descriptor.rawValue, path: name)
                }
                try destination.withFileDescriptor { try synchronizeDirectory($0, path: vaultID) }
                try archives.withFileDescriptor { try synchronizeDirectory($0, path: "legacy-configs") }
                try parent.withFileDescriptor { try synchronizeDirectory($0, path: parent.rootURL.path) }
            }
            try validateArchive()
            return validateArchive
        } catch {
            throw AppError.io("Could not preserve the original configuration under '\(archiveURL.path)'. Key did not replace the active config. Keep these files and check `\(productIdentity.cliExecutableName) config list` before retrying. \(error.localizedDescription)")
        }
    }

    private func requirePrivateArchiveDirectory(_ root: VaultRootDirectoryHandle) throws {
        try root.withFileDescriptor { descriptor in
            var metadata = stat()
            guard fstat(descriptor, &metadata) == 0,
                  metadata.st_uid == geteuid(), metadata.st_mode & 0o077 == 0
            else { throw AppError.io("Retained configuration directories must be private to this user.") }
        }
    }

    private func writeConfigurationFile(
        _ configuration: KeyConfigurationFile, replacing snapshot: KeyConfigurationSnapshot,
        validateSelection: () throws -> Void = {}
    ) throws {
        var validateArchive: (() throws -> Void)?
        if let vaultID = configuration.vaultID,
           snapshot.configuration.vaultID == nil || snapshot.configuration.keychainMode != nil {
            validateArchive = try preserveConfiguration(snapshot, vaultID: vaultID)
        }
        do {
            try V3AtomicStagedObjectWriter(rootHandle: snapshot.root, observer: writeObserver).replace(
                configurationData(configuration), at: "config.toml"
            ) {
                try requireUnchanged(snapshot)
                try validateArchive?()
                try validateSelection()
            }
        } catch {
            // A directory-sync error can occur after the rename. Do not claim
            // that the old config is still selected when publication is unclear.
            throw AppError.io("Could not confirm the configuration save. Keep the config and any retained copies; run `\(productIdentity.cliExecutableName) config list` before retrying. \(error.localizedDescription)")
        }
    }

    private func parseConfigurationFile(_ data: Data, from configFileURL: URL) throws -> KeyConfigurationFile {
        guard let text = String(data: data, encoding: .utf8) else {
            throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' is not valid UTF-8.")
        }

        var vaultDirectory: URL?
        var keychainMode: KeychainMode?
        var vaultID: String?
        var sawVaultID = false

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            guard let separatorIndex = line.firstIndex(of: "=") else {
                continue
            }

            let key = line[..<separatorIndex].trimmingCharacters(in: .whitespaces)
            let valuePortion = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "vault_dir":
                guard vaultDirectory == nil else {
                    throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' declares 'vault_dir' more than once.")
                }

                let configuredPath = try parseQuotedString(
                    valuePortion,
                    configFileURL: configFileURL,
                    keyName: "vault_dir"
                )
                vaultDirectory = try resolveConfiguredPath(configuredPath, configFileURL: configFileURL)
            case "keychain_mode":
                guard keychainMode == nil else {
                    throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' declares 'keychain_mode' more than once.")
                }

                let rawMode = try parseQuotedString(
                    valuePortion,
                    configFileURL: configFileURL,
                    keyName: "keychain_mode"
                )
                guard let parsedMode = KeychainMode(rawValue: rawMode) else {
                    throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' has unsupported 'keychain_mode' value '\(rawMode)'.")
                }
                keychainMode = parsedMode
            case "vault_id":
                guard !sawVaultID else {
                    throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' declares 'vault_id' more than once.")
                }
                sawVaultID = true
                let rawVaultID = try parseQuotedString(
                    valuePortion,
                    configFileURL: configFileURL,
                    keyName: "vault_id"
                )
                guard isValidV3UUID(rawVaultID) else {
                    throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' has an invalid canonical version 3 'vault_id'.")
                }
                vaultID = rawVaultID
            default:
                continue
            }
        }

        guard let vaultDirectory else {
            throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' is missing 'vault_dir'.")
        }

        return KeyConfigurationFile(
            vaultDirectoryURL: vaultDirectory,
            keychainMode: vaultID == nil ? (keychainMode ?? .local) : keychainMode,
            vaultID: vaultID
        )
    }

    private func configurationData(_ configuration: KeyConfigurationFile, includingLegacyMode: Bool = false) -> Data {
        let escapedPath = configuration.vaultDirectoryURL.path(percentEncoded: false)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        var contents = """
        # key configuration
        vault_dir = "\(escapedPath)"
        """
        if configuration.vaultID == nil || includingLegacyMode {
            contents += "\nkeychain_mode = \"\((configuration.keychainMode ?? .local).rawValue)\""
        }
        if let vaultID = configuration.vaultID {
            contents += "\nvault_id = \"\(vaultID)\""
        }

        return Data(contents.utf8)
    }

    private func ensureDirectoryExists(at url: URL, failureMessage: String) throws {
        var isDirectory: ObjCBool = false
        let path = normalizedPath(for: url)

        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw AppError.invalidConfiguration(failureMessage)
            }
            return
        }

        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw AppError.io("Failed to create directory at '\(path)': \(error.localizedDescription)")
        }
    }

    private func ensurePathIsNotDirectory(at url: URL, failureMessage: String) throws {
        var isDirectory: ObjCBool = false
        let path = normalizedPath(for: url)
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        throw AppError.invalidConfiguration(failureMessage)
    }

    private func normalizedPath(for url: URL) -> String {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        guard path.count > 1, path.hasSuffix("/") else {
            return path
        }
        return String(path.dropLast())
    }

    private func parseQuotedString(
        _ valuePortion: String,
        configFileURL: URL,
        keyName: String
    ) throws -> String {
        guard valuePortion.first == "\"" else {
            throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' must quote '\(keyName)'.")
        }

        var result = ""
        var isEscaping = false
        var reachedClosingQuote = false
        var currentIndex = valuePortion.index(after: valuePortion.startIndex)
        var remainderStartIndex = valuePortion.endIndex

        while currentIndex < valuePortion.endIndex {
            let character = valuePortion[currentIndex]
            if isEscaping {
                switch character {
                case "\\", "\"":
                    result.append(character)
                case "n":
                    result.append("\n")
                case "r":
                    result.append("\r")
                case "t":
                    result.append("\t")
                default:
                    throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' contains an unsupported escape in '\(keyName)'.")
                }
                isEscaping = false
                currentIndex = valuePortion.index(after: currentIndex)
                continue
            }

            if character == "\\" {
                isEscaping = true
                currentIndex = valuePortion.index(after: currentIndex)
                continue
            }

            if character == "\"" {
                reachedClosingQuote = true
                remainderStartIndex = valuePortion.index(after: currentIndex)
                break
            }

            result.append(character)
            currentIndex = valuePortion.index(after: currentIndex)
        }

        guard !isEscaping, reachedClosingQuote else {
            throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' has an unterminated '\(keyName)' value.")
        }

        let remainder = valuePortion[remainderStartIndex...].trimmingCharacters(in: .whitespaces)
        if !remainder.isEmpty && !remainder.hasPrefix("#") {
            throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' contains unexpected content after '\(keyName)'.")
        }

        return result
    }

    private func resolveConfiguredPath(_ path: String, configFileURL: URL) throws -> URL {
        let resolvedPath: String
        if path == "~" {
            resolvedPath = homeDirectoryURL.path(percentEncoded: false)
        } else if path.hasPrefix("~/") {
            resolvedPath = homeDirectoryURL
                .appendingPathComponent(String(path.dropFirst(2)), isDirectory: true)
                .path(percentEncoded: false)
        } else {
            resolvedPath = path
        }

        guard resolvedPath.hasPrefix("/") else {
            throw AppError.invalidConfiguration("Vault configuration at '\(configFileURL.path)' must use an absolute path or '~/' for 'vault_dir'.")
        }

        return URL(fileURLWithPath: resolvedPath, isDirectory: true).standardizedFileURL
    }
}

private struct EnrollmentRootRecord: Codable, Equatable {
    let version: Int
    let vaultID: String
    let invitationID: String
    let vaultDirectory: String
    let deviceID: UInt64
    let fileID: UInt64
}

private struct NewVaultInitializationRecord: Encodable {
    let operationID: String
    let vaultDirectory: String
    let deviceID: UInt64
    let fileID: UInt64
}

public struct VaultLocationResolver {
    private let configStore: KeyConfigStore

    public init(
        productIdentity: KeyProductIdentity = .stable,
        fileManager: FileManager = .default,
        homeDirectoryURL: URL? = nil
    ) {
        self.configStore = KeyConfigStore(
            productIdentity: productIdentity,
            fileManager: fileManager,
            homeDirectoryURL: homeDirectoryURL
        )
    }

    public func resolve() throws -> VaultLocation {
        let configuration = try configStore.load()
        return VaultLocation(
            rootURL: configuration.vaultDirectoryURL,
            configFileURL: configuration.configFileURL,
            pathSource: configuration.vaultPathSource
        )
    }
}

private struct KeyConfigurationFile {
    let vaultDirectoryURL: URL
    let keychainMode: KeychainMode?
    let vaultID: String?
}

private struct KeyConfigurationFileIdentity: Equatable {
    let device: UInt64
    let file: UInt64
}

private struct KeyConfigurationSnapshot {
    let configuration: KeyConfigurationFile
    let data: Data
    let root: VaultRootDirectoryHandle
    let identity: KeyConfigurationFileIdentity
}

private struct BootstrapPaths {
    let configDirectoryURL: URL
    let configFileURL: URL
    let defaultVaultURL: URL
}
