#!/bin/zsh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

cd "${repo_root}"
mkdir -p .build/verification
KEY_RUN_MIGRATION_QUALIFICATION=1 \
  swift test \
    --force-resolved-versions \
    --xunit-output .build/verification/migration-tests.xml \
    --filter V3DeviceWrappedGenesisInstallerTests.migratesRealisticLargeMixedSnapshotWithoutChangingV2Source
