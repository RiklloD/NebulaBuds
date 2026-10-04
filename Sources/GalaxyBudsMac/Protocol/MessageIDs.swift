// Message ID names. Base list from GalaxyBudsClient's decompilation-derived MsgIds enum;
// entries marked "B4P" were observed/verified on a Galaxy Buds4 Pro.

enum MsgID {
    static let debugModeLog: UInt8 = 0x21
    static let debugSku: UInt8 = 0x22
    static let debugGetAllData: UInt8 = 0x26
    static let debugSerialNumber: UInt8 = 0x29
    static let ack: UInt8 = 0x42
    static let extraClearCall: UInt8 = 0x48
    static let statusUpdated: UInt8 = 0x60
    static let extendedStatusUpdated: UInt8 = 0x61
    static let versionInfoLong: UInt8 = 0x68
    static let customEqualizerRecv: UInt8 = 0x69
    static let pauseWhenOneBudRemoved: UInt8 = 0x6C
    static let callPathControl: UInt8 = 0x6E
    static let ancWithOneEarbud: UInt8 = 0x6F
    static let multipointInfo: UInt8 = 0x76
    static let noiseControlsUpdate: UInt8 = 0x77
    static let noiseControls: UInt8 = 0x78
    static let touchAndHoldNoiseControls: UInt8 = 0x79
    static let detectConversations: UInt8 = 0x7A
    static let detectConversationsDuration: UInt8 = 0x7B
    static let spatialAudio: UInt8 = 0x7C
    static let speakSeamlessly: UInt8 = 0x7D
    static let customizeAmbient: UInt8 = 0x82
    static let noiseReductionLevel: UInt8 = 0x83
    static let ambientVolume: UInt8 = 0x84
    static let equalizer: UInt8 = 0x86
    static let managerInfo: UInt8 = 0x88
    static let customEqualizerSend: UInt8 = 0x89
    static let sidetone: UInt8 = 0x8B
    static let hearingEnhancements: UInt8 = 0x8F
    static let lockTouchpad: UInt8 = 0x90
    static let touchUpdated: UInt8 = 0x91
    static let touchpadOption: UInt8 = 0x92
    static let fitTest: UInt8 = 0x9D
    static let fitTestResult: UInt8 = 0x9E
    static let findStart: UInt8 = 0xA0
    static let findStop: UInt8 = 0xA1
    static let muteEarbud: UInt8 = 0xA2
    static let muteEarbudStatus: UInt8 = 0xA3
    static let seamlessConnection: UInt8 = 0xAF
    static let spatialAudioData: UInt8 = 0xC2
    static let spatialAudioControl: UInt8 = 0xC3
    static let cradleSerialNumber: UInt8 = 0xCD
    static let socBatteryCycle: UInt8 = 0xCE
    // Named by Samsung's protocol; payload and effect are still experimental on Buds4 Pro.
    static let adaptiveEqualizerControl: UInt8 = 0xDA
    static let adaptiveEqualizerStatus: UInt8 = 0xDB
    static let dumpBondedDevices: UInt8 = 0xD4 // DANGER: leaks link keys, never sent by this app
    static let debugEvent: UInt8 = 0xF2

    static func name(_ id: UInt8) -> String { names[id] ?? String(format: "UNKNOWN_0x%02X", id) }

    static let names: [UInt8: String] = [
        0x01: "UNK_SPP_ALT",
        0x0F: "HOT_COMMAND_MANAGE",
        0x10: "SET_MODE_CHANGE",
        0x11: "GET_MODE",
        0x12: "HIDDEN_CMD_MODE",
        0x13: "HIDDEN_CMD_DATA",
        0x15: "HIDDEN_FACTORYINFO_MODE1",
        0x16: "HIDDEN_FACTORYINFO_MODE2",
        0x17: "HIDDEN_FACTORYINFO_MODE3",
        0x20: "SET_DEBUG_MODE",
        0x21: "DEBUG_MODE_LOG (B4P: per-bud stats pushed after MANAGER_INFO)",
        0x22: "DEBUG_SKU",
        0x23: "READ_WATER_DETECTION_HISTORY",
        0x24: "DEBUG_GET_VERSION",
        0x26: "DEBUG_GET_ALL_DATA",
        0x28: "DEBUG_BUILD_INFO",
        0x29: "DEBUG_SERIAL_NUMBER",
        0x2A: "ACC_SENSOR_LOGGING",
        0x2D: "TOUCH_ON_BUDS",
        0x30: "LOG_COREDUMP_COMMIT_SUICIDE",
        0x31: "LOG_COREDUMP_DATA_SIZE",
        0x32: "LOG_COREDUMP_DATA",
        0x33: "LOG_COREDUMP_COMPLETE",
        0x34: "LOG_TRACE_START",
        0x35: "LOG_TRACE_DATA",
        0x36: "LOG_TRACE_COMPLETE",
        0x37: "LOG_TRACE_ROLE_SWITCH",
        0x38: "LOG_COREDUMP_DATA_DONE",
        0x39: "LOG_TRACE_DATA_DONE",
        0x3A: "LOG_SESSION_OPEN",
        0x3B: "LOG_SESSION_CLOSE",
        0x3C: "LOG_GET_CONFIG",
        0x3D: "LOG_SET_CONFIG",
        0x40: "USAGE_REPORT",
        0x41: "METERING_REPORT",
        0x42: "UNIVERSAL_MSG_ID_ACKNOWLEDGEMENT",
        0x43: "WRITE_PROPERTY",
        0x44: "READ_PROPERTY",
        0x45: "NOTIFY_PROPERTY",
        0x47: "USAGE_REPORT_V2",
        0x48: "EXTRA_CLEAR_SOUND_CALL",
        0x4A: "AGING_TEST_REPORT",
        0x4B: "ACT_TEST_CMD",
        0x50: "RESET",
        0x51: "RESP",
        0x52: "REBOOT",
        0x53: "POWEROFF",
        0x56: "RFTESTMODE",
        0x57: "STATUS_ALERT",
        0x60: "STATUS_UPDATED",
        0x61: "EXTENDED_STATUS_UPDATED",
        0x62: "CONNECTION_UPDATED",
        0x63: "VERSION_INFO",
        0x64: "SET_HOT_COMMAND",
        0x66: "SET_BIXBY_KEYWORD",
        0x67: "SET_HEARING_TEST_RESULT",
        0x68: "VERSION_INFO_LONG",
        0x69: "CUSTOM_EQUALIZE_RECV",
        0x6C: "PAUSE_MEDIA_WHEN_ONE_BUD_REMOVED",
        0x6D: "AMBIENT_DURING_CALL_NOTI",
        0x6E: "SET_CALL_PATH_CONTROL",
        0x6F: "SET_ANC_WITH_ONE_EARBUD",
        0x70: "MAIN_CHANGE",
        0x71: "PROFILE_CONTROL",
        0x72: "PAIRING_MODE",
        0x73: "AUTO_SWITCH_AUDIO_OUTPUT",
        0x76: "MULTIPOINT_INFO",
        0x77: "NOISE_CONTROLS_UPDATE",
        0x78: "NOISE_CONTROLS",
        0x79: "SET_TOUCH_AND_HOLD_NOISE_CONTROLS",
        0x7A: "SET_DETECT_CONVERSATIONS",
        0x7B: "SET_DETECT_CONVERSATIONS_DURATION",
        0x7C: "SET_SPATIAL_AUDIO",
        0x7D: "SET_SPEAK_SEAMLESSLY",
        0x7E: "SET_AMPLIFY_AMBIENT_SOUND",
        0x80: "SET_AMBIENT_MODE",
        0x81: "AMBIENT_MODE_UPDATED",
        0x82: "CUSTOMIZE_AMBIENT_SOUND",
        0x83: "NOISE_REDUCTION_LEVEL",
        0x84: "AMBIENT_VOLUME",
        0x85: "ADJUST_SOUND_SYNC",
        0x86: "EQUALIZER",
        0x87: "GAME_MODE",
        0x88: "MANAGER_INFO",
        0x89: "CUSTOM_EQUALIZE_SEND",
        0x8A: "SET_IN_BAND_RINGTONE",
        0x8B: "SET_SIDETONE",
        0x8D: "TAP_TEST_MODE",
        0x8E: "BUDS_LIGHTING_SYNC",
        0x8F: "SET_HEARING_ENHANCEMENTS",
        0x90: "LOCK_TOUCHPAD",
        0x91: "TOUCH_UPDATED",
        0x92: "SET_TOUCHPAD_OPTION",
        0x93: "SET_TOUCHPAD_OTHER_OPTION",
        0x94: "BATTERY_TYPE",
        0x95: "OUTSIDE_DOUBLE_TAP",
        0x96: "EXTRA_HIGH_AMBIENT",
        0x97: "SET_VOICE_WAKE_UP",
        0x98: "SET_NOISE_REDUCTION",
        0x99: "VOICE_WAKE_UP_LANGUAGE",
        0x9A: "VOICE_WAKE_UP_EVENT",
        0x9B: "NOISE_REDUCTION_MODE_UPDATE",
        0x9C: "VOICE_WAKE_UP_LISTENING_STATUS",
        0x9D: "CHECK_THE_FIT_OF_EARBUDS",
        0x9E: "CHECK_THE_FIT_OF_EARBUDS_RESULT",
        0x9F: "PASS_THROUGH",
        0xA0: "FIND_MY_EARBUDS_START",
        0xA1: "FIND_MY_EARBUDS_STOP",
        0xA2: "MUTE_EARBUD",
        0xA3: "MUTE_EARBUD_STATUS_UPDATED",
        0xA4: "VOICE_NOTI_STATUS",
        0xA5: "VOICE_NOTI_STOP",
        0xA6: "FIND_MY_EARBUDS_ON_WEARING_START",
        0xA7: "UPDATE_TIME",
        0xA8: "START_VOICE_RECORD",
        0xA9: "COUPLING_HELPER_READ",
        0xAA: "COUPLING_HELPER_WRITE",
        0xAB: "SELF_TEST",
        0xAC: "SET_FMM_CONFIG",
        0xAD: "GET_FMM_CONFIG",
        0xAF: "SET_SEAMLESS_CONNECTION",
        0xB0: "FOTA_V1_SESSION",
        0xB1: "FOTA_V1_CONTROL",
        0xB2: "FOTA_V1_DOWNLOAD_DATA",
        0xB3: "FOTA_V1_UPDATED",
        0xB4: "FOTA_DEVICE_INFO_SW_VERSION",
        0xB5: "FOTA_BACKGROUND_NEED",
        0xB6: "FOTA_BACKGROUND_READY",
        0xB7: "FOTA_CHANGE_HALL_IC_STATUS",
        0xB9: "FOTA_RESULT",
        0xBA: "FOTA_EMERGENCY",
        0xBB: "FOTA_OPEN",
        0xBC: "FOTA_CONTROL",
        0xBD: "FOTA_DOWNLOAD_DATA",
        0xBE: "FOTA_UPDATE",
        0xC0: "UPDATE_VOICE_CMD",
        0xC1: "SET_VOICE_CMD",
        0xC2: "SPATIAL_AUDIO_DATA",
        0xC3: "SPATIAL_AUDIO_CONTROL",
        0xC5: "SET_ADAPTIVE_VOLUME_ENABLED",
        0xC6: "NECK_POSTURE_CALI_DATA",
        0xC7: "NECK_POSTURE_CONTROL",
        0xC8: "NECK_POSTURE_PHONE_DATA",
        0xC9: "NECK_POSTURE_SET",
        0xCA: "OVERHEAT",
        0xCC: "HEARING_TEST_DATA",
        0xCD: "CRADLE_SERIAL_NUMBER",
        0xCE: "SOC_BATTERY_CYCLE",
        0xCF: "RESET_BATTERY_SOC_CYCLE",
        0xD3: "GET_PERSONAL_NAME",
        0xD4: "UNK_DUMP_BONDED_DEVICES (B4P: leaks link keys!)",
        0xD6: "UNK_BONDED_DEVICES",
        0xD8: "BLUETERM_TX_TRAFFIC",
        0xD9: "ADAPTIVE_EQ_VOLUME_CONTROL",
        0xDA: "ADAPTIVE_EQ_CONTROL",
        0xDB: "ADAPTIVE_EQ_STATUS",
        0xDE: "UASC_SIREN_DETECT",
        0xE9: "SD_SPEAKER_RES",
        0xEA: "SD_MIC_RES",
        0xF1: "DEBUG_ERROR_CODE",
        0xF2: "DEBUG_EVENT",
        0xFA: "SD_BATTERY_STATUS",
        0xFB: "SD_CABLE_CHARGING",
        0xFC: "SD_WIRELESS_CHARGING",
        0xFE: "SD_TOUCH_RES",
        0xFF: "SET_TOUCH_TYPE",
        0xF4: "UNK_PERIODIC_STATS (B4P: pushed 3-part blob)",
    ]
}
