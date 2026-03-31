#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

configPath  := A_ScriptDir "\config.ini"
sessionPath := A_ScriptDir "\SessionHwnd.ini"
soundFile   := A_ScriptDir "\Sounds\Click.mp3"
hotkeyErrorPath := A_ScriptDir "\HotkeyError.ini"
mainAppDir  := A_ScriptDir "\.."

IsChecked(val) => (StrLower(String(val)) == "true" || String(val) == "1")

NormalizeExeName(s) {
    s := Trim(String(s))
    if (s = "")
        return ""
    return RegExReplace(s, "i)\.exe$", "")
}

BrowserPwaFolderNameFromPath(browserPath, exeName := "") {
    path := Trim(String(browserPath))
    if (path != "") {
        SplitPath(path, &name)
        base := NormalizeExeName(name)
    } else {
        base := NormalizeExeName(exeName)
    }
    if (base = "")
        return "DefaultBrowser_PWA"
    switch StrLower(base) {
        case "msedge":
            return "Microsoft Edge_PWA"
        case "chrome":
            return "Google Chrome_PWA"
        case "brave":
            return "Brave_PWA"
        case "vivaldi":
            return "Vivaldi_PWA"
        case "opera":
            return "Opera_PWA"
        case "firefox":
            return "Firefox_PWA"
        case "librewolf":
            return "LibreWolf_PWA"
        default:
            return base "_PWA"
    }
}

NormalizeHotkeyForRegistration(hk) {
    t := Trim(String(hk))
    if (t = "")
        return "#c"
    if (StrLower(t) = "copilot")
        return "<+#F23"
    if (t = "+#F23")
        return "<+#F23"
    return t
}

try {
    appTitle     := IniRead(configPath, "Settings", "AppTitle", "Поиск в Google")
    shortcutBase := IniRead(configPath, "Settings", "FileName", "gemini")
    exeName      := NormalizeExeName(IniRead(configPath, "Settings", "ExeName", ""))
    customHK     := IniRead(configPath, "Settings", "Hotkey", "#c")
    showTray     := IsChecked(IniRead(configPath, "Settings", "ShowTray", "True"))
    soundOn      := IsChecked(IniRead(configPath, "Settings", "SoundFeedback", "True"))
    memoryPurge  := IsChecked(IniRead(configPath, "Settings", "MemoryPurge", "True"))
    actionClose  := IsChecked(IniRead(configPath, "Settings", "ActionClose", "False"))
} catch {
    ExitApp()
}

browserPath := ""
try browserPath := Trim(IniRead(configPath, "Settings", "BrowserExe", ""))
if (browserPath = "" || !FileExist(browserPath)) {
    browserPath := ""
}
pwaDir := A_ScriptDir "\PWA\" BrowserPwaFolderNameFromPath(browserPath, exeName)
if !DirExist(pwaDir)
    DirCreate(pwaDir)

A_IconHidden := !showTray

GetTrayLanguage() {
    global configPath
    try {
        forced := StrLower(Trim(IniRead(configPath, "Settings", "Language", "")))
        if (forced = "ru")
            return "RU"
        if (forced = "en")
            return "EN"
    } catch {
    }
    try {
        lid := DllCall("kernel32\GetUserDefaultUILanguage", "UShort")
        prim := lid & 0x3FF
        if (prim = 0x19 || prim = 0x22 || prim = 0x23)
            return "RU"
    } catch {
    }
    return "EN"
}

GetTrayOpenText() {
    return (GetTrayLanguage() = "RU") ? "Открыть GoodByCopilot" : "Open GoodByCopilot"
}

GetTrayExitText() {
    return (GetTrayLanguage() = "RU") ? "Выход" : "Exit"
}

GetMainAppPath() {
    global mainAppDir
    exePath := mainAppDir "\GoodByCopilot.exe"
    if FileExist(exePath)
        return exePath
    ahkPath := mainAppDir "\GoodByCopilot.ahk"
    if FileExist(ahkPath)
        return ahkPath
    return ""
}

GetMainAppPid(mainAppPath) {
    if (mainAppPath = "")
        return 0
    isExe := StrLower(RegExReplace(mainAppPath, "^.*\.", "")) = "exe"
    try {
        q := "SELECT ProcessId, ExecutablePath, CommandLine FROM Win32_Process"
        for p in ComObjGet("winmgmts:").ExecQuery(q) {
            if (isExe) {
                try {
                    if (StrLower(String(p.ExecutablePath)) = StrLower(mainAppPath))
                        return Integer(p.ProcessId)
                }
            } else {
                try {
                    if InStr(StrLower(String(p.CommandLine)), StrLower(mainAppPath))
                        return Integer(p.ProcessId)
                }
            }
        }
    } catch {
    }
    return 0
}

FindBestMainAppWindow(pid) {
    if !pid
        return 0
    visible := []
    for hwnd in WinGetList("ahk_pid " pid) {
        try {
            mm := WinGetMinMax("ahk_id " hwnd)
            title := WinGetTitle("ahk_id " hwnd)
            if (mm != "" && title != "")
                visible.Push(hwnd)
        } catch {
        }
    }
    if (visible.Length = 0)
        return 0
    active := WinExist("A")
    for hwnd in visible {
        if (hwnd = active)
            return hwnd
    }
    return visible[1]
}

OpenMainApp(*) {
    global mainAppDir
    mainAppPath := GetMainAppPath()
    if (mainAppPath = "")
        return
    pid := GetMainAppPid(mainAppPath)
    if (pid) {
        hwnd := FindBestMainAppWindow(pid)
        if (hwnd) {
            try {
                if (WinGetMinMax("ahk_id " hwnd) = -1)
                    WinRestore("ahk_id " hwnd)
                WinActivate("ahk_id " hwnd)
                return
            } catch {
            }
        }
    }
    ext := StrLower(RegExReplace(mainAppPath, "^.*\.", ""))
    if (ext = "ahk") {
        runner := ""
        try runner := A_AhkPath
        if (runner = "" || !FileExist(runner))
            runner := ""
        if (runner = "")
            return
        try Run('"' runner '" "' mainAppPath '"', mainAppDir)
    } else {
        try Run('"' mainAppPath '"', mainAppDir)
    }
}

ExitTrayApp(*) {
    ExitApp()
}

ConfigureTrayMenu() {
    global showTray
    if !showTray
        return
    openText := GetTrayOpenText()
    exitText := GetTrayExitText()
    try A_TrayMenu.Delete()
    A_TrayMenu.Add(openText, OpenMainApp)
    A_TrayMenu.Add(exitText, ExitTrayApp)
    try A_TrayMenu.Default := openText
    try A_TrayMenu.ClickCount := 1
}

ConfigureTrayMenu()

targetFile := ""
if DirExist(pwaDir) {
    if FileExist(pwaDir "\" shortcutBase ".lnk")
        targetFile := pwaDir "\" shortcutBase ".lnk"
    else if FileExist(pwaDir "\" shortcutBase ".url")
        targetFile := pwaDir "\" shortcutBase ".url"
    else {
        Loop Files, pwaDir "\" shortcutBase ".*" {
            targetFile := A_LoopFileFullPath
            break
        }
    }
}

ExpectedProcessName(exe) {
    ex := StrLower(NormalizeExeName(exe))
    if (ex = "edge")
        ex := "msedge"
    return ex . ".exe"
}

ProcessMatchesExe(hwnd, exe) {
    if (exe = "")
        return true
    try {
        p := StrLower(WinGetProcessName("ahk_id " hwnd))
        return p = ExpectedProcessName(exe)
    } catch {
        return false
    }
}

NormalizeTitleDashes(s) {
    ; Tab titles often use en/em dash before the browser name; normalize for matching
    s := StrReplace(s, "—", "-")
    s := StrReplace(s, "–", "-")
    return s
}

IsBrowserTabStyleTitle(full) {
    if (full = "")
        return false
    norm := NormalizeTitleDashes(full)
    ; Common pattern: "<page> - … - <Browser product>" on the main window of a tabbed browser.
    ; End-anchored so service titles like "DeepSeek - В неизвестность" (no browser suffix) stay valid.
    return RegExMatch(norm, "i) - (Google Chrome|Microsoft Edge|Mozilla Firefox|Opera GX|Chromium|Brave|Vivaldi|Arc|Yandex|Tor Browser|Samsung Internet|Firefox|Opera|Internet Explorer|LibreWolf|Wavebox|Comet|DuckDuckGo|Waterfox)\s*$")
}

LoadPersistedHwnd(serviceKey, exe) {
    global sessionPath
    if (serviceKey = "")
        return 0
    try {
        h := Integer(IniRead(sessionPath, serviceKey, "Hwnd", "0"))
    } catch {
        return 0
    }
    if (!h || !WinExist("ahk_id " h) || !ProcessMatchesExe(h, exe))
        return 0
    if IsBrowserTabStyleTitle(WinGetTitle("ahk_id " h)) {
        ClearPersistedHwnd(serviceKey)
        return 0
    }
    return h
}

SavePersistedHwnd(serviceKey, hwnd) {
    global sessionPath
    if (serviceKey = "" || !hwnd)
        return
    try IniWrite(hwnd, sessionPath, serviceKey, "Hwnd")
}

ClearPersistedHwnd(serviceKey) {
    global sessionPath
    if (serviceKey = "")
        return
    try IniDelete(sessionPath, serviceKey)
}

ReuseLastServiceWindow(exe, serviceKey) {
    global lastServiceHwnd
    if !lastServiceHwnd
        return 0
    if !WinExist("ahk_id " lastServiceHwnd) {
        lastServiceHwnd := 0
        ClearPersistedHwnd(serviceKey)
        return 0
    }
    if !ProcessMatchesExe(lastServiceHwnd, exe)
        return 0
    if IsBrowserTabStyleTitle(WinGetTitle("ahk_id " lastServiceHwnd)) {
        lastServiceHwnd := 0
        ClearPersistedHwnd(serviceKey)
        return 0
    }
    return lastServiceHwnd
}

FindUniqueNonTabExeWindow(exe) {
    if (exe = "")
        return 0
    crit := "ahk_exe " ExpectedProcessName(exe)
    matched := []
    for hwnd in WinGetList(crit) {
        full := WinGetTitle(hwnd)
        if IsBrowserTabStyleTitle(full)
            continue
        matched.Push(hwnd)
    }
    if (matched.Length = 1)
        return matched[1]
    if (matched.Length > 1) {
        active := WinExist("A")
        for hwnd in matched {
            if (hwnd = active)
                return hwnd
        }
    }
    return 0
}

FilterHwndsTitleMatch(hwnds, title, skipBrowserTab) {
    matched := []
    for hwnd in hwnds {
        full := WinGetTitle(hwnd)
        if !InStr(full, title)
            continue
        if (skipBrowserTab && IsBrowserTabStyleTitle(full))
            continue
        matched.Push(hwnd)
    }
    return matched
}

ChooseBestHwnd(matched, title) {
    if (matched.Length = 0)
        return 0
    if (matched.Length = 1)
        return matched[1]
    active := WinExist("A")
    for hwnd in matched {
        if (hwnd = active)
            return hwnd
    }
    for hwnd in matched {
        if (WinGetTitle(hwnd) = title)
            return hwnd
    }
    return matched[1]
}

FindTargetWindow(title, exe, preferPid := 0) {
    SetTitleMatchMode 2
    if (title = "")
        return 0

    if (preferPid) {
        matched := FilterHwndsTitleMatch(WinGetList("ahk_pid " preferPid), title, true)
        if (hwnd := ChooseBestHwnd(matched, title))
            return hwnd
    }

    if (exe != "") {
        crit := "ahk_exe " ExpectedProcessName(exe)
        matched := FilterHwndsTitleMatch(WinGetList(crit), title, true)
        if (hwnd := ChooseBestHwnd(matched, title))
            return hwnd
    }

    matched := FilterHwndsTitleMatch(WinGetList(), title, true)
    return ChooseBestHwnd(matched, title)
}

HandleHotkey(*) {
    global targetFile, appTitle, exeName, actionClose, memoryPurge, lastServiceHwnd, shortcutBase

    hwnd := FindTargetWindow(appTitle, exeName, 0)
    if !hwnd {
        hwnd := ReuseLastServiceWindow(exeName, shortcutBase)
    }
    if !hwnd {
        hwnd := FindUniqueNonTabExeWindow(exeName)
    }

    if (hwnd) {
        lastServiceHwnd := hwnd
        SavePersistedHwnd(shortcutBase, hwnd)
        pid := WinGetPID(hwnd)

        if WinActive(hwnd) && WinGetMinMax(hwnd) != -1 {
            PlayClick()
            if (actionClose) {
                WinClose(hwnd)
                lastServiceHwnd := 0
                ClearPersistedHwnd(shortcutBase)
                if (memoryPurge)
                    SetTimer(() => FreeSpecificMemory(pid), -500)
            } else {
                WinMinimize(hwnd)
            }
        } else {
            PlayClick()
            if WinExist("ahk_id " hwnd) {
                if (WinGetMinMax(hwnd) = -1)
                    WinRestore(hwnd)
                WinActivate(hwnd)
            }
        }
    } else if (targetFile != "" && FileExist(targetFile)) {
        PlayClick()
        try {
            launchPid := 0
            Run('"' targetFile '"', , , &launchPid)
            found := 0
            loop 40 {
                Sleep 300
                if (found := FindTargetWindow(appTitle, exeName, launchPid))
                    break
            }
            if !found
                found := FindUniqueNonTabExeWindow(exeName)
            if (found) {
                lastServiceHwnd := found
                SavePersistedHwnd(shortcutBase, found)
                WinActivate(found)
            }
        }
    }
}

global lastServiceHwnd := LoadPersistedHwnd(shortcutBase, exeName)
registerHk := NormalizeHotkeyForRegistration(customHK)
registrationOk := false
try {
    Hotkey(registerHk, HandleHotkey)
    registrationOk := true
} catch as regErr {
    try IniWrite(regErr.Message, hotkeyErrorPath, "Hotkey", "Primary")
}
if (InStr(registerHk, "F23")) {
    try {
        Hotkey("#c", HandleHotkey)
        registrationOk := true
    } catch as regErr2 {
        try IniWrite(regErr2.Message, hotkeyErrorPath, "Hotkey", "Fallback")
    }
}
if (registrationOk) {
    try FileDelete(hotkeyErrorPath)
}

PlayClick() {
    if (soundOn && FileExist(soundFile))
        SoundPlay(soundFile)
}

FreeSpecificMemory(pid) {
    try {
        hProcess := DllCall("OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")
        if hProcess {
            DllCall("psapi.dll\EmptyWorkingSet", "Ptr", hProcess)
            DllCall("CloseHandle", "Ptr", hProcess)
        }
    }
}
