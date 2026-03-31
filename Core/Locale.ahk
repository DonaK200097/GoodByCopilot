Loc_UILanguageIsRussianFamily() {
    try {
        lid := DllCall("kernel32\GetUserDefaultUILanguage", "UShort")
        prim := lid & 0x3FF
        if (prim = 0x19 || prim = 0x22 || prim = 0x23)
            return true
    } catch {
    }
    return false
}

Loc_GetAppLanguage(configPath) {
    try {
        forced := StrLower(Trim(IniRead(configPath, "Settings", "Language", "")))
        if (forced = "ru")
            return "RU"
        if (forced = "en")
            return "EN"
    } catch {
    }
    if (Loc_UILanguageIsRussianFamily())
        return "RU"
    try {
        loc := RegRead("HKEY_CURRENT_USER\Control Panel\International", "LocaleName")
        p := StrLower(SubStr(loc, 1, 2))
        if (p = "ru" || p = "uk" || p = "be" || p = "kk")
            return "RU"
    } catch {
    }
    return "EN"
}
