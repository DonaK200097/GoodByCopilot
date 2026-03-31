Svc_GetEngineExePath(coreDir) {
    loop Files, coreDir "\*.*" {
        if (InStr(A_LoopFileName, "CoreGBC") && (StrLower(A_LoopFileExt) = "exe"))
            return A_LoopFileFullPath
    }
    return ""
}

Svc_GetEnginePath(coreDir) {
    engineAhk := ""
    engineExe := ""
    loop Files, coreDir "\*.*" {
        if !InStr(A_LoopFileName, "CoreGBC")
            continue
        ext := StrLower(A_LoopFileExt)
        if (ext = "ahk")
            engineAhk := A_LoopFileFullPath
        else if (ext = "exe")
            engineExe := A_LoopFileFullPath
    }
    ; Prefer compiled engine in released builds, source script in dev mode.
    if (A_IsCompiled && engineExe != "")
        return engineExe
    if (engineAhk != "")
        return engineAhk
    return engineExe
}

Svc_GetAhkRunnerPath() {
    candidates := []
    try candidates.Push(A_AhkPath)
    candidates.Push(A_ProgramFiles "\AutoHotkey\v2\AutoHotkey64.exe")
    candidates.Push(A_ProgramFiles "\AutoHotkey\v2\AutoHotkey.exe")
    candidates.Push(A_ProgramFiles "\AutoHotkey\AutoHotkey64.exe")
    candidates.Push(A_ProgramFiles "\AutoHotkey\AutoHotkey.exe")
    for p in candidates {
        if (p != "" && FileExist(p))
            return p
    }
    return ""
}

Svc_IsServiceRunning() {
    try {
        q := "SELECT * FROM Win32_Process WHERE Name LIKE 'CoreGBC%' OR CommandLine LIKE '%CoreGBC.ahk%'"
        processes := ComObjGet("winmgmts:").ExecQuery(q)
        for _ in processes
            return true
        return false
    } catch {
        return false
    }
}

Svc_IsPidRunning(pid) {
    p := Integer(pid)
    if (p <= 0)
        return false
    try {
        return ProcessExist(p) != 0
    } catch {
        return false
    }
}

Svc_WaitForServiceState(shouldRun, timeoutMs := 2500) {
    started := A_TickCount
    loop {
        running := Svc_IsServiceRunning()
        if (shouldRun && running)
            return true
        if (!shouldRun && !running)
            return true
        if ((A_TickCount - started) >= timeoutMs)
            return false
        Sleep(100)
    }
}

Svc_StartService(coreDir, &enginePid) {
    enginePath := Svc_GetEnginePath(coreDir)
    if (enginePath = "")
        return false
    pid := 0
    ext := StrLower(RegExReplace(enginePath, "^.*\.", ""))
    if (ext = "ahk") {
        runner := Svc_GetAhkRunnerPath()
        if (runner != "")
            Run('"' runner '" "' enginePath '"', coreDir, , &pid)
        else
            Run('"' enginePath '"', coreDir, , &pid)
    } else {
        Run('"' enginePath '"', coreDir, , &pid)
    }
    enginePid := pid
    return true
}

Svc_StopService(&enginePid) {
    if Svc_IsPidRunning(enginePid)
        try RunWait("taskkill /f /pid " enginePid " /t", , "Hide")
    if Svc_IsServiceRunning()
        try RunWait("taskkill /f /im CoreGBC* /t", , "Hide")
    try {
        q := "SELECT * FROM Win32_Process WHERE CommandLine LIKE '%CoreGBC.ahk%'"
        for p in ComObjGet("winmgmts:").ExecQuery(q)
            RunWait("taskkill /f /pid " p.ProcessId " /t", , "Hide")
    }
    enginePid := 0
}

Svc_SetAutoStart(enable, coreDir) {
    startupLnk := A_Startup "\GoodByCopilot.lnk"
    startupExe := A_Startup "\CoreGBC.exe"
    startupAhk := A_Startup "\CoreGBC.ahk"
    if (enable) {
        exePath := Svc_GetEngineExePath(coreDir)
        if (exePath != "") {
            try {
                FileCreateShortcut(exePath, startupLnk, coreDir)
                if FileExist(startupExe)
                    FileDelete(startupExe)
                if FileExist(startupAhk)
                    FileDelete(startupAhk)
            }
        }
        return
    }
    for p in [startupLnk, startupExe, startupAhk] {
        if FileExist(p)
            try FileDelete(p)
    }
}
