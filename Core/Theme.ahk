Theme_GetSystemMode() {
    try {
        isLight := Integer(RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme"))
        return isLight ? "Light" : "Dark"
    } catch {
        return "Light"
    }
}

Theme_GetSupportedMode(modeRaw) {
    mode := StrLower(Trim(String(modeRaw)))
    if (mode = "dark")
        return "Dark"
    if (mode = "light")
        return "Light"
    return "System"
}

Theme_Merge(base, overrides) {
    out := Map()
    for k, v in base
        out[k] := v
    for k, v in overrides
        out[k] := v
    return out
}

Theme_DefaultTokens(mode, accentColor) {
    light := Map(
        "ThemeMode", mode,
        "ResolvedMode", "Light",
        "AccentColor", accentColor,
        "BgColor", "FFFFFF",
        "TextPrimary", "1A1A1A",
        "TextSecondary", "333333",
        "InputBg", "F2F2F2",
        "ButtonBg", "F2F2F2",
        "ButtonText", "1A1A1A",
        "StatusActiveBg", accentColor,
        "StatusActiveText", "000000",
        "StatusStoppedBg", "D8A8A8",
        "StatusStoppedText", "333333",
        "StatusApplyingBg", "FF9800",
        "StatusApplyingText", "000000",
        "StatusAppliedBg", accentColor,
        "StatusAppliedText", "000000",
        "FontFamilyBase", "Segoe UI",
        "FontFamilyTitle", "Segoe UI"
    )
    dark := Theme_Merge(light, Map(
        "ResolvedMode", "Dark",
        "BgColor", "1E1E1E",
        "TextPrimary", "F1F1F1",
        "TextSecondary", "D0D0D0",
        "InputBg", "2A2A2A",
        "ButtonBg", "2E2E2E",
        "ButtonText", "F1F1F1",
        "StatusStoppedBg", "6F3A3A",
        "StatusStoppedText", "FFFFFF",
        "StatusApplyingBg", "B66A00",
        "StatusApplyingText", "FFFFFF"
    ))
    return (Theme_GetSupportedMode(mode) = "Dark") ? dark : light
}

Theme_ReadFromConfig(configPath, accentColor) {
    modeRaw := "System"
    try modeRaw := IniRead(configPath, "Settings", "ThemeMode", "System")
    mode := Theme_GetSupportedMode(modeRaw)
    resolved := (mode = "System") ? Theme_GetSystemMode() : mode
    base := Theme_DefaultTokens(resolved, accentColor)
    base["ThemeMode"] := mode
    for key in ["AccentColor", "BgColor", "TextPrimary", "TextSecondary", "InputBg", "ButtonBg", "ButtonText", "StatusActiveBg", "StatusActiveText", "StatusStoppedBg", "StatusStoppedText", "StatusApplyingBg", "StatusApplyingText", "StatusAppliedBg", "StatusAppliedText"] {
        try {
            v := Trim(IniRead(configPath, "Settings", key, ""))
            if (v != "")
                base[key] := v
        } catch {
        }
    }
    return base
}

Theme_ApplyBaseGui(guiObj, theme) {
    guiObj.BackColor := theme["BgColor"]
}

Theme_ApplyControlFont(ctrl, size, weight, theme, primary := true) {
    color := primary ? theme["TextPrimary"] : theme["TextSecondary"]
    family := primary ? theme["FontFamilyTitle"] : theme["FontFamilyBase"]
    ctrl.SetFont("s" size " w" weight " c" color, family)
}

Theme_ApplyStatusBar(statusBar, theme, statusKey, statusText) {
    stateMap := Map(
        "active", ["StatusActiveBg", "StatusActiveText"],
        "stopped", ["StatusStoppedBg", "StatusStoppedText"],
        "applying", ["StatusApplyingBg", "StatusApplyingText"],
        "applied", ["StatusAppliedBg", "StatusAppliedText"]
    )
    pair := stateMap.Has(statusKey) ? stateMap[statusKey] : stateMap["stopped"]
    statusBar.Value := statusText
    statusBar.SetFont("s11 w600 c" theme[pair[2]], theme["FontFamilyBase"])
    statusBar.Opt("Background" theme[pair[1]])
}

Theme_ApplyButton(ctrl, theme) {
    ctrl.SetFont("s10 w600 c" theme["ButtonText"], theme["FontFamilyBase"])
    ; Win32 themed buttons may ignore background unless visual styles are disabled.
    try ctrl.Opt("-Theme")
    try ctrl.Opt("Background" theme["ButtonBg"])
}

Theme_CustomButtonPalette(theme, variant := "secondary") {
    v := StrLower(Trim(String(variant)))
    hoverBg := Theme_IsDark(theme) ? "454545" : "E6E6E6"
    if (v = "close") {
        ; Windows-style close red on hover; light text on hover for contrast.
        return {bg: theme["ButtonBg"], fg: theme["ButtonText"], hoverBg: "E81123", hoverFg: "FFFFFF"}
    }
    if (v = "primary" || v = "danger" || v = "secondary")
        return {bg: theme["ButtonBg"], fg: theme["ButtonText"], hoverBg: hoverBg}
    return {bg: theme["ButtonBg"], fg: theme["ButtonText"], hoverBg: hoverBg}
}

Theme_ApplyCustomButton(ctrl, theme, variant := "secondary", hovered := false) {
    pal := Theme_CustomButtonPalette(theme, variant)
    ; Object from { } has no .Has(); use HasProp for optional hoverFg.
    fg := (hovered && HasProp(pal, "hoverFg")) ? pal.hoverFg : pal.fg
    ctrl.SetFont("s10 w500 c" fg, theme["FontFamilyBase"])
    ctrl.Opt("Background" (hovered ? pal.hoverBg : pal.bg))
}

Theme_IsDark(theme) {
    try {
        if (StrLower(String(theme["ResolvedMode"])) = "dark")
            return true
    }
    try {
        bg := RegExReplace(String(theme["BgColor"]), "[^0-9A-Fa-f]")
        if (StrLen(bg) = 6) {
            r := Integer("0x" SubStr(bg, 1, 2))
            g := Integer("0x" SubStr(bg, 3, 2))
            b := Integer("0x" SubStr(bg, 5, 2))
            ; Relative luminance threshold for dark backgrounds.
            lum := (0.2126 * r + 0.7152 * g + 0.0722 * b)
            return lum < 140
        }
    }
    return false
}

Theme_ApplyListControl(ctrl, theme) {
    ctrl.SetFont("s10 w500 c" theme["TextPrimary"], theme["FontFamilyBase"])
    try ctrl.Opt("-Theme")
    try ctrl.Opt("Background" theme["InputBg"])
    try ctrl.Opt("c" theme["TextPrimary"])
    ; Ask native common controls to use dark/light explorer style where available.
    themeClass := Theme_IsDark(theme) ? "DarkMode_Explorer" : "Explorer"
    try DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.Hwnd, "str", themeClass, "ptr", 0)
}

Theme_CreateModal(ownerGui, theme, hasOwner := true) {
    modalOpts := "+AlwaysOnTop -Caption +Border"
    if (hasOwner && IsObject(ownerGui))
        modalOpts .= " +Owner" ownerGui.Hwnd
    dlg := Gui(modalOpts)
    Theme_ApplyBaseGui(dlg, theme)
    return dlg
}
