Ui_SetControlsVisible(guiObj, names, isVisible) {
    for n in names
        guiObj[n].Visible := isVisible
}

Ui_StoreSettingsPositions(guiObj, settingsControlNames) {
    if (!IsObject(guiObj))
        return Map()
    posMap := Map()
    for name in settingsControlNames {
        c := guiObj[name]
        c.GetPos(&x, &y, &w, &h)
        posMap[name] := {x: x, y: y, w: w, h: h}
    }
    return posMap
}

Ui_ShowMainView(guiObj, &settingsOrigPos, settingsControlNames, mainControlNames, titleText) {
    guiObj.Opt("-Resize")
    for name in settingsControlNames {
        if (!settingsOrigPos.Has(name))
            continue
        c := guiObj[name]
        pos := settingsOrigPos[name]
        c.Move(pos.x, pos.y, pos.w, pos.h)
        c.Visible := false
    }
    Ui_SetControlsVisible(guiObj, mainControlNames, true)
    guiObj.Title := titleText
    maxBottom := 0
    for name in mainControlNames {
        if (name = "StatusBar")
            continue
        c := guiObj[name]
        if !c.Visible
            continue
        c.GetPos(&x, &y, &w, &h)
        maxBottom := Max(maxBottom, y + h)
    }
    guiObj["StatusBar"].GetPos(&tx, &ty, &tw, &th)
    statusY := maxBottom
    guiObj["StatusBar"].Move(0, statusY, 480, th)
    targetH := statusY + th
    guiObj.Show("w480 h" targetH " xCenter")
    settingsOrigPos := Ui_StoreSettingsPositions(guiObj, settingsControlNames)
}

Ui_ShowSettingsView(guiObj, settingsOrigPos, settingsControlNames, mainControlNames, titleText) {
    if (settingsOrigPos.Count = 0)
        return
    guiObj.Opt("-Resize")
    guiObj["StatusBar"].GetPos(&sx, &sy, &sw, &sh)
    targetY := sy + sh
    fullW := 480
    curY := targetY
    i := 1
    while (i <= settingsControlNames.Length) {
        name := settingsControlNames[i]
        if (name = "BtnAdd" && i < settingsControlNames.Length && settingsControlNames[i + 1] = "BtnDel") {
            c1 := guiObj["BtnAdd"]
            c2 := guiObj["BtnDel"]
            c1.GetPos(&x1, &y1, &w1, &h1)
            c2.GetPos(&x2, &y2, &w2, &h2)
            c1.Move(0, curY, fullW, h1)
            curY += h1
            c2.Move(0, curY, fullW, h2)
            c1.Visible := true
            c2.Visible := true
            curY += h2
            i += 2
            continue
        }
        if (name = "ActionText" && i + 3 <= settingsControlNames.Length
            && settingsControlNames[i + 1] = "ThemeText"
            && settingsControlNames[i + 2] = "BtnActionSelect"
            && settingsControlNames[i + 3] = "BtnThemeSelect") {
            lAction := guiObj["ActionText"]
            lTheme := guiObj["ThemeText"]
            bAction := guiObj["BtnActionSelect"]
            bTheme := guiObj["BtnThemeSelect"]
            lAction.GetPos(&ax, &ay, &aw, &ah)
            lTheme.GetPos(&tx, &ty, &tw, &th)
            bAction.GetPos(&bax, &bay, &baw, &bah)
            bTheme.GetPos(&btx, &bty, &btw, &bth)
            lAction.Move(0, curY, fullW, ah), lAction.Visible := true
            curY += ah
            bAction.Move(0, curY, fullW, bah), bAction.Visible := true
            curY += bah
            lTheme.Move(0, curY, fullW, th), lTheme.Visible := true
            curY += th
            bTheme.Move(0, curY, fullW, bth), bTheme.Visible := true
            curY += bth
            i += 4
            continue
        }
        if (name = "HkLabel" && i + 1 <= settingsControlNames.Length
            && settingsControlNames[i + 1] = "BtnCap") {
            lHk := guiObj["HkLabel"]
            bCap := guiObj["BtnCap"]
            lHk.GetPos(&hx, &hy, &hw, &hh)
            bCap.GetPos(&bx, &by, &bw, &bh)
            halfW := Floor((fullW - 10) / 2)
            lHk.Move(0, curY, halfW, hh), lHk.Visible := true
            bCap.Move(halfW + 10, curY, fullW - halfW - 10, bh), bCap.Visible := true
            curY += Max(hh, bh)
            i += 2
            continue
        }
        c := guiObj[name]
        if (settingsOrigPos.Has(name))
            pos := settingsOrigPos[name]
        else {
            c.GetPos(&x, &y, &w, &h)
            pos := {x: x, y: y, w: w, h: h}
        }
        c.Move(0, curY, fullW, pos.h)
        c.Visible := true
        curY += pos.h
        i += 1
    }
    Ui_SetControlsVisible(guiObj, mainControlNames, true)
    guiObj.Title := titleText
    guiObj.Show("w480 h" curY " xCenter")
}

Ui_AreSettingsVisible(guiObj, settingsControlNames) {
    for name in settingsControlNames {
        try {
            if (guiObj[name].Visible)
                return true
        }
    }
    return false
}

Ui_ApplyResponsiveSize(thisGui, minMax, width, settingsControlNames) {
    if (minMax = -1)
        return false
    margin := 30
    baseGap := Max(6, Round(width * 0.01))
    newW := Max(420, width - margin * 2)
    fixedLabelW := Max(100, Min(160, Round(newW * 0.26)))
    selW := newW - fixedLabelW - baseGap
    if (selW < 180)
        selW := 180
    for name in settingsControlNames
        try thisGui[name].Move(,, newW)
    try {
        thisGui["LblSelect"].Move(,, fixedLabelW)
        thisGui["LblSelect"].GetPos(&lx, &ly, &lw, &lh)
        thisGui["SiteSelect"].GetPos(&sx0, &sy0, &sw0, &sh0)
        thisGui["SiteSelect"].Move(lx + lw + baseGap, ly, selW, sh0)
    }
    ; Keep main title centered to avoid clipping on scaled displays.
    try thisGui["AppTitleText"].Move(, , newW)
    return true
}
