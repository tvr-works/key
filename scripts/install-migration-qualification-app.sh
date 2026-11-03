#!/bin/zsh
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
namespace="${KEY_MIGRATION_QUALIFICATION_NAMESPACE:-migration}"
product="${KEY_MIGRATION_QUALIFICATION_PRODUCT:-stable}"
recovery="${KEY_MIGRATION_QUALIFICATION_RECOVERY:-0}"
install_app="${KEY_MIGRATION_QUALIFICATION_INSTALL:-1}"
case "${product}" in
  stable) product_name=Key; configuration=Debug; identity_prefix=work.tvr.key; cli_name=key; helper_name='Key Agent'; default_root=.key ;;
  preview) product_name='Key Preview'; configuration=PreviewDebug; identity_prefix=work.tvr.key.preview; cli_name=key-preview; helper_name='Key Preview Agent'; default_root=.key-preview ;;
  *) echo 'qualification product must be stable or preview' >&2; exit 1 ;;
esac
if [[ "${recovery}" != 0 && "${recovery}" != 1 ]] || [[ "${install_app}" != 0 && "${install_app}" != 1 ]]; then
  echo 'qualification recovery and install flags must be 0 or 1' >&2
  exit 1
fi
if [[ "${recovery}" == 1 && ( "${product}" != preview || -z "${KEY_MIGRATION_QUALIFICATION_NAMESPACE:-}" ) ]]; then
  echo 'recovery qualification requires Preview and an explicit fresh namespace' >&2
  exit 1
fi
derived_suffix="${namespace}"
[[ "${product}" == stable ]] || derived_suffix="preview-${namespace}"
derived_data_path="${KEY_MIGRATION_QUALIFICATION_DERIVED_DATA_PATH:-${repo_root}/.build/xcode-migration-qualification-${derived_suffix}}"
applications_dir="${KEY_MIGRATION_QUALIFICATION_APPLICATIONS_DIR:-/Applications}"
installed_app_path="${applications_dir}/${product_name} Migration Qualification ${namespace}.app"
agent_label="${identity_prefix}.agent.qualification.${namespace}"
app_bundle_id="${identity_prefix}.app.qualification.${namespace}"
helper_bundle_id="${identity_prefix}.xpc.qualification.${namespace}"
qualification_build_version="${KEY_MIGRATION_QUALIFICATION_BUILD_VERSION:-$(date +%s)}"

if [[ ! "${namespace}" =~ '^[a-z0-9][a-z0-9-]{0,39}$' ]]; then
  echo "qualification namespace must match ^[a-z0-9][a-z0-9-]{0,39}$" >&2
  exit 1
fi
if [[ ! "${qualification_build_version}" =~ '^[1-9][0-9]*$' ]]; then
  echo "qualification build version must be a positive integer" >&2
  exit 1
fi
if [[ "${recovery}" == 1 ]] && [[ -e "${installed_app_path}" || -e "${HOME}/Library/Application Support/${product_name} Qualification ${namespace}" || -e "${HOME}/${default_root}-qualification-${namespace}" ]]; then
  echo 'recovery qualification requires a fresh identity; preserve the existing attempt' >&2
  exit 1
fi

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/key-migration-qualification.XXXXXX")"
trap 'rm -rf -- "${temporary_directory}"' EXIT
launch_agent_plist="${temporary_directory}/${agent_label}.plist"

cp "${repo_root}/Config/${identity_prefix}.agent.plist" "${launch_agent_plist}"
/usr/libexec/PlistBuddy -c "Set :Label ${agent_label}" "${launch_agent_plist}"
/usr/libexec/PlistBuddy -c 'Delete :MachServices' "${launch_agent_plist}"
/usr/libexec/PlistBuddy -c 'Add :MachServices dict' "${launch_agent_plist}"
/usr/libexec/PlistBuddy -c "Add :MachServices:${agent_label} bool true" "${launch_agent_plist}"
/usr/libexec/PlistBuddy -c "Add :MachServices:${agent_label}.status bool true" "${launch_agent_plist}"
/usr/libexec/PlistBuddy -c "Set :SpawnConstraint:signing-identifier ${helper_bundle_id}" "${launch_agent_plist}"

# Override only build inputs. Never edit shipping plists or re-sign a modified product.
plist_settings=()
if [[ "${recovery}" == 1 ]]; then
  for kind in app helper; do
    source_plist="${repo_root}/Config/Key-Info.plist"
    [[ "${kind}" == app ]] || source_plist="${repo_root}/Config/KeyLaunchAgentHelper-Info.plist"
    cp "${source_plist}" "${temporary_directory}/${kind}.plist"
    /usr/libexec/PlistBuddy -c 'Add :KeyExperimentalRecoveryEnabled bool true' "${temporary_directory}/${kind}.plist"
  done
  plist_settings=("KEY_APP_INFO_PLIST_FILE=${temporary_directory}/app.plist" "KEY_HELPER_INFO_PLIST_FILE=${temporary_directory}/helper.plist")
fi

cd "${repo_root}"
xcodebuild \
  -quiet \
  -allowProvisioningUpdates \
  -project Key.xcodeproj \
  -scheme "${product_name}" \
  -configuration "${configuration}" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "${derived_data_path}" \
  CURRENT_PROJECT_VERSION="${qualification_build_version}" \
  KEY_APP_BUNDLE_IDENTIFIER="${app_bundle_id}" \
  KEY_HELPER_BUNDLE_IDENTIFIER="${helper_bundle_id}" \
  KEY_QUALIFICATION_NAMESPACE="${namespace}" \
  KEY_HELPER_MACH_SERVICE_NAME="${agent_label}" \
  KEY_LAUNCH_AGENT_PLIST_NAME="${agent_label}.plist" \
  KEY_LAUNCH_AGENT_PLIST_SOURCE="${launch_agent_plist}" \
  "${plist_settings[@]}" \
  clean build

built_app_path="${derived_data_path}/Build/Products/${configuration}/${product_name}.app"
if [[ ! -d "${built_app_path}" ]]; then
  echo "failed to locate the built qualification app" >&2
  exit 1
fi

app_info="${built_app_path}/Contents/Info.plist"
helper_info="${built_app_path}/Contents/Helpers/${helper_name}.app/Contents/Info.plist"
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${app_info}")" != "${app_bundle_id}" ]]; then
  echo "built qualification app has the wrong bundle identifier" >&2
  exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${helper_info}")" != "${helper_bundle_id}" ]]; then
  echo "built qualification helper has the wrong bundle identifier" >&2
  exit 1
fi
for info in "${app_info}" "${helper_info}"; do
  if [[ "$(/usr/libexec/PlistBuddy -c 'Print :KeyProductVariant' "${info}")" != "${product}" ]]; then
    echo 'built qualification component has the wrong product variant' >&2
    exit 1
  fi
  enabled="$(/usr/libexec/PlistBuddy -c 'Print :KeyExperimentalRecoveryEnabled' "${info}" 2>/dev/null || true)"
  if [[ ( "${recovery}" == 1 && "${enabled}" != true ) || ( "${recovery}" == 0 && -n "${enabled}" && "${enabled}" != false ) ]]; then
    echo 'built qualification component has the wrong recovery setting' >&2
    exit 1
  fi
  if [[ "$(/usr/libexec/PlistBuddy -c 'Print :KeyQualificationNamespace' "${info}")" != "${namespace}" ]]; then
    echo "built component is missing the qualification namespace" >&2
    exit 1
  fi
  if [[ "$(/usr/libexec/PlistBuddy -c 'Print :HelperMachServiceName' "${info}")" != "${agent_label}" ]]; then
    echo "built component has the wrong qualification Mach service" >&2
    exit 1
  fi
done

codesign --verify --deep --strict "${built_app_path}"

if [[ "${install_app}" == 0 ]]; then
  echo "Built without installing or launching: ${built_app_path}"
  echo "  recovery opt-in: ${recovery}"
  exit 0
fi

# Replacing a registered app with the same qualification identity can leave
# launchd's cached lightweight code requirement bound to the previous build.
# Stop only this isolated app and helper before publishing the replacement.
osascript -e "tell application id \"${app_bundle_id}\" to quit" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)/${agent_label}" >/dev/null 2>&1 || true

if [[ -e "${installed_app_path}" ]]; then
  existing_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${installed_app_path}/Contents/Info.plist" 2>/dev/null || true)"
  existing_namespace="$(/usr/libexec/PlistBuddy -c 'Print :KeyQualificationNamespace' "${installed_app_path}/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "${existing_bundle_id}" != "${app_bundle_id}" || "${existing_namespace}" != "${namespace}" ]]; then
    echo "refusing to replace an app with an unexpected identity at ${installed_app_path}" >&2
    exit 1
  fi
fi

mkdir -p "${applications_dir}"
staging_directory="$(mktemp -d "${applications_dir}/.key-migration-qualification-install.XXXXXX")"
staged_app_path="${staging_directory}/${product_name} Migration Qualification ${namespace}.app"
ditto "${built_app_path}" "${staged_app_path}"

previous_app_path="${staging_directory}/Previous Key Migration Qualification ${namespace}.app"
if [[ -e "${installed_app_path}" ]]; then
  mv "${installed_app_path}" "${previous_app_path}"
fi
if ! mv "${staged_app_path}" "${installed_app_path}"; then
  if [[ -e "${previous_app_path}" && ! -e "${installed_app_path}" ]]; then
    mv "${previous_app_path}" "${installed_app_path}"
  fi
  echo "failed to install the migration qualification app" >&2
  exit 1
fi
rm -rf -- "${staging_directory}"

echo "Installed the isolated migration qualification app:"
echo "  app: ${installed_app_path}"
echo "  app bundle: ${app_bundle_id}"
echo "  helper bundle: ${helper_bundle_id}"
echo "  build: ${qualification_build_version}"
echo "  CLI: ${installed_app_path}/Contents/MacOS/${cli_name}"
echo "  helper service: ${agent_label}"
echo "  Keychain service: ${identity_prefix}.secure-vault.qualification.${namespace}"
echo "  Application Support: ${product_name} Qualification ${namespace}"
echo "  recovery opt-in: ${recovery}"
echo
echo "Stable and Preview configuration, vault files, Keychain services, and helper registrations were not changed."
echo
echo "Next:"
echo "  open \"${installed_app_path}\""
if [[ "${recovery}" == 0 && "${product}" == stable ]]; then
  echo "  scripts/run-migration-qualification.sh"
else
  echo '  Follow the explicitly scoped recovery qualification runbook; no hardware command was run.'
fi
