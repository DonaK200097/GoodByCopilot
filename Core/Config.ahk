Cfg_TargetConfigVersion() {
    return 4
}

Cfg_IsChecked(val) {
    return (StrLower(String(val)) == "true" || String(val) == "1")
}

Cfg_WriteSettingsEntries(configPath, entries) {
    for item in entries
        IniWrite(item[2], configPath, "Settings", item[1])
    IniWrite(String(Cfg_TargetConfigVersion()), configPath, "Settings", "ConfigVersion")
}

Cfg_NormalizeExeName(s) {
    t := Trim(String(s))
    if (t = "")
        return ""
    return RegExReplace(t, "i)\.exe$", "")
}

Cfg_GetSelectedServiceData(listPath, selectedSection, emptyText) {
    if (selectedSection = "" || selectedSection = emptyText)
        return {title: "", file: "", exe: "", selected: emptyText}
    finalTitle := selectedSection
    finalFile := selectedSection
    finalExe := ""
    try {
        finalTitle := IniRead(listPath, selectedSection, "title", selectedSection)
        finalFile := IniRead(listPath, selectedSection, "file", selectedSection)
        finalExe := Cfg_NormalizeExeName(IniRead(listPath, selectedSection, "exe", ""))
    } catch {
    }
    return {title: finalTitle, file: finalFile, exe: finalExe, selected: selectedSection}
}

Cfg_TryDeleteFileSafe(path) {
    if FileExist(path)
        try FileDelete(path)
}

Cfg_TryDeleteDirSafe(path) {
    if DirExist(path)
        try DirDelete(path, true)
}

Cfg_CleanRuntimeData(coreDir, configPath, listPath) {
    Cfg_TryDeleteDirSafe(coreDir "\PWA")
    Cfg_TryDeleteFileSafe(configPath)
    Cfg_TryDeleteFileSafe(coreDir "\HotkeyError.ini")
    Cfg_TryDeleteFileSafe(coreDir "\SessionHwnd.ini")
    Cfg_TryDeleteFileSafe(listPath)
}

Cfg_MigrateToV2(configPath) {
    ; Add explicit language key only if missing: empty means auto-detect.
    try {
        _ := IniRead(configPath, "Settings", "Language")
    } catch {
        IniWrite("", configPath, "Settings", "Language")
    }
}

Cfg_MigrateToV3(configPath) {
    defaults := Map(
        "ThemeMode", "System",
        "BgColor", "",
        "TextPrimary", "",
        "TextSecondary", "",
        "InputBg", "",
        "StatusActiveBg", "",
        "StatusActiveText", "",
        "StatusStoppedBg", "",
        "StatusStoppedText", "",
        "StatusApplyingBg", "",
        "StatusApplyingText", "",
        "StatusAppliedBg", "",
        "StatusAppliedText", ""
    )
    for key, value in defaults {
        try {
            _ := IniRead(configPath, "Settings", key)
        } catch {
            IniWrite(value, configPath, "Settings", key)
        }
    }
}

Cfg_MigrateToV4(configPath) {
    defaults := Map(
        "AutoStart", "True",
        "ShowTray", "True",
        "ActionClose", "False"
    )
    for key, value in defaults {
        try {
            _ := IniRead(configPath, "Settings", key)
        } catch {
            IniWrite(value, configPath, "Settings", key)
        }
    }
}

Cfg_EnsureConfigVersion(configPath) {
    if !FileExist(configPath)
        return
    ver := 1
    try {
        ver := Integer(IniRead(configPath, "Settings", "ConfigVersion", "1"))
    } catch {
        ver := 1
    }
    if (ver < 2)
        Cfg_MigrateToV2(configPath)
    if (ver < 3)
        Cfg_MigrateToV3(configPath)
    if (ver < 4)
        Cfg_MigrateToV4(configPath)
    IniWrite(String(Cfg_TargetConfigVersion()), configPath, "Settings", "ConfigVersion")
}
