import ArgumentParser
import Foundation

/// Names are presentation hints only. Completion never authenticates, contacts
/// the helper, reads secret values, or treats a cached manifest as authority.
enum CLIEntryCompletion {
    static var entries: CompletionKind { kind(includeFolders: false) }
    static var paths: CompletionKind { kind(includeFolders: true) }

    private static func kind(includeFolders: Bool) -> CompletionKind {
        .custom { _, _, _ in
            let names = suggestions(
                configStore: KeyConfigStore(productIdentity: .currentProcess),
                includeFolders: includeFolders
            )
            // zsh's _describe interprets a colon as a description separator.
            return CompletionShell.requesting == .zsh
                ? names.map {
                    $0.replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: ":", with: "\\:")
                }
                : names
        }
    }

    static func suggestions(configStore: KeyConfigStore, includeFolders: Bool) -> [String] {
        do {
            // Unlike load(), selection reading does not open the provider's
            // vault folder. A temporarily unavailable sync folder must not
            // prevent suggestions from the existing device-local cache.
            let selection = try configStore.configuredVaultRuntimeSelection()
            let names: [String]
            if let vaultID = selection.vaultID {
                names = try cachedNames(configStore: configStore, vaultID: vaultID).filter(isValidV3EntryName)
            } else {
                // Older vaults name entries directly in their filesystem.
                _ = try VaultRootDirectoryHandle(opening: selection.rootURL)
                let store = EntryStore(rootURL: selection.rootURL)
                names = try store.listEntries().filter {
                    // Preserve legacy spelling and Unicode bytes. Only control
                    // characters are unsuitable for the line-based shell protocol.
                    (try? store.validateEntryName($0)) != nil
                        && !$0.unicodeScalars.contains(where: isV3ControlCharacter)
                }
            }
            var candidates = Set(names)
            if includeFolders {
                for name in Array(candidates) {
                    let parts = name.split(separator: "/")
                    for count in 1 ..< parts.count {
                        candidates.insert(parts.prefix(count).joined(separator: "/") + "/")
                    }
                }
            }
            return candidates.sorted()
        } catch {
            // Tab is not an operation request. Missing, malformed, unsupported,
            // or unsafe local state means no suggestions, without diagnostics.
            return []
        }
    }

    private static func cachedNames(configStore: KeyConfigStore, vaultID: String) throws -> [String] {
        guard isValidV3UUID(vaultID) else { return [] }
        let directory = configStore.initializationConfigFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("v3-checkpoint-manifests", isDirectory: true)
        let root = try VaultRootDirectoryHandle(opening: directory)
        let read = try root.withResolvedDescriptor(at: "\(vaultID).json", expecting: .regularFile) {
            readObjectData(
                descriptor: $0.rawValue,
                maximumBytes: V3ManifestRepositoryLimits.standard.maximumManifestBytes
            )
        }
        guard case let .available(data) = read else { return [] }

        // Reuse the supported format parsers; do not duplicate their schemas
        // in shell scripts. Parsing is deliberately not authentication.
        if let envelope = try? V3DeviceWrappedManifestEnvelopeCodec().parse(data) {
            return envelope.body.vaultID == vaultID ? envelope.body.entries.map(\.name) : []
        }
        if let envelope = try? V3RecoveryManifestCodec().parseEnvelope(data) {
            return envelope.body.fields.vaultID == vaultID ? envelope.body.fields.entries.map(\.name) : []
        }
        let envelope = try V3ManifestAuthenticator().parse(data)
        return envelope.content.manifest.vaultID == vaultID ? envelope.content.manifest.entries.map(\.name) : []
    }
}
