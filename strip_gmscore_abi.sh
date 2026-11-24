#!/bin/bash
# Strips unused native ABIs from vendor/partner_gms/GmsCore/GmsCore.apk in-place
# and re-signs with AOSP testkey (optional manual helper; Android.mk also auto-strips during build).
# Usage: ./strip_gmscore_abi.sh [arm|arm64|x86|x86_64]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARCH="${1:-${TARGET_ARCH:-arm}}"
APK="$SCRIPT_DIR/GmsCore/GmsCore.apk"

if [ ! -f "$APK" ]; then
    echo "ERROR: $APK not found." >&2
    exit 1
fi

case "$ARCH" in
    arm)
        DEL_PATTERNS=("lib/arm64-v8a/*" "lib/x86/*" "lib/x86_64/*")
        ;;
    arm64)
        DEL_PATTERNS=("lib/x86/*" "lib/x86_64/*")
        ;;
    x86)
        DEL_PATTERNS=("lib/armeabi-v7a/*" "lib/arm64-v8a/*" "lib/x86_64/*")
        ;;
    x86_64)
        DEL_PATTERNS=("lib/armeabi-v7a/*" "lib/arm64-v8a/*")
        ;;
    *)
        echo "Usage: $0 [arm|arm64|x86|x86_64]" >&2
        exit 1
        ;;
esac

echo "[partner_gms] Stripping unused ABIs for TARGET_ARCH=$ARCH from $APK..."
zip -d "$APK" "${DEL_PATTERNS[@]}" || true

APKSIGNER_JAR="$TOP_DIR/prebuilts/sdk/tools/linux/lib/apksigner.jar"
TESTKEY_PK8="$TOP_DIR/build/make/target/product/security/testkey.pk8"
TESTKEY_PEM="$TOP_DIR/build/make/target/product/security/testkey.x509.pem"

if [ -r "$APKSIGNER_JAR" ] && [ -r "$TESTKEY_PK8" ] && [ -r "$TESTKEY_PEM" ]; then
    TMP_APK="${APK}.aligned"
    zipalign -f -p 4 "$APK" "$TMP_APK" 2>/dev/null || cp "$APK" "$TMP_APK"
    java -jar "$APKSIGNER_JAR" sign --key "$TESTKEY_PK8" --cert "$TESTKEY_PEM" --out "$APK" "$TMP_APK"
    rm -f "$TMP_APK" "${APK}.idsig"
    touch "$SCRIPT_DIR/GmsCore/.abi_stripped"
    echo "[partner_gms] Done! GmsCore.apk stripped & signed with AOSP testkey."
else
    touch "$SCRIPT_DIR/GmsCore/.abi_stripped"
    echo "[partner_gms] Stripped unused ABIs. Re-signing deferred to build system."
fi
