#!/usr/bin/env bash
# Copyright (c) 2025 Salvo Giangreco
# SPDX-License-Identifier: GPL-3.0-or-later

# [
source "$SRC_DIR/scripts/utils/common_utils.sh" || exit 1

trap '[ $? -ne 0 ] && rm -f "$OUT_DIR/config.sh"' EXIT

GET_BUILD_VAR()
{
    if [ "$2" ]; then
        if [ ! "${!1}" ]; then
            echo "${1}=\"${2}\""
            return 0
        fi
    else
        _CHECK_NON_EMPTY_PARAM "$1" "${!1}" || exit 1
    fi

    echo "${1}=\"${!1}\""
    return 0
}

IS_UNICA_CERT_AVAILABLE()
{
    local PLATFORM_KEY_SHA1="5b0eb951718acc596370dabab83f546e779b21dc"
    local OTA_KEY_SHA1="681aa9d28fe5fc60be8c25dc5f26a73ec3d6fb46"

    local USES_UNICA_CERT="false"
    if [[ "$(sha1sum "$SRC_DIR/security/unica_platform.pk8" 2> /dev/null | cut -d " " -f 1)" == "$PLATFORM_KEY_SHA1" ]] && \
            [[ "$(sha1sum "$SRC_DIR/security/unica_ota.pk8" 2> /dev/null | cut -d " " -f 1)" == "$OTA_KEY_SHA1" ]]; then
        USES_UNICA_CERT="true"
    fi

    echo "$USES_UNICA_CERT"
}
# ]

if [ $# -ne 1 ]; then
    echo "Usage: gen_config_file <target>" >&2
    exit 1
elif [ ! -f "$SRC_DIR/target/$1/config.sh" ]; then
    LOGE "File not found: target/$1/config.sh"
    exit 1
else
    source "$SRC_DIR/unica/configs/version.sh" || exit 1
    source "$SRC_DIR/target/$1/config.sh" || exit 1
    if [ -f "$SRC_DIR/platform/$TARGET_PLATFORM/config.sh" ]; then
        # 임시 처리
        source "$SRC_DIR/platform/$TARGET_PLATFORM/config.sh" || exit 1
        source "$SRC_DIR/target/$1/config.sh" || exit 1
    fi
fi

if [ ! "$TARGET_OS_SINGLE_SYSTEM_IMAGE" ]; then
    LOGE "TARGET_OS_SINGLE_SYSTEM_IMAGE가 설정되지 않았습니다!"
    exit 1
elif [ ! -f "$SRC_DIR/unica/configs/$TARGET_OS_SINGLE_SYSTEM_IMAGE.sh" ]; then
    LOGE "\"$TARGET_OS_SINGLE_SYSTEM_IMAGE\"은(는) 유효한 시스템 이미지가 아닙니다."
    exit 1
else
    source "$SRC_DIR/unica/configs/$TARGET_OS_SINGLE_SYSTEM_IMAGE.sh" || exit 1
fi

if [ -f "$OUT_DIR/config.sh" ]; then
    LOGW "config.sh가 이미 존재합니다. 다시 생성합니다."
    rm -f "$OUT_DIR/config.sh"
fi

# 실행 중에는 다음 환경 변수를 사용합니다:
#
#   ROM_VERSION
#     "x.y.z-xxxxxxxx" 형식의 버전 이름 문자열입니다.
#     unica/configs/version.sh에서 설정됩니다.
#
#   ROM_BUILD_TIMESTAMP
#     빌드 타임스탬프를 초 단위로 담는 정수입니다. UN1CA Updates 앱에서 사용합니다.
#     기본값은 스크립트 실행 시각입니다.
#
#   [SOURCE/TARGET]_FIRMWARE
#     "Model number/CSC/IMEI" 형식의 소스/대상 기기 펌웨어 문자열입니다.
#     FUS에서 펌웨어를 가져오려면 IMEI가 필요하며, 대신 기기 시리얼 번호를 사용할 수도 있습니다.
#
#   [SOURCE/TARGET]_EXTRA_FIRMWARES
#     정의되어 있으면 `download_fw`/`extract_fw` 실행 시 [SOURCE/TARGET]_FIRMWARE에 설정된 것과 함께
#     추가 기기 펌웨어를 다운로드/추출합니다.
#     이 변수는 bash 배열 구문으로 설정해야 하며, 각 문자열 요소는 "Model number/CSC/IMEI" 형식이어야 합니다.
#     bash 제한 때문에 이 변수는 각 항목이 ":"로 구분된 문자열로 저장됩니다.
#
#     예시:
#       - 변수 설정: `SOURCE_EXTRA_FIRMWARES=("SM-A528B/BTU/352599501234566" "SM-A528N/KOO/354049881234560")`
#       - 다시 배열로 변환: `IFS=":" read -r -a SOURCE_EXTRA_FIRMWARES <<< "$SOURCE_EXTRA_FIRMWARES"`
#
#   TARGET_NAME
#     대상 기기 이름 문자열입니다. `SEC_FLOATING_FEATURE_SETTINGS_CONFIG_BRAND_NAME` 설정과 일치해야 합니다.
#     서로 다른 SoC를 쓰는 변형이 여러 개면 SoC OEM 이름을 뒤에 덧붙일 수 있습니다.
#
#     예시:
#       `TARGET_NAME="Galaxy S24 (Exynos)"`
#
#   TARGET_CODENAME
#     대상 기기 코드네임 문자열입니다. `ro.product.vendor.device` prop과 일치해야 합니다.
#
#   TARGET_PLATFORM
#     대상 기기 플랫폼 문자열입니다. 선택 사항이며, 여러 대상이 같은 플랫폼을 사용할 때만 씁니다.
#
#   [SOURCE/TARGET]_PLATFORM_SDK_VERSION
#     기기 펌웨어의 SDK API 레벨을 담는 정수입니다. `ro.build.version.sdk` prop과 일치해야 합니다.
#
#   [SOURCE/TARGET]_PRODUCT_SHIPPING_API_LEVEL
#     기기가 처음 출시될 때의 SDK API 레벨을 담는 정수입니다.
#     `ro.product.first_api_level` prop과 일치해야 합니다.
#
#   [SOURCE/TARGET]_BOARD_API_LEVEL
#     보드 API 레벨을 담는 정수입니다. `ro.board.api_level` prop과 일치해야 합니다.
#
#   TARGET_ASSERT_MODEL
#     정의되어 있으면 zip 패키지는 제공된 모델 번호와 `ro.boot.em.model` prop 값을 사용해
#     현재 설치 중인 기기와 호환되는지 확인합니다. 기본적으로는 TARGET_CODENAME을 검사합니다.
#
#     예시:
#       `TARGET_ASSERT_MODEL=("SM-A528B" "SM-A528N")`
#
#   TARGET_DISABLE_AVB_SIGNING
#     true로 설정하면 AVB 서명을 비활성화합니다.
#     기본값은 false입니다.
#
#   TARGET_KEEP_ORIGINAL_SIGN
#     true로 설정하면 대상 기기 커널 이미지에 원본 AVB/Samsung 서명 footer를 유지합니다.
#     기본값은 false입니다.
#
#   TARGET_BOOT_PARTITION_SIZE
#     대상 기기 boot 파티션 크기를 바이트 단위로 담는 정수입니다.
#
#   TARGET_DTBO_PARTITION_SIZE
#     대상 기기 dtbo 파티션 크기를 바이트 단위로 담는 정수입니다.
#
#   TARGET_INIT_BOOT_PARTITION_SIZE
#     대상 기기 init_boot 파티션 크기를 바이트 단위로 담는 정수입니다.
#
#   TARGET_VENDOR_BOOT_PARTITION_SIZE
#     대상 기기 vendor_boot 파티션 크기를 바이트 단위로 담는 정수입니다.
#
#   TARGET_CACHE_PARTITION_SIZE
#     대상 기기 cache 파티션 크기를 바이트 단위로 담는 정수입니다.
#
#   TARGET_USE_DYNAMIC_PARTITIONS
#     기기가 동적 파티션을 지원하는지 나타내는 불리언입니다.
#     기본값은 false입니다.
#
#   TARGET_SUPER_PARTITION_SIZE
#     대상 기기의 super 파티션 크기를 바이트 단위로 담는 정수입니다. lpdump 도구로 확인할 수 있습니다.
#     TARGET_USE_DYNAMIC_PARTITIONS가 true로 설정된 경우 필수입니다.
#     TARGET_${TARGET_SUPER_GROUP_NAME}_SIZE보다 커야 합니다.
#
#   [SOURCE/TARGET]_SUPER_GROUP_NAME
#     기기가 사용하는 super 파티션 그룹 이름 문자열입니다.
#     TARGET_USE_DYNAMIC_PARTITIONS가 true로 설정된 경우 필수입니다.
#     TARGET_SUPER_GROUP_NAME이 설정되지 않으면 기본적으로 SOURCE_SUPER_GROUP_NAME 값을 사용합니다.
#
#   TARGET_${TARGET_SUPER_GROUP_NAME}_SIZE
#     대상 기기의 super 그룹 크기를 바이트 단위로 담는 정수입니다. lpdump 도구로 확인할 수 있습니다.
#     TARGET_USE_DYNAMIC_PARTITIONS가 true로 설정된 경우 필수입니다.
#     TARGET_SUPER_PARTITION_SIZE보다 작아야 합니다.
#
#   TARGET_SYSTEM_PARTITION_SIZE
#     대상 기기 system 파티션 크기를 바이트 단위로 담는 정수입니다.
#     TARGET_USE_DYNAMIC_PARTITIONS가 false이면 사용하지 않습니다.
#
#   TARGET_VENDOR_PARTITION_SIZE
#     대상 기기 vendor 파티션 크기를 바이트 단위로 담는 정수입니다.
#     TARGET_USE_DYNAMIC_PARTITIONS가 false이면 사용하지 않습니다.
#
#   TARGET_PRODUCT_PARTITION_SIZE
#     대상 기기 product 파티션 크기를 바이트 단위로 담는 정수입니다.
#     TARGET_USE_DYNAMIC_PARTITIONS가 false이면 사용하지 않습니다.
#
#   TARGET_ODM_PARTITION_SIZE
#     대상 기기 odm 파티션 크기를 바이트 단위로 담는 정수입니다.
#     TARGET_USE_DYNAMIC_PARTITIONS가 false이면 사용하지 않습니다.
#
#   TARGET_VENDOR_DLKM_PARTITION_SIZE
#     대상 기기 vendor_dlkm 파티션 크기를 바이트 단위로 담는 정수입니다.
#     TARGET_USE_DYNAMIC_PARTITIONS가 false이면 사용하지 않습니다.
#
#   TARGET_ODM_DLKM_PARTITION_SIZE
#     대상 기기 odm_dlkm 파티션 크기를 바이트 단위로 담는 정수입니다.
#     TARGET_USE_DYNAMIC_PARTITIONS가 false이면 사용하지 않습니다.
#
#   TARGET_SYSTEM_DLKM_PARTITION_SIZE
#     대상 기기 system_dlkm 파티션 크기를 바이트 단위로 담는 정수입니다.
#     TARGET_USE_DYNAMIC_PARTITIONS가 false이면 사용하지 않습니다.
#
#   TARGET_OS_SINGLE_SYSTEM_IMAGE
#     대상 기기 SSI 문자열입니다. `ro.build.product` prop과 일치해야 합니다.
#     현재는 "qssi"와 "essi"만 지원합니다.
#
#   TARGET_OS_FILE_SYSTEM_TYPE
#     대상 기기 펌웨어 파일 시스템 문자열입니다.
#     기본값은 "erofs"입니다.
#     기본값과 다른 값을 사용하면 vendor와 kernel ramdisk의 기기 fstab 파일을 패치해야 합니다.
#
#   TARGET_OS_BUILD_SYSTEM_EXT_PARTITION
#     true로 설정하면 system_ext 파티션을 빌드합니다.
#
#   [SOURCE/TARGET]_AUDIO_CONFIG_RECORDALIVE_LIB_VERSION
#     기기의 RecordAlive 라이브러리 버전을 담는 정수입니다.
#     기본값은 "none"입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `framework.jar` 안의 `com.samsung.android.camera.mic.SemMultiMicManager.isSupported()` 메서드의 `version` 매개변수
#       - "/vendor/lib(64)/lib_SamsungRec_*.so" 라이브러리의 접미사 번호
#
#   [SOURCE/TARGET]_AUDIO_SUPPORT_ACH_RINGTONE
#     기기가 "Sync vibration with ringtone" 기능을 지원하는지 나타내는 불리언입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - /system/media/audio 파일이 "ACH_"로 시작함
#       - `framework.jar` 안의 `com.samsung.android.audio.Rune` 클래스에서 `SEC_AUDIO_SUPPORT_ACH_RINGTONE`이 true로 설정됨
#       - `framework.jar` 안의 `com.samsung.android.vibrator.VibRune` 클래스에서 `SUPPORT_ACH`가 true로 설정됨
#
#   [SOURCE/TARGET]_AUDIO_SUPPORT_DUAL_SPEAKER
#     기기가 듀얼 스피커를 지원하는지 나타내는 불리언입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `framework.jar` 안의 `com.samsung.android.audio.Rune` 클래스에서 `SEC_AUDIO_NUM_OF_SPEAKER`가 "2"로 설정됨
#       - `framework.jar` 안의 `com.samsung.android.audio.Rune` 클래스에서 `SEC_AUDIO_SUPPORT_DUAL_SPEAKER`가 true로 설정됨
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_DUAL_SPEAKER"가 "TRUE"로 설정됨
#
#   [SOURCE/TARGET]_AUDIO_SUPPORT_VIRTUAL_VIBRATION
#     기기가 "Vibration sound for incoming calls" 기능을 지원하는지 나타내는 불리언입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `framework.jar` 안의 `com.samsung.android.audio.Rune` 클래스에서 `SEC_AUDIO_SUPPORT_VIRTUAL_VIBRATION_SOUND`가 true로 설정됨
#       - `framework.jar` 안의 `com.samsung.android.vibrator.VibRune` 클래스에서 `SUPPORT_VIRTUAL_VIBRATION_SOUND`가 true로 설정됨
#
#   [SOURCE/TARGET]_CAMERA_SUPPORT_CAMERAX_EXTENSION
#     기기가 CameraX Extensions API를 지원하는지 나타내는 불리언입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - "/system/build.prop"의 "ro.camerax.extensions.enabled"가 "true"로 설정됨
#
#   [SOURCE/TARGET]_CAMERA_SUPPORT_CUTOUT_PROTECTION
#     기기가 카메라 노치 보호 기능을 지원하는지 나타내는 불리언입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `SystemUI.apk` 안의 "res/values/bools.xml"에서 "config_enableDisplayCutoutProtection"이 "true"로 설정됨
#
#   [SOURCE/TARGET]_CAMERA_SUPPORT_MASS_APP_FLAVOR
#     기기가 mass Samsung Camera 앱 변형을 포함하는지 나타내는 불리언입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `SamsungCamera.apk`의 `AndroidManifest.xml`에 `hal3_mass-phone-release` 값이 있음
#
#   [SOURCE/TARGET]_CAMERA_SUPPORT_SDK_SERVICE
#     기기가 Samsung Camera SDK Service를 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_COMMON_CONFIG_MDNIE_MODE
#     기기의 mDNIe 기능 비트 플래그를 담는 정수입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `services.jar` 안의 `com.samsung.android.hardware.display.SemMdnieManagerService` 클래스에서 `MDNIE_SUPPORT_FUNCTION` 값
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_COMMON_CONFIG_MDNIE_MODE" 값
#
#   [SOURCE/TARGET]_COMMON_SUPPORT_DYN_RESOLUTION_CONTROL
#     기기에 WQHD(+) 디스플레이가 있는지 나타내는 불리언입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `framework.jar` 안의 `com.samsung.android.rune.CoreRune` 클래스에서 `FW_DYNAMIC_RESOLUTION_CONTROL`이 true로 설정됨
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_COMMON_CONFIG_DYN_RESOLUTION_CONTROL"이 설정됨
#
#   [SOURCE/TARGET]_COMMON_SUPPORT_EMBEDDED_SIM
#     기기에 eSIM 지원이 있는지 나타내는 불리언입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_COMMON_CONFIG_EMBEDDED_SIM_SLOTSWITCH"가 설정됨
#
#   [SOURCE/TARGET]_COMMON_SUPPORT_HDR_EFFECT
#     기기가 "Video brightness" 기능을 지원하는지 나타내는 불리언입니다.
#     COMMON_CONFIG_MDNIE_MODE에 "mSupportContentModeVideoEnhance" 비트(1 << 2)가 있으면 기본값은 true입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `SecSettings.apk` 안의 `com.samsung.android.settings.usefulfeature.videoenhancer.VideoEnhancerPreferenceController.getAvailabilityStatus()`
#         메서드가 UNSUPPORTED_ON_DEVICE (3)이 아님
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_COMMON_SUPPORT_HDR_EFFECT"가 "TRUE"로 설정됨
#
#   [SOURCE/TARGET]_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME
#     SDHMS가 사용하는 DVFS 정책 파일 이름 문자열입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `ssrm.jar` 안의 `com.android.server.ssrm.Feature` 클래스에서 `DVFS_FILENAME` 값
#
#   [SOURCE/TARGET]_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME
#     SDHMS가 사용하는 SSRM 정책 파일 이름 문자열입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `ssrm.jar` 안의 `com.android.server.ssrm.Feature` 클래스에서 `SSRM_FILENAME` 값
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" 값
#
#   [SOURCE/TARGET]_FINGERPRINT_CONFIG_SENSOR
#     지문 센서 기능 문자열을 담는 문자열입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `framework.jar` 안의 `com.samsung.android.bio.fingerprint.SemFingerprintManager$Characteristic` 클래스에서 `mConfig` 값
#
#   [SOURCE/TARGET]_LCD_CONFIG_COLOR_WEAKNESS_SOLUTION
#     기기의 mDNIe 색약 기능 플래그를 담는 정수입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - (API 34 이하) `services.jar` 안의 `com.samsung.android.hardware.display.SemMdnieManagerService` 클래스에서 `WEAKNESS_SOLUTION_FUNCTION` 값
#       - (API 35 이상) `framework.jar` 안의 `android.view.accessibility.A11yRune` 클래스에서 `A11Y_COLOR_BOOL_SUPPORT_DMC_COLORWEAKNESS` 값
#
#   [SOURCE/TARGET]_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS
#     기기의 자동 밝기 유형을 담는 정수입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `services.jar` 안의 `com.android.server.power.PowerManagerUtil` 클래스에서 `AUTO_BRIGHTNESS_TYPE` 값
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS" 값
#
#   [SOURCE/TARGET]_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE
#     기기의 기본 주사율을 담는 정수입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE" 값
#
#   [SOURCE/TARGET]_LCD_CONFIG_HFR_MODE
#     기기의 가변 주사율 유형을 담는 정수입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `secinputdev-service.jar` 안의 `com.samsung.android.hardware.secinputdev.SemInputFeatures` 클래스에서 `LCD_CONFIG_HFR_MODE` 값
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_MODE" 값
#
#   [SOURCE/TARGET]_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE
#     기기가 사용할 수 있는 주사율 프로필 문자열입니다.
#     VRR이 없는 기기는 기본값이 "none"입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE" 값
#
#   [SOURCE/TARGET]_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE_NS
#     기기의 주사율 일반 속도 문자열입니다.
#     기본값은 "none"입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE_NS" 값
#
#   [SOURCE/TARGET]_LCD_CONFIG_SEAMLESS_BRT
#     VRR용 저/고 밝기 임계값 문자열입니다.
#     기본값은 "none"입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `framework.jar` 안의 `com.samsung.android.hardware.display.RefreshRateConfig` 클래스에서 `configBrt` 값
#
#   [SOURCE/TARGET]_LCD_CONFIG_SEAMLESS_LUX
#     VRR용 저/고 주변 조도 임계값 문자열입니다.
#     기본값은 "none"입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `framework.jar` 안의 `com.samsung.android.hardware.display.RefreshRateConfig` 클래스에서 `configLux` 값
#
#   [SOURCE/TARGET]_LCD_SUPPORT_MDNIE_HW
#     기기가 하드웨어 mDNIe를 지원하는지 나타내는 불리언입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `framework.jar` 안의 `android.view.accessibility.A11yRune` 클래스에서 `A11Y_COLOR_BOOL_SUPPORT_MDNIE_HW` 값
#       - floating_feature.xml의 "SEC_FLOATING_FEATURE_LCD_SUPPORT_MDNIE_HW" 값
#
#   [SOURCE/TARGET]_RIL_FEATURES
#     기기의 RIL 기능 문자열입니다.
#     기본값은 "none"입니다.
#     다음 방법으로 확인할 수 있습니다:
#     - `framework.jar` 안의 `com.android.internal.telephony.TelephonyFeatures` 클래스에서 `RIL_FEATURES` 값
#
#   [SOURCE/TARGET]_RIL_SIM_CONFIG_MULTISIM_TRAYCOUNT
#     기기의 멀티 SIM 트레이 개수를 담는 정수입니다.
#
#   [SOURCE/TARGET]_RIL_SUPPORT_WATERPROOF_SIM_TRAY_MSG
#     기기 SIM 트레이가 방수 보호를 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_SECURITY_CONFIG_ESE_CHIP_VENDOR
#     기기의 eSE 칩 제조사 문자열입니다.
#     기본값은 "none"입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `framework.jar` 안의 `com.android.server.SemService` 클래스에서 `chipVendor` 값
#       - `framework.jar` 안의 `com.samsung.android.service.SemService.SemServiceManager` 클래스에서 `chipVendor` 값
#       - `SecureElement.apk` 안의 `com.android.se.internal.UtilExtension` 클래스에서 `chipVendor` 값
#
#   [SOURCE/TARGET]_SECURITY_CONFIG_ESE_COS_NAME
#     기기의 eSE cOS 이름 문자열입니다.
#     기본값은 "none"입니다.
#     다음 방법으로 확인할 수 있습니다:
#       - `framework.jar` 안의 `com.android.server.SemService` 클래스에서 `cosName` 값
#       - `framework.jar` 안의 `com.samsung.android.service.SemService.SemServiceManager` 클래스에서 `cosName` 값
#       - `SecureElement.apk` 안의 `com.android.se.internal.UtilExtension` 클래스에서 `mEseCosName` 값
#
#   [SOURCE/TARGET]_WLAN_CONFIG_CONNECTION_PERSONALIZATION
#     기기의 Connection Personalizer 기능 플래그를 담는 정수입니다.
#
#   [SOURCE/TARGET]_WLAN_CONFIG_CPU_CSTATE_DISABLE_THRESHOLD
#     기기의 CPU C-State 부스트 임계값을 담는 정수입니다.
#
#   [SOURCE/TARGET]_WLAN_CONFIG_CUSTOM_BACKOFF
#     Wi-Fi 공존 채널 회피용 기기 backoff 설정 문자열입니다.
#
#   [SOURCE/TARGET]_WLAN_CONFIG_DATA_ACTIVITY_AFFINITY_BOOSTER_THRESHOLD
#     기기의 Wi-Fi affinity 부스트 임계값을 담는 정수입니다.
#
#   [SOURCE/TARGET]_WLAN_CONFIG_DYNAMIC_SWITCH
#     기기의 dynamic switch 기능 플래그를 담는 정수입니다.
#
#   [SOURCE/TARGET]_WLAN_CONFIG_L1SS_DISABLE_THRESHOLD
#     기기의 L1ss 부스트 임계값을 담는 정수입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_80211AX
#     기기가 Wi-Fi 6 표준을 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_80211AX_6GHZ
#     기기가 Wi-Fi 6E 표준을 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_APE_SERVICE
#     기기가 "Realtime Data Priority Mode" 기능을 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_LOWLATENCY
#     기기가 저지연 Wi-Fi를 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_MBO
#     기기가 Wi-Fi Agile Multiband 표준을 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_MOBILEAP_5G_BASEDON_COUNTRY
#     국가 코드에 따라 기기가 5GHz 모바일 핫스팟 대역을 활성화해야 하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_MOBILEAP_6G
#     기기가 Wi-Fi 6E 모바일 핫스팟을 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_MOBILEAP_DUALAP
#     기기가 모바일 핫스팟 듀얼 밴드 기능을 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_MOBILEAP_OWE
#     기기가 OWE 표준을 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_MOBILEAP_POWER_SAVEMODE
#     기기가 모바일 핫스팟 "절전 모드" 기능을 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_MOBILEAP_PRIORITIZE_TRAFFIC
#     기기가 모바일 핫스팟 "실시간 트래픽 우선 처리" 기능을 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_MOBILEAP_WIFI_CONCURRENCY
#     기기가 DBS를 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_MOBILEAP_WIFISHARING_LITE
#     기기가 Wi-Fi Sharing Lite를 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_SWITCH_FOR_INDIVIDUAL_APPS
#     기기가 "개별 앱 전환 허용" 기능을 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_TWT_CONTROL
#     기기가 TWT를 지원하는지 나타내는 불리언입니다.
#
#   [SOURCE/TARGET]_WLAN_SUPPORT_WIFI_TO_CELLULAR
#     기기가 Wi-Fi to Cellular를 지원하는지 나타내는 불리언입니다.
{
    echo "# Automatically generated by scripts/internal/gen_config_file.sh"
    echo "ROM_IS_OFFICIAL=\"$(IS_UNICA_CERT_AVAILABLE)\""
    GET_BUILD_VAR "ROM_VERSION"
    GET_BUILD_VAR "ROM_BUILD_TIMESTAMP" "$(date +%s)"
    GET_BUILD_VAR "SOURCE_FIRMWARE"
    if [ "${#SOURCE_EXTRA_FIRMWARES[@]}" -ge 1 ]; then
        echo "SOURCE_EXTRA_FIRMWARES=\"$(IFS=":"; printf '%s' "${SOURCE_EXTRA_FIRMWARES[*]}")\""
    else
        echo "SOURCE_EXTRA_FIRMWARES=\"\""
    fi
    GET_BUILD_VAR "SOURCE_PLATFORM_SDK_VERSION"
    GET_BUILD_VAR "SOURCE_PRODUCT_SHIPPING_API_LEVEL"
    GET_BUILD_VAR "SOURCE_BOARD_API_LEVEL"
    GET_BUILD_VAR "TARGET_NAME"
    GET_BUILD_VAR "TARGET_CODENAME"
    GET_BUILD_VAR "TARGET_PLATFORM" "none"
    if [ "${#TARGET_ASSERT_MODEL[@]}" -ge 1 ]; then
        echo "TARGET_ASSERT_MODEL=\"$(IFS=":"; printf '%s' "${TARGET_ASSERT_MODEL[*]}")\""
    else
        echo "TARGET_ASSERT_MODEL=\"\""
    fi
    GET_BUILD_VAR "TARGET_FIRMWARE"
    if [ "${#TARGET_EXTRA_FIRMWARES[@]}" -ge 1 ]; then
        echo "TARGET_EXTRA_FIRMWARES=\"$(IFS=":"; printf '%s' "${TARGET_EXTRA_FIRMWARES[*]}")\""
    else
        echo "TARGET_EXTRA_FIRMWARES=\"\""
    fi
    GET_BUILD_VAR "TARGET_PLATFORM_SDK_VERSION"
    GET_BUILD_VAR "TARGET_PRODUCT_SHIPPING_API_LEVEL"
    GET_BUILD_VAR "TARGET_BOARD_API_LEVEL"
    GET_BUILD_VAR "TARGET_DISABLE_AVB_SIGNING" "false"
    GET_BUILD_VAR "TARGET_INCLUDE_PATCHED_VBMETA" "false"
    GET_BUILD_VAR "TARGET_KEEP_ORIGINAL_SIGN" "false"
    GET_BUILD_VAR "TARGET_BOOT_PARTITION_SIZE" "none"
    GET_BUILD_VAR "TARGET_DTBO_PARTITION_SIZE" "none"
    GET_BUILD_VAR "TARGET_INIT_BOOT_PARTITION_SIZE" "none"
    GET_BUILD_VAR "TARGET_VENDOR_BOOT_PARTITION_SIZE" "none"
    GET_BUILD_VAR "TARGET_CACHE_PARTITION_SIZE" "none"
    GET_BUILD_VAR "TARGET_USE_DYNAMIC_PARTITIONS" "false"
    if ${TARGET_USE_DYNAMIC_PARTITIONS:-false}; then
        GET_BUILD_VAR "TARGET_SUPER_PARTITION_SIZE"
        GET_BUILD_VAR "SOURCE_SUPER_GROUP_NAME"
        GET_BUILD_VAR "TARGET_SUPER_GROUP_NAME" "$SOURCE_SUPER_GROUP_NAME"
        GET_BUILD_VAR "TARGET_$(tr "[:lower:]" "[:upper:]" <<< "${TARGET_SUPER_GROUP_NAME:-$SOURCE_SUPER_GROUP_NAME}")_SIZE"
    else
        GET_BUILD_VAR "TARGET_SYSTEM_PARTITION_SIZE" "none"
        GET_BUILD_VAR "TARGET_VENDOR_PARTITION_SIZE" "none"
        GET_BUILD_VAR "TARGET_PRODUCT_PARTITION_SIZE" "none"
        GET_BUILD_VAR "TARGET_ODM_PARTITION_SIZE" "none"
        GET_BUILD_VAR "TARGET_VENDOR_DLKM_PARTITION_SIZE" "none"
        GET_BUILD_VAR "TARGET_ODM_DLKM_PARTITION_SIZE" "none"
        GET_BUILD_VAR "TARGET_SYSTEM_DLKM_PARTITION_SIZE" "none"
    fi
    GET_BUILD_VAR "TARGET_OS_SINGLE_SYSTEM_IMAGE"
    GET_BUILD_VAR "TARGET_OS_FILE_SYSTEM_TYPE" "erofs"
    GET_BUILD_VAR "TARGET_OS_BUILD_SYSTEM_EXT_PARTITION"
    GET_BUILD_VAR "SOURCE_AUDIO_CONFIG_RECORDALIVE_LIB_VERSION" "none"
    GET_BUILD_VAR "TARGET_AUDIO_CONFIG_RECORDALIVE_LIB_VERSION" "none"
    GET_BUILD_VAR "SOURCE_AUDIO_SUPPORT_ACH_RINGTONE"
    GET_BUILD_VAR "TARGET_AUDIO_SUPPORT_ACH_RINGTONE"
    GET_BUILD_VAR "SOURCE_AUDIO_SUPPORT_DUAL_SPEAKER"
    GET_BUILD_VAR "TARGET_AUDIO_SUPPORT_DUAL_SPEAKER"
    GET_BUILD_VAR "SOURCE_AUDIO_SUPPORT_VIRTUAL_VIBRATION"
    GET_BUILD_VAR "TARGET_AUDIO_SUPPORT_VIRTUAL_VIBRATION"
    GET_BUILD_VAR "SOURCE_CAMERA_SUPPORT_CAMERAX_EXTENSION"
    GET_BUILD_VAR "TARGET_CAMERA_SUPPORT_CAMERAX_EXTENSION"
    GET_BUILD_VAR "SOURCE_CAMERA_SUPPORT_CUTOUT_PROTECTION"
    GET_BUILD_VAR "TARGET_CAMERA_SUPPORT_CUTOUT_PROTECTION"
    GET_BUILD_VAR "SOURCE_CAMERA_SUPPORT_MASS_APP_FLAVOR"
    GET_BUILD_VAR "TARGET_CAMERA_SUPPORT_MASS_APP_FLAVOR"
    GET_BUILD_VAR "SOURCE_CAMERA_SUPPORT_SDK_SERVICE"
    GET_BUILD_VAR "TARGET_CAMERA_SUPPORT_SDK_SERVICE"
    GET_BUILD_VAR "SOURCE_COMMON_CONFIG_MDNIE_MODE"
    GET_BUILD_VAR "TARGET_COMMON_CONFIG_MDNIE_MODE"
    GET_BUILD_VAR "SOURCE_COMMON_SUPPORT_DYN_RESOLUTION_CONTROL"
    GET_BUILD_VAR "TARGET_COMMON_SUPPORT_DYN_RESOLUTION_CONTROL"
    GET_BUILD_VAR "SOURCE_COMMON_SUPPORT_EMBEDDED_SIM"
    GET_BUILD_VAR "TARGET_COMMON_SUPPORT_EMBEDDED_SIM"
    GET_BUILD_VAR "SOURCE_COMMON_SUPPORT_HDR_EFFECT" "$(test "$((SOURCE_COMMON_CONFIG_MDNIE_MODE & 4))" != "0" && echo "true" || echo "false")"
    GET_BUILD_VAR "TARGET_COMMON_SUPPORT_HDR_EFFECT" "$(test "$((TARGET_COMMON_CONFIG_MDNIE_MODE & 4))" != "0" && echo "true" || echo "false")"
    GET_BUILD_VAR "SOURCE_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME"
    GET_BUILD_VAR "TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME"
    GET_BUILD_VAR "SOURCE_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME"
    GET_BUILD_VAR "TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME"
    GET_BUILD_VAR "SOURCE_FINGERPRINT_CONFIG_SENSOR"
    GET_BUILD_VAR "TARGET_FINGERPRINT_CONFIG_SENSOR"
    GET_BUILD_VAR "SOURCE_LCD_CONFIG_COLOR_WEAKNESS_SOLUTION"
    GET_BUILD_VAR "TARGET_LCD_CONFIG_COLOR_WEAKNESS_SOLUTION"
    GET_BUILD_VAR "SOURCE_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS"
    GET_BUILD_VAR "TARGET_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS"
    GET_BUILD_VAR "SOURCE_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE"
    GET_BUILD_VAR "TARGET_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE"
    GET_BUILD_VAR "SOURCE_LCD_CONFIG_HFR_MODE"
    GET_BUILD_VAR "TARGET_LCD_CONFIG_HFR_MODE"
    GET_BUILD_VAR "SOURCE_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE" "$(test "$SOURCE_LCD_CONFIG_HFR_MODE" -gt "0" && echo "" || echo "none")"
    GET_BUILD_VAR "TARGET_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE" "$(test "$TARGET_LCD_CONFIG_HFR_MODE" -gt "0" && echo "" || echo "none")"
    GET_BUILD_VAR "SOURCE_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE_NS" "none"
    GET_BUILD_VAR "TARGET_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE_NS" "none"
    GET_BUILD_VAR "SOURCE_LCD_CONFIG_SEAMLESS_BRT" "none"
    GET_BUILD_VAR "TARGET_LCD_CONFIG_SEAMLESS_BRT" "none"
    GET_BUILD_VAR "SOURCE_LCD_CONFIG_SEAMLESS_LUX" "none"
    GET_BUILD_VAR "TARGET_LCD_CONFIG_SEAMLESS_LUX" "none"
    GET_BUILD_VAR "SOURCE_LCD_SUPPORT_MDNIE_HW"
    GET_BUILD_VAR "TARGET_LCD_SUPPORT_MDNIE_HW"
    GET_BUILD_VAR "SOURCE_RIL_FEATURES" "none"
    GET_BUILD_VAR "TARGET_RIL_FEATURES" "none"
    GET_BUILD_VAR "SOURCE_RIL_SIM_CONFIG_MULTISIM_TRAYCOUNT"
    GET_BUILD_VAR "TARGET_RIL_SIM_CONFIG_MULTISIM_TRAYCOUNT"
    GET_BUILD_VAR "SOURCE_RIL_SUPPORT_WATERPROOF_SIM_TRAY_MSG"
    GET_BUILD_VAR "TARGET_RIL_SUPPORT_WATERPROOF_SIM_TRAY_MSG"
    GET_BUILD_VAR "SOURCE_SECURITY_CONFIG_ESE_CHIP_VENDOR" "none"
    GET_BUILD_VAR "TARGET_SECURITY_CONFIG_ESE_CHIP_VENDOR" "none"
    GET_BUILD_VAR "SOURCE_SECURITY_CONFIG_ESE_COS_NAME" "none"
    GET_BUILD_VAR "TARGET_SECURITY_CONFIG_ESE_COS_NAME" "none"
    GET_BUILD_VAR "SOURCE_WLAN_CONFIG_CONNECTION_PERSONALIZATION"
    GET_BUILD_VAR "TARGET_WLAN_CONFIG_CONNECTION_PERSONALIZATION"
    GET_BUILD_VAR "SOURCE_WLAN_CONFIG_CPU_CSTATE_DISABLE_THRESHOLD"
    GET_BUILD_VAR "TARGET_WLAN_CONFIG_CPU_CSTATE_DISABLE_THRESHOLD"
    GET_BUILD_VAR "SOURCE_WLAN_CONFIG_CUSTOM_BACKOFF" "none"
    GET_BUILD_VAR "TARGET_WLAN_CONFIG_CUSTOM_BACKOFF" "none"
    GET_BUILD_VAR "SOURCE_WLAN_CONFIG_DATA_ACTIVITY_AFFINITY_BOOSTER_THRESHOLD"
    GET_BUILD_VAR "TARGET_WLAN_CONFIG_DATA_ACTIVITY_AFFINITY_BOOSTER_THRESHOLD"
    GET_BUILD_VAR "SOURCE_WLAN_CONFIG_DYNAMIC_SWITCH"
    GET_BUILD_VAR "TARGET_WLAN_CONFIG_DYNAMIC_SWITCH"
    GET_BUILD_VAR "SOURCE_WLAN_CONFIG_L1SS_DISABLE_THRESHOLD"
    GET_BUILD_VAR "TARGET_WLAN_CONFIG_L1SS_DISABLE_THRESHOLD"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_80211AX"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_80211AX"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_80211AX_6GHZ"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_80211AX_6GHZ"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_APE_SERVICE"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_APE_SERVICE"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_LOWLATENCY"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_LOWLATENCY"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_MBO"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_MBO"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_MOBILEAP_5G_BASEDON_COUNTRY"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_MOBILEAP_5G_BASEDON_COUNTRY"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_MOBILEAP_6G"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_MOBILEAP_6G"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_MOBILEAP_DUALAP"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_MOBILEAP_DUALAP"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_MOBILEAP_OWE"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_MOBILEAP_OWE"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_MOBILEAP_POWER_SAVEMODE"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_MOBILEAP_POWER_SAVEMODE"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_MOBILEAP_PRIORITIZE_TRAFFIC"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_MOBILEAP_PRIORITIZE_TRAFFIC"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_MOBILEAP_WIFI_CONCURRENCY"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_MOBILEAP_WIFI_CONCURRENCY"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_MOBILEAP_WIFISHARING_LITE"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_MOBILEAP_WIFISHARING_LITE"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_SWITCH_FOR_INDIVIDUAL_APPS"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_SWITCH_FOR_INDIVIDUAL_APPS"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_TWT_CONTROL"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_TWT_CONTROL"
    GET_BUILD_VAR "SOURCE_WLAN_SUPPORT_WIFI_TO_CELLULAR"
    GET_BUILD_VAR "TARGET_WLAN_SUPPORT_WIFI_TO_CELLULAR"
} > "$OUT_DIR/config.sh"

exit 0
