import Foundation
import Testing
@testable import KeyCore

@Suite
struct VaultKeyStoreTests {
    @Test(arguments: [false, true])
    func synchronizedCreationAndReplacementRefuseBeforeKeychainAccess(overwrite: Bool) {
        let store = VaultKeyStore(configuration: RuntimeConfiguration(
            productIdentity: .stable.qualificationIdentity(namespace: "refusal-\(UUID().uuidString.lowercased())"),
            // An attempted query or deletion would fail configuration validation.
            vaultAccount: ""
        ))

        #expect(throws: AppError.legacyICloudKeyCreationUnsupported) {
            try store.storeKey(Data(repeating: 0, count: 32), mode: .icloud, overwriteExisting: overwrite)
        }
    }
}
