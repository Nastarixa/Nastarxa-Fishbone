#Requires AutoHotkey v2.0
#SingleInstance Force
TraySetIcon "Fishbone.ico"

global _ALLOWED := [50, 66, 33, 25, 75, 40, 60]
global _ALLOWED_HINT := ""
for v in _ALLOWED
    _ALLOWED_HINT .= (_ALLOWED_HINT = "" ? "" : ", ") v
global _EXAMPLES_FILE := A_ScriptDir "\Fishbone Examples.ini"
global _PREVIEW_TIMER_MS := 30
global _fishGui := 0

; Migrate old examples to priority-based ordering
if FileExist(_EXAMPLES_FILE) {
    raw := IniRead(_EXAMPLES_FILE)
    needsMigrate := false
    for line in StrSplit(raw, "`n", "`r") {
        name := Trim(line)
        if name != "" && IniRead(_EXAMPLES_FILE, name, "_Priority", "") = ""
            needsMigrate := true
    }
    if needsMigrate {
        idx := 10
        for line in StrSplit(raw, "`n", "`r") {
            name := Trim(line)
            if name != "" && IniRead(_EXAMPLES_FILE, name, "_Priority", "") = "" {
                IniWrite(idx, _EXAMPLES_FILE, name, "_Priority")
                idx += 10
            }
        }
    }
}

OpenTimelineGui()

^F1::OpenTimelineGui()

#HotIf _fishGui && WinActive("ahk_id " _fishGui.Hwnd)
!h::AddHideToSelection(_fishGui)
^z::UndoRedo(_fishGui, -1)
^+z::UndoRedo(_fishGui, 1)
#HotIf

TrayTip("Nastarxa Fishbone", "Press Ctrl+F1 to open the timeline")
OnExit((*) => GDI.Stop())

class GDI {
    static token := 0, pFamily := 0

    static Start() {
        if this.token
            return this.token
        DllCall("LoadLibrary", "Str", "gdiplus")
        si := Buffer(16 + A_PtrSize, 0)
        NumPut("UInt", 1, si, 0)
        NumPut("UInt", 0, si, 4)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &token := 0, "Ptr", si, "Ptr", 0)
        if !token
            return 0
        this.token := token
        return token
    }

    static Stop() {
        if this.token {
            if this.pFamily {
                DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", this.pFamily)
                this.pFamily := 0
            }
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this.token)
            this.token := 0
        }
    }

    static GetFontFamily() {
        if !this.pFamily {
            DllCall("gdiplus\GdipCreateFontFamilyFromName", "Str", "Consolas", "Ptr", 0, "Ptr*", &fam := 0)
            this.pFamily := fam
        }
        return this.pFamily
    }

    static CreateBitmap(w, h) {
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap := 0)
        return pBitmap
    }

    static GetGraphics(pBitmap) {
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &pGraphics := 0)
        return pGraphics
    }

    static GetHBITMAP(pBitmap) {
        if !pBitmap
            return 0
        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "Ptr*", &hBitmap := 0, "UInt", 0xFF000000)
        return hBitmap
    }

    static DeleteGraphics(pGraphics) {
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
    }

    static DisposeImage(pImage) {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pImage)
    }

    static Clear(pGraphics, color := 0xFF2B2D31) {
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", pGraphics, "UInt", color)
    }

    static SetSmoothing(pGraphics, mode := 4) {
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", mode)
    }

    static CreatePen(color, width := 1) {
        DllCall("gdiplus\GdipCreatePen1", "UInt", color, "Float", width, "Int", 2, "Ptr*", &pPen := 0)
        return pPen
    }

    static DeletePen(pPen) {
        DllCall("gdiplus\GdipDeletePen", "Ptr", pPen)
    }

    static CreateBrush(color) {
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", color, "Ptr*", &pBrush := 0)
        return pBrush
    }

    static DeleteBrush(pBrush) {
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrush)
    }

    static LerpColor(c1, c2, t) {
        r1 := (c1 >> 16) & 0xFF, g1 := (c1 >> 8) & 0xFF, b1 := c1 & 0xFF
        r2 := (c2 >> 16) & 0xFF, g2 := (c2 >> 8) & 0xFF, b2 := c2 & 0xFF
        return 0xFF000000 | (Round(r1 + (r2 - r1) * t) << 16) | (Round(g1 + (g2 - g1) * t) << 8) | Round(b1 + (b2 - b1) * t)
    }

    static DrawLine(pGraphics, pPen, x1, y1, x2, y2) {
        DllCall("gdiplus\GdipDrawLineI", "Ptr", pGraphics, "Ptr", pPen, "Int", x1, "Int", y1, "Int", x2, "Int", y2)
    }

    static DrawBezier(pGraphics, pPen, x1, y1, cx1, cy1, cx2, cy2, x2, y2) {
        DllCall("gdiplus\GdipDrawBezierI", "Ptr", pGraphics, "Ptr", pPen, "Int", x1, "Int", y1, "Int", cx1, "Int", cy1, "Int", cx2, "Int", cy2, "Int", x2, "Int", y2)
    }

    static FillEllipse(pGraphics, pBrush, x, y, r) {
        DllCall("gdiplus\GdipFillEllipseI", "Ptr", pGraphics, "Ptr", pBrush, "Int", x - r, "Int", y - r, "Int", r * 2 + 1, "Int", r * 2 + 1)
    }

    static DrawString(pGraphics, text, x, y, w, h, pBrush, fontSize := 10) {
        if text = "" || !pBrush
            return
        pFamily := this.GetFontFamily()
        if !pFamily
            return
        DllCall("gdiplus\GdipCreateFont", "Ptr", pFamily, "Float", fontSize, "Int", 0, "Int", 0, "Ptr*", &pFont := 0)
        DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &pFormat := 0)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", pFormat, "Int", 1)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", pFormat, "Int", 1)
        rectF := Buffer(16)
        NumPut("Float", x, "Float", y, "Float", w, "Float", h, rectF)
        DllCall("gdiplus\GdipDrawString", "Ptr", pGraphics, "Str", text, "Int", -1, "Ptr", pFont, "Ptr", rectF, "Ptr", pFormat, "Ptr", pBrush)
        DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", pFormat)
        DllCall("gdiplus\GdipDeleteFont", "Ptr", pFont)
    }

    static DrawStringLeft(pGraphics, text, x, y, w, h, pBrush, fontSize := 10) {
        if text = "" || !pBrush
            return
        pFamily := this.GetFontFamily()
        if !pFamily
            return
        DllCall("gdiplus\GdipCreateFont", "Ptr", pFamily, "Float", fontSize, "Int", 0, "Int", 0, "Ptr*", &pFont := 0)
        DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &pFormat := 0)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", pFormat, "Int", 0)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", pFormat, "Int", 0)
        rectF := Buffer(16)
        NumPut("Float", x, "Float", y, "Float", w, "Float", h, rectF)
        DllCall("gdiplus\GdipDrawString", "Ptr", pGraphics, "Str", text, "Int", -1, "Ptr", pFont, "Ptr", rectF, "Ptr", pFormat, "Ptr", pBrush)
        DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", pFormat)
        DllCall("gdiplus\GdipDeleteFont", "Ptr", pFont)
    }
}

GetAllowedList(preferred := "") {
    list := []
    if preferred != "" {
        preferred := Integer(preferred)
        if IsAllowed(preferred)
            list.Push(preferred)
    }
    for val in _ALLOWED {
        exists := false
        for current in list {
            if current = val {
                exists := true
                break
            }
        }
        if !exists
            list.Push(val)
    }
    return list
}

IsAllowed(val) {
    for candidate in _ALLOWED {
        if candidate = val
            return true
    }
    return false
}

TryCreatePlacement(leftPos, rightPos, preferredPct, stage, depth, usedMap) {
    for pct in GetAllowedList(preferredPct) {
        pos := Round(leftPos + (rightPos - leftPos) * pct / 100)
        if pos <= leftPos || pos >= rightPos
            continue
        key := "" pos
        if usedMap.Has(key)
            continue
        return {pos: pos, pct: pct, left: leftPos, right: rightPos, depth: depth, stage: stage}
    }
    return 0
}

AddSegment(queue, leftPos, rightPos, depth) {
    if rightPos - leftPos <= 1
        return
    queue.Push({left: leftPos, right: rightPos, depth: depth})
}

SortSegmentsByWidth(queue) {
    sorted := []
    for seg in queue {
        width := seg.right - seg.left
        insertAt := sorted.Length + 1
        Loop sorted.Length {
            other := sorted[A_Index]
            otherWidth := other.right - other.left
            if width > otherWidth || (width = otherWidth && seg.left < other.left) {
                insertAt := A_Index
                break
            }
        }
        sorted.InsertAt(insertAt, seg)
    }
    return sorted
}

NormalizeRefToken(token) {
    token := Trim(StrUpper(token))
    if token = "START" || token = "A" || token = "KF1"
        return "A"
    if token = "END" || token = "B" || token = "KF2"
        return "B"
    if RegExMatch(token, "^(\d+)$", &m)
        return "I" Integer(m[1])
    if RegExMatch(token, "^I(\d+)$", &m)
        return "I" Integer(m[1])
    if RegExMatch(token, "^INBETWEEN\s*(\d+)$", &m)
        return "I" Integer(m[1])
    return ""
}

TrackCaret(g) {
    sel := DllCall("SendMessage", "Ptr", g.priorityRules.Hwnd, "UInt", 0x00B0, "Ptr", 0, "Ptr", 0, "UInt")
    g._savedPos := sel & 0xFFFF
}

AddHideToSelection(g) {
    hEdit := g.priorityRules.Hwnd
    full := g.priorityRules.Value
    len := StrLen(full)

    if g.priorityRules.Focused
        cursorPos0 := DllCall("SendMessage", "Ptr", hEdit, "UInt", 0x00B0, "Ptr", 0, "Ptr", 0, "UInt") & 0xFFFF
    else if g.HasProp("_savedPos")
        cursorPos0 := g._savedPos
    else
        cursorPos0 := 0
    cursorPos1 := cursorPos0 + 1

    ; Find segment boundaries (separators: comma, \r, \n)
    segStart1 := 1
    pos1 := cursorPos1
    while pos1 > 1 {
        ch := SubStr(full, pos1 - 1, 1)
        if ch = "," || ch = "`r" || ch = "`n" {
            segStart1 := pos1
            break
        }
        pos1--
    }

    segEnd1 := len + 1
    pos1 := cursorPos1
    while pos1 <= len {
        ch := SubStr(full, pos1, 1)
        if ch = "," || ch = "`r" || ch = "`n" {
            segEnd1 := pos1
            break
        }
        pos1++
    }

    segText := SubStr(full, segStart1, segEnd1 - segStart1)
    segText := Trim(segText)
    isFollow := RegExMatch(segText, "^\d+_f$")
    if (!InStr(segText, "=") && !isFollow) || RegExMatch(segText, "-Hide$")
        return

    ; Find position after last non-whitespace char in segment
    insertPos1 := segEnd1
    pos1 := segEnd1 - 1
    while pos1 >= segStart1 {
        ch := SubStr(full, pos1, 1)
        if ch != " " && ch != "`t" {
            insertPos1 := pos1 + 1
            break
        }
        pos1--
    }

    insertPos0 := insertPos1 - 1
    DllCall("SendMessage", "Ptr", hEdit, "UInt", 0x00B1, "Ptr", insertPos0, "Ptr", insertPos0)
    strBuf := Buffer(5 * 2 + 2)
    StrPut("-Hide", strBuf, "UTF-16")
    DllCall("SendMessage", "Ptr", hEdit, "UInt", 0x00C2, "Ptr", 1, "Ptr", strBuf.Ptr)
}

SetRefAB(g) {
    hEdit := g.priorityRules.Hwnd
    full := g.priorityRules.Value
    len := StrLen(full)

    if g.priorityRules.Focused
        cursorPos0 := DllCall("SendMessage", "Ptr", hEdit, "UInt", 0x00B0, "Ptr", 0, "Ptr", 0, "UInt") & 0xFFFF
    else if g.HasProp("_savedPos")
        cursorPos0 := g._savedPos
    else
        cursorPos0 := 0
    cursorPos1 := cursorPos0 + 1

    segStart1 := 1
    pos1 := cursorPos1
    while pos1 > 1 {
        ch := SubStr(full, pos1 - 1, 1)
        if ch = "," || ch = "`r" || ch = "`n" {
            segStart1 := pos1
            break
        }
        pos1--
    }

    segEnd1 := len + 1
    pos1 := cursorPos1
    while pos1 <= len {
        ch := SubStr(full, pos1, 1)
        if ch = "," || ch = "`r" || ch = "`n" {
            segEnd1 := pos1
            break
        }
        pos1++
    }

    segText := SubStr(full, segStart1, segEnd1 - segStart1)
    segText := Trim(segText)
    if segText = ""
        return

    newSeg := segText
    if RegExMatch(segText, "i)^(\d+\s*(?:[\[\{\(]\s*\d+\s*[\]\}\)])?\s*_\s*)[A-Z0-9 ]+\s*>[A-Z0-9 ]+(\s*=.*)$", &m)
        newSeg := m[1] "A>B" m[2]
    else if RegExMatch(segText, "i)^(\d+)(\s*(?:[\[\{\(]\s*\d+\s*[\]\}\)])?)\s*(?:_\s*F?)?\s*(-HIDE)?\s*$", &m) {
        hasHide := RegExMatch(segText, "-Hide$")
        newSeg := m[1] m[2] "_A>B=" (hasHide ? "Auto-Hide" : "Auto")
    }

    if newSeg != segText {
        insertPos0 := segStart1
        insertEnd0 := segEnd1 - 1
        if insertEnd0 < insertPos0
            insertEnd0 := insertPos0
        DllCall("SendMessage", "Ptr", hEdit, "UInt", 0x00B1, "Ptr", insertPos0, "Ptr", insertEnd0)
        strBuf := Buffer(StrLen(newSeg) * 2 + 2)
        StrPut(newSeg, strBuf, "UTF-16")
        DllCall("SendMessage", "Ptr", hEdit, "UInt", 0x00C2, "Ptr", 1, "Ptr", strBuf.Ptr)
    }
}

PushHistory(g) {
    if g._historyBusy
        return
    current := g.priorityRules.Value
    if g._history.Length && g._history[g._historyIdx + 1] = current
        return
    while g._history.Length > g._historyIdx + 1
        g._history.Pop()
    g._history.Push(current)
    if g._history.Length > 10
        g._history.RemoveAt(1)
    g._historyIdx := g._history.Length - 1
}

UndoRedo(g, dir) {
    if !g || !g.HasProp("_history")
        return
    newIdx := g._historyIdx + dir
    if newIdx < 0 || newIdx >= g._history.Length
        return
    g._historyBusy := true
    g._historyIdx := newIdx
    g.priorityRules.Value := g._history[newIdx + 1]
    g._historyBusy := false
    RedrawCanvas(g)
}

ParsePriorityRules(text, advanced := false) {
    rules := []
    parts := StrSplit(text, "`n", "`r")

    expanded := []
    for part in parts {
        for sub in StrSplit(part, ",") {
            trimmed := Trim(sub)
            if trimmed != ""
                expanded.Push(trimmed)
        }
    }
    for line in expanded {
        framePattern := "(?:\s*[\[\{\(]\s*(\d+)\s*[\]\}\)])?"
        priorityPattern := advanced
            ? "i)^\s*(\d+)" framePattern "\s*_\s*([A-Z0-9 ]+)\s*>\s*([A-Z0-9 ]+)\s*=\s*(\d+|AUTO)\s*(-HIDE)?\s*$"
            : "i)^\s*(\d+)\s*_\s*([A-Z0-9 ]+)\s*>\s*([A-Z0-9 ]+)\s*=\s*(\d+|AUTO)\s*(-HIDE)?\s*$"
        followPattern := advanced
            ? "i)^\s*(\d+)" framePattern "\s*_\s*F(-HIDE)?(?:\s*=\s*(\d+|AUTO)(-HIDE)?)?\s*$"
            : "i)^\s*(\d+)\s*_\s*F(-HIDE)?(?:\s*=\s*(\d+|AUTO)(-HIDE)?)?\s*$"

        if RegExMatch(line, priorityPattern, &m) {
            targetIdx := Integer(m[1])
            framePos := ""
            if advanced && m.Count >= 2 && m[2] != ""
                framePos := Max(1, Integer(m[2]))
            leftRef := NormalizeRefToken(m[advanced ? 3 : 2])
            rightRef := NormalizeRefToken(m[advanced ? 4 : 3])
            pctRaw := StrUpper(Trim(m[advanced ? 5 : 4]))
            isHide := m.Count >= (advanced ? 6 : 5) && m[advanced ? 6 : 5] != ""
            pct := isHide ? "AUTO" : (pctRaw = "AUTO" ? "AUTO" : Integer(pctRaw))
            if targetIdx >= 1 && leftRef != "" && rightRef != "" && leftRef != rightRef && (pct = "AUTO" || IsAllowed(pct)) {
                ruleObj := {mode: "priority", targetIdx: targetIdx, leftRef: leftRef, rightRef: rightRef, pct: pct, hide: isHide, raw: line}
                if framePos != ""
                    ruleObj.framePos := framePos
                rules.Push(ruleObj)
            }
            continue
        }
        if RegExMatch(line, followPattern, &m) {
            targetIdx := Integer(m[1])
            framePos := ""
            if advanced && m.Count >= 2 && m[2] != ""
                framePos := Max(1, Integer(m[2]))
            isHide := InStr(StrUpper(line), "-HIDE")
            pctGroup := advanced ? 4 : 3
            pct := (m.Count >= pctGroup && m[pctGroup] != "") ? (RegExMatch(m[pctGroup], "^\d+$") ? Integer(m[pctGroup]) : "AUTO") : ""
            if targetIdx >= 1 && (pct = "" || pct = "AUTO" || IsAllowed(pct)) {
                ruleObj := {mode: "follow", targetIdx: targetIdx, hide: isHide, pct: pct, raw: line}
                if framePos != ""
                    ruleObj.framePos := framePos
                rules.Push(ruleObj)
            }
        }
    }
    return rules
}

GetMaxRuleFrame(rules) {
    maxFrame := 0
    for rule in rules {
        if rule.HasProp("framePos") && rule.framePos > maxFrame
            maxFrame := rule.framePos
    }
    return maxFrame
}

CopyRuleFrameToPlacement(rule, placement) {
    if IsObject(rule) && rule.HasProp("framePos")
        placement.framePos := rule.framePos
}

GetRuleCount(rules) {
    maxIdx := 0
    for rule in rules {
        if rule.targetIdx > maxIdx
            maxIdx := rule.targetIdx
    }
    return maxIdx
}

SnapToAllowed(val) {
    nearest := _ALLOWED[1]
    minDist := Abs(val - nearest)
    for candidate in _ALLOWED {
        dist := Abs(val - candidate)
        if dist < minDist {
            minDist := dist
            nearest := candidate
        }
    }
    return nearest
}

LabelToIndex(label, needed) {
    if label = "A"
        return 0
    if label = "B"
        return needed + 1
    if RegExMatch(label, "^I(\d+)$", &m)
        return Integer(m[1])
    return -1
}

ResolveRulePct(rule, needed) {
    if rule.pct != "AUTO"
        return rule.pct
    leftIdx := LabelToIndex(rule.leftRef, needed)
    rightIdx := LabelToIndex(rule.rightRef, needed)
    if leftIdx < 0 || rightIdx < 0 || rightIdx = leftIdx
        return 50
    if rightIdx < leftIdx {
        tmp := leftIdx, leftIdx := rightIdx, rightIdx := tmp
    }
    idealPct := Round(100 * (rule.targetIdx - leftIdx) / (rightIdx - leftIdx))
    return SnapToAllowed(idealPct)
}

EncodeExampleText(text) {
    text := StrReplace(text, "`r`n", "\n")
    text := StrReplace(text, "`r", "\n")
    return StrReplace(text, "`n", "\n")
}

DecodeExampleText(text) {
    text := StrReplace(text, "\n", "`r`n")
    return StrReplace(text, "`n", "`r`n")
}

GetExampleNames() {
    if !FileExist(_EXAMPLES_FILE)
        return []
    raw := IniRead(_EXAMPLES_FILE)
    allNames := []
    for line in StrSplit(raw, "`n", "`r") {
        name := Trim(line)
        if name != ""
            allNames.Push(name)
    }
    ; Sort by _Priority, append un-prioritized at the end
    withPrio := []
    withoutPrio := []
    for n in allNames {
        p := IniRead(_EXAMPLES_FILE, n, "_Priority", "")
        if p ~= "^\d+$"
            withPrio.Push({name: n, prio: Integer(p)})
        else
            withoutPrio.Push(n)
    }
    ; Sort prioritized by priority value
    sorted := []
    for item in withPrio {
        i := sorted.Length + 1
        Loop sorted.Length {
            if item.prio < sorted[A_Index].prio {
                i := A_Index
                break
            }
        }
        sorted.InsertAt(i, item)
    }
    result := []
    for s in sorted
        result.Push(s.name)
    for n in withoutPrio
        result.Push(n)
    return result
}

SaveExample(name, rulesText, notesText := "", advanced := false, fps := 24, frames := 100) {
    name := Trim(name)
    if name = ""
        return false
    rulesText := EncodeExampleText(rulesText)
    notesText := EncodeExampleText(notesText)
    fps := Integer(fps)
    frames := Integer(frames)
    if fps < 1
        fps := 24
    if frames < 2
        frames := 100
    IniWrite(rulesText, _EXAMPLES_FILE, name, "Rules")
    IniWrite(notesText, _EXAMPLES_FILE, name, "Notes")
    IniWrite(advanced ? "1" : "0", _EXAMPLES_FILE, name, "Advanced")
    IniWrite(fps, _EXAMPLES_FILE, name, "FPS")
    IniWrite(frames, _EXAMPLES_FILE, name, "Frames")
    ; Assign next priority if new example
    if !IniRead(_EXAMPLES_FILE, name, "_Priority", "")
        IniWrite(_NextPriority(), _EXAMPLES_FILE, name, "_Priority")
    return true
}

_NextPriority() {
    maxP := 0
    for n in StrSplit(IniRead(_EXAMPLES_FILE), "`n", "`r") {
        if Trim(n) = ""
            continue
        p := IniRead(_EXAMPLES_FILE, n, "_Priority", "")
        if p ~= "^\d+$" && Integer(p) > maxP
            maxP := Integer(p)
    }
    return maxP + 10
}

LoadExample(name) {
    if !FileExist(_EXAMPLES_FILE)
        return ""
    return DecodeExampleText(IniRead(_EXAMPLES_FILE, name, "Rules", ""))
}

LoadExampleNotes(name) {
    if !FileExist(_EXAMPLES_FILE)
        return ""
    return DecodeExampleText(IniRead(_EXAMPLES_FILE, name, "Notes", ""))
}

LoadExampleMeta(name) {
    if !FileExist(_EXAMPLES_FILE)
        return {advanced: false, fps: 24, frames: 100}
    advanced := IniRead(_EXAMPLES_FILE, name, "Advanced", "0")
    fps := Integer(IniRead(_EXAMPLES_FILE, name, "FPS", "24"))
    frames := Integer(IniRead(_EXAMPLES_FILE, name, "Frames", "100"))
    if fps < 1
        fps := 24
    if frames < 2
        frames := 100
    return {advanced: advanced = "1", fps: fps, frames: frames}
}

DeleteExample(name) {
    if !FileExist(_EXAMPLES_FILE)
        return
    try IniDelete(_EXAMPLES_FILE, name)
}

MoveExample(listBox, dir) {
    global _EXAMPLES_FILE
    idx := listBox.Value
    if idx <= 0
        return
    names := GetExampleNames()
    newIdx := idx + dir
    if newIdx < 1 || newIdx > names.Length
        return

    name1 := names[idx]
    name2 := names[newIdx]
    p1 := IniRead(_EXAMPLES_FILE, name1, "_Priority", "")
    p2 := IniRead(_EXAMPLES_FILE, name2, "_Priority", "")

    if p1 = "" {
        p1 := _NextPriority()
        IniWrite(p1, _EXAMPLES_FILE, name1, "_Priority")
    }
    if p2 = "" {
        p2 := _NextPriority() + 1
        IniWrite(p2, _EXAMPLES_FILE, name2, "_Priority")
    }

    IniWrite(p2, _EXAMPLES_FILE, name1, "_Priority")
    IniWrite(p1, _EXAMPLES_FILE, name2, "_Priority")
}

GetPlacementLabel(idx) {
    return "I" idx
}

FindPlacementByLabel(placementsByIndex, label) {
    if label = "A"
        return {exists: true, pos: 0, label: "A"}
    if label = "B"
        return {exists: true, pos: 100, label: "B"}
    if RegExMatch(label, "^I(\d+)$", &m) {
        idx := Integer(m[1])
        if placementsByIndex.Has(idx) {
            p := placementsByIndex[idx]
            return {exists: true, pos: p.pos, label: p.label}
        }
    }
    return {exists: false}
}

BuildFinalStops(placementsByIndex) {
    stops := [{label: "A", pos: 0, type: "endpoint"}]
    for _, placement in placementsByIndex {
        stop := {label: placement.pct, pos: placement.pos, type: placement.stage, targetIdx: placement.targetIdx}
        if placement.HasProp("framePos")
            stop.framePos := placement.framePos
        stops.Push(stop)
    }
    stops.Push({label: "B", pos: 100, type: "endpoint"})

    sortedStops := []
    for stop in stops {
        insertAt := sortedStops.Length + 1
        Loop sortedStops.Length {
            if stop.pos < sortedStops[A_Index].pos {
                insertAt := A_Index
                break
            }
        }
        sortedStops.InsertAt(insertAt, stop)
    }
    return sortedStops
}

BuildQueueFromStops(stops, depth := 2) {
    queue := []
    for i, stop in stops {
        if i < stops.Length
            AddSegment(queue, stop.pos, stops[i + 1].pos, depth)
    }
    return queue
}

TakeBestSegment(queue) {
    queue := SortSegmentsByWidth(queue)
    if queue.Length = 0
        return {queue: queue, seg: 0}
    seg := queue.RemoveAt(1)
    return {queue: queue, seg: seg}
}

AddPlacementToQueue(queue, placement) {
    AddSegment(queue, placement.left, placement.pos, placement.depth + 1)
    AddSegment(queue, placement.pos, placement.right, placement.depth + 1)
    return queue
}

SeedAutoPriorityAnchors(plan, followRuleMap, needed, usedMap) {
    if needed <= 0 || followRuleMap.Count = 0
        return false

    progress := false
    midLeft := Ceil(needed / 2)
    midRight := Floor(needed / 2) + 1
    anchorTargets := []
    anchorTargets.Push(midLeft)
    if midRight != midLeft
        anchorTargets.Push(midRight)

    for targetIdx in anchorTargets {
        if !followRuleMap.Has(targetIdx) || plan.placementsByIndex.Has(targetIdx)
            continue
        pct := 50
        if anchorTargets.Length = 2
            pct := (targetIdx = midLeft) ? 40 : 60
        anchor := TryCreatePlacement(0, 100, pct, "priority", 1, usedMap)
        if !anchor
            continue
        anchor.label := GetPlacementLabel(targetIdx)
        anchor.leftRef := "A"
        anchor.rightRef := "B"
        anchor.targetIdx := targetIdx
        anchor.ruleText := followRuleMap[targetIdx].raw " [auto-anchor]"
        CopyRuleFrameToPlacement(followRuleMap[targetIdx], anchor)
        usedMap["" anchor.pos] := true
        plan.placementsByIndex[targetIdx] := anchor
        plan.placements.Push(anchor)
        progress := true
    }

    return progress
}

ResolveFollowRuns(plan, followRuleMap, needed, usedMap, followPct := 50) {
    progress := false
    idx := 1
    while idx <= needed {
        if !followRuleMap.Has(idx) || plan.placementsByIndex.Has(idx) {
            idx += 1
            continue
        }

        runStart := idx
        runEnd := idx
        while runEnd < needed && followRuleMap.Has(runEnd + 1) && !plan.placementsByIndex.Has(runEnd + 1)
            runEnd += 1

        leftIdx := runStart - 1
        rightIdx := runEnd + 1
        leftKnown := (leftIdx = 0) || plan.placementsByIndex.Has(leftIdx)
        rightKnown := (rightIdx = needed + 1) || plan.placementsByIndex.Has(rightIdx)

        if !leftKnown || !rightKnown {
            idx := runEnd + 1
            continue
        }

        leftPos := leftIdx = 0 ? 0 : plan.placementsByIndex[leftIdx].pos
        rightPos := rightIdx = needed + 1 ? 100 : plan.placementsByIndex[rightIdx].pos
        spanCount := rightIdx - leftIdx
        if spanCount <= 1 {
            idx := runEnd + 1
            continue
        }

        segLeft := leftPos
        Loop runEnd - runStart + 1 {
            targetIdx := runStart + A_Index - 1
            rule := followRuleMap[targetIdx]

            if A_Index > 1 {
                prevIdx := targetIdx - 1
                if plan.placementsByIndex.Has(prevIdx)
                    segLeft := plan.placementsByIndex[prevIdx].pos
            }

            ; Auto keeps the original follow behavior: evenly distribute a run inside its available gap.
            if rule.pct is Integer
                pos := Round(leftPos + (rightPos - leftPos) * rule.pct / 100)
            else if followPct = "AUTO" {
                frac := (targetIdx - leftIdx) / spanCount
                pos := Round(leftPos + (rightPos - leftPos) * frac)
            }
            else {
                placementCandidate := TryCreatePlacement(segLeft, rightPos, followPct, "follow", 1, usedMap)
                if !placementCandidate
                    continue
                pos := placementCandidate.pos
            }

            ; PCT label: local between immediate left neighbor and right boundary
            localPct := Round(100 * (pos - segLeft) / (rightPos - segLeft))
            pct := SnapToAllowed(localPct)
            placement := {pos: pos, pct: pct, left: segLeft, right: rightPos, depth: 1, stage: "follow"}
            placement.label := GetPlacementLabel(targetIdx)
            placement.leftRef := leftIdx = 0 ? "A" : GetPlacementLabel(targetIdx - 1)
            placement.rightRef := rightIdx = needed + 1 ? "B" : GetPlacementLabel(targetIdx + 1)
            placement.targetIdx := targetIdx
            placement.ruleText := followRuleMap[targetIdx].raw
            CopyRuleFrameToPlacement(rule, placement)
            usedMap["" pos] := true
            plan.placementsByIndex[targetIdx] := placement
            plan.placements.Push(placement)
            segLeft := pos
            progress := true
        }

        idx := runEnd + 1
    }

    return progress
}

ResolvePriorityPending(plan, pendingRules, usedMap, needed) {
    nextPending := []
    progress := false
    for rule in pendingRules {
        if plan.placementsByIndex.Has(rule.targetIdx)
            continue
        leftNode := FindPlacementByLabel(plan.placementsByIndex, rule.leftRef)
        rightNode := FindPlacementByLabel(plan.placementsByIndex, rule.rightRef)
        if !leftNode.exists || !rightNode.exists {
            nextPending.Push(rule)
            continue
        }
        leftPos := leftNode.pos
        rightPos := rightNode.pos
        if rightPos < leftPos {
            tmp := leftPos, leftPos := rightPos, rightPos := tmp
        }
        pct := ResolveRulePct(rule, needed)
        priority := TryCreatePlacement(leftPos, rightPos, pct, "priority", 1, usedMap)
        if !priority {
            nextPending.Push(rule)
            continue
        }
        priority.label := GetPlacementLabel(rule.targetIdx)
        priority.leftRef := leftNode.label
        priority.rightRef := rightNode.label
        priority.targetIdx := rule.targetIdx
        priority.ruleText := rule.raw
        CopyRuleFrameToPlacement(rule, priority)
        usedMap["" priority.pos] := true
        plan.placementsByIndex[rule.targetIdx] := priority
        plan.placements.Push(priority)
        progress := true
    }
    return {pending: nextPending, progress: progress}
}

BuildAdvancedFrameMap(rules, needed, totalFrames) {
    frameMap := Map()
    for rule in rules {
        if rule.targetIdx <= needed && rule.HasProp("framePos") && !frameMap.Has(rule.targetIdx) {
            frameNum := Min(Max(1, rule.framePos), Max(2, totalFrames))
            frameMap[rule.targetIdx] := {pos: FrameToPos(frameNum, totalFrames), label: GetPlacementLabel(rule.targetIdx), framePos: frameNum}
        }
    }
    return frameMap
}

FindAdvancedNode(frameMap, label, needed) {
    if label = "A"
        return {exists: true, pos: 0, label: "A"}
    if label = "B"
        return {exists: true, pos: 100, label: "B"}
    if RegExMatch(label, "^I(\d+)$", &m) {
        idx := Integer(m[1])
        if frameMap.Has(idx)
            return {exists: true, pos: frameMap[idx].pos, label: frameMap[idx].label}
    }
    return {exists: false, pos: 0, label: ""}
}

CreateAdvancedPlacement(rule, plan, needed, totalFrames, frameMap) {
    if !rule.HasProp("framePos")
        return 0

    frameNum := Min(Max(1, rule.framePos), Max(2, totalFrames))
    pos := FrameToPos(frameNum, totalFrames)
    placement := {pos: pos, left: 0, right: 100, depth: 1, stage: rule.mode}
    placement.label := GetPlacementLabel(rule.targetIdx)
    placement.targetIdx := rule.targetIdx
    placement.ruleText := rule.raw
    placement.framePos := frameNum

    if rule.mode = "priority" {
        leftNode := FindAdvancedNode(frameMap, rule.leftRef, needed)
        rightNode := FindAdvancedNode(frameMap, rule.rightRef, needed)
        if !leftNode.exists || !rightNode.exists
            return 0
        placement.left := leftNode.pos
        placement.right := rightNode.pos
        placement.leftRef := leftNode.label
        placement.rightRef := rightNode.label
        if placement.right < placement.left {
            tmp := placement.left, placement.left := placement.right, placement.right := tmp
            tmpRef := placement.leftRef, placement.leftRef := placement.rightRef, placement.rightRef := tmpRef
        }
    } else {
        leftIdx := rule.targetIdx - 1
        while leftIdx > 0 && !plan.placementsByIndex.Has(leftIdx)
            leftIdx -= 1
        rightIdx := rule.targetIdx + 1
        while rightIdx <= needed && !plan.placementsByIndex.Has(rightIdx)
            rightIdx += 1
        placement.left := leftIdx = 0 ? 0 : plan.placementsByIndex[leftIdx].pos
        placement.right := rightIdx > needed ? 100 : plan.placementsByIndex[rightIdx].pos
        placement.leftRef := leftIdx = 0 ? "A" : GetPlacementLabel(leftIdx)
        placement.rightRef := rightIdx > needed ? "B" : GetPlacementLabel(rightIdx)
    }

    span := placement.right - placement.left
    localPct := span != 0 ? Round(100 * (placement.pos - placement.left) / span) : 50
    placement.actualPct := Max(0, Min(100, localPct))
    placement.autoPct := SnapToAllowed(placement.actualPct)
    placement.pct := placement.autoPct
    if rule.HasProp("pct") && rule.pct != "AUTO" && rule.pct != "" {
        placement.pct := rule.pct
        placement.requestedPct := rule.pct
        placement.forcedPct := true
    }
    return placement
}

CreateAdvancedFakePriority(rule, totalFrames) {
    frameNum := Min(Max(1, rule.framePos), Max(2, totalFrames))
    pos := FrameToPos(frameNum, totalFrames)
    placement := {pos: pos, left: 0, right: 100, depth: 1, stage: "priority"}
    placement.label := GetPlacementLabel(rule.targetIdx)
    placement.leftRef := "A"
    placement.rightRef := "B"
    placement.targetIdx := rule.targetIdx
    placement.framePos := frameNum
    placement.actualPct := pos
    placement.autoPct := SnapToAllowed(pos)
    placement.pct := placement.autoPct
    placement.ruleText := rule.raw " [auto-anchor]"
    placement.fakePriority := true
    return placement
}

GenerateAdvancedFishbonePlan(totalInbetweens, priorityRules, totalFrames, useFakePriority := true) {
    plan := {placements: [], finalStops: [], placementsByIndex: Map(), advanced: true}
    needed := totalInbetweens
    priorityPending := []
    followPending := []
    for rule in priorityRules {
        if rule.targetIdx > needed || !rule.HasProp("framePos")
            continue
        if rule.mode = "priority"
            priorityPending.Push(rule)
        else
            followPending.Push(rule)
    }

    SortAdvancedRulesByFrame(priorityPending)
    SortAdvancedRulesByFrame(followPending)

    if useFakePriority && priorityPending.Length = 0 && followPending.Length > 0 {
        anchorAt := Ceil(followPending.Length / 2)
        fakeRule := followPending[anchorAt]
        fake := CreateAdvancedFakePriority(fakeRule, totalFrames)
        plan.placementsByIndex[fakeRule.targetIdx] := fake
        plan.placements.Push(fake)
        followPending.RemoveAt(anchorAt)
    }

    frameMap := BuildAdvancedFrameMap(priorityPending, needed, totalFrames)
    loopGuard := 0
    pending := priorityPending
    while pending.Length > 0 && loopGuard < Max(1, pending.Length * 3) {
        loopGuard += 1
        nextPending := []
        progress := false
        for rule in pending {
            if plan.placementsByIndex.Has(rule.targetIdx)
                continue
            placement := CreateAdvancedPlacement(rule, plan, needed, totalFrames, frameMap)
            if !placement {
                nextPending.Push(rule)
                continue
            }
            plan.placementsByIndex[rule.targetIdx] := placement
            plan.placements.Push(placement)
            progress := true
        }
        if !progress
            break
        pending := nextPending
    }

    for rule in followPending {
        if plan.placementsByIndex.Has(rule.targetIdx)
            continue
        placement := CreateAdvancedPlacement(rule, plan, needed, totalFrames, frameMap)
        if !placement
            continue
        plan.placementsByIndex[rule.targetIdx] := placement
        plan.placements.Push(placement)
    }

    plan.finalStops := BuildFinalStops(plan.placementsByIndex)
    return plan
}

SortAdvancedRulesByFrame(rules) {
    sorted := []
    for rule in rules {
        insertAt := sorted.Length + 1
        Loop sorted.Length {
            other := sorted[A_Index]
            if (rule.framePos < other.framePos) || (rule.framePos = other.framePos && rule.targetIdx < other.targetIdx) {
                insertAt := A_Index
                break
            }
        }
        sorted.InsertAt(insertAt, rule)
    }
    if rules.Length > 0
        rules.RemoveAt(1, rules.Length)
    for rule in sorted
        rules.Push(rule)
}

GenerateFishbonePlan(totalInbetweens, followPct, priorityRules, advanced := false, totalFrames := 100, useFakePriority := true) {
    if advanced
        return GenerateAdvancedFishbonePlan(totalInbetweens, priorityRules, totalFrames, useFakePriority)

    plan := {placements: [], finalStops: [], placementsByIndex: Map()}
    needed := totalInbetweens
    if needed <= 0 {
        plan.finalStops := [{label: "A", pos: 0, type: "endpoint"}, {label: "B", pos: 100, type: "endpoint"}]
        return plan
    }

    usedMap := Map()
    priorityPending := []
    followRuleMap := Map()
    hasExplicitPriority := false
    for rule in priorityRules {
        if rule.targetIdx > needed
            continue
        if rule.mode = "priority" {
            priorityPending.Push(rule)
            hasExplicitPriority := true
        } else if rule.mode = "follow"
            followRuleMap[rule.targetIdx] := rule
    }

    if useFakePriority && !hasExplicitPriority && followRuleMap.Count > 0
        SeedAutoPriorityAnchors(plan, followRuleMap, needed, usedMap)

    loopGuard := 0
    while priorityPending.Length > 0 && loopGuard < needed * 4 {
        loopGuard += 1
        resolved := ResolvePriorityPending(plan, priorityPending, usedMap, needed)
        priorityPending := resolved.pending
        followProgress := ResolveFollowRuns(plan, followRuleMap, needed, usedMap, followPct)
        if !resolved.progress && !followProgress
            break
    }

    if followRuleMap.Count > 0
        ResolveFollowRuns(plan, followRuleMap, needed, usedMap, followPct)

    queue := plan.placementsByIndex.Count ? BuildQueueFromStops(BuildFinalStops(plan.placementsByIndex), 2) : [{left: 0, right: 100, depth: 1}]

    Loop needed {
        idx := A_Index
        if plan.placementsByIndex.Has(idx)
            continue
        if followRuleMap.Has(idx)
            continue
        pick := TakeBestSegment(queue)
        queue := pick.queue
        seg := pick.seg
        if !seg
            break
        nextPct := followPct = "AUTO" ? 50 : followPct
        next := TryCreatePlacement(seg.left, seg.right, nextPct, "follow", seg.depth, usedMap)
        if !next
            continue
        next.label := GetPlacementLabel(idx)
        next.leftRef := ""
        next.rightRef := ""
        next.targetIdx := idx
        next.ruleText := ""
        usedMap["" next.pos] := true
        plan.placementsByIndex[idx] := next
        plan.placements.Push(next)
        queue := AddPlacementToQueue(queue, next)
        if priorityPending.Length > 0 || followRuleMap.Count > 0 {
            resolved := ResolvePriorityPending(plan, priorityPending, usedMap, needed)
            priorityPending := resolved.pending
            ResolveFollowRuns(plan, followRuleMap, needed, usedMap, followPct)
            queue := BuildQueueFromStops(BuildFinalStops(plan.placementsByIndex), 2)
        }
    }

    plan.finalStops := BuildFinalStops(plan.placementsByIndex)
    return plan
}

GetCanvasState(g) {
    advanced := g.HasProp("advancedCb") && g.advancedCb.Value
    useFakePriority := g.HasProp("fakePriorityCb") ? g.fakePriorityCb.Value : true
    priorityRules := ParsePriorityRules(g.priorityRules.Value, advanced)
    totalInbetweens := GetRuleCount(priorityRules)
    if totalInbetweens < 1
        totalInbetweens := 6
    fps := 24
    if g.HasProp("advancedFps") {
        fps := Integer(g.advancedFps)
        if fps < 1
            fps := 24
    }
    frames := 100
    if g.HasProp("advancedFrames") {
        frames := Integer(g.advancedFrames)
        if frames < 2
            frames := 100
    }
    if advanced {
        maxRuleFrame := GetMaxRuleFrame(priorityRules)
        if maxRuleFrame > frames
            frames := maxRuleFrame
    }
    followPct := "AUTO"
    if g.HasProp("followPctDdl") {
        followText := StrUpper(Trim(g.followPctDdl.Text))
        if followText != "AUTO" {
            followPct := Integer(followText)
            if !IsAllowed(followPct)
                followPct := "AUTO"
        }
    }

    g.canvas.GetPos(, , &w, &h)
    if w < 100
        w := 620
    if h < 100
        h := 320

    ml := 60, mr := 60, mt := 36, mb := 36
    gw := w - ml - mr
    gh := h - mt - mb

    return {totalInbetweens: totalInbetweens, followPct: followPct, priorityRules: priorityRules, advanced: advanced, useFakePriority: useFakePriority, fps: fps, frames: frames, w: w, h: h, ml: ml, mr: mr, mt: mt, mb: mb, gw: gw, gh: gh}
}

PosToX(s, pos) {
    return Round(s.ml + s.gw * pos / 100)
}

DrawBranch(pGraphics, pPen, baseY, leftX, nodeX, rightX, arcHeight, above := true) {
    dir := above ? -1 : 1
    topY := baseY + dir * arcHeight
    midLeft := Round((leftX + nodeX) / 2)
    midRight := Round((nodeX + rightX) / 2)

    GDI.DrawBezier(pGraphics, pPen, leftX, baseY, leftX, topY, midLeft, topY, nodeX, baseY)
    GDI.DrawBezier(pGraphics, pPen, nodeX, baseY, midRight, topY, rightX, topY, rightX, baseY)
}

RedrawCanvas(g) {
    s := GetCanvasState(g)
    plan := GenerateFishbonePlan(s.totalInbetweens, s.followPct, s.priorityRules, s.advanced, s.frames, s.useFakePriority)
    UpdateAdvancedInfo(g, plan, s)

    hiddenByRule := Map()
    for rule in s.priorityRules
        if rule.HasProp("hide") && rule.hide
            hiddenByRule[rule.targetIdx] := true

    pBitmap := GDI.CreateBitmap(s.w, s.h)
    if !pBitmap {
        UpdateOutput(g, plan, s)
        return
    }
    pGraphics := GDI.GetGraphics(pBitmap)
    if !pGraphics {
        GDI.DisposeImage(pBitmap)
        UpdateOutput(g, plan, s)
        return
    }
    GDI.SetSmoothing(pGraphics, 4)
    GDI.Clear(pGraphics, 0xFF2B2D31)

    baseY := Round(s.mt + s.gh / 2)

    pAxisPen := GDI.CreatePen(0xFFE8E8E8, 2)
    pTickPen := GDI.CreatePen(0xFFBFC5D2, 2)
    pLabelBrush := GDI.CreateBrush(0xFFFFFFFF)
    pMutedBrush := GDI.CreateBrush(0xFF9AA0AA)
    pPriorityBrush := GDI.CreateBrush(0xFFFFC857)
    pFollowBrush := GDI.CreateBrush(0xFF72DDF7)
    pDotBrush := GDI.CreateBrush(0xFFFFFFFF)

    GDI.DrawLine(pGraphics, pAxisPen, s.ml, baseY, s.ml + s.gw, baseY)

    for stop in plan.finalStops {
        x := PosToX(s, stop.pos)
        tickH := (stop.type = "endpoint") ? 22 : 18
        GDI.DrawLine(pGraphics, pTickPen, x, baseY - tickH, x, baseY + tickH)
        GDI.FillEllipse(pGraphics, pDotBrush, x, baseY, 4)

        if stop.type = "endpoint" {
            labelY := baseY - 42
            GDI.DrawString(pGraphics, stop.label, x - 20, labelY, 40, 24, pLabelBrush, 18)
        } else {
            labelBrush := (stop.type = "priority") ? pPriorityBrush : pFollowBrush
            labelY := baseY - 56
            GDI.DrawString(pGraphics, stop.label, x - 20, labelY, 40, 20, labelBrush, 14)
        }
    }

    showPriority := !g.HasProp("showPriority") || g.showPriority
    showFollow := !g.HasProp("showFollow") || g.showFollow
    if showPriority || showFollow {
        pCount := 0, fCount := 0
        for placement in plan.placements {
            if placement.stage = "priority" && !showPriority
                continue
            if placement.stage = "follow" && !showFollow
                continue
            if g.HasProp("hiddenLines") && g.hiddenLines.Has(placement.stage "_" placement.targetIdx)
                continue
            if hiddenByRule.Has(placement.targetIdx)
                continue
            if placement.stage = "priority"
                pCount += 1
            else
                fCount += 1
        }
        pIdx := 0, fIdx := 0, seqIdx := 0
        for placement in plan.placements {
            if placement.stage = "priority" && !showPriority
                continue
            if placement.stage = "follow" && !showFollow
                continue
            if g.HasProp("hiddenLines") && g.hiddenLines.Has(placement.stage "_" placement.targetIdx)
                continue
            if hiddenByRule.Has(placement.targetIdx)
                continue
            seqIdx += 1
            leftX := PosToX(s, placement.left)
            nodeX := PosToX(s, placement.pos)
            rightX := PosToX(s, placement.right)
            if placement.stage = "priority" {
                t := pCount > 1 ? pIdx / (pCount - 1) : 0
                branchPen := GDI.CreatePen(GDI.LerpColor(0xFFFFD700, 0xFFFFB300, t), 2)
                pIdx += 1
            } else {
                t := fCount > 1 ? fIdx / (fCount - 1) : 0
                branchPen := GDI.CreatePen(GDI.LerpColor(0xFF99EEFF, 0xFF7EC8E3, t), 2)
                fIdx += 1
            }
            arcHeight := 10 + placement.depth * 12 + (seqIdx - 1) * 5
            above := placement.stage != "follow"
            DrawBranch(pGraphics, branchPen, baseY, leftX, nodeX, rightX, arcHeight, above)
            GDI.DeletePen(branchPen)
        }
    }

    GDI.DrawString(pGraphics, "A", s.ml - 24, baseY - 4, 20, 20, pLabelBrush, 18)
    GDI.DrawString(pGraphics, "B", s.ml + s.gw + 8, baseY - 4, 20, 20, pLabelBrush, 18)
    if s.advanced {
        duration := Round((s.frames - 1) / s.fps, 2)
        summary := "Advanced: frame-driven | Positions: " plan.placements.Length " | Segments: " Max(0, plan.finalStops.Length - 1) " | Frames: " s.frames " | FPS: " s.fps " | Time: " duration "s"
        GDI.DrawString(pGraphics, summary, s.ml, s.h - 28, s.w - s.ml - s.mr, 16, pMutedBrush, 10)
    } else {
        GDI.DrawString(pGraphics, "Priority", s.ml, s.h - 28, 80, 16, pPriorityBrush, 10)
        GDI.DrawString(pGraphics, "Follow", s.ml + 86, s.h - 28, 70, 16, pFollowBrush, 10)
        GDI.DrawString(pGraphics, "Allowed: " _ALLOWED_HINT, s.ml + 170, s.h - 28, 320, 16, pMutedBrush, 10)
    }

    hBitmap := GDI.GetHBITMAP(pBitmap)
    if hBitmap
        g.canvas.Value := "HBITMAP:" hBitmap

    GDI.DeletePen(pAxisPen)
    GDI.DeletePen(pTickPen)
    GDI.DeleteBrush(pLabelBrush)
    GDI.DeleteBrush(pMutedBrush)
    GDI.DeleteBrush(pPriorityBrush)
    GDI.DeleteBrush(pFollowBrush)
    GDI.DeleteBrush(pDotBrush)
    GDI.DeleteGraphics(pGraphics)
    GDI.DisposeImage(pBitmap)

    UpdateOutput(g, plan, s)
}

UpdateAdvancedInfo(g, plan, s) {
    if !g.HasProp("advancedInfo")
        return
    if !s.advanced {
        g.advancedInfo.Text := ""
        return
    }
    duration := Round((s.frames - 1) / s.fps, 2)
    g.advancedInfo.Text := "Positions: " plan.placements.Length "  |  Segments: " Max(0, plan.finalStops.Length - 1) "  |  Frames: " s.frames "  |  FPS: " s.fps "  |  Timing: " duration "s"
}

OnCanvasClick(g) {
    MouseGetPos(&clickX, &clickY, , , 2)
    s := GetCanvasState(g)
    plan := GenerateFishbonePlan(s.totalInbetweens, s.followPct, s.priorityRules, s.advanced, s.frames, s.useFakePriority)
    baseY := Round(s.mt + s.gh / 2)

    g.canvas.GetPos(&cX, &cY, &cW, &cH)
    relX := clickX - cX
    relY := clickY - cY

    if Abs(relY - baseY) > 70
        return

    for placement in plan.placements {
        if Abs(relX - PosToX(s, placement.pos)) <= 10 {
            key := placement.stage "_" placement.targetIdx
            if g.hiddenLines.Has(key)
                g.hiddenLines.Delete(key)
            else
                g.hiddenLines[key] := true
            RedrawCanvas(g)
            return
        }
    }

    clickPos := Round((relX - s.ml) / s.gw * 100)
    if clickPos < 0 || clickPos > 100
        return

    dlg := Gui("+AlwaysOnTop +ToolWindow", "Insert Inbetween")
    dlg.BackColor := "25282E"
    dlg.SetFont("s9", "Segoe UI")
    dlg.MarginX := 12
    dlg.MarginY := 10
    dlg.AddText("xm cFFFFFF", "Insert inbetween at " clickPos "%")
    dlg.AddText("xm y+6 c909090", "Inbetween number (N):")
    nEd := dlg.AddEdit("xm w60 h24 Center Number", "1")
    dlg.AddUpDown("Range1-99", 1)
    dlg.AddText("xm y+4 c909090", "Position (%):")
    pEd := dlg.AddEdit("xm w60 h24 Center Number", clickPos)
    dlg.AddUpDown("Range1-99", clickPos)
    dlg.AddButton("xm y+8 w70 Default", "Insert").OnEvent("Click", (*) => (
        InsertRuleAt(g, nEd.Value, pEd.Value),
        dlg.Destroy()
    ))
    dlg.AddButton("x+8 w60", "Cancel").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize Center")
}

InsertRuleAt(g, n, pos) {
    existing := Trim(g.priorityRules.Value)
    newRule := n "_A>B=" pos
    if existing = ""
        g.priorityRules.Value := newRule
    else
        g.priorityRules.Value := existing ", " newRule
    RedrawCanvas(g)
}

RepeatText(text, count) {
    out := ""
    Loop count
        out .= text
    return out
}

PadLeft(text, width) {
    text := "" text
    while StrLen(text) < width
        text := " " text
    return text
}

StripAdvancedFrameCages(text) {
    return RegExReplace(text, "(\d+)\s*[\[\{\(]\s*\d+\s*[\]\}\)]", "$1")
}

InsertAdvancedFrameCage(ruleText, frameNum) {
    clean := StripAdvancedFrameCages(ruleText)
    return RegExReplace(clean, "^\s*(\d+)", "$1[" frameNum "]", , 1)
}

BuildAdvancedRuleTextFromNormal(g) {
    normalText := StripAdvancedFrameCages(g.priorityRules.Value)
    rules := ParsePriorityRules(normalText, false)
    needed := GetRuleCount(rules)
    if needed < 1
        needed := 6
    frames := g.HasProp("advancedFrames") ? Integer(g.advancedFrames) : 100
    if frames < 2
        frames := 100
    followPct := "AUTO"
    if g.HasProp("followPctDdl") {
        followText := StrUpper(Trim(g.followPctDdl.Text))
        if followText != "AUTO" {
            followPct := Integer(followText)
            if !IsAllowed(followPct)
                followPct := "AUTO"
        }
    }
    useFakePriority := g.HasProp("fakePriorityCb") ? g.fakePriorityCb.Value : true
    plan := GenerateFishbonePlan(needed, followPct, rules, false, frames, useFakePriority)
    converted := ""
    for rule in rules {
        frameNum := 1
        if plan.placementsByIndex.Has(rule.targetIdx)
            frameNum := PosToFrame(plan.placementsByIndex[rule.targetIdx].pos, frames)
        else
            frameNum := PosToFrame(100 * rule.targetIdx / (needed + 1), frames)
        converted .= (converted = "" ? "" : ", ") InsertAdvancedFrameCage(rule.raw, frameNum)
    }
    return converted
}

ConvertRulesMode(g) {
    if g.HasProp("advancedCb") && g.advancedCb.Value {
        g.priorityRules.Value := StripAdvancedFrameCages(g.priorityRules.Value)
        g.advancedCb.Value := false
    } else {
        g.priorityRules.Value := BuildAdvancedRuleTextFromNormal(g)
        g.advancedCb.Value := true
    }
    ToggleAdvanced(g)
}

BuildAdvancedTimesheetOutput(plan, s) {
    byFrame := Map()
    for placement in plan.placements {
        if !placement.HasProp("framePos")
            continue
        cell := placement.targetIdx " [" placement.pct "]"
        if byFrame.Has(placement.framePos)
            byFrame[placement.framePos] .= ", " cell
        else
            byFrame[placement.framePos] := cell
    }

    text := "Frame = " s.frames "`r`n"
    text .= "Rule = " GetRuleTextForOutput(s) "`r`n`r`n"
    frameWidth := Max(2, StrLen("" s.frames))
    text .= " " PadLeft("Fr", frameWidth) " |    IB`r`n"
    text .= RepeatText("-", frameWidth + 2) "+----------------`r`n"
    Loop s.frames {
        frame := A_Index
        if frame = 1
            cell := "A"
        else if frame = s.frames
            cell := "B"
        else if byFrame.Has(frame)
            cell := byFrame[frame]
        else
            cell := Chr(0x2502)
        text .= " " PadLeft(frame, frameWidth) " |     " cell "`r`n"
    }
    return text
}

GetRuleTextForOutput(s) {
    rulesText := ""
    for rule in s.priorityRules {
        rulesText .= (rulesText = "" ? "" : ", ") rule.raw
    }
    return rulesText
}

UpdateOutput(g, plan, s) {
    text := "Fishbone Order`r`n"
    text .= "Inbetweens: " s.totalInbetweens "`r`n"
    text .= "Auto Follow: " (s.followPct = "AUTO" ? "Auto" : s.followPct) "`r`n"
    if s.advanced
        text .= "Advanced Frames: On | FPS: " s.fps " | Frames: " s.frames "`r`n"
    text .= "Rules: " s.priorityRules.Length "`r`n`r`n"

    text .= "Generation Steps`r`n"
    if plan.placements.Length = 0 {
        text .= "A -> B only`r`n`r`n"
    } else {
        for i, placement in plan.placements {
            role := placement.stage = "priority" ? "priority" : "follow"
            span := (placement.leftRef != "" && placement.rightRef != "") ? placement.leftRef " > " placement.rightRef : placement.left " > " placement.right
            ruleText := placement.ruleText != "" ? " [" placement.ruleText "]" : ""
            frameText := s.advanced && placement.HasProp("framePos") ? " | frame " placement.framePos : ""
            actualText := s.advanced && placement.HasProp("actualPct") ? " actual " placement.actualPct "%" : ""
            requestedText := s.advanced && placement.HasProp("requestedPct") ? " forced " placement.requestedPct "%" : ""
            text .= Format("{:02d}. {} {} on {} -> {}%{}{} (pos {}){}{}", i, placement.label, role, span, placement.pct, actualText, requestedText, placement.pos, frameText, ruleText) "`r`n"
        }
        text .= "`r`n"
    }

    text .= "Final Order`r`n"
    for i, stop in plan.finalStops {
        if stop.type = "endpoint"
            text .= stop.label
        else
            text .= stop.label "%"
        if i < plan.finalStops.Length
            text .= " -> "
    }
    if s.advanced {
        text .= "`r`n`r`n"
        text .= BuildAdvancedTimesheetOutput(plan, s)
    }

    g.lastOutputText := text
}

SaveTextBlockAsTXT(text, defaultName := "fishbone-output.txt", title := "Save as TXT") {
    if Trim(text) = "" {
        MsgBox("There is no text to save yet.", "Save TXT", "Icon!")
        return
    }
    file := FileSelect("S16", defaultName, title, "Text (*.txt)")
    if file = ""
        return
    if !RegExMatch(file, "i)\.txt$")
        file .= ".txt"
    try FileDelete(file)
    FileAppend(text, file, "UTF-8")
    TrayTip("Fishbone", "TXT saved to " file)
}

SaveTextBlockAsPNG(text, defaultName := "fishbone-output.png", title := "Save as PNG") {
    if Trim(text) = "" {
        MsgBox("There is no text to save yet.", "Save PNG", "Icon!")
        return
    }
    file := FileSelect("S16", defaultName, title, "PNG (*.png)")
    if file = ""
        return
    if !RegExMatch(file, "i)\.png$")
        file .= ".png"

    normalized := StrReplace(text, "`r`n", "`n")
    normalized := StrReplace(normalized, "`r", "`n")
    lines := StrSplit(normalized, "`n")
    maxChars := 1
    for line in lines
        maxChars := Max(maxChars, StrLen(line))

    fontSize := 11
    charW := 8
    lineH := 18
    pad := 24
    imgW := Max(720, Min(3200, pad * 2 + maxChars * charW))
    imgH := Max(240, pad * 2 + lines.Length * lineH)

    pBitmap := GDI.CreateBitmap(imgW, imgH)
    if !pBitmap {
        MsgBox("Could not create PNG canvas.", "Save PNG", "Iconx")
        return
    }
    pGraphics := GDI.GetGraphics(pBitmap)
    if !pGraphics {
        GDI.DisposeImage(pBitmap)
        MsgBox("Could not create PNG renderer.", "Save PNG", "Iconx")
        return
    }

    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", pGraphics, "Int", 5)
    GDI.Clear(pGraphics, 0xFFFFFFFF)
    pBrush := GDI.CreateBrush(0xFF000000)
    y := pad
    for line in lines {
        GDI.DrawStringLeft(pGraphics, line, pad, y, imgW - pad * 2, lineH + 4, pBrush, fontSize)
        y += lineH
    }
    GDI.DeleteBrush(pBrush)

    clsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
    status := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Str", file, "Ptr", clsid, "Ptr", 0)

    GDI.DeleteGraphics(pGraphics)
    GDI.DisposeImage(pBitmap)

    if status != 0
        MsgBox("Could not save PNG.`nStatus: " status, "Save PNG", "Iconx")
    else
        TrayTip("Fishbone", "PNG saved to " file)
}

ShowAdvancedTimesheet(mainGui) {
    static sheetGui := 0
    s := GetCanvasState(mainGui)
    plan := GenerateFishbonePlan(s.totalInbetweens, s.followPct, s.priorityRules, s.advanced, s.frames, s.useFakePriority)
    text := s.advanced ? BuildAdvancedTimesheetOutput(plan, s) : "Advanced mode is not active."

    if IsObject(sheetGui) {
        try {
            sheetGui.outputEdit.Value := text
            sheetGui.Show()
            WinActivate(sheetGui.Hwnd)
        }
        return
    }

    sheetGui := Gui("+Owner" mainGui.Hwnd, "Timesheet")
    sheetGui.BackColor := "25282E"
    sheetGui.SetFont("s10", "Segoe UI")
    sheetGui.MarginX := 14
    sheetGui.MarginY := 14
    sheetGui.AddText("x14 y12 cFFFFFF", "Timesheet")
    sheetGui.SetFont("s10", "Consolas")
    sheetGui.outputEdit := sheetGui.AddEdit("x14 y36 w560 h420 ReadOnly Multi BackgroundFFFFFF c000000", text)
    sheetGui.SetFont("s10", "Segoe UI")
    
    sheetGui.btnCopy := sheetGui.AddButton(
        "x14 y468 w80 h28",
        "📋 Copy"
    )

    sheetGui.btnCopy.OnEvent("Click", (*) => (
        A_Clipboard := sheetGui.outputEdit.Value,
        TrayTip("Timeline", "Copied to clipboard")
    ))

    sheetGui.btnSaveTxt := sheetGui.AddButton("x104 y468 w90 h28", "Save TXT")
    sheetGui.btnSaveTxt.OnEvent("Click", (*) => SaveTextBlockAsTXT(sheetGui.outputEdit.Value, "timesheet.txt", "Save Timesheet as TXT"))

    sheetGui.btnSavePng := sheetGui.AddButton("x204 y468 w90 h28", "Save PNG")
    sheetGui.btnSavePng.OnEvent("Click", (*) => SaveTextBlockAsPNG(sheetGui.outputEdit.Value, "timesheet.png", "Save Timesheet as PNG"))

    sheetGui.btnClose := sheetGui.AddButton("x304 y468 w80 h28","Close")
    sheetGui.btnClose.OnEvent("Click", (*) => sheetGui.Hide())
    sheetGui.OnEvent("Close", (*) => (sheetGui.Hide(), true))
    sheetGui.Show("w590 h510 Center")
    sheetGui.btnCopy.Focus()
}

OpenOutputGui(mainGui) {
    static outputGui := 0

    if IsObject(outputGui) {
        try {
            outputGui.outputEdit.Value := mainGui.HasProp("lastOutputText") ? mainGui.lastOutputText : ""
            outputGui.Show()
            WinActivate(outputGui.Hwnd)
        }
        return
    }

    outputGui := Gui("+Owner" mainGui.Hwnd, "Generated Output")
    outputGui.BackColor := "25282E"
    outputGui.SetFont("s10", "Segoe UI")
    outputGui.MarginX := 14
    outputGui.MarginY := 14

    outputGui.AddText("x14 y12 cFFFFFF", "Generated Output")

    outputGui.outputEdit := outputGui.AddEdit(
        "x14 y36 w560 h300 ReadOnly Multi BackgroundFFFFFF c000000",
        mainGui.HasProp("lastOutputText") ? mainGui.lastOutputText : ""
    )

    outputGui.btnCopy := outputGui.AddButton(
        "x14 y348 w100 h30",
        "📋Copy"
    )

    outputGui.btnCopy.OnEvent("Click", (*) => (
        A_Clipboard := outputGui.outputEdit.Value,
        TrayTip("Timeline", "Copied to clipboard")
    ))

    outputGui.btnSaveTxt := outputGui.AddButton("x124 y348 w90 h30", "Save TXT")
    outputGui.btnSaveTxt.OnEvent("Click", (*) => SaveTextBlockAsTXT(outputGui.outputEdit.Value, "fishbone-output.txt", "Save Output as TXT"))

    outputGui.btnSavePng := outputGui.AddButton("x224 y348 w90 h30", "Save PNG")
    outputGui.btnSavePng.OnEvent("Click", (*) => SaveTextBlockAsPNG(outputGui.outputEdit.Value, "fishbone-output.png", "Save Output as PNG"))

    outputGui.btnClose := outputGui.AddButton("x324 y348 w90 h30","Close")
    outputGui.btnClose.OnEvent("Click", (*) => outputGui.Hide())
    outputGui.OnEvent("Close", (*) => (outputGui.Hide(), true))

    outputGui.OnEvent("Close", (*) => outputGui := 0)

    outputGui.Show("w590 h410 Center")
    outputGui.btnCopy.Focus()

}

ShowGuide() {
    guideHwnd := WinExist("Fishbone Guide")

    if guideHwnd {
        guideGui := GuiFromHwnd(guideHwnd)
        guideGui.Show("Center")
        return
    }

    guideGui := Gui("+AlwaysOnTop +ToolWindow", "Fishbone Guide")
    guideGui.BackColor := "ffffff"

    guideGui.SetFont("s9", "Segoe UI")
    guideGui.MarginX := 12
    guideGui.MarginY := 10

    ; =====================================================
    ; HEADER
    ; =====================================================

    guideGui.SetFont("s12", "Segoe UI Semibold")

    guideGui.AddText(
        "xm c202020",
        "Nastarxa Fishbone Inbetween Generator Guide"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm y+4 c505050",
        "Create inbetween positions for animation using priority rules and follow chains."
    )

    guideGui.AddText(
        "xm y+2 c6A6A6A",
        "Rules are comma-separated (newlines also supported). Each controls one inbetween."
    )

    ; =====================================================
    ; TAB
    ; =====================================================

    tab := guideGui.AddTab3(
        "xm y+10 w570 h550 BackgroundFFFFFF c202020",
        ["How to Use", "Rule Format", "Advanced", "Tips"]
    )

    ; =====================================================
    ; TAB 1 â€” How to Use
    ; =====================================================

    tab.UseTab("How to Use")

    guideGui.SetFont("s10", "Segoe UI Semibold")

    guideGui.AddText(
        "xm+6 y+12 c1B6FA8",
        "What is Nastarxa Fishbone?"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "Nastarxa Fishbone generates inbetween positions for animation frames. Each inbetween is a"
        " numbered layer between two endpoints (A and B). Two modes control placement:"
    )

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "Priority: inbetween placed at a fixed percentage between its neighbors."
        " E.g. 3_A>B=50 means inbetween 3 sits at 50% (exactly halfway)"
        " between endpoints A and B. Higher priority inbetweens serve"
        " as anchors that lower-numbered Follow inbetweens distribute around."
    )

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "Follow: inbetween is auto-distributed evenly between its neighbors."
        " E.g. 1_f automatically places inbetween 1 at a calculated position."
        " If multiple Follow inbetweens sit in the same gap, they are spaced"
        " evenly. This lets you create smooth transitions without manual math."
    )

    guideGui.AddText(
        "xm+6 y+6 w540 c606060",
        "Normal mode is value-driven: the inbetween number and rule choose a position."
        " Advanced mode is frame-driven: the frame position chooses the placement,"
        " and Auto calculates the closest useful inbetween value from that position."
    )

    guideGui.SetFont("s10", "Segoe UI Semibold")

    guideGui.AddText(
        "xm+6 y+16 c1B6FA8",
        "Quick Start"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "1. Write rules in the editor — e.g. 3_A>B=50, 1_f, 2_f"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c404040",
        "2. Click Preview (▶) to see movement playback"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c404040",
        "3. Save PNG or SVG to export the timeline"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c404040",
        "4. Use Save Example to reuse rule sets across scenes"
    )

    guideGui.SetFont("s10", "Segoe UI Semibold")

    guideGui.AddText(
        "xm+6 y+16 c1B6FA8",
        "Saving and Applying Examples"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "Click the Examples button to open the dialog. Save named rule sets"
        " with optional notes, load them back, delete old ones, and reorder"
        " with the up/down arrows."
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Tip: The Save Example button next to Save PNG/SVG saves the current"
        " rules directly without opening the Examples dialog."
    )

    ; =====================================================
    ; TAB 2 â€” Rule Format
    ; =====================================================

    tab.UseTab("Rule Format")

    guideGui.SetFont("s10", "Segoe UI Semibold")

    guideGui.AddText(
        "xm+6 y+12 c1B6FA8",
        "Syntax"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "Priority:  <N>_<A/B/IN>><A/B/IN>=<PCT>"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "N = inbetween number | A/B = endpoints | I1/I2 = other inbetweens"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c404040",
        "PCT = 25, 33, 40, 50, 60, 66, 75 or Auto"
    )

    guideGui.AddText(
        "xm+6 y+10 w540 c404040",
        "Follow:  <N>_f"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Automatically placed between neighbors. No percentage needed."
    )

    guideGui.SetFont("s10", "Segoe UI Semibold")

    guideGui.AddText(
        "xm+6 y+16 c1B6FA8",
        "Priority Examples"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "3_A>B=50  â€” Inbetween 3 at 50% between A and B"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c404040",
        "2_1>3=25  â€” Inbetween 2 at 25% between I1 and I3"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c404040",
        "3_A>B=Auto  â€” Automatically calculated percentage"
    )

    guideGui.SetFont("s10", "Segoe UI Semibold")

    guideGui.AddText(
        "xm+6 y+16 c1B6FA8",
        "Follow Examples"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "1_f  â€” Automatically placed between neighbors"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c404040",
        "2_f=Auto  â€” Same behavior as 2_f"
    )

    guideGui.SetFont("s10", "Segoe UI Semibold")

    guideGui.AddText(
        "xm+6 y+16 c1B6FA8",
        "Hide Rule"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "4_f=Auto-Hide  â€” Hide follow line at frame 4"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c404040",
        "2_A>B=Auto-Hide  â€” Hide priority line at frame 2"
    )

    guideGui.SetFont("s10", "Segoe UI Semibold")

    guideGui.AddText(
        "xm+6 y+16 c1B6FA8",
        "Allowed Percentages"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "Allowed values: 25, 33, 40, 50, 60, 66, 75"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Rules use commas. Newlines are also supported as separators."
    )

    ; =====================================================
    ; TAB 3 â€” Tips
    ; =====================================================

    tab.UseTab("Advanced")

    guideGui.SetFont("s10", "Segoe UI Semibold")

    guideGui.AddText(
        "xm+6 y+12 c1B6FA8",
        "What Advanced Mode Adds"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "Advanced mode reverses the normal solver. Instead of auto-placing"
        " inbetweens from their numbers, you place an inbetween on a preview"
        " frame and the app calculates the closest useful percentage/value."
    )

    guideGui.AddText(
        "xm+6 y+8 w540 c404040",
        "The bracket frame is the source of truth. Follow% is disabled in Advanced"
        " mode because follow bias would be a second placement system. FPS and"
        " Frames are edited below the diagram and applied with the Apply button."
        " The bottom info line shows position count, segment count, frames, FPS,"
        " and total timing."
    )

    guideGui.SetFont("s10", "Segoe UI Semibold")

    guideGui.AddText(
        "xm+6 y+16 c1B6FA8",
        "Advanced Syntax"
    )

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "1[10]_f"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Inbetween 1 is placed at preview frame 10. The displayed percent is calculated from that frame."
    )

    guideGui.AddText(
        "xm+6 y+4 w540 c606060",
        "Frame cages can use [10], {10}, or (10). They all mean the same thing."
    )

    guideGui.AddText(
        "xm+6 y+8 w540 c404040",
        "4[25]_A>B=Auto"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Inbetween 4 is placed at frame 25 between A and B. Auto can calculate the best percentage from that position."
    )

    guideGui.AddText(
        "xm+6 y+8 w540 c404040",
        "2[50]_A>B=40"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Inbetween 2 is placed at frame 50, but its displayed inbetween value is forced to 40."
    )

    guideGui.AddText(
        "xm+6 y+8 w540 c404040",
        "3[700]_f-Hide"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Inbetween 3 uses Follow spacing, appears on preview frame 700, and hides its line."
    )

    guideGui.AddText(
        "xm+6 y+12 w540 c606060",
        "Frame numbers are 1-based, like an exposure sheet. If a rule uses a frame"
        " beyond the Frames input, the app expands the preview length automatically."
    )

    guideGui.AddText(
        "xm+6 y+8 w540 c606060",
        "The Timesheet button appears in Advanced mode and opens only the frame-by-frame sheet."
        " The same sheet is also included in Output. Both windows can save TXT or PNG."
    )

    guideGui.AddText(
        "xm+6 y+8 w540 c606060",
        "Use To Advanced / To Normal below the diagram to convert rule text between value-driven and frame-driven modes."
    )

    tab.UseTab("Tips")

    guideGui.SetFont("s9", "Segoe UI")

    guideGui.AddText(
        "xm+6 y+6 w540 c404040",
        "1. Use Follow (N_f) for even spacing"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Most inbetweens should just follow. The tool distributes them automatically."
    )

    guideGui.AddText(
        "xm+6 y+10 w540 c404040",
        "2. Use Priority (N_A>B=PCT) for key frames"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Only lock positions that matter: slow-ins, holds, impact frames."
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Let Follow fill the rest."
    )

    guideGui.AddText(
        "xm+6 y+10 w540 c404040",
        "3. Chain references for layered control"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Ex: 3_A>I2=50 places I3 between A and I2."
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Great for secondary motion layers."
    )

    guideGui.AddText(
        "xm+6 y+10 w540 c404040",
        "4. Hide (-Hide) to skip lines"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Clean up the preview by hiding inbetweens that are already well-placed."
    )

    guideGui.AddText(
        "xm+6 y+10 w540 c404040",
        "5. Use Preview (▶) to test timing"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Speed slider controls playback rate. Toggle Curve for linear vs arc motion."
    )

    guideGui.AddText(
        "xm+6 y+10 w540 c404040",
        "6. Save your setups as examples"
    )

    guideGui.AddText(
        "xm+6 y+2 w540 c606060",
        "Reuse common patterns across scenes."
    )

    ; =====================================================
    ; Bottom buttons (outside tabs)
    ; =====================================================

    tab.UseTab(0)

    btnClose := guideGui.AddButton(
        "x12 y640 w80 h28",
        "Close"
    )

    btnClose.OnEvent("Click", (*) => guideGui.Destroy())

    guideGui.Show("w600 h680 Center")
}

ApplyExampleToTimeline(mainGui, rulesText, advanced, fps, frames) {
    mainGui.priorityRules.Value := rulesText
    if mainGui.HasProp("advancedCb")
        mainGui.advancedCb.Value := advanced
    fps := Integer(fps)
    frames := Integer(frames)
    if fps < 1
        fps := 24
    if frames < 2
        frames := 100
    if mainGui.HasProp("advFpsEdit")
        mainGui.advFpsEdit.Value := fps
    if mainGui.HasProp("advFramesEdit")
        mainGui.advFramesEdit.Value := frames
    mainGui.advancedFps := fps
    mainGui.advancedFrames := frames
    ToggleAdvanced(mainGui)
}

LoadExampleIntoEditor(eg) {
    if eg.list.Text = ""
        return
    meta := LoadExampleMeta(eg.list.Text)
    eg.nameEdit.Value := eg.list.Text
    eg.rulesEdit.Value := LoadExample(eg.list.Text)
    eg.notesEdit.Value := LoadExampleNotes(eg.list.Text)
    eg.advancedCb.Value := meta.advanced
    eg.fpsEdit.Value := meta.fps
    eg.framesEdit.Value := meta.frames
    eg.status.Text := "Loaded: " eg.list.Text
    DrawExamplePreview(eg.preview, eg.rulesEdit.Value, meta.advanced, meta.frames)
    UpdateExamplePreviewInfo(eg)
}

UpdateExamplePreviewInfo(eg) {
    if !eg.HasProp("previewInfo")
        return
    fps := Integer(eg.fpsEdit.Value)
    frames := Integer(eg.framesEdit.Value)
    if fps < 1
        fps := 24
    if frames < 2
        frames := 100
    mode := eg.advancedCb.Value ? "Advanced" : "Normal"
    eg.previewInfo.Text := mode " | FPS: " fps " | Frames: " frames
}

SaveExampleFromEditor(eg) {
    if !SaveExample(eg.nameEdit.Value, eg.rulesEdit.Value, eg.notesEdit.Value, eg.advancedCb.Value, eg.fpsEdit.Value, eg.framesEdit.Value)
        return
    eg.list.Delete()
    eg.list.Add(GetExampleNames())
    eg.status.Text := "Saved: " eg.nameEdit.Value
    DrawExamplePreview(eg.preview, eg.rulesEdit.Value, eg.advancedCb.Value, eg.framesEdit.Value)
    UpdateExamplePreviewInfo(eg)
}

ApplyExampleFromEditor(mainGui, eg) {
    ApplyExampleToTimeline(mainGui, eg.rulesEdit.Value, eg.advancedCb.Value, eg.fpsEdit.Value, eg.framesEdit.Value)
    eg.status.Text := "Applied to timeline"
}

OpenExamplesGui(mainGui) {

    eg := Gui("+Owner" mainGui.Hwnd, "Examples")
    eg.BackColor := "25282E"

    eg.SetFont("s10", "Segoe UI")
    eg.MarginX := 14
    eg.MarginY := 14

    eg.AddText("x14 y12 cFFFFFF", "Saved Examples")

    eg.list := eg.AddListBox(
        "x14 y36 w220 h240 BackgroundFFFFFF c000000"
    )

    eg.btnLoad := eg.AddButton(
        "x14 y286 w68 h30",
        "✅ Apply"
    )

    eg.btnSave := eg.AddButton(
        "x90 yp w68 h30",
        "💾 Save"
    )

    eg.btnDelete := eg.AddButton(
        "x166 yp w68 h30",
        "🗑️ Delete"
    )

    eg.btnUp := eg.AddButton(
        "x14 y326 w48 h24",
        "▲"
    )

    eg.btnDown := eg.AddButton(
        "x66 yp w48 h24",
        "▼"
    )

    eg.preview := eg.AddPicture(
        "x14 y358 w220 h120 Background1E2127"
    )
    eg.previewInfo := eg.AddText("x14 y484 w220 c909090", "")

    rightX := 250

    eg.AddText("x" rightX " y12 cFFFFFF", "Example Name")

    eg.nameEdit := eg.AddEdit(
        "x" rightX " y36 w320 h28 BackgroundFFFFFF c000000",
        ""
    )

    eg.AddText("x" rightX " y74 cFFFFFF", "Rules")

    eg.rulesEdit := eg.AddEdit(
        "x" rightX " y98 w320 h260 Multi WantTab BackgroundFFFFFF c000000",
        mainGui.priorityRules.Value
    )

    eg.advancedCb := eg.AddCheckbox("x" rightX " y366 cFFFFFF Background25282E", "Advanced")
    eg.advancedCb.Value := mainGui.HasProp("advancedCb") && mainGui.advancedCb.Value
    eg.AddText("x+14 yp+3 cFFFFFF", "FPS:")
    eg.fpsEdit := eg.AddEdit("x+4 yp-3 w48 h22 Center Number BackgroundFFFFFF c000000", mainGui.HasProp("advancedFps") ? mainGui.advancedFps : 24)
    eg.AddText("x+12 yp+3 cFFFFFF", "Frames:")
    eg.framesEdit := eg.AddEdit("x+4 yp-3 w64 h22 Center Number BackgroundFFFFFF c000000", mainGui.HasProp("advancedFrames") ? mainGui.advancedFrames : 100)

    eg.AddText("x" rightX " y396 cFFFFFF", "Notes")

    eg.notesEdit := eg.AddEdit(
        "x" rightX " y420 w320 h84 Multi BackgroundFFFFFF c000000",
        ""
    )

    eg.status := eg.AddText(
        "x" rightX " y514 w320 c909090",
        ""
    )


    ; Metadata pass keeps examples compatible with both normal and Advanced mode.
    eg.list.OnEvent("Change", (*) => LoadExampleIntoEditor(eg))
    eg.btnLoad.OnEvent("Click", (*) => ApplyExampleFromEditor(mainGui, eg))
    eg.btnSave.OnEvent("Click", (*) => SaveExampleFromEditor(eg))
    eg.advancedCb.OnEvent("Click", (*) => (
        DrawExamplePreview(eg.preview, eg.rulesEdit.Value, eg.advancedCb.Value, eg.framesEdit.Value),
        UpdateExamplePreviewInfo(eg)
    ))
    eg.fpsEdit.OnEvent("Change", (*) => UpdateExamplePreviewInfo(eg))
    eg.framesEdit.OnEvent("Change", (*) => (
        DrawExamplePreview(eg.preview, eg.rulesEdit.Value, eg.advancedCb.Value, eg.framesEdit.Value),
        UpdateExamplePreviewInfo(eg)
    ))
    eg.rulesEdit.OnEvent("Change", (*) => DrawExamplePreview(eg.preview, eg.rulesEdit.Value, eg.advancedCb.Value, eg.framesEdit.Value))

    eg.btnDelete.OnEvent("Click", (*) => (
        DeleteExample(eg.nameEdit.Value),
        eg.list.Delete(),
        eg.list.Add(GetExampleNames()),
        eg.status.Text := "🗑️ Deleted: " eg.nameEdit.Value,
        eg.nameEdit.Value := "",
        eg.rulesEdit.Value := "",
        eg.notesEdit.Value := "",
        DrawExamplePreview(eg.preview, "")
    ))

    eg.btnUp.OnEvent("Click", (*) => (
        sel := eg.list.Value,
        sel := sel > 1 ? sel - 1 : 1,
        MoveExample(eg.list, -1),
        eg.list.Delete(),
        eg.list.Add(GetExampleNames()),
        eg.list.Value := sel,
        eg.status.Text := "▲ Moved up"
    ))

    eg.btnDown.OnEvent("Click", (*) => (
        sel := eg.list.Value,
        names := GetExampleNames(),
        sel := sel < names.Length ? sel + 1 : names.Length,
        MoveExample(eg.list, 1),
        eg.list.Delete(),
        eg.list.Add(GetExampleNames()),
        eg.list.Value := sel,
        eg.status.Text := "▼ Moved down"
    ))

    eg.list.Add(GetExampleNames())
    DrawExamplePreview(eg.preview, eg.rulesEdit.Value, eg.advancedCb.Value, eg.framesEdit.Value)
    UpdateExamplePreviewInfo(eg)

    eg.Show("w590 h560 Center")
}

; ─── Preview System ──────────────────────────────────────────────

PosToFrame(pos, totalFrames) {
    if totalFrames < 2
        totalFrames := 2
    return Min(totalFrames, Max(1, Round((totalFrames - 1) * pos / 100) + 1))
}

FrameToPos(frameNum, totalFrames) {
    if totalFrames < 2
        totalFrames := 2
    frameNum := Min(totalFrames, Max(1, frameNum))
    return Round(100 * (frameNum - 1) / (totalFrames - 1))
}

SortPreviewFrames(frames) {
    sorted := []
    for frame in frames {
        insertAt := sorted.Length + 1
        Loop sorted.Length {
            cmp := sorted[A_Index]
            if (frame.frameNum < cmp.frameNum) || (frame.frameNum = cmp.frameNum && frame.pos < cmp.pos) {
                insertAt := A_Index
                break
            }
        }
        sorted.InsertAt(insertAt, frame)
    }
    return sorted
}

BuildPreviewFrames(plan, s) {
    if !s.advanced {
        frames := []
        for stop in plan.finalStops
            frames.Push({label: stop.label, pos: stop.pos, frameNum: PosToFrame(stop.pos, 100)})
        return frames
    }

    totalFrames := Max(2, s.frames)
    frames := [{label: "A", pos: 0, frameNum: 1}]
    for placement in plan.placements {
        frameNum := placement.HasProp("framePos") ? placement.framePos : PosToFrame(placement.pos, totalFrames)
        frameNum := Min(totalFrames, Max(1, frameNum))
        frames.Push({label: placement.label, pos: FrameToPos(frameNum, totalFrames), frameNum: frameNum, sourcePos: placement.pos})
    }
    frames.Push({label: "B", pos: 100, frameNum: totalFrames})
    return SortPreviewFrames(frames)
}

ShowPreview(g) {
    static previewGui := 0

    if IsObject(previewGui) {
        try previewGui.Show()
        WinActivate(previewGui.Hwnd)
        UpdatePreviewFrames(previewGui, g)
        return
    }

    previewGui := Gui("+Owner" g.Hwnd, "Preview - Movement Test")
    previewGui.BackColor := "25282E"
    previewGui.SetFont("s10", "Segoe UI")
    previewGui.MarginX := 14
    previewGui.MarginY := 14

    previewGui.SetFont("s12", "Segoe UI")
    previewGui.titleText := previewGui.AddText("x18 y14 cFFFFFF", "Movement Preview")
    previewGui.SetFont("s10", "Segoe UI")

    previewGui.canvas := previewGui.AddPicture("x18 y48 w844 h320 Background1E2127")

    cY := 382

    previewGui.fpsText := previewGui.AddText("x18 y" cY " c909090", "FPS:")
    previewGui.fpsEdit := previewGui.AddEdit("x+4 yp-3 w50 h24 Center BackgroundFFFFFF c000000 Number", "24")

    previewGui.framesText := previewGui.AddText("x+14 y" cY " c909090", "Frames:")
    previewGui.framesEdit := previewGui.AddEdit("x+4 yp-3 w60 h24 Center BackgroundFFFFFF c000000 Number", "100")

    previewGui.curveCb := previewGui.AddCheckbox("x+14 y" (cY - 2) " cB0BEC5 Background25282E Checked", "Curve")
    previewGui.curveCb.OnEvent("Click", (*) => (previewGui._useCurve := previewGui.curveCb.Value, DrawPreview(previewGui, g)))

    row2Y := cY + 34

    previewGui.btnStart := previewGui.AddButton("x18 y" (row2Y - 1) " w34 h26", "|<")
    previewGui.btnPrevFrame := previewGui.AddButton("x+4 yp w38 h26", "<<")
    previewGui.btnPrev := previewGui.AddButton("x+4 yp w34 h26", "<")
    previewGui.btnPlay := previewGui.AddButton("x+6 yp w56 h26", "Play")
    previewGui.btnStop := previewGui.AddButton("x+4 yp w48 h26", "Stop")
    previewGui.btnNext := previewGui.AddButton("x+6 yp w34 h26", ">")
    previewGui.btnNextFrame := previewGui.AddButton("x+4 yp w38 h26", ">>")
    previewGui.btnEnd := previewGui.AddButton("x+4 yp w34 h26", ">|")

    previewGui.stepText := previewGui.AddText("x+18 y" row2Y " c909090", "Step:")
    previewGui.stepLabel := previewGui.AddText("x+4 y" row2Y " w66 cFFFFFF", "0 / 0")

    previewGui.posText := previewGui.AddText("x+10 y" row2Y " c909090", "Pos:")
    previewGui.posLabel := previewGui.AddText("x+4 y" row2Y " w56 cFFFFFF", "0%")

    previewGui.frameText := previewGui.AddText("x+10 y" row2Y " c909090", "Frame:")
    previewGui.frameLabel := previewGui.AddText("x+4 y" row2Y " w96 cFFFFFF", "0 / 100")

    previewGui.timeText := previewGui.AddText("x+10 y" row2Y " c909090", "Time:")
    previewGui.timeLabel := previewGui.AddText("x+4 y" row2Y " w80 cFFFFFF", "0s 0f")
    previewGui._settingsRow := [
        {ctrl: previewGui.fpsText, offset: 0},
        {ctrl: previewGui.fpsEdit, offset: -3},
        {ctrl: previewGui.framesText, offset: 0},
        {ctrl: previewGui.framesEdit, offset: -3},
        {ctrl: previewGui.curveCb, offset: -2}
    ]
    previewGui._controlsRow := [
        {ctrl: previewGui.btnStart, offset: -1},
        {ctrl: previewGui.btnPrevFrame, offset: -1},
        {ctrl: previewGui.btnPrev, offset: -1},
        {ctrl: previewGui.btnPlay, offset: -1},
        {ctrl: previewGui.btnStop, offset: -1},
        {ctrl: previewGui.btnNext, offset: -1},
        {ctrl: previewGui.btnNextFrame, offset: -1},
        {ctrl: previewGui.btnEnd, offset: -1},
        {ctrl: previewGui.stepText, offset: 0},
        {ctrl: previewGui.stepLabel, offset: 0},
        {ctrl: previewGui.posText, offset: 0},
        {ctrl: previewGui.posLabel, offset: 0},
        {ctrl: previewGui.frameText, offset: 0},
        {ctrl: previewGui.frameLabel, offset: 0},
        {ctrl: previewGui.timeText, offset: 0},
        {ctrl: previewGui.timeLabel, offset: 0}
    ]
    previewGui._frames := []
    previewGui._currentIdx := 0
    previewGui._overallProgress := 0.0
    previewGui._playing := false
    previewGui._mainGui := g
    previewGui._tickFn := 0
    previewGui._useCurve := true

    previewGui.btnStart.OnEvent("Click", (*) => (
        StopPlay(previewGui),
        previewGui._currentIdx := 0,
        previewGui._overallProgress := 0.0,
        UpdateFrameUI(previewGui, g)
    ))
    previewGui.btnPrevFrame.OnEvent("Click", (*) => (
        StopPlay(previewGui),
        previewGui._currentIdx := Max(0, previewGui._currentIdx - 1),
        UpdateFrameUI(previewGui, g)
    ))
    previewGui.btnPrev.OnEvent("Click", (*) => StepPreviewFrame(previewGui, g, -1))
    previewGui.btnPlay.OnEvent("Click", (*) => TogglePlay(previewGui, g))
    previewGui.btnStop.OnEvent("Click", (*) => (
        StopPlay(previewGui),
        previewGui._currentIdx := 0,
        previewGui._overallProgress := 0.0,
        UpdateFrameUI(previewGui, g)
    ))
    previewGui.btnNext.OnEvent("Click", (*) => StepPreviewFrame(previewGui, g, 1))
    previewGui.btnNextFrame.OnEvent("Click", (*) => (
        StopPlay(previewGui),
        previewGui._currentIdx := Min(previewGui._frames.Length - 1, previewGui._currentIdx + 1),
        UpdateFrameUI(previewGui, g)
    ))
    previewGui.btnEnd.OnEvent("Click", (*) => (
        StopPlay(previewGui),
        previewGui._currentIdx := Max(0, previewGui._frames.Length - 1),
        previewGui._overallProgress := 1.0,
        UpdateFrameUI(previewGui, g)
    ))

    previewGui.OnEvent("Close", (*) => (
        StopPlay(previewGui),
        previewGui := 0
    ))

    previewGui.OnEvent("Size", (thisGui, minMax, aW, aH) => OnPreviewSize(thisGui, minMax, aW, aH, g))

    previewGui.Show("w880 h510")
    OnPreviewSize(previewGui, 0, 880, 520, g)
    UpdatePreviewFrames(previewGui, g)
}

UpdatePreviewFrames(previewGui, g) {
    s := GetCanvasState(g)
    plan := GenerateFishbonePlan(s.totalInbetweens, s.followPct, s.priorityRules, s.advanced, s.frames, s.useFakePriority)

    if s.advanced {
        previewGui.fpsEdit.Value := s.fps
        previewGui.framesEdit.Value := s.frames
    }

    previewGui._frames := BuildPreviewFrames(plan, s)
    previewGui._currentIdx := 0
    UpdateFrameUI(previewGui, g)
}

UpdateFrameUI(previewGui, g) {
    frames := previewGui._frames
    curIdx := previewGui._currentIdx
    if curIdx < 0 || curIdx >= frames.Length
        curIdx := 0
    previewGui._overallProgress := frames[curIdx + 1].pos / 100
    RefreshPreviewLabels(previewGui)
    DrawPreview(previewGui, g)
}

RefreshPreviewLabels(previewGui) {
    frames := previewGui._frames
    if frames.Length = 0
        return
    targetPos := previewGui._overallProgress * 100
    curIdx := Max(0, frames.Length - 2)
    Loop frames.Length - 1 {
        i := A_Index
        nextPos := frames[i+1].pos
        if targetPos < nextPos {
            curIdx := i - 1
            break
        }
    }
    totalFrames := Integer(previewGui.framesEdit.Value)
    if totalFrames < 1
        totalFrames := 100
    curFrameNum := Min(Round(totalFrames * targetPos / 100), totalFrames - 1) + 1
    previewGui.stepLabel.Text := (curIdx + 1) " / " (frames.Length - 1)
    previewGui.posLabel.Text := Round(targetPos) "%"
    previewGui.frameLabel.Text := curFrameNum " / " totalFrames
    fps := Integer(previewGui.fpsEdit.Value)
    if fps < 1
        fps := 1
    timeInFrames := curFrameNum - 1
    secs := Floor(timeInFrames / fps)
    remF := Mod(timeInFrames, fps)
    previewGui.timeLabel.Text := secs "s " remF "f"
}

DrawPreview(previewGui, g) {
    frames := previewGui._frames
    if frames.Length = 0
        return

    previewGui.canvas.GetPos(, , &w, &h)
    if w < 100 {
        w := 600
        h := 200
    }

    pBitmap := GDI.CreateBitmap(w, h)
    if !pBitmap
        return
    pGraphics := GDI.GetGraphics(pBitmap)
    if !pGraphics {
        GDI.DisposeImage(pBitmap)
        return
    }

    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)
    GDI.Clear(pGraphics, 0xFF1E2127)

    ml := 72
    mr := 72
    gw := w - ml - mr
    baseY := h / 2

    useCurve := previewGui._useCurve

    ; --- Draw axis (curve or line) ---
    pAxis := GDI.CreatePen(0xFFE8E8E8, 2)
    arcHeight := Min(70, Max(34, h // 4))

    if useCurve {
        for i, frame in frames {
            if i >= frames.Length
                break
            x1 := ml + Round(gw * frame.pos / 100)
            x2 := ml + Round(gw * frames[i+1].pos / 100)
            midX := (x1 + x2) // 2
            dir := Mod(i - 1, 2) = 0 ? -1 : 1
            ctrlY := baseY + dir * arcHeight
            GDI.DrawBezier(pGraphics, pAxis, x1, baseY, midX, ctrlY, midX, ctrlY, x2, baseY)
        }
    } else {
        GDI.DrawLine(pGraphics, pAxis, ml, baseY, ml + gw, baseY)
    }
    GDI.DeletePen(pAxis)

    pTick := GDI.CreatePen(0xFFBFC5D2, 1)
    pLabelBrush := GDI.CreateBrush(0xFF9AA0AA)
    pInRangeBrush := GDI.CreateBrush(0xFF72DDF7)

    for i, frame in frames {
        x := ml + Round(gw * frame.pos / 100)
        GDI.DrawLine(pGraphics, pTick, x, baseY - 6, x, baseY + 6)
        label := frame.label
        if RegExMatch(label, "^\d+$")
            label .= "%"
        labelX := Max(0, Min(w - 46, x - 23))
        GDI.DrawString(pGraphics, label, labelX, baseY + 12, 46, 14, pLabelBrush, 8)
        GDI.FillEllipse(pGraphics, pInRangeBrush, x, baseY, 4)
    }

    GDI.DeletePen(pTick)
    GDI.DeleteBrush(pLabelBrush)
    GDI.DeleteBrush(pInRangeBrush)

    ; Interpolated circle position from overall progress
    targetPos := previewGui._overallProgress * 100
    curIdx := Max(0, frames.Length - 2)
    t := 0.0
    curFrame := frames[Max(1, frames.Length - 1)]
    nextFrame := frames[frames.Length]
    Loop frames.Length - 1 {
        i := A_Index
        nextPos := frames[i+1].pos
        if targetPos < nextPos {
            curIdx := i - 1
            curFrame := frames[i]
            nextFrame := frames[i+1]
            break
        }
    }
    segLen := nextFrame.pos - curFrame.pos
    t := segLen > 0 ? (targetPos - curFrame.pos) / segLen : 0.0
    t := Max(0.0, Min(1.0, t))

    x1 := ml + Round(gw * curFrame.pos / 100)
    x2 := ml + Round(gw * nextFrame.pos / 100)

    if useCurve {
        midX := (x1 + x2) // 2
        dir := Mod(curIdx, 2) = 0 ? -1 : 1
        ctrlY := baseY + dir * arcHeight
        mt := 1 - t
        circleX := Round(mt*mt*mt * x1 + 3*mt*mt*t * midX + 3*mt*t*t * midX + t*t*t * x2)
        circleY := Round(mt*mt*mt * baseY + 3*mt*mt*t * ctrlY + 3*mt*t*t * ctrlY + t*t*t * baseY)
    } else {
        circleX := Round(x1 + (x2 - x1) * t)
        circleY := baseY
    }

    curPos := Round(curFrame.pos + (nextFrame.pos - curFrame.pos) * t)

    totalFrames := Integer(previewGui.framesEdit.Value)
    if totalFrames < 1
        totalFrames := 100
    curFrameNum := Min(Round(totalFrames * curPos / 100), totalFrames - 1) + 1
    fps := Integer(previewGui.fpsEdit.Value)
    if fps < 1
        fps := 1
    timeF := curFrameNum - 1
    secs := Floor(timeF / fps)
    remF := Mod(timeF, fps)

    pCurrentBrush2 := GDI.CreateBrush(0xFFFFC857)
    GDI.FillEllipse(pGraphics, pCurrentBrush2, circleX, circleY, 10)
    GDI.DeleteBrush(pCurrentBrush2)

    info := "Position: " curPos "%  |  Frame " curFrameNum " / " totalFrames "  |  Time " secs "s " remF "f  |  Segment: " (curIdx + 1) " / " (frames.Length - 1)
    pInfo := GDI.CreateBrush(0xFFFFFFFF)
    GDI.DrawString(pGraphics, info, ml, h - 24, 400, 18, pInfo, 10)
    GDI.DeleteBrush(pInfo)

    pABrush := GDI.CreateBrush(0xFFFFC857)
    pBBrush := GDI.CreateBrush(0xFF72DDF7)
    GDI.DrawString(pGraphics, "A (0%)", ml - 35, baseY - 34, 70, 16, pABrush, 9)
    GDI.DrawString(pGraphics, "B (100%)", ml + gw - 40, baseY - 34, 80, 16, pBBrush, 9)
    GDI.DeleteBrush(pABrush)
    GDI.DeleteBrush(pBBrush)

    hBitmap := GDI.GetHBITMAP(pBitmap)
    if hBitmap
        previewGui.canvas.Value := "HBITMAP:" hBitmap

    GDI.DeleteGraphics(pGraphics)
    GDI.DisposeImage(pBitmap)
}

DrawExamplePreview(picCtrl, rulesText, advanced := false, frames := 100) {
    picCtrl.GetPos(, , &w, &h)
    if w < 20 || h < 20
        return

    parsed := ParsePriorityRules(rulesText, advanced)
    total := GetRuleCount(parsed)

    pBitmap := GDI.CreateBitmap(w, h)
    if !pBitmap
        return
    pGraphics := GDI.GetGraphics(pBitmap)
    if !pGraphics {
        GDI.DisposeImage(pBitmap)
        return
    }

    GDI.SetSmoothing(pGraphics, 4)
    GDI.Clear(pGraphics, 0xFF1E2127)

    if total > 0 {
        plan := GenerateFishbonePlan(total, 50, parsed, advanced, frames)
        stops := plan.finalStops

        ml := 28
        mr := 28
        gw := w - ml - mr
        baseY := h // 2

        pAxis := GDI.CreatePen(0xFFE8E8E8, 1)
        GDI.DrawLine(pGraphics, pAxis, ml, baseY, ml + gw, baseY)
        GDI.DeletePen(pAxis)

        pInBrush := GDI.CreateBrush(0xFF72DDF7)
        pLabelBrush := GDI.CreateBrush(0xFF9AA0AA)
        for stop in stops {
            if stop.type = "endpoint"
                continue
            x := ml + Round(gw * stop.pos / 100)
            GDI.FillEllipse(pGraphics, pInBrush, x, baseY, 4)
            GDI.DrawString(pGraphics, Format("{:d}", stop.targetIdx), x - 8, baseY + 8, 18, 14, pLabelBrush, 8)
        }
        GDI.DeleteBrush(pInBrush)
        GDI.DeleteBrush(pLabelBrush)

        pABrush := GDI.CreateBrush(0xFFFFC857)
        pBBrush := GDI.CreateBrush(0xFF72DDF7)
        GDI.DrawString(pGraphics, "A", 2, baseY - 8, 24, 16, pABrush, 9)
        GDI.DrawString(pGraphics, "B", w - 22, baseY - 8, 24, 16, pBBrush, 9)
        GDI.DeleteBrush(pABrush)
        GDI.DeleteBrush(pBBrush)
    }

    hBitmap := GDI.GetHBITMAP(pBitmap)
    if hBitmap
        picCtrl.Value := "HBITMAP:" hBitmap

    GDI.DeleteGraphics(pGraphics)
    GDI.DisposeImage(pBitmap)
}

TogglePlay(previewGui, g) {
    if previewGui._playing
        StopPlay(previewGui)
    else
        StartPlay(previewGui, g)
}

StartPlay(previewGui, g) {
    if previewGui._frames.Length = 0
        return
    previewGui._playing := true
    previewGui.btnPlay.Text := "Pause"

    previewGui._tickFn := () => OnPreviewTick(previewGui, g)
    SetTimer(previewGui._tickFn, _PREVIEW_TIMER_MS)
}

OnPreviewTick(previewGui, g) {
    if !previewGui._playing
        return
    fps := Integer(previewGui.fpsEdit.Value)
    if fps < 1
        fps := 1
    totalFrames := Integer(previewGui.framesEdit.Value)
    if totalFrames < 1
        totalFrames := 100
    previewGui._overallProgress += (_PREVIEW_TIMER_MS / 1000) * fps / totalFrames
    if previewGui._overallProgress >= 1.0
        previewGui._overallProgress -= 1.0
    RefreshPreviewLabels(previewGui)
    DrawPreview(previewGui, g)
}

StopPlay(previewGui) {
    previewGui._playing := false
    previewGui.btnPlay.Text := "Play"
    if previewGui._tickFn {
        SetTimer(previewGui._tickFn, 0)
        previewGui._tickFn := 0
    }
}

StepPreviewFrame(previewGui, g, dir) {
    if previewGui._frames.Length = 0
        return
    StopPlay(previewGui)
    totalFrames := Integer(previewGui.framesEdit.Value)
    if totalFrames < 1
        totalFrames := 100
    step := 1.0 / totalFrames
    previewGui._overallProgress := Max(0.0, Min(1.0, previewGui._overallProgress + step * dir))
    RefreshPreviewLabels(previewGui)
    DrawPreview(previewGui, g)
}

MovePreviewControlRow(row, y) {
    for item in row
        item.ctrl.Move(, y + item.offset)
}

OnPreviewSize(thisGui, minMax, aW, aH, g) {
    if minMax = -1
        return
    try {
        margin := 18
        canvasY := 48
        newW := aW - margin * 2
        newH := aH - canvasY - 116
        if newW < 200
            newW := 200
        if newH < 160
            newH := 160
        thisGui.canvas.Move(margin, canvasY, newW, newH)
        row1Y := canvasY + newH + 14
        row2Y := row1Y + 34
        MovePreviewControlRow(thisGui._settingsRow, row1Y)
        MovePreviewControlRow(thisGui._controlsRow, row2Y)
        DrawPreview(thisGui, g)
    }
}

; ─── Timeline Export ─────────────────────────────────────────────

SaveTimelinePNG(g) {
    file := FileSelect("S16", "inbetween.png", "Save Timeline Preview as PNG", "PNG (*.png)")
    if file = ""
        return

    s := GetCanvasState(g)
    plan := GenerateFishbonePlan(s.totalInbetweens, s.followPct, s.priorityRules, s.advanced, s.frames, s.useFakePriority)

    ew := 1400, eh := 450
    ml := 80, mr := 80, mt := 50, mb := 50
    gw := ew - ml - mr
    gh := eh - mt - mb
    baseY := Round(mt + gh / 2)

    pBitmap := GDI.CreateBitmap(ew, eh)
    if !pBitmap
        return
    pGraphics := GDI.GetGraphics(pBitmap)
    if !pGraphics {
        GDI.DisposeImage(pBitmap)
        return
    }

    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)
    GDI.Clear(pGraphics, 0xFF2B2D31)

    pAxisPen := GDI.CreatePen(0xFFE8E8E8, 3)
    pTickPen := GDI.CreatePen(0xFFBFC5D2, 2)
    pLabelBrush := GDI.CreateBrush(0xFFFFFFFF)
    pMutedBrush := GDI.CreateBrush(0xFF9AA0AA)
    pPriorityBrush := GDI.CreateBrush(0xFFFFC857)
    pFollowBrush := GDI.CreateBrush(0xFF72DDF7)
    pDotBrush := GDI.CreateBrush(0xFFFFFFFF)

    GDI.DrawLine(pGraphics, pAxisPen, ml, baseY, ml + gw, baseY)

    for stop in plan.finalStops {
        x := ml + Round(gw * stop.pos / 100)
        tickH := (stop.type = "endpoint") ? 22 : 18
        GDI.DrawLine(pGraphics, pTickPen, x, baseY - tickH, x, baseY + tickH)
        GDI.FillEllipse(pGraphics, pDotBrush, x, baseY, 5)

        if stop.type = "endpoint" {
            GDI.DrawString(pGraphics, stop.label, x - 25, baseY - 48, 50, 28, pLabelBrush, 20)
        } else {
            labelBrush := (stop.type = "priority") ? pPriorityBrush : pFollowBrush
            GDI.DrawString(pGraphics, stop.label, x - 25, baseY - 64, 50, 24, labelBrush, 16)
        }
    }

    hiddenByRule := Map()
    for rule in s.priorityRules
        if rule.HasProp("hide") && rule.hide
            hiddenByRule[rule.targetIdx] := true

    showPriority := !g.HasProp("showPriority") || g.showPriority
    showFollow := !g.HasProp("showFollow") || g.showFollow

    if showPriority || showFollow {
        pCount := 0, fCount := 0
        for placement in plan.placements {
            if placement.stage = "priority" && !showPriority
                continue
            if placement.stage = "follow" && !showFollow
                continue
            if g.HasProp("hiddenLines") && g.hiddenLines.Has(placement.stage "_" placement.targetIdx)
                continue
            if hiddenByRule.Has(placement.targetIdx)
                continue
            if placement.stage = "priority"
                pCount += 1
            else
                fCount += 1
        }
        pIdx := 0, fIdx := 0, seqIdx := 0
        for placement in plan.placements {
            if placement.stage = "priority" && !showPriority
                continue
            if placement.stage = "follow" && !showFollow
                continue
            if g.HasProp("hiddenLines") && g.hiddenLines.Has(placement.stage "_" placement.targetIdx)
                continue
            if hiddenByRule.Has(placement.targetIdx)
                continue
            seqIdx += 1
            leftX := ml + Round(gw * placement.left / 100)
            nodeX := ml + Round(gw * placement.pos / 100)
            rightX := ml + Round(gw * placement.right / 100)
            if placement.stage = "priority" {
                t := pCount > 1 ? pIdx / (pCount - 1) : 0
                branchPen := GDI.CreatePen(GDI.LerpColor(0xFFFFD700, 0xFFFFB300, t), 3)
                pIdx += 1
            } else {
                t := fCount > 1 ? fIdx / (fCount - 1) : 0
                branchPen := GDI.CreatePen(GDI.LerpColor(0xFF99EEFF, 0xFF7EC8E3, t), 3)
                fIdx += 1
            }
            arcHeight := 12 + placement.depth * 14 + (seqIdx - 1) * 6
            above := placement.stage != "follow"
            midLeft := Round((leftX + nodeX) / 2)
            midRight := Round((nodeX + rightX) / 2)
            dir := above ? -1 : 1
            topY := baseY + dir * arcHeight
            GDI.DrawBezier(pGraphics, branchPen, leftX, baseY, leftX, topY, midLeft, topY, nodeX, baseY)
            GDI.DrawBezier(pGraphics, branchPen, nodeX, baseY, midRight, topY, rightX, topY, rightX, baseY)
            GDI.DeletePen(branchPen)
        }
    }

    GDI.DrawString(pGraphics, "A", ml - 30, baseY - 5, 24, 24, pLabelBrush, 20)
    GDI.DrawString(pGraphics, "B", ml + gw + 10, baseY - 5, 24, 24, pLabelBrush, 20)
    GDI.DrawString(pGraphics, "Priority", ml, eh - 36, 100, 20, pPriorityBrush, 12)
    GDI.DrawString(pGraphics, "Follow", ml + 110, eh - 36, 80, 20, pFollowBrush, 12)
    GDI.DrawString(pGraphics, "Allowed: " _ALLOWED_HINT, ml + 210, eh - 36, 400, 20, pMutedBrush, 12)

    GDI.DeletePen(pAxisPen)
    GDI.DeletePen(pTickPen)
    GDI.DeleteBrush(pLabelBrush)
    GDI.DeleteBrush(pMutedBrush)
    GDI.DeleteBrush(pPriorityBrush)
    GDI.DeleteBrush(pFollowBrush)
    GDI.DeleteBrush(pDotBrush)

    clsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)
    DllCall("gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "Str", file, "Ptr", clsid, "Ptr", 0)

    GDI.DeleteGraphics(pGraphics)
    GDI.DisposeImage(pBitmap)
    TrayTip("Timeline", "PNG saved to " file)
}

SaveTimelineSVG(g) {
    file := FileSelect("S16", "inbetween.svg", "Save Timeline Preview as SVG", "SVG (*.svg)")
    if file = ""
        return

    s := GetCanvasState(g)
    plan := GenerateFishbonePlan(s.totalInbetweens, s.followPct, s.priorityRules, s.advanced, s.frames, s.useFakePriority)

    ew := 1400, eh := 450
    ml := 80, mr := 80, mt := 50, mb := 50
    gw := ew - ml - mr
    gh := eh - mt - mb
    baseY := Round(mt + gh / 2)

    svg := '<?xml version="1.0" encoding="UTF-8"?>'
    svg .= '<svg xmlns="http://www.w3.org/2000/svg" width="' ew '" height="' eh '" viewBox="0 0 ' ew ' ' eh '">'
    svg .= '<rect width="' ew '" height="' eh '" fill="#2B2D31"/>'
    svg .= '<line x1="' ml '" y1="' baseY '" x2="' (ml+gw) '" y2="' baseY '" stroke="#E8E8E8" stroke-width="3"/>'

    for stop in plan.finalStops {
        x := ml + Round(gw * stop.pos / 100)
        tickH := (stop.type = "endpoint") ? 22 : 18
        svg .= '<line x1="' x '" y1="' (baseY - tickH) '" x2="' x '" y2="' (baseY + tickH) '" stroke="#BFC5D2" stroke-width="2"/>'
        svg .= '<circle cx="' x '" cy="' baseY '" r="5" fill="#FFFFFF"/>'

        if stop.type = "endpoint" {
            svg .= '<text x="' x '" y="' (baseY - 48) '" fill="#FFFFFF" font-family="Consolas" font-size="20" text-anchor="middle">' SvgEsc(stop.label) '</text>'
        } else {
            fill := (stop.type = "priority") ? "#FFC857" : "#72DDF7"
            svg .= '<text x="' x '" y="' (baseY - 64) '" fill="' fill '" font-family="Consolas" font-size="16" text-anchor="middle">' SvgEsc(stop.label) '</text>'
        }
    }

    hiddenByRule := Map()
    for rule in s.priorityRules
        if rule.HasProp("hide") && rule.hide
            hiddenByRule[rule.targetIdx] := true

    showPriority := !g.HasProp("showPriority") || g.showPriority
    showFollow := !g.HasProp("showFollow") || g.showFollow

    if showPriority || showFollow {
        pCount := 0, fCount := 0
        for placement in plan.placements {
            if placement.stage = "priority" && !showPriority
                continue
            if placement.stage = "follow" && !showFollow
                continue
            if g.HasProp("hiddenLines") && g.hiddenLines.Has(placement.stage "_" placement.targetIdx)
                continue
            if hiddenByRule.Has(placement.targetIdx)
                continue
            if placement.stage = "priority"
                pCount += 1
            else
                fCount += 1
        }
        pIdx := 0, fIdx := 0, seqIdx := 0
        for placement in plan.placements {
            if placement.stage = "priority" && !showPriority
                continue
            if placement.stage = "follow" && !showFollow
                continue
            if g.HasProp("hiddenLines") && g.hiddenLines.Has(placement.stage "_" placement.targetIdx)
                continue
            if hiddenByRule.Has(placement.targetIdx)
                continue
            seqIdx += 1
            leftX := ml + Round(gw * placement.left / 100)
            nodeX := ml + Round(gw * placement.pos / 100)
            rightX := ml + Round(gw * placement.right / 100)
            arcHeight := 12 + placement.depth * 14 + (seqIdx - 1) * 6
            above := placement.stage != "follow"
            dir := above ? -1 : 1
            topY := baseY + dir * arcHeight
            midLeft := Round((leftX + nodeX) / 2)
            midRight := Round((nodeX + rightX) / 2)

            if placement.stage = "priority" {
                t := pCount > 1 ? pIdx / (pCount - 1) : 0
                r := Round(255 - (255 - 179) * t)
                gg := Round(215 - (215 - 179) * t)
                b := Round(0 + (0 - 0) * t)
                stroke := '#' Format("{:02X}{:02X}{:02X}", r, gg, b)
                pIdx += 1
            } else {
                t := fCount > 1 ? fIdx / (fCount - 1) : 0
                r := Round(153 - (153 - 126) * t)
                gg := Round(238 - (238 - 200) * t)
                b := Round(255 - (255 - 227) * t)
                stroke := '#' Format("{:02X}{:02X}{:02X}", r, gg, b)
                fIdx += 1
            }

            svg .= '<path d="M' leftX ',' baseY ' C' leftX ',' topY ' ' midLeft ',' topY ' ' nodeX ',' baseY '" stroke="' stroke '" stroke-width="3" fill="none"/>'
            svg .= '<path d="M' nodeX ',' baseY ' C' midRight ',' topY ' ' rightX ',' topY ' ' rightX ',' baseY '" stroke="' stroke '" stroke-width="3" fill="none"/>'
        }
    }

    svg .= '<text x="' (ml - 30) '" y="' (baseY + 7) '" fill="#FFFFFF" font-family="Consolas" font-size="20" text-anchor="middle">A</text>'
    svg .= '<text x="' (ml + gw + 10) '" y="' (baseY + 7) '" fill="#FFFFFF" font-family="Consolas" font-size="20" text-anchor="middle">B</text>'
    svg .= '<text x="' ml '" y="' (eh - 26) '" fill="#FFC857" font-family="Consolas" font-size="12">Priority</text>'
    svg .= '<text x="' (ml + 110) '" y="' (eh - 26) '" fill="#72DDF7" font-family="Consolas" font-size="12">Follow</text>'
    svg .= '<text x="' (ml + 210) '" y="' (eh - 26) '" fill="#9AA0AA" font-family="Consolas" font-size="12">Allowed: ' _ALLOWED_HINT '</text>'
    svg .= '</svg>'

    try FileDelete(file)
    FileAppend(svg, file, "UTF-8")
    TrayTip("Timeline", "SVG saved to " file)
}

SaveCurrentAsExample(g) {
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Save as Example")
    dlg.BackColor := "25282E"
    dlg.SetFont("s9", "Segoe UI")
    dlg.MarginX := 12
    dlg.MarginY := 10
    dlg.AddText("xm cFFFFFF", "Example name:")
    nameEd := dlg.AddEdit("xm w240 BackgroundFFFFFF c000000", "")
    dlg.AddText("xm y+6 cFFFFFF", "Notes:")
    notesEd := dlg.AddEdit("xm w240 h60 Multi BackgroundFFFFFF c000000", "")
    dlg.AddButton("xm y+6 w80 Default", "Save").OnEvent("Click", (*) => (SaveExample(nameEd.Value, g.priorityRules.Value, notesEd.Value, g.advancedCb.Value, g.advancedFps, g.advancedFrames), TrayTip("Fishbone", "Saved as example: " nameEd.Value), dlg.Destroy()))
    dlg.AddButton("x+10 w80", "Cancel").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize Center")
}

SvgEsc(text) {
    text := StrReplace(text, "&", "&amp;")
    text := StrReplace(text, "<", "&lt;")
    text := StrReplace(text, ">", "&gt;")
    text := StrReplace(text, "'", "&apos;")
    text := StrReplace(text, '"', "&quot;")
    return text
}

; â”€â”€â”€ Main GUI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

ToggleAdvanced(g) {
    showAdvanced := g.HasProp("advancedCb") && g.advancedCb.Value
    for ctrl in [g.advFpsLabel, g.advFpsEdit, g.advFramesLabel, g.advFramesEdit, g.btnApplyAdvanced, g.btnTimesheet, g.advancedInfo]
        ctrl.Visible := showAdvanced
    if g.HasProp("btnConvertMode")
        g.btnConvertMode.Text := showAdvanced ? "To Normal" : "To Advanced"
    if g.HasProp("followPctDdl")
        g.followPctDdl.Enabled := !showAdvanced
    if g.HasProp("followPctLabel")
        g.followPctLabel.Enabled := !showAdvanced
    RedrawCanvas(g)
}

ApplyAdvancedTiming(g) {
    fps := Integer(g.advFpsEdit.Value)
    if fps < 1
        fps := 24
    frames := Integer(g.advFramesEdit.Value)
    if frames < 2
        frames := 100
    g.advFpsEdit.Value := fps
    g.advFramesEdit.Value := frames
    g.advancedFps := fps
    g.advancedFrames := frames
    RedrawCanvas(g)
}

OpenTimelineGui() {
    global _fishGui
    static guiObj := 0

    if IsObject(guiObj) {
        try {
            guiObj.Show()
            WinActivate(guiObj.Hwnd)
        }
        return
    }

    if !GDI.token
        GDI.Start()

    g := Gui(" +MinSize500x420", "Nastarxa Fishbone Inbetween-Generator")
    guiObj := g

    g.BackColor := "25282E"
    g.SetFont("s10", "Segoe UI")

    g.MarginX := 14
    g.MarginY := 14

    g.AddText(
        "x14 y12 cFFFFFF",
        "Timeline Rules"
    )
    x := 14
    y := 38
    gap := 4
    groupGap := 12

    ; Documentation
    g.btnGuide := g.AddButton("x" x " y" y " w70 h28", "📘 Guide")
    x += 70 + gap

    g.btnExamples := g.AddButton("x" x " y" y " w90 h28", "📂 Examples")
    x += 90 + gap

    g.btnOutput := g.AddButton("x" x " y" y " w90 h28", "📄 Output")
    x += 90 + groupGap

    g.btnRefAB := g.AddButton("x" x " y" y " w54 h28", "_A>B")
    g.btnRefAB.OnEvent("Click", (*) => SetRefAB(g))
    x += 54 + gap

    g.btnHide := g.AddButton("x" x " y" y " w56 h28", "-Hide")
    g.btnHide.OnEvent("Click", (*) => AddHideToSelection(g))
    x += 56 + groupGap


    g.showPriority := true
    g.showFollow := true
    g.btnPriority := g.AddButton("x" x " y" y " w95 h28", "✅ Priority")
    g.btnPriority.OnEvent("Click", (*) => (
        g.showPriority := !g.showPriority,
        g.btnPriority.Text := (g.showPriority ? "✅ Priority" : "❌ Priority"),
        RedrawCanvas(g)
    ))

    x += 95 + gap

    g.btnFollow := g.AddButton("x" x " y" y " w85 h28", "✅ Follow")

    g.btnFollow.OnEvent("Click", (*) => (
        g.showFollow := !g.showFollow,
        g.btnFollow.Text := (g.showFollow ? "✅ Follow" : "❌ Follow"),
        RedrawCanvas(g)
    ))

 
    g.priorityRules := g.AddEdit(
        "x14 y74 w580 h86 Multi WantTab BackgroundFFFFFF c000000",
        "1_f, 2_A>B=Auto, 3_f, 4_f"
    )
    g._history := [g.priorityRules.Value]
    g._historyIdx := 0
    g._historyBusy := false

    g.AddText(
        "x14 y164 w600 c909090",
        "Format: 3_A>B=50, 1_f | Advanced: 4[25]_A>B=Auto, 3[700]_f-Hide"
    )

    canvasY := 196
    g.AddText(
        "x14 y" canvasY " cFFFFFF",
        "Timeline Preview"
    )

    g.btnPreview := g.AddButton("x+7 yp-3 w75 h24", "Preview")
    g.btnPreview.OnEvent("Click", (*) => ShowPreview(g))
    g.btnSavePNG := g.AddButton("x+7 yp w80 h24", "Save PNG")
    g.btnSavePNG.OnEvent("Click", (*) => SaveTimelinePNG(g))
    g.btnSaveSVG := g.AddButton("x+4 yp w78 h24", "Save SVG")
    g.btnSaveSVG.OnEvent("Click", (*) => SaveTimelineSVG(g))
    g.btnSaveExample := g.AddButton("x+7 yp w82 h24", "💾 Example")
    g.btnSaveExample.OnEvent("Click", (*) => SaveCurrentAsExample(g))
    g.followPctLabel := g.AddText("x+8 yp+4 cffffff", "Follow%:")
    g.followPctDdl := g.AddDropDownList("x+5 yp-4 w70 c000000 BackgroundFFFFFF Choose1", ["Auto", "25", "33", "40", "50", "60", "66", "75"])
    g.followPctDdl.OnEvent("Change", (*) => RedrawCanvas(g))

    g.canvas := g.AddPicture(
        "x14 y" (canvasY + 28) " w580 h200 Background1E2127"
    )
    g.hiddenLines := Map()
    g.canvas.OnEvent("Click", (*) => OnCanvasClick(g))

    advY := canvasY + 236
    g.fakePriorityCb := g.AddCheckbox("x14 y" advY " cFFFFFF Background25282E Checked", "Fake Priority")
    g.fakePriorityCb.OnEvent("Click", (*) => RedrawCanvas(g))
    g.advancedCb := g.AddCheckbox("x+16 yp cFFFFFF Background25282E", "Advanced")
    g.advancedCb.OnEvent("Click", (*) => ToggleAdvanced(g))
    g.advFpsLabel := g.AddText("x+4 yp+3 cffffff Hidden", "FPS:")
    g.advFpsEdit := g.AddEdit("x+4 yp-3 w48 h22 Center Number BackgroundFFFFFF c000000 Hidden", "24")
    g.advFramesLabel := g.AddText("x+6 yp+3 cffffff Hidden", "Frames:")
    g.advFramesEdit := g.AddEdit("x+4 yp-3 w64 h22 Center Number BackgroundFFFFFF c000000 Hidden", "100")
    g.btnApplyAdvanced := g.AddButton("x+8 yp-1 w58 h24 Hidden", "Apply")
    g.btnApplyAdvanced.OnEvent("Click", (*) => ApplyAdvancedTiming(g))
    g.btnTimesheet := g.AddButton("x+29 yp w95 h24 Hidden", "Timesheet")
    g.btnTimesheet.OnEvent("Click", (*) => ShowAdvancedTimesheet(g))
    g.btnConvertMode := g.AddButton("x+8 yp w95 h24", "To Advanced")
    g.btnConvertMode.OnEvent("Click", (*) => ConvertRulesMode(g))
    g.advancedInfo := g.AddText("x14 y" (advY + 28) " w570 c909090 Hidden", "")
    g.advancedFps := 24
    g.advancedFrames := 100

    g.priorityRules.OnEvent(
        "Change",
        (*) => (g._historyBusy ? "" : RedrawCanvas(g), PushHistory(g))
    )
    TrackCaret(g)
    g.priorityRules.OnEvent("Focus", (*) => TrackCaret(g))
    g.priorityRules.OnEvent("LoseFocus", (*) => TrackCaret(g))

    g.btnGuide.OnEvent(
        "Click",
        (*) => ShowGuide()
    )

    g.btnExamples.OnEvent(
        "Click",
        (*) => OpenExamplesGui(g)
    )

    g.btnOutput.OnEvent(
        "Click",
        (*) => OpenOutputGui(g)
    )

    g.OnEvent(
        "Close",
        (*) => (
            guiObj := 0,
            _fishGui := 0
        )
    )

    g._initialSetup := true

    _fishGui := g
    g.Show("w605 h505 Center")

    g._initialSetup := false

    RedrawCanvas(g)
}

