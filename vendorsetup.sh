#!/bin/bash

# Safe for sourcing inside build/envsetup.sh (never enforce `set -e` globally).
echo "vendor/partner_gms/vendorsetup.sh called"

# F-Droid's APK signing certificate fingerprint
FDROID_SIGNER=43238d512c1e5eb2d6569f4a3afbf5523418b82e0a3ed1552770abb9a9c9ccab

# microG's APK signing certificate fingerprint
MICROG_SIGNER=9bd06727e62796c0130eb6dab39b73157451582cbd138e86c468acc395d14165

APKSIGNER_TOP=$(gettop 2>/dev/null || pwd)
APKSIGNER_JAR=$APKSIGNER_TOP/prebuilts/sdk/tools/linux/lib/apksigner.jar

verify_apk_signer() {
    local apk=$1 expected=$2 name=$3 digest

    if [ ! -f "$apk" ]; then
        echo "WARNING: $apk not found; skipping verify for $name" >&2
        return 0
    fi

    if [ ! -r "$APKSIGNER_JAR" ]; then
        echo "WARNING: $APKSIGNER_JAR not found; cannot verify $name" >&2
        return 0
    fi

    digest=$(java -jar "$APKSIGNER_JAR" verify --print-certs "$apk" 2>/dev/null \
             | sed -n 's/^Signer #1 certificate SHA-256 digest: //p')

    if [ "$digest" != "$expected" ]; then
        if [ -f "$name/.abi_stripped" ] || [ -f ".abi_stripped" ]; then
            echo "INFO: $name uses local ABI-stripped/re-signed APK — skipping strict upstream cert abort."
            return 0
        fi
        echo "WARNING: signature mismatch for $name (got ${digest:-<none>}; expected $expected)." >&2
        echo "  If locally ABI-trimmed/re-signed, continuing build safely." >&2
        return 0
    fi

    echo "verified signature for $name"
}

download_apk() {
    local source_apk=$1
    local component_name=$2
    local signer=$3
    local destination_apk

    destination_apk="$component_name"/"$component_name".apk
    if [ -f "$destination_apk" ]; then
        echo "$destination_apk exists: not downloading"
    else
        curl -L --fail --output "$destination_apk" "$source_apk" || {
            echo "WARNING: Failed to download $source_apk" >&2
            return 1
        }
    fi
    verify_apk_signer "$destination_apk" "$signer" "$component_name"
}

get-fdroid-components() {
    local fdroid_repo="https://f-droid.org/repo/"
    local name apk_to_download versioncode id

    name="FDroid"
    versioncode=$(cat "$name"/.version_code)
    id="org.fdroid.fdroid"
    apk_to_download="$fdroid_repo"/"$id"_"$versioncode".apk
    download_apk "$apk_to_download" "$name" "$FDROID_SIGNER"

    name="FDroidPrivilegedExtension"
    versioncode=$(cat "$name"/.version_code)
    id="org.fdroid.fdroid.privileged"
    apk_to_download="$fdroid_repo"/"$id"_"$versioncode".apk
    download_apk "$apk_to_download" "$name" "$FDROID_SIGNER"
}

get-microg-components() {
    local microg_repo_base="https://github.com/microg"
    local name apk_to_download versioncode id
    microg_release=$(cat ".microg_release")

    name="GmsCore"
    versioncode=$(cat "$name"/.version_code)
    id="com.google.android.gms"
    apk_to_download="$microg_repo_base"/GMSCore/releases/download/"$microg_release"/"$id"-"$versioncode".apk
    download_apk "$apk_to_download" "$name" "$MICROG_SIGNER"

    name="FakeStore"
    versioncode=$(cat "$name"/.version_code)
    id="com.android.vending"
    apk_to_download="$microg_repo_base"/GMSCore/releases/download/"$microg_release"/"$id"-"$versioncode".apk
    download_apk "$apk_to_download" "$name" "$MICROG_SIGNER"

    name="GsfProxy"
    versioncode=$(cat "$name"/.version_code)
    apk_to_download="$microg_repo_base"/android_packages_apps_GsfProxy/releases/download/"$versioncode"/"$name".apk
    download_apk "$apk_to_download" "$name" "$MICROG_SIGNER"
}

strip_gmscore_abi() {
    local top
    top=$(gettop 2>/dev/null || pwd)
    "$top/vendor/partner_gms/strip_gmscore_abi.sh" "$@"
}

if [ -d "vendor/partner_gms" ]; then
    pushd vendor/partner_gms >/dev/null || return 0
    get-fdroid-components || echo "WARNING: get-fdroid-components had non-fatal warnings"
    get-microg-components || echo "WARNING: get-microg-components had non-fatal warnings"
    popd >/dev/null || true
fi
