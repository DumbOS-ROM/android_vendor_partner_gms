LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := privapp-permissions-com.google.android.gms.xml
LOCAL_MODULE_CLASS := ETC
LOCAL_PRODUCT_MODULE := true
LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT_ETC)/permissions
LOCAL_SRC_FILES := $(LOCAL_MODULE)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := default-permissions-com.google.android.gms.xml
LOCAL_MODULE_CLASS := ETC
LOCAL_PRODUCT_MODULE := true
LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT_ETC)/default-permissions
LOCAL_SRC_FILES := $(LOCAL_MODULE)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := sysconfig-com.google.android.gms.xml
LOCAL_MODULE_CLASS := ETC
LOCAL_PRODUCT_MODULE := true
LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT_ETC)/sysconfig
LOCAL_SRC_FILES := $(LOCAL_MODULE)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := microg.xml
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT_ETC)/
LOCAL_SRC_FILES := $(LOCAL_MODULE)
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := GmsCore
LOCAL_MODULE_CLASS := APPS
LOCAL_PRODUCT_MODULE := true
LOCAL_PRIVILEGED_MODULE := true
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_OVERRIDES_PACKAGES := com.qualcomm.location
LOCAL_REQUIRED_MODULES := privapp-permissions-com.google.android.gms.xml default-permissions-com.google.android.gms.xml sysconfig-com.google.android.gms.xml microg.xml
ifneq ($(call math_gt_or_eq, $(PLATFORM_SDK_VERSION), 31),)
LOCAL_USES_LIBRARIES := com.android.location.provider
LOCAL_OPTIONAL_USES_LIBRARIES := org.apache.http.legacy androidx.window.extensions androidx.window.sidecar
endif
LOCAL_DEX_PREOPT := false

# DumbOS: automatically strip non-matching ABI native libraries (~150-183 MiB /system savings)
# unless explicitly disabled via DUMBOS_STRIP_GMSCORE_ABI := false.
DUMBOS_STRIP_GMSCORE_ABI ?= true
gmscore_abi_excludes :=
ifeq ($(DUMBOS_STRIP_GMSCORE_ABI),true)
ifeq ($(TARGET_ARCH),arm)
  gmscore_abi_excludes := -x 'lib/arm64-v8a/**' -x 'lib/x86/**' -x 'lib/x86_64/**'
else ifeq ($(TARGET_ARCH),arm64)
  ifeq ($(TARGET_2ND_ARCH),arm)
    gmscore_abi_excludes := -x 'lib/x86/**' -x 'lib/x86_64/**'
  else
    gmscore_abi_excludes := -x 'lib/armeabi-v7a/**' -x 'lib/x86/**' -x 'lib/x86_64/**'
  endif
else ifeq ($(TARGET_ARCH),x86)
  gmscore_abi_excludes := -x 'lib/armeabi-v7a/**' -x 'lib/arm64-v8a/**' -x 'lib/x86_64/**'
else ifeq ($(TARGET_ARCH),x86_64)
  ifeq ($(TARGET_2ND_ARCH),x86)
    gmscore_abi_excludes := -x 'lib/armeabi-v7a/**' -x 'lib/arm64-v8a/**'
  else
    gmscore_abi_excludes := -x 'lib/armeabi-v7a/**' -x 'lib/arm64-v8a/**' -x 'lib/x86/**'
  endif
endif
endif

ifneq ($(strip $(gmscore_abi_excludes)),)
gmscore_stripped_apk := $(call local-intermediates-dir)/GmsCore_abi_stripped.apk
$(gmscore_stripped_apk): PRIVATE_ABI_EXCLUDES := $(gmscore_abi_excludes)
$(gmscore_stripped_apk): $(LOCAL_PATH)/GmsCore.apk | $(ZIP2ZIP)
	@echo "[DumbOS] Stripping unused ABIs from GmsCore.apk for $(TARGET_ARCH) -> $@"
	$(hide) mkdir -p $(dir $@) && rm -f $@
	$(hide) $(ZIP2ZIP) -i $< -o $@ $(PRIVATE_ABI_EXCLUDES)

LOCAL_PREBUILT_MODULE_FILE := $(gmscore_stripped_apk)
LOCAL_CERTIFICATE := $(DEFAULT_SYSTEM_DEV_CERTIFICATE)
else
LOCAL_SRC_FILES := GmsCore.apk
LOCAL_CERTIFICATE := PRESIGNED
endif

include $(BUILD_PREBUILT)
