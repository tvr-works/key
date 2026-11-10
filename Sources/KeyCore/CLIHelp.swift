/// Workflow explanations supplied to Argument Parser's generated help.
/// Keep paragraphs unwrapped; the renderer owns wrapping and column alignment.
enum CLIHelp {
    static let recoveryGuideURL = "https://github.com/tvr-works/key/blob/main/docs/recovery-user-guide.md"
    static let troubleshootingURL = "https://github.com/tvr-works/key/blob/main/docs/troubleshooting.md"

    static let recovery = """
    Recover a vault using its encrypted files and a previously registered hardware key.

    Before you need recovery:

    1. Set up each physical key using the hardware setup guide.

    2. Run \(KeyProductIdentity.currentProcess.cliExecutableName) recovery adopt, then \(KeyProductIdentity.currentProcess.cliExecutableName) recovery register.

    3. Store independent backup keys separately.

    To recover, run \(KeyProductIdentity.currentProcess.cliExecutableName) recovery review, then \(KeyProductIdentity.currentProcess.cliExecutableName) recovery restore. Restore creates a separate vault on a Mac with no configured vault. Register recovery keys again afterward.

    A key cannot replace missing files. Key cannot prove that every newer file has synchronized.

    If interrupted, keep all files and saved records. See \(KeyProductIdentity.currentProcess.cliExecutableName) recovery resume --help. Cancel any PIN dialog left open after a timeout or disconnection. Key does not retry automatically.

    Setup guide: \(recoveryGuideURL)
    """

    static let recoveryTokens = """
    List connected keys and their complete token IDs without PIN or touch. This does not check recovery setup or list the vault's registered keys.

    Use --token <token-id> with \(KeyProductIdentity.currentProcess.cliExecutableName) recovery credential to check setup, or with recovery review --source <directory> to check against vault files. Key does not select a key automatically. --json prints the same public information for scripts.
    """

    static let recoveryAbandon = """
    Release a restore attempt that stopped before its complete encrypted preparation was saved. Use the original --source and --destination, plus the full --vault-id and --operation ID reported by resume. No hardware key or Mac authentication is needed.

    Key checks that this Mac still has the matching early attempt, the original folders, an empty destination, and no configured or fully prepared vault. It refuses changed, missing or invalid records. A fully prepared restore must be resumed instead.

    This leaves files, the destination folder and saved Mac credentials intact. It does not start another restore. After successful abandonment, a new restore needs a different destination that does not exist. If the result is uncertain, keep the records and save the error; see troubleshooting below.

    Troubleshooting: \(troubleshootingURL)
    """

    static let recoveryCredential = """
    Check a key's public recovery setup without PIN or touch. Use the complete token ID from \(KeyProductIdentity.currentProcess.cliExecutableName) recovery tokens.

    Reports the PIV slot 9d credential, key type, PIN/touch settings and recovery setup record (anchor). Use the recovery key ID with --recipient. It identifies the recovery public key, not the certificate fingerprint.

    This does not change or register the key. It cannot prove recovery works, administration is protected, or PIN/touch is enforced. Registration and restore verify the key with hardware approval.
    """

    static let recoveryRegistration = """
    Register a hardware key to recover this vault if your Macs are lost. First run \(KeyProductIdentity.currentProcess.cliExecutableName) recovery adopt.

    Prepare the physical key using the hardware setup guide: P-256 generated in PIV slot 9d, a matching certificate, PIN-always and touch-always settings, and protected administration credentials. Key does not set up, reset or write to the physical key.

    1. Run \(KeyProductIdentity.currentProcess.cliExecutableName) recovery credential --token <token-id>.

    2. Use its token and recovery key IDs with \(KeyProductIdentity.currentProcess.cliExecutableName) recovery register prepare --export-anchor <new-file>.

    3. Install that exact public setup file (anchor) on the selected key using the guide's vendor-tool procedure.

    4. Run \(KeyProductIdentity.currentProcess.cliExecutableName) recovery register finish with the same --token and --recipient. Enter the PIN only in macOS, then touch when it flashes.

    Recovery is inactive until registration finishes. Register each backup key separately.

    If export fails, keep the saved records and use register resume-export with a new filename. Follow resume instructions if interrupted; do not delete records to retry. Use register status to check saved registration state, not hardware recovery or sync completion.

    Setup guide: \(recoveryGuideURL)
    """

    static let recoveryRegistrationAbandon = """
    Release a registration attempt that stopped before its recovery setup file was ready to export. Find its original operation ID with \(KeyProductIdentity.currentProcess.cliExecutableName) recovery pending.

    Type ABANDON and approve the Mac prompt. Key keeps the saved files and does not contact or change the physical key. This cannot remove an active recovery key or release an attempt already ready for export. Follow that attempt's resume-export or finish instructions instead.

    After successful abandonment, starting registration again is a separate action. If the result is uncertain, keep the records intact; do not delete them to force a retry.
    """

    static let recoveryAdoption = """
    Update this vault's format to support recovery keys. This does not register a key or make recovery available yet. Keep a complete backup and upgrade every participating Mac first: older apps cannot open the updated format.

    Approve the Mac prompts while Key rewrites and verifies the encrypted vault in the new format. The vault folder stays the same, and no hardware key is contacted. After completion, use \(KeyProductIdentity.currentProcess.cliExecutableName) recovery register to add recovery keys.

    If interrupted, keep the vault files and saved records. Use --resume <operation-id> with the original ID from \(KeyProductIdentity.currentProcess.cliExecutableName) recovery pending. Resume continues only that saved attempt.

    If Key reports that preparation stopped too early to resume, use --abandon <operation-id>. This requires ABANDON confirmation and Mac approval. It preserves files and only releases an attempt that has not reached the stage where the format change can be saved. Later attempts must follow the resume path.
    """

    static let recoveryRecipientRemoval = """
    Remove a registered recovery key from future versions of the configured vault. The key can remain disconnected: Key uses this Mac's credentials and never changes the physical key or its saved anchor. Old copies can still be opened with their old keys. If the recovery key ID starts with '-', place -- before it.

    An interactive review shows the selected recovery key and how many recovery keys will remain. Type REMOVE to confirm. Removing the last key instead requires typing REMOVE LAST RECOVERY KEY after acknowledging that recovery will be unavailable until another key is registered. There is no noninteractive override.

    If interrupted, preserve files and local records. Run this command again to review and explicitly finish the same saved removal; it never silently starts a replacement candidate. No automatic retry is made.
    """

    static let recoveryRotation = """
    Change this vault's encryption key while keeping access for its enrolled Macs and registered recovery keys. The configured vault must already support recovery. Your hardware keys can stay disconnected.

    Keep a backup, type ROTATE, and approve each Mac prompt until the command finishes. Key rewrites the current encrypted contents with the new encryption key.

    If interrupted, keep the vault files and this Mac's saved records. After the background service restarts, inspect \(KeyProductIdentity.currentProcess.cliExecutableName) status and \(KeyProductIdentity.currentProcess.cliExecutableName) recovery pending. Use --resume <operation-id> to continue the original saved rotation. If required records are missing or invalid, save the error and follow troubleshooting below; do not delete them or start another rotation. Key does not retry automatically.

    Troubleshooting: \(troubleshootingURL)
    """

    static let recoveryReview = """
    Check whether the source vault's public history matches the selected recovery key. Use an existing --source folder and the complete --token ID from \(KeyProductIdentity.currentProcess.cliExecutableName) recovery tokens. Key does not use your configured vault folder by default.

    This check reads the key's public credential, reported PIN/touch settings, recovery setup record (anchor), and available vault history. It refuses incompatible keys, missing required history, or competing versions. It does not ask for PIN or touch, read secret contents, create a destination, or change configuration.

    Successful review does not prove that recovery will work, that the key will enforce PIN/touch, or that every newer file has arrived. Restore checks the source again and uses hardware approval to verify its contents. --json prints the same public information for scripts.
    """

    static let recoveryRestore = """
    Recover into a new vault on a Mac with no configured vault. See \(KeyProductIdentity.currentProcess.cliExecutableName) recovery --help for prerequisites.

    Use --name for this Mac's name. Supply --source, --destination, --token and --recipient exactly once. Use the complete IDs from \(KeyProductIdentity.currentProcess.cliExecutableName) recovery review; the recovery key ID is not a certificate fingerprint. These IDs are public identifiers, not secrets or approval to restore. Paths may be absolute or relative to the current directory.

    The source and destination parent must exist. The destination itself must not exist, even as an empty folder. Source and destination cannot overlap. Key leaves the source unchanged and selects the verified new vault for future commands.

    Enter the key's PIN in macOS, touch it when it flashes, then approve the Mac prompts until completion. The background service restarts afterward. Check the recovered entries and register recovery keys again for the new vault.

    If interrupted, keep all files and saved records. Use \(KeyProductIdentity.currentProcess.cliExecutableName) recovery resume --help before another attempt. If a PIN dialog remains open after timeout, click Cancel.
    """

    static let recoveryResume = """
    Continue the restore attempt saved on this Mac. Use the original --source, --destination, --token and complete --recipient. Do not supply a new Mac name. Resume never starts a replacement restore or recreates missing files or credentials.

    If the background service is restarting, run \(KeyProductIdentity.currentProcess.cliExecutableName) lock, then \(KeyProductIdentity.currentProcess.cliExecutableName) status. Status alone does not finish an interrupted restore. Resume the saved attempt explicitly and approve its hardware and Mac prompts.

    If preparation stopped too early to resume, Key reports the original vault and operation IDs. See \(KeyProductIdentity.currentProcess.cliExecutableName) recovery abandon --help to release that incomplete attempt. If records are changed, missing or invalid, stop and save the error. Keep them and the vault folders intact; see troubleshooting below.

    A completed attempt cannot be resumed once its saved operation records have been cleared. After a timeout, cancel any remaining PIN dialog before another attempt. Key does not retry automatically.

    Troubleshooting: \(troubleshootingURL)
    """

    static let overview = """
    Use \(KeyProductIdentity.currentProcess.cliExecutableName) init for a new vault, or \(KeyProductIdentity.currentProcess.cliExecutableName) share to join one from another Mac. Run \(KeyProductIdentity.currentProcess.cliExecutableName) <command> --help for options and examples.

    Help, version, and lock work before setup. Most other commands need a configured vault. Joining and Preview recovery have their own setup steps; see \(KeyProductIdentity.currentProcess.cliExecutableName) share --help and \(KeyProductIdentity.currentProcess.cliExecutableName) recovery --help.

    Keep at least two active enrolled Macs. If every enrolled Mac is lost, you cannot recover access from the vault folder alone. There is no password, cloud, or support override. Preview offers separately registered hardware recovery keys; see \(KeyProductIdentity.currentProcess.cliExecutableName) recovery --help.
    """

    static let initialize = """
    With no directory, Key uses your current directory. It must be empty, including hidden files. If the destination does not exist, Key creates it; the parent directory must already exist. Destination symlinks are refused.

    Examples:
      \(KeyProductIdentity.currentProcess.cliExecutableName) init
      \(KeyProductIdentity.currentProcess.cliExecutableName) init /path/to/NewVault
      \(KeyProductIdentity.currentProcess.cliExecutableName) init -- -vault

    Key checks that this Mac can reopen the new vault before saving its configuration. Init never replaces existing configuration or reinitializes a vault. If setup is interrupted, keep the files and local records intact and follow the error's instructions; do not delete them to force a retry.

    To join a vault from another Mac, use \(KeyProductIdentity.currentProcess.cliExecutableName) share --help, not init. An empty synced folder may still have files waiting to download.

    After setup: run \(KeyProductIdentity.currentProcess.cliExecutableName) status, then \(KeyProductIdentity.currentProcess.cliExecutableName) add <name>. Add another Mac before relying on this vault. If every enrolled Mac is lost, a backup of the vault folder alone cannot restore access.
    """

    static let share = """
    On a Mac that already has access:

    1. Run \(KeyProductIdentity.currentProcess.cliExecutableName) share devices to find this Mac's recorded name.

    2. Run \(KeyProductIdentity.currentProcess.cliExecutableName) share invite --name "Existing Mac" using that exact name. --name identifies this Mac, not the Mac you are inviting.

    On the joining Mac:

    1. Open the existing synced vault folder in your terminal. Do not run init.

    2. Run \(KeyProductIdentity.currentProcess.cliExecutableName) share invitations, then use the invitation ID:

    \(KeyProductIdentity.currentProcess.cliExecutableName) share join <invitation-id> --name "New Mac"

    Here, --name is the name you want to give the joining Mac.

    Follow the commands printed on each Mac. Compare the exact code and both Mac names on the two screens. Stop if they differ. Approve on the existing Mac, then accept on the joining Mac. Only verified acceptance saves the joining Mac's vault configuration. Invitations expire after 10 minutes.

    Folder selection:

    With no configuration, joining commands use the current directory. Use --vault-dir on invitations/join/compare/accept to run elsewhere. Keep using the same folder and invitation for that attempt. A configured Mac uses its configured folder; --vault-dir cannot switch vaults. Joining never creates a folder. Wait for existing vault files to download.

    Removing access:

    \(KeyProductIdentity.currentProcess.cliExecutableName) share revoke shows a review and requires you to type REVOKE. The removed Mac cannot read the new vault or future changes, but keeps any secrets and older vault data it already obtained. A lost or revoked Mac rejoins through an invitation from a surviving Mac.

    Keep at least two active enrolled Macs. If all are lost, the vault folder alone cannot restore access. There is no password, cloud, or support fallback.
    """

    static let joiningDirectory = """
    With no configuration, this command uses the current directory. Use --vault-dir to select the existing vault folder elsewhere. A configured Mac uses its configured folder; --vault-dir cannot switch vaults. Joining never creates a folder. Wait for existing vault files to download, and do not run init.

    Keep using the same folder and invitation for this attempt. See \(KeyProductIdentity.currentProcess.cliExecutableName) share --help for the full sequence.
    """

    static let config = """
    vault-dir is the folder Key uses for this vault. To correct its path after deliberately moving the complete vault:
      \(KeyProductIdentity.currentProcess.cliExecutableName) config set vault-dir /path/to/ExistingVault

    The folder must already exist. This changes the path, not the vault's ID, and does not move files or join a different vault. Missing vault files or keys are errors; Key will not create replacements.

    For device-enrolled vaults, put the vault folder in iCloud Drive or another file-sync location to synchronize files. keychain-mode does not control their synchronization or device access. Key retains that setting for compatibility and omits it from config list for these vaults.

    For older vaults, keychain-mode selects an existing local or icloud key. Key cannot create or replace synchronized keys: macOS does not support syncing keys with Key's required approval protection. Existing synchronized keys remain readable and migratable. Use \(KeyProductIdentity.currentProcess.cliExecutableName) migrate --help to prepare for migration; afterward, share the vault folder using your preferred file-sync provider.

    Config commands require existing configuration. Use init for a new vault or share to join an existing one; config set is not a setup command.
    """

    static let migrate = """
    Move an older Keychain-backed vault to the device-enrolled format. Migration never starts automatically; choose exactly one action.

    Examples:
      \(KeyProductIdentity.currentProcess.cliExecutableName) migrate --check
      \(KeyProductIdentity.currentProcess.cliExecutableName) migrate --apply

    --check verifies readiness without changing files or Keychain items. --apply creates a new copy, verifies it, and configures this Mac to use it.

    Key retains the original files. Keep them while checking the migration. They do not receive later changes from the new vault and cannot restore access to it. Other Macs are not migrated automatically; add them to the new vault using \(KeyProductIdentity.currentProcess.cliExecutableName) share --help after installing a compatible release.

    Keep at least two active enrolled Macs. If all are lost, the new vault's files alone cannot restore access. No password, cloud, or support fallback is currently available.

    The older vault format (v2) is deprecated, but reads and writes still work. No removal release has been scheduled. Format numbers describe storage compatibility, not the version of the Key app.
    """

    static let status = """
    Check whether your vault is ready to use, has missing files, or needs attention. This does not edit entries or resolve conflicts. Use either --json or --verbose, not both.

    If files are unavailable, check your sync provider before retrying. Local APFS and iCloud Drive were directly validated for Stable 0.2.0. Other ordinary folder-backed providers may work, but are not directly validated. These results do not qualify new setup behavior in later builds.

    Troubleshooting: \(troubleshootingURL)
    """

    static let conflict = """
    Start with \(KeyProductIdentity.currentProcess.cliExecutableName) conflict list, then \(KeyProductIdentity.currentProcess.cliExecutableName) conflict show for each conflict. Use get or copy to inspect a particular secret version. Get prints the secret; copy uses the clipboard.

    Resolve every current conflict together, with one choice for each conflict. If the vault changes during review, review the new conflicts before retrying.

    Choosing a version can discard another edit or keep a deletion. Review all versions first. Conflicts involving older revisions or device access cannot be bypassed with resolve. Keep vault files and local records intact if Key reports that it cannot safely continue.

    Example:
      \(KeyProductIdentity.currentProcess.cliExecutableName) conflict resolve conflict-a=version-a conflict-b=version-b
    """

    static let read = """
    --allow-stale allows reading the last complete version already verified on this Mac when newer files are unavailable or have competing edits. The files for that verified version must still be available on this Mac; this option cannot restore missing files. The value may be out of date. It does not bypass failed security checks.

    Examples:
      \(KeyProductIdentity.currentProcess.cliExecutableName) get github/personal
      \(KeyProductIdentity.currentProcess.cliExecutableName) copy github/personal
    """

    static let write = """
    Type the secret at the hidden prompt, or pipe it through standard input. Do not put the secret in the command's arguments.

    --totp stores an authenticator setup secret to generate one-time codes. Supply the Base32 secret, not a current code or a full otpauth:// URL.

    Examples:
      \(KeyProductIdentity.currentProcess.cliExecutableName) add github/personal
      \(KeyProductIdentity.currentProcess.cliExecutableName) edit --totp github/mfa
    """

    static let unlock = """
    Authenticate with macOS before running commands that need the vault key. Key normally asks when access is needed, so unlocking in advance is optional. Access expires after inactivity. Use \(KeyProductIdentity.currentProcess.cliExecutableName) lock to end it immediately.
    """

    static let lock = """
    End this Mac's unlocked session and stop Key's background service. The next command that needs the vault key will require authentication. This does not lock other Macs or clear secrets already printed or copied.
    """
}
