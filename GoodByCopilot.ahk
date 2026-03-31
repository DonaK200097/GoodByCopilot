#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
SetWorkingDir(A_ScriptDir)
#Include %A_ScriptDir%\Core\Config.ahk
#Include %A_ScriptDir%\Core\Service.ahk
#Include %A_ScriptDir%\Core\Locale.ahk
#Include %A_ScriptDir%\Core\UI.ahk
#Include %A_ScriptDir%\Core\Theme.ahk

coreDir    := A_ScriptDir "\Core"
pwaDir     := coreDir "\PWA"
defaultDir := coreDir "\default"
langDir    := coreDir "\LangPackage"
configPath := coreDir "\config.ini"
listPath   := coreDir "\list.ini"
g_frWizardDone := false
g_frWizardResult := ""
g_defaultPwaSeeded := false
g_suppressSiteChange := false
g_enginePid := 0
global ctx := Map()
global settingsOrigPos := Map()
global g_theme := Map()
global UI_BASE_WIDTH := 420
global UI_ROW_HEIGHT := 36
global UI_TITLEBAR_HEIGHT := 28
global UI_CLOSE_SIZE := 28
global UI_HEADER_GAP := 10
global UI_MAIN_ROW_GAP := 10
global UI_MAIN_TILE_HEIGHT := 48
global UI_MAIN_TILE_GAP := 2
global g_customButtons := Map()
global g_hoveredButtonHwnd := 0
mainControlNames := ["BtnServiceList", "BtnSettings", "StatusBar"]
settingsControlNames := ["BtnAdd", "BtnDel", "ActionText", "ThemeText", "BtnActionSelect", "BtnThemeSelect", "HkLabel", "BtnCap", "AutoStart", "ShowTray", "MemoryPurge", "BtnReset"]
global g_serviceIds := []
global g_serviceSelectIdx := 1
global g_actionSelectIdx := 1
global g_themeSelectIdx := 1
global g_pickerPopup := 0
global g_pickerPopupKind := ""
global g_autoApplyPending := false
global g_autoApplyRunning := false
global g_layoutTransition := false
global g_statusBarMode := ""
global g_statusBarBaseText := ""
global g_statusBarHintApplied := false

; Button / list row icons (Unicode; Windows draws emoji & symbols via Segoe UI / emoji fonts)
global G_IC_SVC := Chr(0x1F310) A_Space
global G_IC_CFG := Chr(0x2699) A_Space
global G_IC_ADD := Chr(0x2795) A_Space
global G_IC_DEL := Chr(0x1F5D1) A_Space
global G_IC_KEY := Chr(0x2328) A_Space
global G_IC_RST := Chr(0x21BB) A_Space
global G_IC_OK := Chr(0x2713) A_Space
global G_IC_NO := Chr(0x2717) A_Space
global G_IC_CLS := Chr(0x2715) A_Space
global G_IC_ACT := Chr(0x1F4DD) A_Space
global G_IC_THM := Chr(0x1F3A8) A_Space
global G_IC_DOT := Chr(0x25B8) A_Space
global G_IC_AI := Chr(0x1F916) A_Space
global G_IC_WIN := Chr(0x229E) A_Space
global G_IC_EXIT := Chr(0x1F6AA) A_Space

for dir in [coreDir, pwaDir, langDir, defaultDir] {
    if !DirExist(dir)
        DirCreate(dir)
}
ctx["settingsControlNames"] := settingsControlNames
ctx["mainControlNames"] := mainControlNames

UILanguageIsRussianFamily() {
    return Loc_UILanguageIsRussianFamily()
}

GetAppLanguage() {
    global configPath
    return Loc_GetAppLanguage(configPath)
}

GetLangText(section, key) {
    ; IniRead uses GetPrivateProfileString: Unicode only in UTF-16 .ini (with BOM). UTF-8 lang files fall back to ANSI and break Cyrillic.
    global langDir
    static lang := "", langPath := ""
    if (lang = "") {
        lang := GetAppLanguage()
        langPath := langDir "\" lang ".ini"
    }
    if !FileExist(langPath) {
        return key
    }
    ; Default 4th arg: missing key/section must not throw (AHK v2 IniRead otherwise errors)
    return IniRead(langPath, section, key, key)
}

GetLangTextOrDefault(section, key, ruText, enText) {
    t := GetLangText(section, key)
    if (t = key)
        return (GetAppLanguage() = "RU") ? ruText : enText
    return t
}

GetStopEngineButtonText() {
    t := GetLangText("Main", "StopButton")
    if (t = "StopButton")
        return (GetAppLanguage() = "RU") ? "Остановить движок" : "Stop engine"
    return t
}

ThemeCaptionText() {
    return GetLangTextOrDefault("Main", "ThemeLabel", "Тема интерфейса:", "Interface theme:")
}

ActionCaptionText() {
    return GetLangTextOrDefault("Main", "ActionTextClosed", "Если окно уже закрыто:", "If window is already closed:")
}

HotkeyInvokeLabel() {
    return GetLangTextOrDefault("Main", "HotkeyLabelInvoke", "Горячая клавиша: ", "Hotkey: ")
}

GetBrandTitle() {
    return "GOODBY COPILOT"
}

; Main screen: service button ~72% width, settings ~28%, same row (inner width = content area like UI_BASE_WIDTH).
MainRowButtonWidths(innerW) {
    global UI_MAIN_ROW_GAP
    gap := UI_MAIN_ROW_GAP
    innerW := Max(120, innerW)
    avail := Max(0, innerW - gap)
    svcW := Floor(avail * 0.72)
    setW := innerW - gap - svcW
    if (setW < 72) {
        setW := 72
        svcW := Max(80, innerW - gap - setW)
    }
    return [svcW, setW]
}

SetCtrlCaption(ctrl, text) {
    try {
        ctrl.Text := text
        return
    } catch {
    }
    try ctrl.Value := text
}

AddCustomButton(guiObj, name, options, caption, theme, variant := "secondary") {
    global g_customButtons
    ctrl := guiObj.Add("Text", "v" name " +0x100 +0x200 Border " options, caption)
    Theme_ApplyCustomButton(ctrl, theme, variant)
    g_customButtons[ctrl.Hwnd] := {ctrl: ctrl, variant: variant}
    return ctrl
}

CustomButtonApplyHover(hwnd, isHover) {
    global g_customButtons, g_theme, g_hoveredButtonHwnd
    if !g_customButtons.Has(hwnd)
        return
    if !WinExist("ahk_id " hwnd) {
        g_customButtons.Delete(hwnd)
        if (g_hoveredButtonHwnd = hwnd)
            g_hoveredButtonHwnd := 0
        return
    }
    item := g_customButtons[hwnd]
    try {
        Theme_ApplyCustomButton(item.ctrl, g_theme, item.variant, isHover)
    } catch {
        g_customButtons.Delete(hwnd)
        if (g_hoveredButtonHwnd = hwnd)
            g_hoveredButtonHwnd := 0
    }
}

CustomButtonHoverTick() {
    global g_customButtons, g_hoveredButtonHwnd
    if (g_customButtons.Count = 0)
        return
    stale := []
    for hwnd, _ in g_customButtons {
        if !WinExist("ahk_id " hwnd)
            stale.Push(hwnd)
    }
    for hwnd in stale
        g_customButtons.Delete(hwnd)
    if (g_customButtons.Count = 0) {
        g_hoveredButtonHwnd := 0
        return
    }
    MouseGetPos(, , , &ctrlHwnd, 2)
    newHover := g_customButtons.Has(ctrlHwnd) ? ctrlHwnd : 0
    if (newHover = g_hoveredButtonHwnd)
        return
    if (g_hoveredButtonHwnd)
        CustomButtonApplyHover(g_hoveredButtonHwnd, false)
    if (newHover)
        CustomButtonApplyHover(newHover, true)
    g_hoveredButtonHwnd := newHover
}

RefreshCustomButtonsAfterLayout() {
    global g_customButtons, g_theme, g_hoveredButtonHwnd
    stale := []
    for hwnd, item in g_customButtons {
        if !WinExist("ahk_id " hwnd) {
            stale.Push(hwnd)
            continue
        }
        try {
            isHover := (hwnd = g_hoveredButtonHwnd)
            Theme_ApplyCustomButton(item.ctrl, g_theme, item.variant, isHover)
            item.ctrl.Redraw()
        } catch {
            stale.Push(hwnd)
        }
    }
    for hwnd in stale
        g_customButtons.Delete(hwnd)
}

ThemeOptionsDisplay() {
    return [
        GetLangTextOrDefault("Main", "ThemeSystem", "Системная", "System"),
        GetLangTextOrDefault("Main", "ThemeLight", "Светлая", "Light"),
        GetLangTextOrDefault("Main", "ThemeDark", "Темная", "Dark")
    ]
}

ThemeModeToIndex(mode) {
    m := StrLower(Trim(String(mode)))
    if (m = "light")
        return 2
    if (m = "dark")
        return 3
    return 1
}

ThemeIndexToMode(idx) {
    i := Integer(idx)
    if (i = 2)
        return "Light"
    if (i = 3)
        return "Dark"
    return "System"
}

; First-run wizard: embedded RU/EN strings so Cyrillic is never broken by mixed UTF-8/UTF-16 .ini. Save this script as UTF-8 with BOM.
FirstRunWizardLine(key) {
    switch GetAppLanguage() {
        case "RU":
            switch key {
                case "Title": return "стартовые настройки"
                case "Subtitle": return "Позже всё можно изменить в настройках."
                case "HotkeyPrompt": return "Горячая клавиша"
                case "HotkeyFixed": return "Горячая клавиша - Copilot / Win+C"
                case "HotkeyHint": return "Вы можете изменить хоткей в настройках"
                case "ContinueButton": return "Продолжить"
                case "PickHotkeyError": return "Выберите «Кнопка Copilot» или «Win+C»."
                default: return GetLangText("FirstRun", key)
            }
        case "EN":
            switch key {
                case "Title": return "Starting settings"
                case "Subtitle": return "You can change these later in settings."
                case "HotkeyPrompt": return "Hotkey"
                case "HotkeyFixed": return "Hotkey - Copilot / Win+C"
                case "HotkeyHint": return "You can change the hotkey in settings"
                case "ContinueButton": return "Continue"
                case "PickHotkeyError": return "Select «Copilot key» or «Win+C»."
                default: return GetLangText("FirstRun", key)
            }
        default:
            return GetLangText("FirstRun", key)
    }
}

GetServicesList() {
    global listPath
    if !FileExist(listPath)
        return []
    names := []
    try {
        loop read, listPath {
            line := Trim(A_LoopReadLine)
            if RegExMatch(line, "^\[([^\]]+)\]$", &m)
                names.Push(m[1])
        }
    } catch {
        return []
    }
    return names
}

IsServiceListEmpty() {
    global listPath
    if !FileExist(listPath)
        return true
    return GetServicesList().Length = 0
}

ParseOpenCommandToExe(cmd) {
    cmd := Trim(String(cmd))
    if (cmd = "")
        return ""
    if RegExMatch(cmd, '"([^"]+\.[Ee][Xx][Ee])"', &m)
        return m[1]
    if RegExMatch(cmd, 'i)^([A-Za-z]:\\[^"]+\.[Ee][Xx][Ee])', &m)
        return m[1]
    if RegExMatch(cmd, 'i)([A-Za-z]:\\[^\s]+\.[Ee][Xx][Ee])', &m)
        return m[1]
    return ""
}

GetDefaultBrowserExePath() {
    try {
        progId := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice", "ProgId")
    } catch {
        return ""
    }
    if (progId = "")
        return ""
    cmd := ""
    for root in ["HKEY_CURRENT_USER\Software\Classes", "HKEY_LOCAL_MACHINE\Software\Classes"] {
        try {
            cmd := RegRead(root "\" progId "\shell\open\command", "")
            if (cmd != "")
                break
        } catch {
        }
    }
    if (cmd = "")
        return ""
    exePath := ParseOpenCommandToExe(cmd)
    return (exePath != "" && FileExist(exePath)) ? exePath : ""
}

GetFallbackBrowserExePath() {
    for name in ["msedge.exe", "chrome.exe"] {
        try {
            p := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" name, "")
            if (p != "" && FileExist(p))
                return p
        } catch {
        }
    }
    return ""
}

GetBrowserExeFromHint(hint) {
    hint := StrLower(Trim(String(hint)))
    if (hint = "" || hint = "default" || hint = "auto")
        return ""
    map := Map(
        "edge", "msedge.exe",
        "msedge", "msedge.exe",
        "chrome", "chrome.exe",
        "google chrome", "chrome.exe",
        "brave", "brave.exe",
        "vivaldi", "vivaldi.exe",
        "opera", "opera.exe",
        "opera gx", "opera.exe",
        "firefox", "firefox.exe",
        "librewolf", "librewolf.exe"
    )
    exeName := map.Has(hint) ? map[hint] : ""
    if (exeName = "")
        return ""
    try {
        p := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" exeName, "")
        if (p != "" && FileExist(p))
            return p
    } catch {
    }
    return ""
}

ResolveBrowserExeForSeed(exeHint) {
    p := GetBrowserExeFromHint(exeHint)
    if (p != "")
        return p
    p := GetDefaultBrowserExePath()
    if (p != "")
        return p
    return GetFallbackBrowserExePath()
}

NormalizeExeName(s) {
    s := Trim(String(s))
    if (s = "")
        return ""
    return RegExReplace(s, "i)\.exe$", "")
}

ExeNameFromExePath(exePath) {
    SplitPath(exePath, &name)
    base := NormalizeExeName(name)
    if (StrLower(base) = "edge")
        return "msedge"
    return base
}

AppModeArgsForUrl(url) {
    u := Trim(String(url))
    if (u = "")
        return ""
    return "--app=" Chr(34) u Chr(34)
}

TrySeedDefaultPwaFromDefaultFolder() {
    global configPath, listPath, pwaDir, defaultDir, g_defaultPwaSeeded
    if !DirExist(defaultDir)
        return
    if !IsServiceListEmpty()
        return
    if FileExist(configPath) {
        try {
            if (StrLower(Trim(IniRead(configPath, "Settings", "SeedDefaultPwaDone", ""))) = "true")
                return
        } catch {
        }
    }
    seeded := 0
    defaultBrowserCache := ""
    loop files, defaultDir "\*.url" {
        id := SubStr(A_LoopFileName, 1, StrLen(A_LoopFileName) - 4)
        if (id = "")
            continue
        urlPath := A_LoopFileFullPath
        try {
            url := Trim(IniRead(urlPath, "InternetShortcut", "URL", ""))
        } catch {
            url := ""
        }
        if (url = "")
            continue
        metaPath := defaultDir "\" id ".ini"
        title := id
        exeHint := ""
        if FileExist(metaPath) {
            try {
                t := Trim(IniRead(metaPath, "Service", "Title", ""))
                if (t != "")
                    title := t
            } catch {
            }
            try {
                exeHint := Trim(IniRead(metaPath, "Service", "Exe", ""))
            } catch {
                exeHint := ""
            }
        }
        browserExe := ""
        if (exeHint = "" || StrLower(exeHint) = "default" || StrLower(exeHint) = "auto") {
            if (defaultBrowserCache = "")
                defaultBrowserCache := ResolveBrowserExeForSeed("")
            browserExe := defaultBrowserCache
        } else {
            browserExe := ResolveBrowserExeForSeed(exeHint)
            if (browserExe = "")
                browserExe := ResolveBrowserExeForSeed("")
        }
        if (browserExe = "" || !FileExist(browserExe))
            continue
        args := AppModeArgsForUrl(url)
        if (args = "")
            continue
        exeName := ExeNameFromExePath(browserExe)
        try {
            FileCreateShortcut(browserExe, pwaDir "\" id ".lnk", , args)
            IniWrite(title, listPath, id, "title")
            IniWrite(id, listPath, id, "file")
            IniWrite(exeName, listPath, id, "exe")
            seeded++
        } catch {
        }
    }
    if (seeded = 0)
        return
    g_defaultPwaSeeded := true
    if FileExist(configPath) {
        try IniWrite("True", configPath, "Settings", "SeedDefaultPwaDone")
        catch {
        }
    }
}

GetFriendlyName(hk) {
    if (hk = "")
        return GetLangText("Main", "NotSet")
    if (hk = "<+#F23") {
        d := GetLangText("FirstRun", "CopilotKeyDisplay")
        return (d = "CopilotKeyDisplay") ? "Copilot" : d
    }
    name := StrReplace(StrReplace(hk, "<", ""), ">", "")
    name := StrReplace(name, "+", "Shift + "), name := StrReplace(name, "^", "Ctrl + ")
    name := StrReplace(name, "!", "Alt + "), name := StrReplace(name, "#", "Win + ")
    return RegExReplace(name, "\s\+\s$", "")
}

HotkeyDisplayName(hk) {
    if (hk = "<+#F23") {
        d := GetLangText("FirstRun", "CopilotKeyDisplay")
        return (d = "CopilotKeyDisplay") ? "Copilot" : d
    }
    return hk
}

GetHeaderHotkeyText(hk) {
    shown := HotkeyDisplayName(hk)
    return "Активный хоткей: " shown
}

GetHotkeyRegistrationError() {
    global coreDir
    errPath := coreDir "\HotkeyError.ini"
    if !FileExist(errPath)
        return ""
    try {
        return Trim(IniRead(errPath, "Hotkey", "Fallback", IniRead(errPath, "Hotkey", "Primary", "")))
    } catch {
        return ""
    }
}

NormalizeHotkeyFromUi(s) {
    t := Trim(String(s))
    cop := GetLangText("FirstRun", "CopilotKeyDisplay")
    if (cop != "CopilotKeyDisplay" && t = cop)
        return "<+#F23"
    if (StrLower(t) = "copilot")
        return "<+#F23"
    return t
}

MaxStrLenInList(arr) {
    m := 0
    for s in arr
        m := Max(m, StrLen(String(s)))
    return m
}

PadRowCenter(text, fieldChars) {
    t := String(text)
    n := StrLen(t)
    if (n >= fieldChars)
        return t
    pad := fieldChars - n
    L := pad // 2
    R := pad - L
    sp := "                                                                                                                        "
    return SubStr(sp, 1, L) . t . SubStr(sp, 1, R)
}

BuildServiceDDLContent(ids, fieldChars) {
    global g_serviceIds
    g_serviceIds := []
    disp := []
    for id in ids {
        g_serviceIds.Push(id)
        shown := id
        try {
            shown := IniRead(listPath, id, "title", id)
        }
        disp.Push(PadRowCenter(shown, fieldChars))
    }
    return disp
}

ServiceFieldCharsForWidth(serviceList) {
    shown := []
    for id in serviceList {
        try {
            shown.Push(IniRead(listPath, id, "title", id))
        } catch {
            shown.Push(id)
        }
    }
    return Max(44, MaxStrLenInList(shown) + 4)
}

SiteSelectIndexToName(idx) {
    global g_serviceIds
    i := Integer(idx)
    if (i < 1 || i > g_serviceIds.Length)
        return ""
    return g_serviceIds[i]
}

ServiceDisplayNameById(id) {
    global listPath
    shown := id
    try shown := IniRead(listPath, id, "title", id)
    return shown
}

SetServicePickerCaption(guiObj, idx) {
    global g_serviceIds, G_IC_SVC
    i := Integer(idx)
    if (i < 1 || i > g_serviceIds.Length)
        return
    SetCtrlCaption(guiObj["BtnServiceList"], G_IC_SVC GetLangText("Main", "SelectService") " - " ServiceDisplayNameById(g_serviceIds[i]))
}

ServicePickerSetItems(guiObj, ids, selectedIdx := 1) {
    global g_serviceIds, g_serviceSelectIdx, G_IC_SVC
    g_serviceIds := []
    items := []
    for id in ids {
        g_serviceIds.Push(id)
        items.Push(ServiceDisplayNameById(id))
    }
    lb := guiObj["ServiceListBox"]
    lb.Delete()
    if (items.Length > 0)
        lb.Add(items)
    g_serviceSelectIdx := Max(1, Min(selectedIdx, items.Length > 0 ? items.Length : 1))
    if (items.Length > 0) {
        lb.Value := g_serviceSelectIdx
        SetServicePickerCaption(guiObj, g_serviceSelectIdx)
    } else {
        SetCtrlCaption(guiObj["BtnServiceList"], G_IC_SVC GetLangText("Main", "SelectService") " - " GetLangText("Main", "EmptyServiceList"))
    }
    lb.Visible := false
    try PositionPickerList(guiObj, "BtnServiceList", "ServiceListBox", 6, 24)
}

PositionPickerList(guiObj, btnName, listBoxName, maxRows := 6, rowH := 24) {
    btn := guiObj[btnName]
    lb := guiObj[listBoxName]
    btn.GetPos(&bx, &by, &bw, &bh)
    ; Avoid relying on ListBox methods that may vary by control state.
    rows := maxRows
    listH := rows * rowH + 6
    lb.Move(bx, by + bh + 2, bw, listH)
}

ClientToScreenPoint(hwnd, x, y, &sx, &sy) {
    pt := Buffer(8, 0)
    NumPut("int", x, pt, 0)
    NumPut("int", y, pt, 4)
    DllCall("User32\ClientToScreen", "ptr", hwnd, "ptr", pt)
    sx := NumGet(pt, 0, "int")
    sy := NumGet(pt, 4, "int")
}

GetControlScreenRect(ctrl, &left, &top, &right, &bottom) {
    rc := Buffer(16, 0)
    DllCall("User32\GetWindowRect", "ptr", ctrl.Hwnd, "ptr", rc)
    left := NumGet(rc, 0, "int")
    top := NumGet(rc, 4, "int")
    right := NumGet(rc, 8, "int")
    bottom := NumGet(rc, 12, "int")
}

ClosePickerPopup() {
    global g_pickerPopup, g_pickerPopupKind
    if (IsObject(g_pickerPopup)) {
        try g_pickerPopup.Destroy()
    }
    g_pickerPopup := 0
    g_pickerPopupKind := ""
}

PickerPopupItemClick(onPickCallback, idx, *) {
    onPickCallback(idx)
    ClosePickerPopup()
}

OpenPickerPopup(kind, btnName, items, selectedIdx, onPickCallback, itemPrefix := "") {
    global myGui, g_theme, g_pickerPopup, g_pickerPopupKind
    if (g_pickerPopupKind = kind) {
        ClosePickerPopup()
        return
    }
    ClosePickerPopup()
    btn := myGui[btnName]
    ; Anchor by control screen position, but always keep width
    ; equal to the parent button width.
    btn.GetPos(&bx, &by, &bw, &bh)
    GetControlScreenRect(btn, &sx, &syTop, &sxRight, &syBottom)
    sy := syBottom + 2
    rows := Min(Max(1, items.Length), 7)
    listH := rows * 34
    pop := Gui("+AlwaysOnTop -Caption +Border +ToolWindow +Owner" myGui.Hwnd)
    Theme_ApplyBaseGui(pop, g_theme)
    pop.MarginX := 0
    pop.MarginY := 0
    y := 0
    itemW := Max(40, bw - 2)
    for i, label in items {
        cap := (itemPrefix != "") ? itemPrefix label : label
        itemBtn := AddCustomButton(pop, "Pick_" kind "_" i, "x0 y" y " w" itemW " h34 Center", cap, g_theme)
        if (i = selectedIdx)
            Theme_ApplyCustomButton(itemBtn, g_theme, "secondary", true)
        itemBtn.OnEvent("Click", PickerPopupItemClick.Bind(onPickCallback, i))
        y += 34
        if (i >= rows)
            break
    }
    pop.OnEvent("Close", (*) => ClosePickerPopup())
    pop.Show("x" sx " y" sy " w" bw " h" listH)
    g_pickerPopup := pop
    g_pickerPopupKind := kind
}

RefreshPickerLayouts() {
    ; List popups are separate windows; layout stays stable.
}

ToggleServiceList(*) {
    global g_serviceIds, g_serviceSelectIdx, G_IC_DOT
    items := []
    for id in g_serviceIds
        items.Push(ServiceDisplayNameById(id))
    OpenPickerPopup("service", "BtnServiceList", items, g_serviceSelectIdx, (idx) => OnServicePickerChosen(idx), G_IC_DOT)
}

HideServiceList() {
    ClosePickerPopup()
}

SetSimplePickerCaption(guiObj, btnName, list, idx) {
    global G_IC_ACT, G_IC_THM
    i := Integer(idx)
    if (i < 1 || i > list.Length)
        return
    icon := ""
    if (btnName = "BtnActionSelect")
        icon := G_IC_ACT
    else if (btnName = "BtnThemeSelect")
        icon := G_IC_THM
    SetCtrlCaption(guiObj[btnName], icon list[i])
}

SimplePickerSetItems(guiObj, listBoxName, btnName, values, selectedIdx := 1) {
    lb := guiObj[listBoxName]
    lb.Delete()
    if (values.Length > 0)
        lb.Add(values)
    i := Max(1, Min(selectedIdx, values.Length > 0 ? values.Length : 1))
    if (values.Length > 0) {
        lb.Value := i
        SetSimplePickerCaption(guiObj, btnName, values, i)
    } else {
        SetCtrlCaption(guiObj[btnName], "")
    }
    lb.Visible := false
    try PositionPickerList(guiObj, btnName, listBoxName, 4, 24)
}

ToggleActionList(*) {
    global actionOptions, g_actionSelectIdx, G_IC_DOT
    OpenPickerPopup("action", "BtnActionSelect", actionOptions, g_actionSelectIdx, (idx) => OnActionPickerChosen(idx), G_IC_DOT)
}

ToggleThemeList(*) {
    global themeDisplay, g_themeSelectIdx, G_IC_DOT
    OpenPickerPopup("theme", "BtnThemeSelect", themeDisplay, g_themeSelectIdx, (idx) => OnThemePickerChosen(idx), G_IC_DOT)
}

OnActionPickerChosen(idx) {
    global myGui, g_actionSelectIdx, actionOptions
    g_actionSelectIdx := idx
    SetSimplePickerCaption(myGui, "BtnActionSelect", actionOptions, idx)
    QueueAutoApplySettings()
}

OnThemePickerChosen(idx) {
    global myGui, g_themeSelectIdx, themeDisplay
    g_themeSelectIdx := idx
    SetSimplePickerCaption(myGui, "BtnThemeSelect", themeDisplay, idx)
    QueueAutoApplySettings()
}

HideSettingsLists() {
    ClosePickerPopup()
}

OnServicePickerChosen(idx) {
    global myGui, g_serviceSelectIdx, g_suppressSiteChange
    g_serviceSelectIdx := idx
    SetServicePickerCaption(myGui, idx)
    if (!g_suppressSiteChange)
        ApplyServiceSelection()
}

GetWinAccentColor() {
    try {
        colorBGR := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM", "AccentColor")
        return Format("{:02X}{:02X}{:02X}", colorBGR & 0xFF, (colorBGR >> 8) & 0xFF, (colorBGR >> 16) & 0xFF)
    } catch {
        return "0078D7"
    }
}

IsServiceRunning() {
    return Svc_IsServiceRunning()
}

IsPidRunning(pid) {
    return Svc_IsPidRunning(pid)
}

WaitForServiceState(shouldRun, timeoutMs := 2500) {
    return Svc_WaitForServiceState(shouldRun, timeoutMs)
}

ShowCustomPopup(message, title) {
    global myGui, g_theme, G_IC_OK
    myGui.Opt("+Disabled")
    pop := Theme_CreateModal(myGui, g_theme)
    pop.SetFont("s12 w700 c" g_theme["AccentColor"], g_theme["FontFamilyTitle"])
    pop.Add("Text", "Center w300 y20", title)
    pop.SetFont("s10 w400 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    pop.Add("Text", "Center w260 x20 y+15", message)
    btnOk := AddCustomButton(pop, "BtnOkPop", "w120 h34 x90 y+20 Center", G_IC_OK GetLangText("Confirm", "OkButton"), g_theme, "primary")
    btnOk.OnEvent("Click", (GuiCtrl, *) => (myGui.Opt("-Disabled"), pop.Destroy()))
    pop.Show("AutoSize Center")
}

ShowCustomConfirm(message, title, onYesCallback) {
    global myGui, g_theme, G_IC_OK, G_IC_NO
    myGui.Opt("+Disabled")
    conf := Theme_CreateModal(myGui, g_theme)
    conf.SetFont("s12 w700 c" g_theme["AccentColor"], g_theme["FontFamilyTitle"])
    conf.Add("Text", "Center w300 y20", title)
    conf.SetFont("s10 w400 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    conf.Add("Text", "Center w260 x20 y+15", message)
    btnYes := AddCustomButton(conf, "BtnYesConfirm", "w120 h34 x30 y+20 Center", G_IC_OK GetLangText("Confirm", "YesButton"), g_theme, "primary")
    btnNo  := AddCustomButton(conf, "BtnNoConfirm", "w120 h34 x+10 Center", G_IC_NO GetLangText("Confirm", "NoButton"), g_theme)
    btnYes.OnEvent("Click", (GuiCtrl, *) => (myGui.Opt("-Disabled"), conf.Destroy(), onYesCallback()))
    btnNo.OnEvent("Click", (GuiCtrl, *) => (myGui.Opt("-Disabled"), conf.Destroy()))
    conf.Show("AutoSize Center")
}

NeedsFirstRunHotkeyChoice() {
    global configPath
    if !FileExist(configPath)
        return true
    try {
        if (Trim(IniRead(configPath, "Settings", "Hotkey")) = "")
            return true
    } catch {
        return true
    }
    return false
}

WriteFirstRunHotkeyBaseline(chosenHotkey, autoStart, showTray, memoryOn) {
    global configPath, listPath, serviceList, emptyText, g_defaultPwaSeeded
    lastSvc := GetPreferredDefaultService(serviceList, emptyText)
    IniWrite(chosenHotkey, configPath, "Settings", "Hotkey")
    IniWrite("True", configPath, "Settings", "FirstRunHotkeyDone")
    IniWrite(lastSvc, configPath, "Settings", "SelectedService")
    IniWrite(autoStart ? "True" : "False", configPath, "Settings", "AutoStart")
    IniWrite(showTray ? "True" : "False", configPath, "Settings", "ShowTray")
    IniWrite(memoryOn ? "True" : "False", configPath, "Settings", "MemoryPurge")
    IniWrite("False", configPath, "Settings", "ActionClose")
    if (g_defaultPwaSeeded)
        IniWrite("True", configPath, "Settings", "SeedDefaultPwaDone")
    if (lastSvc != emptyText) {
        try {
            finalTitle := IniRead(listPath, lastSvc, "title", lastSvc)
            finalFile := IniRead(listPath, lastSvc, "file", lastSvc)
            finalExe := NormalizeExeName(IniRead(listPath, lastSvc, "exe", ""))
            IniWrite(finalTitle, configPath, "Settings", "AppTitle")
            IniWrite(finalFile, configPath, "Settings", "FileName")
            IniWrite(finalExe, configPath, "Settings", "ExeName")
        } catch {
        }
    }
    IniWrite(String(Cfg_TargetConfigVersion()), configPath, "Settings", "ConfigVersion")
    SetAutoStart(autoStart)
}

GetPreferredDefaultService(services, emptyText) {
    global listPath
    if (services.Length = 0)
        return emptyText
    for name in services {
        if (StrLower(Trim(String(name))) = "googleai")
            return name
    }
    for name in services {
        if (name = "" || name = emptyText)
            continue
        shown := name
        try shown := IniRead(listPath, name, "title", name)
        if InStr(StrLower(shown), "google")
            return name
    }
    for name in services {
        if (StrLower(Trim(String(name))) = "gemini")
            return name
    }
    for name in services {
        if (name = "" || name = emptyText)
            continue
        shown := name
        try shown := IniRead(listPath, name, "title", name)
        if InStr(StrLower(shown), "gemini")
            return name
    }
    return services[1]
}

FirstRunWizardTrySubmit(dlg, st) {
    global g_frWizardDone, g_frWizardResult
    if (st.hk = "") {
        ShowFirstRunWizardError(dlg, FirstRunWizardLine("PickHotkeyError"), FirstRunWizardLine("Title"))
        return
    }
    vals := dlg.Submit(false)
    g_frWizardResult := Map(
        "hotkey", st.hk,
        "autoStart", vals.AutoStart = 1,
        "showTray", vals.ShowTray = 1,
        "memory", vals.MemoryPurge = 1
    )
    g_frWizardDone := true
    dlg.Destroy()
}

ShowFirstRunWizardError(dlg, message, title) {
    global g_theme, G_IC_OK
    dlg.Opt("+Disabled")
    pop := Theme_CreateModal(dlg, g_theme)
    pop.SetFont("s12 w700 c" g_theme["TextPrimary"], g_theme["FontFamilyTitle"])
    pop.Add("Text", "Center w320 y16", title)
    pop.SetFont("s10 w400 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    pop.Add("Text", "Center w280 x20 y+12", message)
    btnOk := AddCustomButton(pop, "BtnWizardErrOk", "w120 h34 x100 y+16 Center", G_IC_OK GetLangText("Confirm", "OkButton"), g_theme, "primary")
    ClosePop(*) {
        dlg.Opt("-Disabled")
        pop.Destroy()
    }
    btnOk.OnEvent("Click", ClosePop)
    pop.OnEvent("Close", ClosePop)
    pop.Show("AutoSize Center")
}

ShowFirstRunWizard() {
    global g_theme, g_frWizardDone, g_frWizardResult, G_IC_OK
    st := { hk: "<+#F23" }
    g_frWizardDone := false
    g_frWizardResult := ""
    ; First-run wizard appears before main GUI initialization.
    ; Ensure custom-button hover timer is already running here.
    SetTimer(CustomButtonHoverTick, 40)
    dlg := Theme_CreateModal("", g_theme, false)
    dlg.SetFont("s12 w700 c" g_theme["AccentColor"], g_theme["FontFamilyTitle"])
    dlg.Add("Text", "Center w420 y12", FirstRunWizardLine("Title"))
    dlg.SetFont("s9 w400 c" g_theme["TextSecondary"], g_theme["FontFamilyBase"])
    dlg.Add("Text", "Center w420 y+6", FirstRunWizardLine("Subtitle"))
    dlg.SetFont("s11 w600 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    dlg.Add("Text", "xm y+14 w420", FirstRunWizardLine("HotkeyFixed"))
    dlg.SetFont("s9 w400 c" g_theme["TextSecondary"], g_theme["FontFamilyBase"])
    dlg.Add("Text", "xm y+4 w420", FirstRunWizardLine("HotkeyHint"))
    dlg.Add("CheckBox", "vAutoStart xm y+14 w420 Checked", GetLangText("Main", "AutoStart"))
    dlg.Add("CheckBox", "vShowTray xm y+8 w420 Checked", GetLangText("Main", "ShowTray"))
    dlg.Add("CheckBox", "vMemoryPurge xm y+8 w420 Checked", GetLangText("Main", "MemoryPurge"))
    btnOk := AddCustomButton(dlg, "BtnFirstRunContinue", "w220 h38 Center xm+100 y+16", G_IC_OK FirstRunWizardLine("ContinueButton"), g_theme, "primary")
    btnOk.OnEvent("Click", (*) => FirstRunWizardTrySubmit(dlg, st))
    dlg.OnEvent("Close", (*) => ExitApp())
    dlg.Show("AutoSize Center")
    while !g_frWizardDone {
        Sleep(50)
    }
    return g_frWizardResult
}

GetEngineExePath() {
    global coreDir
    loop Files, coreDir "\*.*" {
        if (InStr(A_LoopFileName, "CoreGBC") && (StrLower(A_LoopFileExt) = "exe"))
            return A_LoopFileFullPath
    }
    return ""
}

GetEnginePath() {
    global coreDir
    enginePath := ""
    loop Files, coreDir "\*.*" {
        if (InStr(A_LoopFileName, "CoreGBC") && (A_LoopFileExt ~= "i)exe|ahk")) {
            enginePath := A_LoopFileFullPath
            if (StrLower(A_LoopFileExt) = "exe")
                break
        }
    }
    return enginePath
}

StartService() {
    global coreDir, g_enginePid
    return Svc_StartService(coreDir, &g_enginePid)
}

StopService() {
    global g_enginePid
    Svc_StopService(&g_enginePid)
}

SetAutoStart(enable) {
    global coreDir
    Svc_SetAutoStart(enable, coreDir)
}

ApplyThemeToMainGui() {
    global myGui, g_theme, g_customButtons, g_hoveredButtonHwnd
    Theme_ApplyBaseGui(myGui, g_theme)
    ApplyMainWindowChrome(myGui, g_theme)
    try myGui["DragArea"].Opt("Background" g_theme["BgColor"])
    myGui.SetFont("s11 w400 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    myGui["AppTitleText"].SetFont("s14 w700 c" g_theme["TextPrimary"], "Terminal")
    try myGui["AppTitleText"].Opt("Background" g_theme["BgColor"])
    try myGui["ActiveHotkeyText"].SetFont("s9 w500 c" g_theme["TextSecondary"], g_theme["FontFamilyBase"])
    try myGui["ActiveHotkeyText"].Opt("Background" g_theme["BgColor"])
    ; Same face as the rest of the UI (Segoe UI / FontFamilyBase).
    for name in ["ActionText", "ThemeText", "HkLabel"]
        try myGui[name].SetFont("s10 w500 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    for name in ["AutoStart", "ShowTray", "MemoryPurge"]
        try myGui[name].SetFont("s10 w500 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    for name in ["ActionListBox", "ThemeListBox", "ServiceListBox", "ActionSelect", "ThemeSelect"]
        try Theme_ApplyListControl(myGui[name], g_theme)
    myGui["Hotkey"].Opt("Background" g_theme["InputBg"])
    myGui["Hotkey"].SetFont("s10 w500 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    variantByName := Map(
        "BtnWindowClose", "close",
        "BtnServiceList", "secondary",
        "BtnActionSelect", "secondary",
        "BtnThemeSelect", "secondary",
        "BtnSettings", "secondary",
        "BtnAdd", "primary",
        "BtnDel", "danger",
        "BtnCap", "secondary",
        "BtnReset", "danger"
    )
    for name, variant in variantByName
        try Theme_ApplyCustomButton(myGui[name], g_theme, variant)
    if (g_hoveredButtonHwnd && g_customButtons.Has(g_hoveredButtonHwnd))
        CustomButtonApplyHover(g_hoveredButtonHwnd, true)
    UpdateServiceButton()
}

UpdateServiceButton() {
    global statusBar, g_theme
    err := GetHotkeyRegistrationError()
    if (err != "") {
        SetStatusBarState("stopped", GetLangTextOrDefault("Main", "StatusHotkeyError", "Ошибка регистрации хоткея", "Hotkey registration failed"))
    } else if (IsServiceRunning()) {
        SetStatusBarState("active", GetLangText("Main", "StatusActive"))
    } else {
        SetStatusBarState("stopped", GetLangText("Main", "StatusStopped"))
    }
}

SetStatusApplying() {
    SetStatusBarState("applying", GetLangText("Main", "StatusApplying"))
}

ShowSettingsAppliedThenServiceStatus() {
    SetStatusBarState("applied", GetLangText("Main", "StatusApplied"))
    SetTimer(FinishApplyStatusTimer, -1200)
}

SetStatusBarState(mode, text) {
    global statusBar, g_theme, g_statusBarMode, g_statusBarBaseText, g_statusBarHintApplied
    g_statusBarMode := mode
    g_statusBarBaseText := text
    g_statusBarHintApplied := false
    Theme_ApplyStatusBar(statusBar, g_theme, mode, text)
}

StatusBarHoverTick() {
    global statusBar, g_statusBarMode, g_statusBarBaseText, g_statusBarHintApplied
    if !IsSet(statusBar)
        return
    if !IsObject(statusBar)
        return
    hint := ""
    if (g_statusBarMode = "active")
        hint := GetLangTextOrDefault("Main", "StatusHintStop", "Нажмите чтобы остановить", "Click to stop")
    else if (g_statusBarMode = "stopped")
        hint := GetLangTextOrDefault("Main", "StatusHintStart", "Нажмите чтобы запустить", "Click to start")
    if (hint = "") {
        if (g_statusBarHintApplied) {
            statusBar.Value := g_statusBarBaseText
            g_statusBarHintApplied := false
        }
        return
    }
    MouseGetPos(, , , &ctrlHwnd, 2)
    isHover := (ctrlHwnd = statusBar.Hwnd)
    if (isHover) {
        if (!g_statusBarHintApplied || statusBar.Value != hint) {
            statusBar.Value := hint
            g_statusBarHintApplied := true
        }
        return
    }
    if (g_statusBarHintApplied) {
        statusBar.Value := g_statusBarBaseText
        g_statusBarHintApplied := false
    }
}

FinishApplyStatusTimer() {
    SetTimer(FinishApplyStatusTimer, 0)
    UpdateServiceButton()
}

EnsureServiceRunning(showError := true) {
    if (IsServiceRunning()) {
        UpdateServiceButton()
        return true
    }
    if (StartService()) {
        if WaitForServiceState(true, 3000) {
            UpdateServiceButton()
            return true
        }
    }
    UpdateServiceButton()
    if (showError)
        ShowCustomPopup(GetLangText("Main", "ServiceStartError"), GetLangText("Main", "Error"))
    return false
}

ToggleServiceByStatusBar(*) {
    ; Toggle engine process by current CoreGBC running state.
    if (IsServiceRunning()) {
        StopService()
        WaitForServiceState(false, 3000)
        UpdateServiceButton()
        return
    }
    EnsureServiceRunning(true)
}

CloseMainGui(*) {
    global actionVal, myGui
    if (actionVal = "True") {
        ExitApp()
        return
    }
    try myGui.Minimize()
}

StartWindowDrag(*) {
    PostMessage(0xA1, 2,,, "A")
}

BeginGuiLayoutBatch(guiObj) {
    ; Prevent intermediate repaints while controls are moved/resized.
    try DllCall("User32\SendMessageW", "ptr", guiObj.Hwnd, "uint", 0x000B, "ptr", 0, "ptr", 0) ; WM_SETREDRAW=false
}

EndGuiLayoutBatch(guiObj) {
    ; Re-enable redraw and repaint once after layout changes.
    try DllCall("User32\SendMessageW", "ptr", guiObj.Hwnd, "uint", 0x000B, "ptr", 1, "ptr", 0) ; WM_SETREDRAW=true
    try DllCall("User32\RedrawWindow", "ptr", guiObj.Hwnd, "ptr", 0, "ptr", 0, "uint", 0x0001 | 0x0004 | 0x0080) ; RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN
}

HexColorToColorRef(hexRgb) {
    h := RegExReplace(String(hexRgb), "[^0-9A-Fa-f]")
    if (StrLen(h) != 6)
        return 0x202020
    r := Integer("0x" SubStr(h, 1, 2))
    g := Integer("0x" SubStr(h, 3, 2))
    b := Integer("0x" SubStr(h, 5, 2))
    return (b << 16) | (g << 8) | r
}

ApplyMainWindowChrome(guiObj, theme) {
    hwnd := guiObj.Hwnd
    dark := Theme_IsDark(theme) ? 1 : 0
    noRound := 1
    borderColor := HexColorToColorRef(theme["BgColor"])
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 20, "int*", dark, "int", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 33, "int*", noRound, "int", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 34, "int*", borderColor, "int", 4)
}

LayoutMainHeader(guiObj, contentW) {
    global UI_TITLEBAR_HEIGHT
    y := 2
    leftX := 16
    hotkeyW := Max(160, Round(contentW * 0.34))
    titleW := Max(140, contentW - hotkeyW - 20)
    hotkeyX := leftX + titleW + 8
    try guiObj["DragArea"].Move(leftX, y, contentW, UI_TITLEBAR_HEIGHT)
    try guiObj["AppTitleText"].Move(leftX, y, titleW, UI_TITLEBAR_HEIGHT)
    try guiObj["ActiveHotkeyText"].Move(hotkeyX, y + 1, hotkeyW, UI_TITLEBAR_HEIGHT)
}

LayoutMainTiles(guiObj, winW, winH := 0) {
    global UI_MAIN_TILE_HEIGHT, UI_MAIN_TILE_GAP, UI_CLOSE_SIZE, UI_TITLEBAR_HEIGHT
    tileH := UI_MAIN_TILE_HEIGHT
    gap := UI_MAIN_TILE_GAP
    rowY := 2 + UI_TITLEBAR_HEIGHT + 2
    closeW := Max(74, Round(winW * 0.14))
    freeW := Max(200, winW - closeW - gap * 2)
    settingsW := Max(120, Round(freeW * 0.28))
    serviceW := Max(140, freeW - settingsW - gap)
    settingsX := serviceW + gap
    closeX := settingsX + settingsW + gap
    ; Avoid a visible right-side gap caused by rounding: force close tile to the edge.
    closeW := Max(74, winW - closeX)
    statusH := UI_CLOSE_SIZE
    try guiObj["StatusBar"].GetPos(&sx0, &sy0, &sw0, &sh0)
    if (sh0 > 0)
        statusH := sh0
    try guiObj["BtnServiceList"].Move(0, rowY, serviceW, tileH)
    try guiObj["BtnSettings"].Move(settingsX, rowY, settingsW, tileH)
    try guiObj["BtnWindowClose"].Move(closeX, rowY, closeW, tileH)
    try guiObj["StatusBar"].Move(0, rowY + tileH, winW, statusH)
}

AddAppWizard(*) {
    global myGui, pwaDir, listPath, configPath, g_theme, G_IC_ADD, G_IC_NO
    addGui := Theme_CreateModal(myGui, g_theme), myGui.Opt("+Disabled")
    addGui.SetFont("s14 w700 c" g_theme["AccentColor"], g_theme["FontFamilyTitle"]), addGui.Add("Text", "Center x35 y20 w350", GetLangText("Wizard", "Title"))
    addGui.SetFont("s10 w400 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    addGui.Add("Text", "x55 y+20 w310", "Ссылка (URL)")
    addGui.Add("Edit", "x55 w310 vServiceUrl", "")
    btnSaveAdd := AddCustomButton(addGui, "BtnAddSave", "x55 y+25 w150 h40 Center", G_IC_ADD GetLangText("Wizard", "CreateButton"), g_theme, "primary")
    btnCancelAdd := AddCustomButton(addGui, "BtnAddCancel", "w150 h40 x+10 Center", G_IC_NO GetLangText("Wizard", "CancelButton"), g_theme)
    btnCancelAdd.OnEvent("Click", (*) => (myGui.Opt("-Disabled"), addGui.Destroy()))
    btnSaveAdd.OnEvent("Click", (*) => OnConfirmAdd())
    OnConfirmAdd() {
        vals := addGui.Submit()
        sUrl := Trim(vals.ServiceUrl)

        if (sUrl = "") {
            ShowCustomPopup("Введите ссылку (URL).", GetLangText("Main", "Error"))
            return
        }

        urlHost := ""
        if RegExMatch(sUrl, "i)^https?://([^/]+)", &m)
            urlHost := m[1]
        else
            urlHost := sUrl
        urlHost := RegExReplace(urlHost, ":\d+$", "")
        parts := StrSplit(urlHost, ".")
        ignore := ["www", "chat", "app", "m", "web"]
        nameLabel := ""
        for part in parts {
            lower := StrLower(part)
            if ignore.Has(lower)
                continue
            nameLabel := part
            break
        }
        ; Fallback: second-level domain (e.g. deepseek.com -> deepseek).
        if (nameLabel = "" && parts.Length >= 2)
            nameLabel := parts[parts.Length - 2]
        if (nameLabel = "")
            nameLabel := urlHost

        nameLabel := RegExReplace(nameLabel, "[^A-Za-z0-9]+", "")
        if (nameLabel = "") {
            ShowCustomPopup("Не удалось автоматически определить имя из URL.", GetLangText("Main", "Error"))
            return
        }

        sID := RegExReplace(StrLower(nameLabel), "[^a-z0-9]+", "")
        if (sID = "")
            sID := RegExReplace(StrLower(urlHost), "[^a-z0-9]+", "")

        sTitle := StrUpper(SubStr(nameLabel, 1, 1)) . SubStr(nameLabel, 2)

        browserExe := ResolveBrowserExeForSeed("")
        if (browserExe = "" || !FileExist(browserExe)) {
            ShowCustomPopup("Не удалось определить браузер для ярлыка.", GetLangText("Main", "Error"))
            return
        }
        args := AppModeArgsForUrl(sUrl)
        if (args = "") {
            ShowCustomPopup("Не удалось сформировать аргументы запуска из URL.", GetLangText("Main", "Error"))
            return
        }
        try {
            lnkPath := pwaDir "\" sID ".lnk"
            exeName := ExeNameFromExePath(browserExe) ; expected by CoreGBC
            procName := exeName
            if (StrLower(procName) = "edge")
                procName := "msedge"
            crit := "ahk_exe " procName ".exe"

            before := Map()
            try {
                for hwnd in WinGetList(crit)
                    before[hwnd] := true
            }

            FileCreateShortcut(browserExe, lnkPath, , args)

            launchPid := 0
            ; Launch once so we can capture the real window title.
            Run('"' lnkPath '"', , , &launchPid)

            actualTitle := ""
            attempt := 0
            loop 40 {
                attempt++
                Sleep(250)
                for hwnd in WinGetList(crit) {
                    if (before.Has(hwnd))
                        continue
                    try {
                        if (launchPid && WinGetPID("ahk_id " hwnd) != launchPid)
                            continue
                    } catch {
                        continue
                    }
                    t := Trim(WinGetTitle("ahk_id " hwnd))
                    if (t != "" && !LocalIsBrowserTabStyleTitle(t)) {
                        actualTitle := t
                        break
                    }
                }
                if (actualTitle != "")
                    break
            }
            if (actualTitle = "") {
                try FileDelete(lnkPath)
                ShowCustomPopup("Не удалось надёжно определить окно нового сервиса. Повторите попытку при закрытых лишних окнах браузера.", GetLangText("Main", "Error"))
                return
            }
            sTitle := actualTitle

            IniWrite(sTitle, listPath, sID, "title")
            IniWrite(sID, listPath, sID, "file")
            IniWrite(exeName, listPath, sID, "exe")

            ; Autostart: switch to newly added service and restart engine.
            IniWrite(sTitle, configPath, "Settings", "AppTitle")
            IniWrite(sID, configPath, "Settings", "FileName")
            IniWrite(exeName, configPath, "Settings", "ExeName")
            IniWrite(sID, configPath, "Settings", "SelectedService")

            myGui.Opt("-Disabled")
            addGui.Destroy()
            LoadGuiFromConfig()
            ShowMainView()
            RestartAll()
        } catch {
            ShowCustomPopup(GetLangText("Wizard", "ErrorCreateShortcut"), GetLangText("Main", "Error"))
        }
    }
    LocalIsBrowserTabStyleTitle(full) {
        if (full = "")
            return false
        norm := StrReplace(StrReplace(full, "—", "-"), "–", "-")
        return RegExMatch(norm, "i) - (Google Chrome|Microsoft Edge|Mozilla Firefox|Opera GX|Chromium|Brave|Vivaldi|Arc|Yandex|Tor Browser|Samsung Internet|Firefox|Opera|Internet Explorer|LibreWolf|Wavebox|Comet|DuckDuckGo|Waterfox)\s*$")
    }
    addGui.Show("w420")
}

RunDeleteService(selected) {
    global listPath, pwaDir
    try {
        Loop Files, pwaDir "\" selected ".*" {
            try FileDelete(A_LoopFileFullPath)
        }
        IniDelete(listPath, selected)
        Reload()
    } catch {
        ShowCustomPopup(GetLangText("Wizard", "ErrorDeleteService"), GetLangText("Main", "Error"))
    }
}

DeleteService(*) {
    global myGui, g_theme, G_IC_OK, G_IC_NO
    emptyText := GetLangText("Main", "EmptyServiceList")
    clean := []
    for n in GetServicesList() {
        if (n != "" && n != emptyText)
            clean.Push(n)
    }
    if (clean.Length = 0) {
        ShowCustomPopup(GetLangText("Main", "DeleteNoServices"), GetLangText("Main", "Error"))
        return
    }
    myGui.Opt("+Disabled")
    pick := Theme_CreateModal(myGui, g_theme)
    pick.SetFont("s11 w400 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    pick.Add("Text", "xm w340 y12", GetLangText("Main", "DeletePickTitle"))
    lb := pick.Add("ListBox", "w340 h200 vPickList", clean)
    Theme_ApplyListControl(lb, g_theme)
    lb.Value := 1
    btnOk := AddCustomButton(pick, "BtnDeletePickOk", "w110 h35 xm y+14 Center", G_IC_OK GetLangText("Confirm", "OkButton"), g_theme, "primary")
    btnCancel := AddCustomButton(pick, "BtnDeletePickCancel", "w110 h35 x+10 Center", G_IC_NO GetLangText("Wizard", "CancelButton"), g_theme)
    ClosePick(*) {
        myGui.Opt("-Disabled")
        pick.Destroy()
    }
    DoPickOk(*) {
        idx := lb.Value
        sel := lb.Text
        pick.Destroy()
        myGui.Opt("-Disabled")
        if (idx = 0 || sel = "")
            return
        ShowCustomConfirm(Format(GetLangText("Confirm", "DeleteMessage"), sel), GetLangText("Confirm", "DeleteTitle"), () => RunDeleteService(sel))
    }
    btnCancel.OnEvent("Click", ClosePick)
    btnOk.OnEvent("Click", DoPickOk)
    lb.OnEvent("DoubleClick", DoPickOk)
    pick.Show("w380 AutoSize Center")
}

ShowHotkeyCaptureDialog(*) {
    global myGui, g_theme, G_IC_EXIT, G_IC_OK
    myGui.Opt("+Disabled")
    cap := Theme_CreateModal(myGui, g_theme)
    cap.SetFont("s12 w700 c" g_theme["TextPrimary"], g_theme["FontFamilyTitle"])
    cap.Add("Text", "Center x20 y16 w360", RTrim(HotkeyInvokeLabel()))
    cap.SetFont("s10 w400 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
    currentHk := NormalizeHotkeyFromUi(myGui["Hotkey"].Value)
    currentCap := GetLangTextOrDefault("Main", "CurrentHotkeyCaption", "Текущий хоткей", "Current hotkey")
    hintCap := GetLangTextOrDefault("Main", "HotkeyCaptureHint", "Нажмите клавишу или сочетание клавиш", "Press a key or key combination")
    newCap := GetLangTextOrDefault("Main", "NewHotkeyCaption", "Новый хоткей", "New hotkey")
    exitCap := GetLangTextOrDefault("Main", "ExitButton", "Выйти", "Exit")
    cap.Add("Text", "Center x30 y+18 w340", currentCap ": " HotkeyDisplayName(currentHk))
    cap.Add("Text", "Center x30 y+10 w340", hintCap)
    capturedText := cap.Add("Text", "vCapturedText Center x30 y+10 w340 Hidden", "")
    btnExit := AddCustomButton(cap, "BtnCaptureExit", "x30 y+18 w165 h35 Center", G_IC_EXIT exitCap, g_theme)
    btnApply := AddCustomButton(cap, "CapApplyBtn", "x+10 yp w165 h35 Hidden Center", G_IC_OK GetLangText("Main", "ApplyButton"), g_theme, "primary")
    pendingHk := ""

    CloseCaptureDialog(*) {
        myGui.Opt("-Disabled")
        cap.Destroy()
    }

    ApplyCapturedHotkey(*) {
        if (pendingHk = "")
            return
        myGui["Hotkey"].Value := HotkeyDisplayName(pendingHk)
        myGui["HkLabel"].Value := HotkeyInvokeLabel() . GetFriendlyName(pendingHk)
        CloseCaptureDialog()
        QueueAutoApplySettings()
    }

    CaptureOnce() {
        ih := InputHook("L1 T10")
        ih.KeyOpt("{All}", "E")
        ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-E")
        ih.Start()
        ih.Wait()
        if (ih.EndReason != "EndKey" || ih.EndKey = "")
            return
        mods := RegExReplace(ih.EndMods, "[<>](.)(?:>\1)?", "$1")
        pendingHk := mods . ih.EndKey
        capturedText.Value := newCap ": " HotkeyDisplayName(pendingHk)
        capturedText.Visible := true
        btnApply.Visible := true
        cap.Show("w400 AutoSize Center")
    }

    cap.OnEvent("Close", CloseCaptureDialog)
    btnExit.OnEvent("Click", CloseCaptureDialog)
    btnApply.OnEvent("Click", ApplyCapturedHotkey)
    cap.Show("w400 AutoSize Center")
    CaptureOnce()
}

RestartAll() {
    StopService()
    WaitForServiceState(false, 2500)
    if (StartService()) {
        if WaitForServiceState(true, 3000)
            ShowSettingsAppliedThenServiceStatus()
        else
            UpdateServiceButton()
    } else {
        UpdateServiceButton()
    }
}

ExpectedProcessNameFromExe(exe) {
    ex := StrLower(NormalizeExeName(exe))
    if (ex = "edge")
        ex := "msedge"
    if (ex = "")
        return ""
    return ex ".exe"
}

FindPwaWindowByTitleAndExe(title, exe) {
    SetTitleMatchMode(2)
    if (title = "")
        return 0
    expectedProc := ExpectedProcessNameFromExe(exe)
    if (expectedProc != "") {
        for hwnd in WinGetList("ahk_exe " expectedProc) {
            t := ""
            try t := WinGetTitle("ahk_id " hwnd)
            if (t != "" && InStr(t, title))
                return hwnd
        }
    }
    for hwnd in WinGetList() {
        t := ""
        try t := WinGetTitle("ahk_id " hwnd)
        if (t != "" && InStr(t, title))
            return hwnd
    }
    return 0
}

CloseCurrentPwaWindowFromConfig() {
    global configPath
    oldTitle := ""
    oldExe := ""
    try oldTitle := IniRead(configPath, "Settings", "AppTitle", "")
    try oldExe := IniRead(configPath, "Settings", "ExeName", "")
    hwnd := FindPwaWindowByTitleAndExe(oldTitle, oldExe)
    if (hwnd)
        try WinClose("ahk_id " hwnd)
}

OpenSelectedPwaWindow(fileName) {
    global pwaDir
    if (fileName = "")
        return false
    lnkPath := pwaDir "\" fileName ".lnk"
    urlPath := pwaDir "\" fileName ".url"
    if FileExist(lnkPath) {
        try {
            Run('"' lnkPath '"')
            return true
        }
    } else if FileExist(urlPath) {
        try {
            Run('"' urlPath '"')
            return true
        }
    }
    return false
}

SwitchToSelectedPwaWindow(fileName, title := "", exe := "") {
    if !OpenSelectedPwaWindow(fileName)
        return false
    if (title != "") {
        loop 20 {
            Sleep(200)
            if FindPwaWindowByTitleAndExe(title, exe) {
                CloseCurrentPwaWindowFromConfig()
                return true
            }
        }
        return false
    }
    CloseCurrentPwaWindowFromConfig()
    return true
}

QueueAutoApplySettings() {
    global g_suppressSiteChange, g_autoApplyPending
    if (g_suppressSiteChange)
        return
    g_autoApplyPending := true
    SetTimer(RunAutoApplySettings, -120)
}

RunAutoApplySettings() {
    global g_autoApplyPending, g_autoApplyRunning
    if !g_autoApplyPending
        return
    if (g_autoApplyRunning) {
        SetTimer(RunAutoApplySettings, -120)
        return
    }
    g_autoApplyPending := false
    g_autoApplyRunning := true
    try ApplySettings(false)
    g_autoApplyRunning := false
}

ResetApp(*) {
    ShowCustomConfirm(GetLangText("Confirm", "ResetMessage"), GetLangText("Confirm", "ResetTitle"), ResetAppConfirm)
}

ResetAppConfirm() {
    CleanRuntimeData()
    SetAutoStart(false)
    Reload()
}

CleanRuntimeData() {
    global coreDir, configPath, listPath
    Cfg_CleanRuntimeData(coreDir, configPath, listPath)
}

IsChecked(val) => Cfg_IsChecked(val)

ReadConfigIniValues() {
    global configPath, emptyText
    serviceList := GetServicesList()
    if (serviceList.Length = 0)
        serviceList := [emptyText]
    try {
        hotkeyVal := IniRead(configPath, "Settings", "Hotkey")
        lastService := IniRead(configPath, "Settings", "SelectedService")
        autoStartVal := IsChecked(IniRead(configPath, "Settings", "AutoStart", "True"))
        showTrayVal := IsChecked(IniRead(configPath, "Settings", "ShowTray", "True"))
        memoryVal := IsChecked(IniRead(configPath, "Settings", "MemoryPurge"))
        actionVal := IniRead(configPath, "Settings", "ActionClose", "False")
        themeModeVal := IniRead(configPath, "Settings", "ThemeMode", "System")
    } catch {
        hotkeyVal := "#c"
        lastService := serviceList[1]
        autoStartVal := true
        showTrayVal := true
        memoryVal := true
        actionVal := "False"
        themeModeVal := "System"
    }
    defIdx := 1
    for i, name in serviceList {
        if (name = lastService)
            defIdx := i
    }
    actionIdx := (actionVal = "True") ? 1 : 2
    return { hotkeyVal: hotkeyVal, lastService: lastService, autoStartVal: autoStartVal, showTrayVal: showTrayVal, memoryVal: memoryVal, actionVal: actionVal, themeModeVal: themeModeVal, defIdx: defIdx, actionIdx: actionIdx, serviceList: serviceList }
}

EnsureSelectedServiceConfigSynced(cfgObj) {
    global configPath, emptyText
    svcName := ""
    idx := Integer(cfgObj.defIdx)
    if (idx >= 1 && idx <= cfgObj.serviceList.Length)
        svcName := cfgObj.serviceList[idx]
    if (svcName = "" || svcName = emptyText)
        return
    svc := GetSelectedServiceData(svcName, emptyText)
    if (svc.selected = emptyText)
        return
    currentTitle := ""
    currentFile := ""
    currentExe := ""
    currentSel := ""
    try currentTitle := Trim(IniRead(configPath, "Settings", "AppTitle", ""))
    try currentFile := Trim(IniRead(configPath, "Settings", "FileName", ""))
    try currentExe := NormalizeExeName(IniRead(configPath, "Settings", "ExeName", ""))
    try currentSel := Trim(IniRead(configPath, "Settings", "SelectedService", ""))
    needsSync := (currentTitle = "" || currentFile = "" || currentSel = "" || currentSel != svc.selected || currentFile != svc.file || currentExe != svc.exe)
    if (!needsSync)
        return
    WriteSettingsEntries([["AppTitle", svc.title], ["FileName", svc.file], ["ExeName", svc.exe], ["SelectedService", svc.selected]])
}

GetSelectedServiceData(selectedSection, emptyText) {
    global listPath
    return Cfg_GetSelectedServiceData(listPath, selectedSection, emptyText)
}

WriteSettingsEntries(entries) {
    global configPath
    Cfg_WriteSettingsEntries(configPath, entries)
}

Cfg_EnsureConfigVersion(configPath)
TrySeedDefaultPwaFromDefaultFolder()
accentColor := GetWinAccentColor(), serviceList := GetServicesList()
g_theme := Theme_ReadFromConfig(configPath, accentColor)
emptyText := GetLangText("Main", "EmptyServiceList")
if (serviceList.Length = 0)
    serviceList := [emptyText]

if (NeedsFirstRunHotkeyChoice()) {
    fr := ShowFirstRunWizard()
    WriteFirstRunHotkeyBaseline(fr["hotkey"], fr["autoStart"], fr["showTray"], fr["memory"])
}

cfg := ReadConfigIniValues()
serviceList := cfg.serviceList
EnsureSelectedServiceConfigSynced(cfg)
cfg := ReadConfigIniValues()
serviceList := cfg.serviceList
hotkeyVal := cfg.hotkeyVal
lastService := cfg.lastService
autoStartVal := cfg.autoStartVal
showTrayVal := cfg.showTrayVal
memoryVal := cfg.memoryVal
actionVal := cfg.actionVal
themeModeVal := cfg.themeModeVal
defIdx := cfg.defIdx
actionIdx := cfg.actionIdx
actionOptions := [GetLangText("Main", "ActionClose"), GetLangText("Main", "ActionMinimize")]
serviceFieldChars := ServiceFieldCharsForWidth(serviceList)
serviceDisplay := BuildServiceDDLContent(serviceList, serviceFieldChars)
actionField := Max(StrLen(actionOptions[1]), StrLen(actionOptions[2])) + 4
actionDisplay := [PadRowCenter(actionOptions[1], actionField), PadRowCenter(actionOptions[2], actionField)]
themeDisplay := ThemeOptionsDisplay()

myGui := Gui("+AlwaysOnTop -Resize -Caption", GetLangText("Main", "WindowTitleMain"))
Theme_ApplyBaseGui(myGui, g_theme), myGui.MarginX := 30, myGui.MarginY := 4
myGui.OnEvent("Close", CloseMainGui)
ctx["myGui"] := myGui

dragArea := myGui.Add("Text", "vDragArea xm y2 w" UI_BASE_WIDTH " h" UI_TITLEBAR_HEIGHT " +0x200 Background" g_theme["BgColor"], "")
dragArea.OnEvent("Click", StartWindowDrag)
myGui.SetFont("s18 w700 c" g_theme["TextPrimary"], "Terminal")
appTitleText := myGui.Add("Text", "vAppTitleText x16 y2 w" (UI_BASE_WIDTH - 24) " h" UI_TITLEBAR_HEIGHT " +0x200 Background" g_theme["BgColor"], GetBrandTitle())
appTitleText.OnEvent("Click", StartWindowDrag)
activeHotkeyText := myGui.Add("Text", "vActiveHotkeyText x16 y2 w180 h" UI_TITLEBAR_HEIGHT " Right +0x200 Background" g_theme["BgColor"], GetHeaderHotkeyText(hotkeyVal))
activeHotkeyText.OnEvent("Click", StartWindowDrag)
btnWindowClose := AddCustomButton(myGui, "BtnWindowClose", "x16 y2 w74 h48 Center", G_IC_CLS, g_theme, "close")
btnWindowClose.OnEvent("Click", CloseMainGui)
btnWindowClose.OnEvent("DoubleClick", CloseMainGui)

myGui.SetFont("s11 w400 c" g_theme["TextPrimary"], g_theme["FontFamilyBase"])
statusBar := myGui.Add("Text", "vStatusBar xm y+10 w" UI_BASE_WIDTH " h" UI_CLOSE_SIZE " Background" g_theme["StatusActiveBg"] " c" g_theme["StatusActiveText"] " Center +0x200", GetLangText("Main", "StatusActive"))
statusBar.SetFont("s10 w600", g_theme["FontFamilyBase"])
statusBar.OnEvent("Click", ToggleServiceByStatusBar)
LayoutMainHeader(myGui, UI_BASE_WIDTH)

mainRow := MainRowButtonWidths(UI_BASE_WIDTH)
btnServiceList := AddCustomButton(myGui, "BtnServiceList", "x0 y66 w" mainRow[1] " h48 Center", "", g_theme)
btnServiceList.OnEvent("Click", ToggleServiceList)
btnSettings := AddCustomButton(myGui, "BtnSettings", "x+" UI_MAIN_ROW_GAP " yp w" mainRow[2] " h48 Center", G_IC_CFG GetLangText("Main", "SettingsButton"), g_theme)
btnSettings.OnEvent("Click", ShowSettingsView)
LayoutMainTiles(myGui, UI_BASE_WIDTH + 60)

btnAdd := AddCustomButton(myGui, "BtnAdd", "xm w205 h" UI_ROW_HEIGHT " Hidden y+5 Center", G_IC_ADD GetLangText("Main", "AddButton"), g_theme, "primary")
btnAdd.OnEvent("Click", AddAppWizard)

btnDel := AddCustomButton(myGui, "BtnDel", "x+10 yp w205 h" UI_ROW_HEIGHT " Hidden Center", G_IC_DEL GetLangText("Main", "DeleteButton"), g_theme, "danger")
btnDel.OnEvent("Click", DeleteService)

myGui.Add("Text", "vActionText xm w205 y+15 Hidden Center +0x200", ActionCaptionText())
myGui.Add("Text", "vThemeText x+10 yp w205 Hidden Center +0x200", ThemeCaptionText())
btnActionSelect := AddCustomButton(myGui, "BtnActionSelect", "xm w205 h32 Hidden Center y+6", "", g_theme)
btnActionSelect.OnEvent("Click", ToggleActionList)

btnThemeSelect := AddCustomButton(myGui, "BtnThemeSelect", "x+10 yp w205 h32 Hidden Center", "", g_theme)
btnThemeSelect.OnEvent("Click", ToggleThemeList)

hkLabel := myGui.Add("Text", "vHkLabel xm w205 y+15 Hidden +0x200", HotkeyInvokeLabel() . GetFriendlyName(hotkeyVal))

btnCap := AddCustomButton(myGui, "BtnCap", "x+10 yp w205 h" UI_ROW_HEIGHT " Hidden Center", G_IC_KEY GetLangTextOrDefault("Main", "ChangeHotkeyButton", "Изменить хоткей", "Change hotkey"), g_theme)
btnCap.OnEvent("Click", ShowHotkeyCaptureDialog)

hkEdit := myGui.Add("Edit", "vHotkey xm w" UI_BASE_WIDTH " h32 y+6 ReadOnly Background" g_theme["InputBg"] " Hidden", HotkeyDisplayName(hotkeyVal))

autoStartChk := myGui.Add("CheckBox", "vAutoStart xm y+15 w" UI_BASE_WIDTH " Hidden" (autoStartVal ? " Checked" : ""), GetLangText("Main", "AutoStart"))

showTrayChk := myGui.Add("CheckBox", "vShowTray xm y+10 w" UI_BASE_WIDTH " Hidden" (showTrayVal ? " Checked" : ""), GetLangText("Main", "ShowTray"))

memoryChk := myGui.Add("CheckBox", "vMemoryPurge xm y+10 w" UI_BASE_WIDTH " Hidden" (memoryVal ? " Checked" : ""), GetLangText("Main", "MemoryPurge"))

btnReset := AddCustomButton(myGui, "BtnReset", "xm w" UI_BASE_WIDTH " h" UI_ROW_HEIGHT " y+5 Hidden Center", G_IC_RST GetLangText("Main", "ResetButton"), g_theme, "danger")
btnReset.OnEvent("Click", ResetApp)

autoStartChk.OnEvent("Click", (*) => QueueAutoApplySettings())
showTrayChk.OnEvent("Click", (*) => QueueAutoApplySettings())
memoryChk.OnEvent("Click", (*) => QueueAutoApplySettings())

; Overlay lists are created after layout controls so they don't affect y+ flow.
serviceListBox := myGui.Add("ListBox", "vServiceListBox x0 y0 w120 h90 Hidden", [])

actionListBox := myGui.Add("ListBox", "vActionListBox x0 y0 w120 h90 Hidden", [])

themeListBox := myGui.Add("ListBox", "vThemeListBox x0 y0 w120 h95 Hidden", [])

ServicePickerSetItems(myGui, serviceList, defIdx)
g_actionSelectIdx := actionIdx
g_themeSelectIdx := ThemeModeToIndex(themeModeVal)
SimplePickerSetItems(myGui, "ActionListBox", "BtnActionSelect", actionOptions, g_actionSelectIdx)
SimplePickerSetItems(myGui, "ThemeListBox", "BtnThemeSelect", themeDisplay, g_themeSelectIdx)

StoreSettingsPositions() {
    global myGui, settingsOrigPos, settingsControlNames, ctx
    guiObj := ctx.Has("myGui") ? ctx["myGui"] : myGui
    names := ctx.Has("settingsControlNames") ? ctx["settingsControlNames"] : settingsControlNames
    settingsOrigPos := Ui_StoreSettingsPositions(guiObj, names)
    ctx["settingsOrigPos"] := settingsOrigPos
}

ShowMainView() {
    global myGui, settingsOrigPos, settingsControlNames, mainControlNames, ctx, g_layoutTransition
    guiObj := ctx.Has("myGui") ? ctx["myGui"] : myGui
    names := ctx.Has("settingsControlNames") ? ctx["settingsControlNames"] : settingsControlNames
    mainNames := ctx.Has("mainControlNames") ? ctx["mainControlNames"] : mainControlNames
    g_layoutTransition := true
    BeginGuiLayoutBatch(guiObj)
    try {
        HideServiceList()
        HideSettingsLists()
        RefreshPickerLayouts()
        Ui_ShowMainView(guiObj, &settingsOrigPos, names, mainNames, GetLangText("Main", "WindowTitleMain"))
        ctx["settingsOrigPos"] := settingsOrigPos
    } finally {
        EndGuiLayoutBatch(guiObj)
    }
    g_layoutTransition := false
    try {
        guiObj.GetClientPos(&cx, &cy, &cw, &ch)
        Gui_Size(guiObj, 0, cw, ch)
    }
    RefreshCustomButtonsAfterLayout()
}

ShowSettingsView(*) {
    global myGui, settingsOrigPos, settingsControlNames, mainControlNames, ctx, g_layoutTransition
    guiObj := ctx.Has("myGui") ? ctx["myGui"] : myGui
    names := ctx.Has("settingsControlNames") ? ctx["settingsControlNames"] : settingsControlNames
    mainNames := ctx.Has("mainControlNames") ? ctx["mainControlNames"] : mainControlNames
    if Ui_AreSettingsVisible(guiObj, names) {
        ShowMainView()
        return
    }
    g_layoutTransition := true
    BeginGuiLayoutBatch(guiObj)
    try {
        HideServiceList()
        HideSettingsLists()
        RefreshPickerLayouts()
        if (settingsOrigPos.Count = 0)
            StoreSettingsPositions()
        Ui_ShowSettingsView(guiObj, settingsOrigPos, names, mainNames, GetLangText("Main", "WindowTitleSettings"))
    } finally {
        EndGuiLayoutBatch(guiObj)
    }
    g_layoutTransition := false
    try {
        guiObj.GetClientPos(&cx, &cy, &cw, &ch)
        Gui_Size(guiObj, 0, cw, ch)
    }
    RefreshCustomButtonsAfterLayout()
}

LoadGuiFromConfig() {
    global myGui, g_suppressSiteChange, serviceList, emptyText, g_serviceSelectIdx, g_actionSelectIdx, g_themeSelectIdx, actionOptions, themeDisplay
    g_suppressSiteChange := true
    o := ReadConfigIniValues()
    serviceList := o.serviceList
    ServicePickerSetItems(myGui, serviceList, o.defIdx)
    g_serviceSelectIdx := o.defIdx
    myGui["Hotkey"].Value := HotkeyDisplayName(o.hotkeyVal)
    myGui["HkLabel"].Value := HotkeyInvokeLabel() . GetFriendlyName(o.hotkeyVal)
    myGui["ActiveHotkeyText"].Value := GetHeaderHotkeyText(o.hotkeyVal)
    g_actionSelectIdx := o.actionIdx
    g_themeSelectIdx := ThemeModeToIndex(o.themeModeVal)
    SimplePickerSetItems(myGui, "ActionListBox", "BtnActionSelect", actionOptions, g_actionSelectIdx)
    SimplePickerSetItems(myGui, "ThemeListBox", "BtnThemeSelect", themeDisplay, g_themeSelectIdx)
    RefreshPickerLayouts()
    myGui["AutoStart"].Value := o.autoStartVal ? 1 : 0
    myGui["ShowTray"].Value := o.showTrayVal ? 1 : 0
    myGui["MemoryPurge"].Value := o.memoryVal ? 1 : 0
    g_suppressSiteChange := false
}

ApplyServiceSelection(*) {
    global myGui, configPath, listPath, g_suppressSiteChange, g_serviceSelectIdx
    if (g_suppressSiteChange)
        return
    selectedSection := SiteSelectIndexToName(g_serviceSelectIdx)
    emptyText := GetLangText("Main", "EmptyServiceList")
    SetStatusApplying()
    svc := GetSelectedServiceData(selectedSection, emptyText)
    if (svc.selected = emptyText)
        return
    if !SwitchToSelectedPwaWindow(svc.file, svc.title, svc.exe) {
        ShowCustomPopup(GetLangTextOrDefault("Main", "ErrorOpenService", "Не удалось открыть выбранный сервис.", "Failed to open the selected service."), GetLangText("Main", "Error"))
        UpdateServiceButton()
        return
    }
    WriteSettingsEntries([["AppTitle", svc.title], ["FileName", svc.file], ["ExeName", svc.exe], ["SelectedService", svc.selected]])
    RestartAll()
}

ApplySettings(returnToMain := true) {
    global myGui, configPath, listPath, g_theme, g_serviceSelectIdx, g_actionSelectIdx, g_themeSelectIdx
    vals := myGui.Submit(false)
    SetStatusApplying()
    selectedSection := SiteSelectIndexToName(g_serviceSelectIdx)
    emptyText := GetLangText("Main", "EmptyServiceList")
    svc := GetSelectedServiceData(selectedSection, emptyText)

    isClosing := (g_actionSelectIdx = 1) ? "True" : "False"
    hkStored := NormalizeHotkeyFromUi(vals.Hotkey)
    themeMode := ThemeIndexToMode(g_themeSelectIdx)
    configs := [["AppTitle", svc.title], ["FileName", svc.file], ["ExeName", svc.exe], ["Hotkey", hkStored], ["AutoStart", vals.AutoStart ? "True" : "False"], ["ShowTray", vals.ShowTray ? "True" : "False"], ["MemoryPurge", vals.MemoryPurge ? "True" : "False"], ["ActionClose", isClosing], ["ThemeMode", themeMode], ["SelectedService", svc.selected]]
    try IniDelete(configPath, "Settings", "IgnoreBrowser")
    WriteSettingsEntries(configs)
    try IniDelete(configPath, "Settings", "SkipBrowserTabTitles")
    g_theme := Theme_ReadFromConfig(configPath, GetWinAccentColor())
    ApplyThemeToMainGui()
    LoadGuiFromConfig()
    SetAutoStart(vals.AutoStart)
    StopService()
    WaitForServiceState(false, 2500)
    if (returnToMain)
        ShowMainView()
    if (StartService()) {
        if WaitForServiceState(true, 3000)
            ShowSettingsAppliedThenServiceStatus()
        else
            UpdateServiceButton()
    } else {
        UpdateServiceButton()
    }
}

Gui_Size(thisGui, minMax, width, height) {
    global settingsControlNames, ctx, g_layoutTransition
    if (g_layoutTransition)
        return
    ClosePickerPopup()
    names := ctx.Has("settingsControlNames") ? ctx["settingsControlNames"] : settingsControlNames
    if Ui_ApplyResponsiveSize(thisGui, minMax, width, names)
        StoreSettingsPositions()
    if (minMax = -1)
        return
    newW := Max(420, width - 60)
    try LayoutMainHeader(thisGui, newW)
    try LayoutMainTiles(thisGui, width, height)
    for name in ["ActionText", "BtnActionSelect", "ThemeText", "BtnThemeSelect", "HkLabel", "Hotkey", "BtnCap", "AutoStart", "ShowTray", "MemoryPurge", "BtnReset"]
        try thisGui[name].Move(,, newW)
    try thisGui["ActionListBox"].Move(,, newW)
    try thisGui["ThemeListBox"].Move(,, newW)
    try {
        thisGui["BtnServiceList"].GetPos(&sx, &sy, &sw, &sh)
        thisGui["ServiceListBox"].Move(sx, sy + sh + 2, newW)
    }
    try {
        thisGui["BtnAdd"].GetPos(&ax, &ay, &aw, &ah)
        halfW := Floor((newW - 10) / 2)
        thisGui["BtnAdd"].Move(30, ay, halfW, ah)
        thisGui["BtnDel"].Move(30 + halfW + 10, ay, halfW, ah)
    }
    if Ui_AreSettingsVisible(thisGui, names) {
        thisGui["StatusBar"].GetPos(&sx, &sy, &sw, &sh)
        curY := sy + sh
        i := 1
        while (i <= names.Length) {
            name := names[i]
            if (name = "BtnAdd" && i < names.Length && names[i + 1] = "BtnDel") {
                thisGui["BtnAdd"].GetPos(&ax, &ay, &aw, &ah)
                thisGui["BtnDel"].GetPos(&dx, &dy, &dw, &dh)
                thisGui["BtnAdd"].Move(0, curY, width, ah)
                curY += ah
                thisGui["BtnDel"].Move(0, curY, width, dh)
                curY += dh
                i += 2
                continue
            }
            if (name = "ActionText" && i + 3 <= names.Length && names[i + 1] = "ThemeText" && names[i + 2] = "BtnActionSelect" && names[i + 3] = "BtnThemeSelect") {
                thisGui["ActionText"].GetPos(&tx, &ty, &tw, &th)
                thisGui["ThemeText"].GetPos(&tx2, &ty2, &tw2, &th2)
                thisGui["BtnActionSelect"].GetPos(&bx, &by, &bw, &bh)
                thisGui["BtnThemeSelect"].GetPos(&bx2, &by2, &bw2, &bh2)
                thisGui["ActionText"].Move(0, curY, width, th)
                curY += th
                thisGui["BtnActionSelect"].Move(0, curY, width, bh)
                curY += bh
                thisGui["ThemeText"].Move(0, curY, width, th2)
                curY += th2
                thisGui["BtnThemeSelect"].Move(0, curY, width, bh2)
                curY += bh2
                i += 4
                continue
            }
            if (name = "HkLabel" && i + 1 <= names.Length && names[i + 1] = "BtnCap") {
                thisGui["HkLabel"].GetPos(&hx, &hy, &hw, &hh)
                thisGui["BtnCap"].GetPos(&cx2, &cy2, &cw2, &ch2)
                halfW := Floor((width - 10) / 2)
                thisGui["HkLabel"].Move(0, curY, halfW, hh)
                thisGui["BtnCap"].Move(halfW + 10, curY, width - halfW - 10, ch2)
                curY += Max(hh, ch2)
                i += 2
                continue
            }
            c := thisGui[name]
            c.GetPos(&cx, &cy, &cw, &ch)
            c.Move(0, curY, width, ch)
            curY += ch
            i += 1
        }
        thisGui.Show("w" width " h" curY)
    }
    RefreshCustomButtonsAfterLayout()
    RefreshPickerLayouts()
}

myGui.OnEvent("Size", Gui_Size)
SetTimer(CustomButtonHoverTick, 40)
SetTimer(StatusBarHoverTick, 40)

ApplyThemeToMainGui()
myGui.Show("w480")
StoreSettingsPositions()
ShowMainView()
EnsureServiceRunning()
