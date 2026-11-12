# Documentation

Use the [project README](../README.md) for installation and everyday commands. The [roadmap](roadmap.md) owns planned work; the [release record](release.md) records what shipped and its qualification limits. Historical plans do not add current release gates.

## Using Key

| Document | Use it for |
|---|---|
| [Hardware recovery](recovery-user-guide.md) | Registering independent keys, restoring a retained vault, and resuming an interrupted attempt. |
| [Security, continuity and recovery](security-continuity-recovery.md) | Mac authentication, file delivery, device loss, revocation and backup limits. |
| [Troubleshooting](troubleshooting.md) | Missing files, failed verification, saved operations and uncertain replies. |

## Maintaining Key

| Document | Use it for |
|---|---|
| [Development workflow](development-workflow.md) | Local checks, PR verification and additional release qualification. |
| [Release process and record](release.md) | Versioning, packaging, publication and dated release results. |
| [Apple setup](apple-setup.md) | Signing identities, entitlements, profiles and the shared notarization credential. |
| [Migration qualification](migration-qualification.md) | Disposable compatibility testing using existing legacy keys and isolated app identities. |
| [Configuration design](config-simplification-design.md) | Current config compatibility rules, preservation order and remaining retirement stages. |
| [User-facing language](user-facing-language.md) | Consistent help, prompts, diagnostics and documentation. |

## Architecture and formats

- [Device-wrapped key architecture](v3-device-wrapped-key-architecture.md) defines the base enrolled-device profile.
- [Recovery contract](piv-recovery-contract.md) defines its hardware-recovery extension and failure boundaries.
- [Canonical JSON](json-canonicalization.md) explains the shared encoding module and ownership boundaries.
- [Schemas](schemas/) preserve machine-readable format definitions; the profile-specific contracts and codecs determine applicability.

## Historical records

[History](history/) contains earlier design comparisons, the replaced alpha storage specification, implementation trackers and 0.3.0 qualification records. Keep these as evidence of what a particular version or test established. Their earlier "next", "pending" and "current" labels are not instructions for today's release.

The [dashboard](todo-dashboard-live-status.md) and [menu bar](todo-menu-bar-app.md) proposals remain available for future work. The roadmap determines whether they are scheduled.
