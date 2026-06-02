; ============================================================
; Nastarxa CSP Animator Toolkit
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

#Include Notify.ahk
TraySetIcon "CSPToolkit.ico"

; ============================================================
; GLOBALS
; ============================================================
; --- Inbetween ---
global InbetweenIndex := 1
global InbetweenMode := "End > Start"
global InbetweenData := BuildInbetweenData(InbetweenMode)
; --- IB GUI ---
global IB_GUI := 0, IB_Text := 0, IB_LTInd := 0, IB_LockBtn := 0
global IB_Buttons := []
global IB_ModeBtn := 0
global AutoSaveBtn := 0
global IB_X := 760, IB_Y := 10

; --- Color GUI ---
global ColorGUI := 0
global ColorGUI_X := 78, ColorGUI_Y := 810
global ColorLayout := "V"
global ColorGUIVisible := false

; --- Link GUI ---
global LinkGUI := 0
global LinkGUI_X := 78, LinkGUI_Y := 1090
global LinkGUIVisible := false

; --- State ---
global CSPActive := false
global CSP_PID := 0
global IBVisible := true
global GUIEnabled := true
global GUIVisible := false

; --- Lock ---
global LTLock := false

; --- Main GUI ---
global MainGUI := 0
global MainGUIVisible := false
global IBManualHide := false
global LinkManualHide := false
global ColorManualHide := false

; --- Auto Save ---
global AutoSaveOn := false

; --- Navigation ---
global NavEnabled := true
global CapslockEnabled := true
global TabCombosEnabled := true
global ResetEnabled := true
global LWinEnabled := true

; --- Configurable paths & URLs ---
global PickerPath := A_ScriptDir "\..\Nastarxa-Color-Picker\Nastarxa Color Picker.ahk"
global FishbonePath := A_ScriptDir "\..\Nastarxa-Fishbone-Inbetween-Generator\Nastarxa Fishbone Inbetween-Generator.ahk"
global ResizerPath := A_ScriptDir "\..\Nastarxa-Batch-Image-Resizer\Nastarxa Batch Image Resizer.ahk"
global SheetsURL := "https://docs.google.com/spreadsheets/d/1RO_WUyMEOLPDR-S9uM_qseg9T1IFu08vGWCOzAWfNaQ/edit?gid=0#gid=0"
global DriveURL := "https://drive.google.com/drive/u/0/folders/12DcDx1Oq0amOOhm1G42oHF6HbibovhAB"

; --- Configurable click coordinates ---
global LT_ClickX := 2237, LT_ClickY := 131
global ColorClick1X := 2324, ColorClick1Y := 856
global ColorClick2X := 2324, ColorClick2Y := 951

; --- Link Button Manager ---
global LinkItems := []

; --- DPI scaling ---
global Scale := 1.0
S(n) => Floor(n * Scale)

global TabCombosBtn := 0
global NavBtn := 0
global CapslockBtn := 0
global LWinBtn := 0
global ResetBtn := 0
global _ccBtnIB := 0

; --- Hover Popup ---
global _hoverMap := Map()
global _hoverPopup := 0
global _hoverLast := 0
global _hoverPending := 0
global _hoverPendingX := 0
global _hoverPendingY := 0

; --- Collapsible Link Sections ---
global _linkCollapsed := Map()

; --- Debug Log ---
global _debugLog := []
global _debugGUI := 0
global _debugDateShown := false
global _debugSaveOnExit := false

; --- Auto Save Interval ---
global AutoSaveInterval := 60

; --- IB Timer / Stopwatch ---
global _timerRunning := false
global _timerStart := 0
global _timerElapsed := 0
global _timerDisplay := 0
global _tmrPlay := 0
global _tmrPause := 0
global _rBtn := 0
global _saveBtn := 0
global _timerAskFileName := true
global _timerNameResult := ""
global _timerFocusPaused := false

; --- GUI Opacity ---
global IB_Opacity := 255
global Color_Opacity := 255
global Link_Opacity := 255

; --- CSP Auto-Restart ---
global CSP_RestartMonitor := false

; --- Settings ---
global Speed := 15
global HotkeysPaused := false
global LT_X := 2305, LT_Y := 172, LT_Color := 0x677187
global NotifyBase := ""
global SETTINGS_FILE := A_ScriptDir "\gui_settings.ini"

; Migrate old gui_pos.ini to new name
oldIni := A_ScriptDir "\gui_pos.ini"
if FileExist(oldIni) && !FileExist(SETTINGS_FILE)
    FileMove(oldIni, SETTINGS_FILE, 0) ; 0 = no overwrite

; ============================================================
; HOTKEY CONFIGURATION SYSTEM
; ============================================================

; Custom hotkey overrides loaded from INI
global HK_Custom := Map()
global HotkeyDefs := []
global _hkFilteredIndices := []

; Groups:
;   csp       = WinActive("ahk_exe CLIPStudioPaint.exe")
;   csp_nav   = ... && NavEnabled && !IsTyping()
;   csp_caps  = ... && CapslockEnabled && !IsTyping()
;   csp_tab   = ... && TabCombosEnabled && !IsTyping()
;   csp_reset = ... && ResetEnabled
;   bg        = WinExist(...) && !WinActive(...)
;   global    = (none)

; --- Extracted inline handlers ---
SpacePan(*) {
    Send("{Space Down}{LButton Down}")
    KeyWait("Space")
    Send("{LButton Up}{Space Up}{Ctrl Up}")
}
SpacePanCtrl(*) {
    Send("{Ctrl Down}{Space Down}{LButton Down}")
    KeyWait("Space")
    Send("{LButton Up}{Space Up}{Ctrl Up}")
}
SpacePanShiftAlt(*) {
    Send("+!{Space Down}{LButton Down}")
    KeyWait("Space")
    Send("{LButton Up}{Space Up}{Alt Up}{Shift Up}")
}
CapslockMod(*) {
    Send("{Ctrl Down}{Shift Down}{Alt Down}")
    ShowNotify("Capslock","LightTable 1-2-3")
    KeyWait("CapsLock")
    Send("{Ctrl Up}{Shift Up}{Alt Up}")
}
TabPaper1(*) {
    if GetKeyState("Ctrl") || GetKeyState("Alt")
        return
    Send("^+7"), ShowNotify("Paper Purple","","0xD283F6")
}
TabPaper2(*) {
    if GetKeyState("Ctrl") || GetKeyState("Alt")
        return
    Send("^+8"), ShowNotify("Paper Green","","0x5CD377")
}
TabPaper3(*) {
    if GetKeyState("Ctrl") || GetKeyState("Alt")
        return
    Send("^+9"), ShowNotify("Paper White","","0xC80207")
}
TabResetLT(*) {
    global LT_ClickX, LT_ClickY
    MouseClick("left", LT_ClickX, LT_ClickY)
    ShowNotify("Reset Lighttable")
    Sleep(50)
    ResetLT()
}
ResetModifiers(*) {
    Send("{Ctrl Up}{Shift Up}{Alt Up}{LButton Up}{RButton Up}{Space Up}{MButton Up}")
    ShowNotify("Reset Keys","All modifiers released")
}
HotkeyIB1(*) {
    global InbetweenIndex
    SelectIB(InbetweenIndex)
}
HotkeyChangeColor(*) {
    global ColorClick1X, ColorClick1Y, ColorClick2X, ColorClick2Y
    if !IsLTActive()
        ResetLT()
    Click "Up Left"
    Sleep 100
    MouseClick "left", ColorClick1X, ColorClick1Y
    Sleep 200
    Send("{Shift Down}{CTRL Down}{=}{Shift Up}{CTRL Up}")
    Click "Up Left"
    Sleep 250
    MouseClick "left", ColorClick2X, ColorClick2Y
    Sleep 200
    Send("{Shift Down}{CTRL Down}{-}{Shift Up}{CTRL Up}")
    Click "Up Left"
    ShowNotify("Change Lightable Color")
    ResetLT()
}
HotkeyToggleOnion(*) {
    static t := false
    ShowNotify("Toggle Onion Skin: Alt+W", (t := !t) ? "On" : "Off")
}
HotkeyToggleLT(*) {
    static t := false
    ShowNotify("Toggle Light Table", (t := !t) ? "On" : "Off")
}
HotkeySwapBrush(*) {
    static t := false
    ShowNotify("Brush Color", (t := !t) ? "Secondary" : "Primary")
}
HotkeyToggleTransparent(*) {
    static t := false
    ShowNotify("Brush Transparent", (t := !t) ? "Transparent" : "Solid")
}
HotkeyBGPicker(*) {
    WinActivate
    Sleep 250
    Send("^+b")
    ShowNotify("Color Picker")
}

; Track currently-registered hotkey per id (for clean unregister on customization change)
global HK_Registered := Map()
	
; --- Build hotkey definitions ---
InitHotkeyDefs() {
    global HotkeyDefs
    HotkeyDefs := [
        ; ---- Group: csp ----
        {id:"toggle_guis",      group:"csp", def:"^F1",       desc:"Toggle Tool GUIs",                                       fn:ToggleToolGUIs},
        {id:"toggle_lt_lock",   group:"csp", def:"^F2",      desc:"Toggle LT Lock",                                         fn:ToggleLTLock},
        {id:"toggle_lt_lock_a", group:"csp", def:"!l",       desc:"Toggle LT Lock (Alt)",                                   fn:ToggleLTLock},
        {id:"toggle_autosave",  group:"csp", def:"^F4",      desc:"Toggle Auto Save",                                       fn:ToggleAutoSave},
        {id:"toggle_nav",       group:"csp", def:"^F5",      desc:"Toggle Nav",                                             fn:ToggleNav},
        {id:"toggle_capslock",  group:"csp", def:"^F6",      desc:"Toggle Capslock",                                        fn:ToggleCapslock},
        {id:"toggle_tab",       group:"csp", def:"^F7",      desc:"Toggle Tab Combos",                                      fn:ToggleTabCombos},
        {id:"toggle_reset",     group:"csp", def:"^F8",      desc:"Toggle Reset Keys",                                      fn:ToggleReset},
        {id:"toggle_lwin",      group:"csp", def:"^F9",      desc:"Toggle LWin Right-click",                                fn:ToggleLWin},
        {id:"lwin_rightclick",  group:"csp_lwin", def:"LWin", desc:"Right-click via LWin",                                  fn:(*) => Send("{RButton}")},
        {id:"wheel_down",       group:"csp", def:"WheelDown",desc:"Scroll Down",                                            fn:(*) => Send("{WheelDown " Speed "}")},
        {id:"wheel_up",         group:"csp", def:"WheelUp",  desc:"Scroll Up",                                              fn:(*) => Send("{WheelUp " Speed "}")},
        {id:"ib_1",             group:"csp", def:"$^1",      desc:"IB: Select current",                                     fn:HotkeyIB1},
        {id:"ib_2",             group:"csp", def:"$^2",      desc:"IB: Type 1 (50/50)",                                     fn:(*) => SelectIB(1)},
        {id:"ib_3",             group:"csp", def:"$^3",      desc:"IB: Type 2 (direction mode)",                           fn:(*) => SelectIB(2)},
        {id:"ib_4",             group:"csp", def:"$^4",      desc:"IB: Type 3 (direction mode)",                           fn:(*) => SelectIB(3)},
        {id:"ib_5",             group:"csp", def:"$^5",      desc:"IB: Type 4 (direction mode)",                           fn:(*) => SelectIB(4)},
        {id:"ib_6",             group:"csp", def:"$^6",      desc:"IB: Type 5 (direction mode)",                           fn:(*) => SelectIB(5)},
        {id:"ib_7",             group:"csp", def:"$^7",      desc:"IB: Type 6 (direction mode)",                           fn:(*) => SelectIB(6)},
        {id:"ib_8",             group:"csp", def:"$^8",      desc:"IB: Type 7 (direction mode)",                           fn:(*) => SelectIB(7)},
        {id:"layer_1",          group:"csp", def:"$+1",     desc:"Layer: Black",                                            fn:(*) => DoLayer("1","Black")},
        {id:"layer_2",          group:"csp", def:"$+2",     desc:"Layer: Red",                                              fn:(*) => DoLayer("2","Red","0xBF0000")},
        {id:"layer_3",          group:"csp", def:"$+3",     desc:"Layer: Blue",                                             fn:(*) => DoLayer("3","Blue","0x487AE3")},
        {id:"layer_4",          group:"csp", def:"$+4",     desc:"Layer: Green",                                            fn:(*) => DoLayer("4","Green","0x5CD377")},
        {id:"layer_5",          group:"csp", def:"$+5",     desc:"Layer: Pink",                                             fn:(*) => DoLayer("5","Pink","0xC11C84")},
        {id:"layer_6",          group:"csp", def:"$+6",     desc:"Layer: Uranuri/Shadow",                                   fn:(*) => DoLayer("6","Uranuri / Shadow","","{g}")},
        {id:"layer_7",          group:"csp", def:"$+7",     desc:"Layer: Paint",                                            fn:(*) => DoLayer("7","Paint")},
        {id:"layer_8",          group:"csp", def:"$+8",     desc:"Layer: Rough",                                            fn:(*) => DoLayer("8","Rough")},
        {id:"create_1",         group:"csp", def:"~!1",      desc:"Create: Paper Layer",                                    fn:(*) => ShowNotify("New Paper Layer","Alt+1")},
        {id:"create_2",         group:"csp", def:"~!2",      desc:"Create: Raster Layer",                                   fn:(*) => ShowNotify("New Raster Layer","Alt+2")},
        {id:"create_3",         group:"csp", def:"~!3",      desc:"Create: Vector Layer",                                   fn:(*) => ShowNotify("New Vector Layer","Alt+3")},
        {id:"create_4",         group:"csp", def:"~!4",      desc:"Create: Colored Vector Layer",                           fn:(*) => ShowNotify("New Colored Vector Layer","Alt+4")},
        {id:"create_5",         group:"csp", def:"~!5",      desc:"Create: Dummy Layer",                                    fn:(*) => ShowNotify("New Dummy Layer","Alt+5")},
        {id:"create_6",         group:"csp", def:"~!6",      desc:"Create: Outline for Coloring",                           fn:(*) => ShowNotify("Create Outline Layer For Coloring","Alt+6")},
        {id:"create_7",         group:"csp", def:"~!7",      desc:"Create: Pink Vector Layer",                              fn:(*) => ShowNotify("New Pink Vector Layer","Alt+7")},
        {id:"create_8",         group:"csp", def:"~!8",      desc:"Create: Cyan Vector Layer",                              fn:(*) => ShowNotify("New Cyan Vector Layer","Alt+8")},
        {id:"create_9",         group:"csp", def:"~!9",      desc:"Create: Orange Vector Layer",                            fn:(*) => ShowNotify("New Orange Vector Layer","Alt+9")},
        {id:"create_0",         group:"csp", def:"~!0",      desc:"Create: Animation Folder",                               fn:(*) => ShowNotify("New Animation Folder","Alt+0")},
        {id:"feature_kf",       group:"csp", def:"~+^1",    desc:"Feature: Set Keyframe Color",                             fn:(*) => ShowNotify("Set Layer Keyframe Color","CTRL+Shift+1")},
        {id:"feature_ref",      group:"csp", def:"~+^2",    desc:"Feature: Set Reference Color",                            fn:(*) => ShowNotify("Set Layer Reference Color","CTRL+Shift+2")},
        {id:"feature_rm",       group:"csp", def:"~+^3",    desc:"Feature: Remove Layer Color",                             fn:(*) => ShowNotify("Remove Layer Keyframe Color","CTRL+Shift+3")},
        {id:"feature_lt_color", group:"csp", def:"+^4",     desc:"Feature: Change Lightable Color",                         fn:HotkeyChangeColor},
        {id:"feature_norm",     group:"csp", def:"~+^5",    desc:"Feature: Normal Color",                                   fn:(*) => (ShowNotify("Normal Color"), ResetLT())},
        {id:"feature_act",      group:"csp", def:"~+^7",    desc:"Feature: Activate Layer Color",                           fn:(*) => ShowNotify("Activate Layer Color","CTRL+Shift+7")},
        {id:"feature_deact",    group:"csp", def:"~+^8",    desc:"Feature: Deactivate Layer Color",                         fn:(*) => ShowNotify("Deactivate Layer Color","CTRL+Shift+8")},
        {id:"transfer_raster",  group:"csp", def:"!;",      desc:"Transfer Down + Rasterize",                               fn:(*) => (Send("{;}"), Send("{Home}"), Send("^{;}"), ShowNotify("Transfer Down Vector and Rasterize"))},
        {id:"transfer_vector",  group:"csp", def:"+^!R",   desc:"Transfer Down Vector",                                     fn:(*) => (Send("{;}"), Send("{Home}"), ShowNotify("Transfer Down Vector"))},
        {id:"merge_down",       group:"csp", def:"~+^!E",  desc:"Merge Down Layer",                                         fn:(*) => ShowNotify("Merge Down Layer")},
        {id:"color_gray",       group:"csp", def:"~+^!T",  desc:"Color Expression: Gray",                                   fn:(*) => ShowNotify("Change Color Expression: Gray")},
        {id:"delete_layer",     group:"csp", def:"+^!X",   desc:"Delete Layer",                                             fn:(*) => (Send("{Del}"), ShowNotify("Delete Layer"))},
        {id:"delete_cel_tl",    group:"csp", def:"+^X",    desc:"Delete Cel from Timeline",                                 fn:(*) => (Send("^+X"), ShowNotify("Delete Cel from Timeline"))},
        {id:"delete_cel_lt",    group:"csp", def:"+X",     desc:"Delete Cel from Lighttable",                               fn:(*) => (Send("+X"), ShowNotify("Delete Cel from Lighttable"))},
        {id:"slash_command",    group:"csp", def:"!f",      desc:"Slash Command",                                           fn:(*) => Send("{/}")},
        {id:"opacity_100",      group:"csp", def:"~+B",     desc:"Opacity 100",                                             fn:(*) => ShowNotify("Opacity 100","Shift+B")},
        {id:"opacity_50",       group:"csp", def:"~!B",     desc:"Opacity 50",                                              fn:(*) => ShowNotify("Opacity 50","Alt+B")},
        {id:"opacity_25",       group:"csp", def:"~!^B",   desc:"Opacity 25",                                               fn:(*) => ShowNotify("Opacity 25","Ctrl+Alt+B")},
        {id:"toggle_layer_clr", group:"csp", def:"~^B",    desc:"Toggle Layer Color",                                       fn:(*) => ShowNotify("Toggle Layer Color","Ctrl+B")},
        {id:"duplicate_layer",  group:"csp", def:"~!^D",   desc:"Duplicate Layer",                                          fn:(*) => ShowNotify("Duplicate Layer")},
        {id:"group_folder",     group:"csp", def:"~!^G",   desc:"Create Group Folder",                                      fn:(*) => ShowNotify("Create Group Folder","CTRL+Alt+G")},
        {id:"ungroup_folder",   group:"csp", def:"~+^!G",  desc:"UnGroup Folder",                                           fn:(*) => ShowNotify("UnGroup Folder","CTRL+Alt+Shift+G")},
        {id:"toggle_onion",     group:"csp", def:"~!W",    desc:"Toggle Onion Skin",                                        fn:HotkeyToggleOnion},
        {id:"toggle_vis",       group:"csp", def:"~!V",    desc:"Toggle Layer Visibility",                                  fn:(*) => ShowNotify("Toggle Layer Visibility","Alt+V")},
        {id:"toggle_lt",        group:"csp", def:"~!^W",   desc:"Toggle Light Table",                                       fn:HotkeyToggleLT},
        {id:"onion_to_lt",      group:"csp", def:"~!+W",   desc:"Add Onionskin to Lighttable",                              fn:(*) => ShowNotify("Add Onionskin to Lighttable","Shift+Alt+W")},
        {id:"sel_transparent",  group:"csp", def:"~+^!F",  desc:"Select Transparent",                                       fn:(*) => ShowNotify("Select Transparent","","0x333333")},
        {id:"sel_red",          group:"csp", def:"~+^!C",  desc:"Select Red Line",                                          fn:(*) => ShowNotify("Select Red Line","","0xBF0000")},
        {id:"sel_green",        group:"csp", def:"~+^!V",  desc:"Select Green Line",                                        fn:(*) => ShowNotify("Select Green Line","","0x5CD377")},
        {id:"sel_blue",         group:"csp", def:"~+^!B",  desc:"Select Blue Line",                                         fn:(*) => ShowNotify("Select Blue Line","","0x487AE3")},
        {id:"color_picker",     group:"csp", def:"~+^B",   desc:"Color Picker",                                             fn:(*) => ShowNotify("Color Picker","CTRL+Shift+B")},
        {id:"ref_layer",        group:"csp", def:"~+^Q",   desc:"Set as Reference Layer",                                   fn:(*) => ShowNotify("Set as Reference Layer")},
        {id:"draft_layer",      group:"csp", def:"~+^F",   desc:"Set as Draft Layer",                                       fn:(*) => ShowNotify("Set as Draft Layer")},
        {id:"clip_below",       group:"csp", def:"~+^G",   desc:"Clip to Layer Below",                                      fn:(*) => ShowNotify("Clip to Layer Below")},
        {id:"lock_layer",       group:"csp", def:"~+^R",   desc:"Lock Layer",                                               fn:(*) => ShowNotify("Lock Layer")},
        {id:"lock_transparent", group:"csp", def:"~+^E",   desc:"Lock Layer Transparent",                                   fn:(*) => ShowNotify("Lock Layer Transparent")},
        {id:"lock_cel",         group:"csp", def:"~+^W",   desc:"Lock Animation Cel",                                       fn:(*) => ShowNotify("Lock Animation Cel")},
        {id:"swap_brush",       group:"csp", def:"~x",     desc:"Swap Brush Primary/Secondary",                             fn:HotkeySwapBrush},
        {id:"toggle_transp",    group:"csp", def:"~!C",    desc:"Toggle Brush Transparent",                                 fn:HotkeyToggleTransparent},
        {id:"reset_color",      group:"csp", def:"~+C",    desc:"Reset Color",                                              fn:(*) => ShowNotify("Reset Color","Shift+C")},
        {id:"layer_up",         group:"csp", def:"~+!Z",   desc:"Layer Up",                                                 fn:(*) => ShowNotify("Layer Up","Shift+Alt+Z","0x4CAF50")},
        {id:"layer_down",       group:"csp", def:"~+!X",   desc:"Layer Down",                                               fn:(*) => ShowNotify("Layer Down","Shift+Alt+X","0xE53935")},
        {id:"top_layer",        group:"csp", def:"~[",     desc:"Top Layer",                                                fn:(*) => ShowNotify("Top Layer","[","0x2196F3")},
        {id:"bottom_layer",     group:"csp", def:"~]",     desc:"Bottom Layer",                                             fn:(*) => ShowNotify("Bottom Layer","]","0xFB8C00")},
        {id:"guide_ib",         group:"csp", def:"^``",    desc:"Guide: InBetween",                                         fn:(*) => ShowNotify("InBetween","CTRL+1~7")},
        {id:"guide_create",     group:"csp", def:"!``",    desc:"Guide: Create New",                                        fn:(*) => ShowNotify("Create","Alt+1~3")},
        {id:"guide_shortcut",   group:"csp", def:"+``",    desc:"Guide: Shortcuts",                                         fn:(*) => ShowNotify("Shortcut","X / Alt+C / Shift+C")},
        {id:"guide_autoaction", group:"csp", def:"^+``",   desc:"Guide: AutoAction",                                        fn:(*) => ShowNotify("AutoAction","Layer Color")},
        {id:"guide_anim",       group:"csp", def:"^!``",   desc:"Guide: Animation",                                         fn:(*) => ShowNotify("Animation","Lighttable")},

        ; ---- Group: csp_nav ----
        {id:"nav_pan",          group:"csp_nav", def:"Space",      desc:"Pan Space",                                        fn:SpacePan},
        {id:"nav_pan_ctrl",     group:"csp_nav", def:"^Space",     desc:"Pan Ctrl+Space",                                   fn:SpacePanCtrl},
        {id:"nav_pan_quick",    group:"csp_nav", def:"^+Space",    desc:"Quick Space Tap",                                  fn:(*) => Send("{Space Down}{Space Up}")},
        {id:"nav_pan_shalt",    group:"csp_nav", def:"+!Space",    desc:"Pan Shift+Alt+Space",                              fn:SpacePanShiftAlt},

        ; ---- Group: csp_caps ----
        {id:"capslock_mod",     group:"csp_caps", def:"CapsLock", desc:"Capslock LT Mod",                                   fn:CapslockMod},

        ; ---- Group: csp_tab ----
        {id:"tab_paper1",       group:"csp_tab", def:"Tab & 1",    desc:"Tab+1: Paper Purple",                              fn:TabPaper1},
        {id:"tab_paper2",       group:"csp_tab", def:"Tab & 2",    desc:"Tab+2: Paper Green",                               fn:TabPaper2},
        {id:"tab_paper3",       group:"csp_tab", def:"Tab & 3",    desc:"Tab+3: Paper White",                               fn:TabPaper3},
        {id:"tab_reset_lt",     group:"csp_tab", def:"Tab & ``",    desc:"Tab+`: Reset LT",                                 fn:TabResetLT},

        ; ---- Group: csp_reset ----
        {id:"reset_mods",       group:"csp_reset", def:"^!+Space", desc:"Reset Modifier Keys",                              fn:ResetModifiers},

        ; ---- Group: global ----
        {id:"toggle_main_gui",  group:"global", def:"!F1", desc:"Toggle Main GUI",                                          fn:ToggleMainWindow},
        {id:"show_debug_log",   group:"global", def:"^!F12", desc:"Show Debug Log",                                         fn:ShowDebugGUI},
        {id:"toggle_csp_monitor",group:"global", def:"^!F11", desc:"Toggle CSP Restart Monitor",                            fn:ToggleCSPMonitor},


        ; ---- Group: bg ----
        {id:"bg_picker",        group:"bg", def:"+^B", desc:"Color Picker (bg)",                                            fn:HotkeyBGPicker},
    ]
    ; Populate sends descriptions
    for d in HotkeyDefs {
        if d.fn.Name
            d.sends := "Calls " d.fn.Name
        else if InStr(d.desc, "Send") || InStr(d.desc, "scroll") || InStr(d.desc, "Pan") || InStr(d.desc, "Space")
            d.sends := d.desc
        else if InStr(d.desc, "Toggle")
            d.sends := "Toggles " Trim(SubStr(d.desc, 8))
        else if InStr(d.desc, "Create:")
            d.sends := "ShowNotify('" Trim(SubStr(d.desc, 9)) "')"
        else if InStr(d.desc, "Layer:")
            d.sends := "Calls DoLayer() — sets layer " SubStr(d.desc, 8)
        else if InStr(d.desc, "Tab+")
            d.sends := d.desc
        else if InStr(d.desc, "Feature:")
            d.sends := "CSP feature: " Trim(SubStr(d.desc, 10))
        else if InStr(d.desc, "Guide:")
            d.sends := "ShowNotify — CSP guide for " Trim(SubStr(d.desc, 7))
        else if InStr(d.desc, "IB:")
            d.sends := "Selects inbetween type: " Trim(SubStr(d.desc, 4))
        else
            d.sends := d.desc
    }
}

; --- Load custom hotkeys from INI ---
HK_Load() {
    global HK_Custom, SETTINGS_FILE
    HK_Custom := Map()
    if !FileExist(SETTINGS_FILE)
        return
    try section := IniRead(SETTINGS_FILE, "Hotkeys")
    catch
        return
    for line in StrSplit(section, "`n") {
        if !InStr(line, "=")
            continue
        id := Trim(SubStr(line, 1, InStr(line, "=") - 1))
        val := Trim(SubStr(line, InStr(line, "=") + 1))
        HK_Custom[id] := val
    }
}

; --- Save custom hotkeys to INI ---
HK_Save() {
    global HK_Custom, SETTINGS_FILE
    IniDelete(SETTINGS_FILE, "Hotkeys")
    for id, val in HK_Custom
        IniWrite(val, SETTINGS_FILE, "Hotkeys", id)
}

; --- Get effective hotkey (custom or default) ---
HK_Get(id, def) {
    global HK_Custom
    return HK_Custom.Has(id) && HK_Custom[id] != "" ? HK_Custom[id] : def
}

; --- Re-apply overrides for all groups (call at startup + after save) ---
; Each group function is positioned under its #HotIf so Hotkey() calls get the right context.

HotIfConditionCSP(*) {
    return !HotkeysPaused && WinActive("ahk_exe CLIPStudioPaint.exe") && !IsTyping()
}
HotIfConditionNav(*) {
    return !HotkeysPaused && WinActive("ahk_exe CLIPStudioPaint.exe") && NavEnabled && !IsTyping()
}
HotIfConditionCaps(*) {
    return !HotkeysPaused && WinActive("ahk_exe CLIPStudioPaint.exe") && CapslockEnabled && !IsTyping()
}
HotIfConditionTab(*) {
    return !HotkeysPaused && WinActive("ahk_exe CLIPStudioPaint.exe") && TabCombosEnabled && !IsTyping()
}
HotIfConditionReset(*) {
    return !HotkeysPaused && WinActive("ahk_exe CLIPStudioPaint.exe") && ResetEnabled && !IsTyping()
}
HotIfConditionBG(*) {
    return !HotkeysPaused && WinExist("ahk_exe CLIPStudioPaint.exe") && !WinActive("ahk_exe CLIPStudioPaint.exe") && !IsTyping()
}
HotIfConditionLWin(*) {
    return !HotkeysPaused && WinActive("ahk_exe CLIPStudioPaint.exe") && LWinEnabled && !IsTyping()
}
HotIfConditionGlobal(*) {
    return !HotkeysPaused && !IsTyping()
}

HK_ReapplyGroup(hotifFn, groupName) {
    HotIf(hotifFn)
    for d in HotkeyDefs {
        if d.group = groupName {
            key := HK_Get(d.id, d.def)
            if HK_Registered.Has(d.id) {
                old := HK_Registered[d.id]
                if old != key
                    try Hotkey(old, "Off")
            }
            if !HK_Registered.Has(d.id) || HK_Registered[d.id] != key {
                try {
                    Hotkey(key, d.fn)
                    HK_Registered[d.id] := key
                }
            }
        }
    }
}
HK_ReapplyCSP()    => HK_ReapplyGroup(HotIfConditionCSP,    "csp")
HK_ReapplyNav()    => HK_ReapplyGroup(HotIfConditionNav,    "csp_nav")
HK_ReapplyCaps()   => HK_ReapplyGroup(HotIfConditionCaps,   "csp_caps")
HK_ReapplyTab()    => HK_ReapplyGroup(HotIfConditionTab,    "csp_tab")
HK_ReapplyReset()  => HK_ReapplyGroup(HotIfConditionReset,  "csp_reset")
HK_ReapplyLWin()   => HK_ReapplyGroup(HotIfConditionLWin,   "csp_lwin")
HK_ReapplyGlobal() => HK_ReapplyGroup(HotIfConditionGlobal, "global")
HK_ReapplyBG()     => HK_ReapplyGroup(HotIfConditionBG,     "bg")

HK_ReapplyAll() {
    HK_ReapplyCSP()
    HK_ReapplyNav()
    HK_ReapplyCaps()
    HK_ReapplyTab()
    HK_ReapplyReset()
    HK_ReapplyLWin()
    HK_ReapplyGlobal()
    HK_ReapplyBG()
}

; ============================================================
; AUTO-EXECUTE (runs at startup)
; ============================================================

OnMessage(0x201, WM_LBUTTONDOWN)
OnMessage(0x200, WM_MOUSEMOVE)
OnMessage(0x0232, WM_EXITSIZEMOVE)

InitHotkeyDefs()
HK_Load()

LoadConfigurablePaths()  ; loads paths, URLs, click coords from INI
InitHoverPopup()
LoadLinkItems()
LoadGUIPositions()
CreateIBGui()
CreateColorGui()
CreateLinkGUI()
IB_PositionGui()
PositionColorGui()
PositionLinkGUI()

CreateMainGui()

; Show all GUIs at startup only if CSP is running
if WinExist("ahk_exe CLIPStudioPaint.exe") {
    if IsObject(IB_GUI)
        IB_GUI.Show("NoActivate")
    if IsObject(ColorGUI)
        ColorGUI.Show("NoActivate")
    if IsObject(LinkGUI)
        LinkGUI.Show("NoActivate")
    if IsObject(MainGUI)
        MainGUI.Show("NoActivate")
    MainGUIVisible := true
    ColorGUIVisible := true
    LinkGUIVisible := true
    IBVisible := true
} else {
    if IsObject(IB_GUI)   IB_GUI.Hide()
    if IsObject(ColorGUI) ColorGUI.Hide()
    if IsObject(LinkGUI)  LinkGUI.Hide()
    MainGUIVisible := false
    ColorGUIVisible := false
    LinkGUIVisible := false
    IBVisible := false
}
if IsObject(MainGUI) {
    if HasProp(MainGUI, "btnIB")
        MainGUI.btnIB.Opt("Background4CAF50 cFFFFFF")
    if HasProp(MainGUI, "btnLink")
        MainGUI.btnLink.Opt("Background4CAF50 cFFFFFF")
    if HasProp(MainGUI, "btnColor")
        MainGUI.btnColor.Opt("Background4CAF50 cFFFFFF")
}

; Start CSP focus monitor for timer auto-pause/resume
SetTimer(CheckCSPFocus, 1000)
CheckCSPFocus()

; First run: center all GUIs
if !FileExist(SETTINGS_FILE)
    ResetGUIPositions()

; Apply custom hotkey overrides on top of :: defaults
HK_ReapplyAll()

SetTimer(DoAutoSave, AutoSaveInterval * 1000)

OnExit((*) => (
    SaveGUIPositions(),
    _debugSaveOnExit && SaveDebugLog(),
    SaveConfigurablePaths(),
    HK_Save(),
    SaveLinkItems()
))

SetTimer(CheckCSP, 200)
; First-run wizard
if !FileExist(SETTINGS_FILE)
    SetTimer(FirstRunWizard, -100)

; ============================================================
; CORE FUNCTIONS — CSP state & light table helpers
; ============================================================

IsLTActive() {
    global LT_X, LT_Y, LT_Color
    return PixelGetColor(LT_X, LT_Y) == LT_Color
}

ResetLT() {
    global InbetweenIndex
    Send("{Ctrl Down}{Shift Down}{Alt Down}{w}{Ctrl Up}{Shift Up}{Alt Up}")
    UpdateIBGui(InbetweenIndex)
}

EnsureLT() {
    if IsLTActive()
        ResetLT()
}

NormalizeInbetweenMode(mode) {
    return mode = "Start > End" ? "Start > End" : "End > Start"
}

BuildInbetweenData(mode) {
    mode := NormalizeInbetweenMode(mode)
    if mode = "Start > End" {
        return Map(
            1, {bar:"50 |-----|-----|>", desc:"50", color:"0x000000"},
            2, {bar:"66 |-------|---|>", desc:"Start > End", color:"0x81C784"},
            3, {bar:"33 |---|-------|>", desc:"Start > End", color:"0x795548"},
            4, {bar:"75 |--------|--|>", desc:"Start > End", color:"0x43A047"},
            5, {bar:"25 |--|--------|>", desc:"Start > End", color:"0x5D4037"},
            6, {bar:"60 |------|----|>", desc:"Start > End", color:"0x2E7D32"},
            7, {bar:"40 |----|------|>", desc:"Start > End", color:"0xFFB300"}
        )
    }
    return Map(
        1, {bar:"50 |-----|-----|>", desc:"50", color:"0x000000"},
        2, {bar:"33 |---|-------|>", desc:"End > Start", color:"0x81C784"},
        3, {bar:"66 |-------|---|>", desc:"End > Start", color:"0x795548"},
        4, {bar:"25 |--|--------|>", desc:"End > Start", color:"0x43A047"},
        5, {bar:"75 |--------|--|>", desc:"End > Start", color:"0x5D4037"},
        6, {bar:"40 |----|------|>", desc:"End > Start", color:"0x2E7D32"},
        7, {bar:"60 |------|----|>", desc:"End > Start", color:"0xFFB300"}
    )
}

DoLayer(key, name, color:="", extra:="") {
    EnsureLT()
    Send("{Enter}")
    Send("+" key)
    if extra
        Send(extra)
    ShowNotify(name, "Shift+" key, color)
}

CheckCSP() {
    global IB_GUI, ColorGUI, LinkGUI
    global IBVisible, ColorGUIVisible, LinkGUIVisible
    global IBManualHide, LinkManualHide, ColorManualHide
    global CSPActive, IB_LTInd, LTLock, CSP_PID
    global GUIEnabled, GUIVisible, MainGUIVisible
    global LT_ClickX, LT_ClickY
    global NavEnabled, NavBtn, CapslockEnabled, CapslockBtn, TabCombosEnabled, TabCombosBtn, LWinEnabled, LWinBtn
    global IB_Opacity, Color_Opacity, Link_Opacity
    global _timerRunning
    _pid := DllCall("GetCurrentProcessId")

    ; --- Process guard: detect CSP restart ---
    cspHwnd := WinExist("ahk_exe CLIPStudioPaint.exe")
    if cspHwnd {
        pid := WinGetPID(cspHwnd)
        if pid != CSP_PID && CSP_PID != 0
            CSPActive := false
        CSP_PID := pid
    }

    isCSP   := WinExist("ahk_exe CLIPStudioPaint.exe") && WinActive("ahk_exe CLIPStudioPaint.exe")
    isIB    := SafeGuiHwnd(IB_GUI) && WinActive("ahk_id " SafeGuiHwnd(IB_GUI))
    isColor := SafeGuiHwnd(ColorGUI) && WinActive("ahk_id " SafeGuiHwnd(ColorGUI))
    isLink  := SafeGuiHwnd(LinkGUI) && WinActive("ahk_id " SafeGuiHwnd(LinkGUI))
    isScriptDlg := WinExist("A") && (WinGetPID("A") = _pid) && !isCSP && !isIB && !isColor && !isLink

    ; --- State tracking ---
    if isCSP
        CSPActive := true

    ; --- LT indicator ---
    if IsObject(IB_GUI) {
        static _prevState := -1
        ltOn := CSPActive && IsLTActive()
        newState := LTLock || !ltOn
        if newState != _prevState {
            _prevState := newState
            IB_LTInd.Opt("Background" (newState ? "E53935" : "42A5F5"))
        }
    }

    ; --- LT Lock: auto-kill LT when active ---
    if LTLock && CSPActive && IsLTActive() {
        static _lockLastAction := 0
        if A_TickCount - _lockLastAction > 800 {
            _lockLastAction := A_TickCount
            MouseClick "left", LT_ClickX, LT_ClickY
            Sleep 50
            ResetLT()
        }
    }

    ; --- Show / Hide GUIs based on CSP focus ---
    if GUIEnabled {
        showGUI := isCSP || (CSPActive && (isIB || isColor || isLink))
        if showGUI || isScriptDlg {
            if !isScriptDlg
                CSPActive := true
            if !IBVisible && !IBManualHide {
                if IsObject(IB_GUI)   IB_GUI.Show("NoActivate")
                IBVisible := true
                GUIVisible := true
                if IsObject(MainGUI) && IsObject(MainGUI.btnIB)
                    MainGUI.btnIB.Opt("Background4CAF50 cFFFFFF")
                DebugLog("IB auto-shown (opacity " IB_Opacity ")")
            }
            if !ColorGUIVisible && !ColorManualHide {
                if IsObject(ColorGUI) ColorGUI.Show("NoActivate")
                ColorGUIVisible := true
                GUIVisible := true
                if IsObject(MainGUI) && IsObject(MainGUI.btnColor)
                    MainGUI.btnColor.Opt("Background4CAF50 cFFFFFF")
                DebugLog("Color auto-shown (opacity " Color_Opacity ")")
            }
            if !LinkGUIVisible && !LinkManualHide {
                if IsObject(LinkGUI)  LinkGUI.Show("NoActivate")
                LinkGUIVisible := true
                GUIVisible := true
                if IsObject(MainGUI) && IsObject(MainGUI.btnLink)
                    MainGUI.btnLink.Opt("Background4CAF50 cFFFFFF")
                DebugLog("Link auto-shown (opacity " Link_Opacity ")")
            }
            if MainGUIVisible && !IsGuiVisibleSafe(MainGUI)
                MainGUI.Show("NoActivate")
        } else if IBVisible || ColorGUIVisible || LinkGUIVisible
            || IsGuiVisibleSafe(IB_GUI)
            || IsGuiVisibleSafe(ColorGUI)
            || IsGuiVisibleSafe(LinkGUI) {
            if IsObject(IB_GUI)    IB_GUI.Hide()
            if IsObject(ColorGUI)  ColorGUI.Hide()
            if IsObject(LinkGUI)   LinkGUI.Hide()
            IBVisible := false
            IBManualHide := false
            ColorGUIVisible := false
            ColorManualHide := false
            LinkGUIVisible := false
            LinkManualHide := false
            GUIVisible := false
            if IsGuiVisibleSafe(MainGUI)
                MainGUI.Hide()
            if _timerRunning
                DebugLog("GUIs auto-hidden (CSP focus lost), timer active")
            else
                DebugLog("GUIs auto-hidden (CSP focus lost)")
        }
        if CSPActive && !showGUI && !isScriptDlg
            CSPActive := false
    }

    ; --- CSP auto-restart monitor ---
    if CSP_RestartMonitor && !cspHwnd && CSP_PID != 0 {
        CSP_PID := 0
        DebugLog("CSP process detected missing, attempting restart...")
        if MsgBox("CSP appears to have closed. Restart it?", "CSP Monitor", "0x1 0x30") = "Yes"
            Run("C:\Program Files\CELSYS\CLIP STUDIO 1.5\CLIP STUDIO\CLIPStudioPaint.exe")
    }

    ; --- Auto-disable Nav/Capslock/Tab/LWin when typing ---
    if isCSP {
        static _prevNav := false, _prevCaps := false, _prevTab := false, _prevLWin := false
        if IsTyping() {
            if NavEnabled {
                _prevNav := true
                NavEnabled := false
                if IsObject(NavBtn) {
                    NavBtn.Text := "🚫"
                    NavBtn.Opt("Background2A2A2A cFFFFFF")
                }
            }
            if CapslockEnabled {
                _prevCaps := true
                CapslockEnabled := false
                if IsObject(CapslockBtn) {
                    CapslockBtn.Text := "🚫"
                    CapslockBtn.Opt("Background2A2A2A cFFFFFF")
                }
            }
            if TabCombosEnabled {
                _prevTab := true
                TabCombosEnabled := false
                if IsObject(TabCombosBtn) {
                    TabCombosBtn.Text := "🚫"
                    TabCombosBtn.Opt("Background2A2A2A cFFFFFF")
                }
            }
            if LWinEnabled {
                _prevLWin := true
                LWinEnabled := false
                if IsObject(LWinBtn) {
                    LWinBtn.Text := "🚫"
                    LWinBtn.Opt("Background2A2A2A cFFFFFF")
                }
            }
        } else {
            if _prevNav && !NavEnabled {
                _prevNav := false
                NavEnabled := true
                if IsObject(NavBtn) {
                    NavBtn.Text := "🖐"
                    NavBtn.Opt("BackgroundE65100 cFFFFFF")
                }
            }
            if _prevCaps && !CapslockEnabled {
                _prevCaps := false
                CapslockEnabled := true
                if IsObject(CapslockBtn) {
                    CapslockBtn.Text := "⇪"
                    CapslockBtn.Opt("Background1565C0 cFFFFFF")
                }
            }
            if _prevTab && !TabCombosEnabled {
                _prevTab := false
                TabCombosEnabled := true
                if IsObject(TabCombosBtn) {
                    TabCombosBtn.Text := "Tab"
                    TabCombosBtn.Opt("Background2E7D32 cFFFFFF")
                }
            }
            if _prevLWin && !LWinEnabled {
                _prevLWin := false
                LWinEnabled := true
                if IsObject(LWinBtn) {
                    LWinBtn.Text := "⊞"
                    LWinBtn.Opt("BackgroundFF6F00 cFFFFFF")
                }
            }
        }
    }
}

; ============================================================
; NOTIFICATION SYSTEM
; ============================================================

ShowNotify(t, s:="", c:="") {
    global NotifyBase
    static _lastT := "", _lastTime := 0
    if t = _lastT && A_TickCount - _lastTime < 1200
        return
    _lastT := t
    _lastTime := A_TickCount
    Notify.Show(t, s,,,, 'pos=TC dur=1 ts=10 ms=7 pad=8,4,6,6,6,6,2,3 mf=Segoe UI Black mfo=norm Bold mali=Center' NotifyBase (c ? " bc=" c : ""))
}

DebugLog(msg) {
    global _debugLog, _debugDateShown
    if !_debugDateShown {
        d := FormatTime(, "dd-MM-yyyy HH:mm:ss")
        w := FormatTime(, "dddd")
        _debugLog.Push("=== " w " " d " ===")
        _debugDateShown := true
    }
    _debugLog.Push(FormatTime(, "HH:mm:ss") " " msg)
    if _debugLog.Length > 500
        _debugLog.RemoveAt(1)
}

ShowDebugGUI(*) {
    global _debugLog, _debugGUI, _debugSaveOnExit, _debugDateShown, SETTINGS_FILE
    if IsObject(_debugGUI) {
        _debugGUI.Show()
        SetTimer(_DebugAutoRefresh, 2000)
        return
    }
    _debugGUI := Gui("+AlwaysOnTop +ToolWindow", "Debug Log")
    _debugGUI.BackColor := "1E1F22"
    _debugGUI.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    _debugGUI.MarginX := S(6)
    _debugGUI.MarginY := S(6)
    _debugGUI.SetFont("s" S(8) " c000000", "Consolas")
    ed := _debugGUI.AddEdit("xm w" S(600) " h" S(330) " +ReadOnly -Wrap BackgroundFFFFFF", "")
    ed.SetFont("s" S(8) " c000000", "Consolas")
    _debugGUI.ed := ed
    _debugGUI.OnEvent("Close", (*) => (_debugGUI.Destroy(), _debugGUI := 0))
    _debugGUI.SetFont("s" S(8) " cFFFFFF", "Segoe UI")

    _debugGUI.AddButton("xm w" S(60) " h" S(22), "Refresh").OnEvent("Click", _DebugRefresh)
    _debugGUI.AddButton("x+" S(6) " yp w" S(55) " h" S(22), "Clear").OnEvent("Click", (*) => (
        _debugLog := [],
        _debugDateShown := false,
        ed.Value := ""
    ))
    _debugGUI.AddButton("x+" S(6) " yp w" S(55) " h" S(22), "Save").OnEvent("Click", (*) => _DebugSave())
    _debugGUI.AddButton("x+" S(6) " yp w" S(55) " h" S(22), "Close").OnEvent("Click", (*) => (_debugGUI.Destroy(), _debugGUI := 0))
    cb := _debugGUI.AddCheckbox("x+" S(12) " yp+1 Background1E1F22 cCCCCCC", "Save on exit")
    cb.Value := _debugSaveOnExit
    cb.OnEvent("Click", _DebugSaveOnExitToggle)
    _txt := ""
    for v in _debugLog
        _txt := v "`n" _txt
    ed.Value := RTrim(_txt, "`n")
    _debugGUI.Show("w" S(620) " h" S(380))
    SetTimer(_DebugAutoRefresh, 2000)
}

_DebugSaveOnExitToggle(ctrl, *) {
    global _debugSaveOnExit, SETTINGS_FILE
    _debugSaveOnExit := ctrl.Value
    IniWrite(_debugSaveOnExit, SETTINGS_FILE, "Settings", "DebugSaveOnExit")
}

_DebugRefresh(*) {
    global _debugLog
    _txt := ""
    for v in _debugLog
        _txt := v "`n" _txt
    _debugGUI.ed.Value := RTrim(_txt, "`n")
}

_DebugAutoRefresh(*) {
    global _debugGUI, _debugLog
    if !IsObject(_debugGUI) {
        SetTimer(_DebugAutoRefresh, 0)
        return
    }
    if !IsObject(_debugGUI.ed)
        return
    _txt := ""
    for v in _debugLog
        _txt := v "`n" _txt
    _debugGUI.ed.Value := RTrim(_txt, "`n")
}

_DebugSave() {
    global _debugLog
    if _debugLog.Length = 0
        return
    ts := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    def := A_MyDocuments "\CSPtoolkit_debug_log_" ts ".txt"
    fp := FileSelect("S", def, "Save Debug Log", "Text (*.txt)")
    if fp = ""
        return
    _txt := ""
    for v in _debugLog
        _txt .= v "`n"
    try FileAppend(RTrim(_txt, "`n") "`n", fp)
    ShowNotify("Debug Log", "Saved")
}

SaveDebugLog() {
    global _debugLog
    if _debugLog.Length = 0
        return
    ts := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    fp := A_MyDocuments "\CSPtoolkit_debug_log_" ts ".txt"
    _txt := ""
    for v in _debugLog
        _txt .= v "`n"
    try FileAppend(RTrim(_txt, "`n") "`n", fp)
}

SendColor(keys, label, desc:="", color:="") {
    global NotifyBase
    if WinExist("ahk_exe CLIPStudioPaint.exe") {
        WinActivate("ahk_exe CLIPStudioPaint.exe")
        WinWaitActive("ahk_exe CLIPStudioPaint.exe",, 0.5)
        Send(keys)
        hasColor := (Type(color)="String" && RegExMatch(color, "^0x[0-9A-Fa-f]{6}$"))
    } else {
        Notify.Show("CSP not found", "Open Clip Studio Paint first",,,, NotifyBase " bc=0xC80207")
        return
    }
    opt := NotifyBase (hasColor ? " bc=" color : "")
    Notify.Show(label, desc,,,, opt)
}

; ============================================================
; GUI — Hover Popup
; ============================================================

InitHoverPopup() {
    global _hoverPopup
    _hoverPopup := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x08000020 +Owner")
    _hoverPopup.BackColor := "1E1F22"
    _hoverPopup.SetFont("s" S(9), "Segoe UI")
    _hoverPopup.MarginX := S(8)
    _hoverPopup.MarginY := S(4)
    _hoverPopup.textCtrl := _hoverPopup.AddText("w" S(280) " cFFFFFF Wrap", "")
}

AddHoverPopup(ctrl, text) {
    global _hoverMap
    _hoverMap[ctrl.Hwnd] := text
}

_HoverShowPending() {
    global _hoverMap, _hoverPopup, _hoverPending, _hoverPendingX, _hoverPendingY
    if _hoverPending && _hoverMap.Has(_hoverPending) {
        text := StrReplace(_hoverMap[_hoverPending], "\n", Chr(10))
        _hoverPopup.textCtrl.Text := text

        hFont := SendMessage(0x0031, 0, 0, _hoverPopup.textCtrl)
        if !hFont
            hFont := DllCall("GetStockObject", "Int", 17)
        hdc := DllCall("GetDC", "Ptr", _hoverPopup.textCtrl.Hwnd, "Ptr")
        oldFont := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont)

        rect := Buffer(16)
        maxW := 0
        for line in StrSplit(text, "`n") {
            NumPut("Int", 0, rect, 0)
            NumPut("Int", 0, rect, 4)
            NumPut("Int", 0, rect, 8)
            NumPut("Int", 0, rect, 12)
            DllCall("DrawTextW", "Ptr", hdc, "Str", line, "Int", -1, "Ptr", rect, "UInt", 0x0400)
            lineW := NumGet(rect, 8, "Int")
            if lineW > maxW
                maxW := lineW
        }

        pad := S(16)
        ctrlW := Max(S(40), Min(maxW + pad, S(400)))

        NumPut("Int", 0, rect, 0)
        NumPut("Int", 0, rect, 4)
        NumPut("Int", ctrlW, rect, 8)
        NumPut("Int", 0, rect, 12)
        DllCall("DrawTextW", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", rect, "UInt", 0x0440)
        needH := NumGet(rect, 12, "Int")

        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont)
        DllCall("ReleaseDC", "Ptr", _hoverPopup.textCtrl.Hwnd, "Ptr", hdc)

        ctrlH := Max(S(20), needH)
        _hoverPopup.textCtrl.Move(,, ctrlW, ctrlH)

        winW := ctrlW + _hoverPopup.MarginX * 2
        winH := ctrlH + _hoverPopup.MarginY * 2
        _hoverPopup.Show("NA x" _hoverPendingX + 16 " y" _hoverPendingY + 20 " w" winW " h" winH)
        DllCall("SetWindowPos", "Ptr", _hoverPopup.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0002 | 0x0001)
        SetTimer(_HoverCheck, 200)
    }
    _hoverPending := 0
}

_HoverCheck() {
    global _hoverMap, _hoverPopup
    MouseGetPos(,,, &ctrlHwnd, 2)
    if !_hoverMap.Has(ctrlHwnd) && ctrlHwnd != _hoverPopup.textCtrl.Hwnd && ctrlHwnd != _hoverPopup.Hwnd {
        HoverPopClose()
    }
}

HoverPopClose() {
    global _hoverPopup, _hoverLast, _hoverPending
    _hoverLast := 0
    _hoverPending := 0
    SetTimer(_HoverShowPending, 0)
    SetTimer(_HoverCheck, 0)
    try _hoverPopup.Hide()
}

WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global _hoverMap, _hoverPopup, _hoverLast, _hoverPending, _hoverPendingX, _hoverPendingY
    static lastCursor := 0

    MouseGetPos(,,, &ctrlHwnd, 2)
    pt := Buffer(8)
    NumPut("Int", lParam & 0xFFFF, pt, 0)
    NumPut("Int", lParam >> 16, pt, 4)
    DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt)
    mx := NumGet(pt, 0, "Int")
    my := NumGet(pt, 4, "Int")

    ; --- Hover popup ---
    if _hoverMap.Has(ctrlHwnd) {
        if _hoverLast != ctrlHwnd {
            _hoverLast := ctrlHwnd
            _hoverPending := ctrlHwnd
            _hoverPendingX := mx
            _hoverPendingY := my
            SetTimer(_HoverShowPending, 0)
            try _hoverPopup.Hide()
            SetTimer(_HoverShowPending, -500)
        } else if _hoverPending {
            _hoverPendingX := mx
            _hoverPendingY := my
            SetTimer(_HoverShowPending, -500)
        } else if DllCall("IsWindowVisible", "Ptr", _hoverPopup.Hwnd) {
            WinMove(mx + 16, my + 20,,, "ahk_id " _hoverPopup.Hwnd)
        }
    } else if ctrlHwnd != _hoverPopup.textCtrl.Hwnd && ctrlHwnd != _hoverPopup.Hwnd {
        _hoverLast := 0
        _hoverPending := 0
        SetTimer(_HoverShowPending, 0)
        SetTimer(_HoverCheck, 0)
        try _hoverPopup.Hide()
    }

    ; --- Hand cursor on GUI windows ---
    if IsMyGui(hwnd) {
        if lastCursor != hwnd {
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32649, "Ptr"))
            lastCursor := hwnd
        }
    } else {
        if lastCursor != 0 {
            DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Int", 32512, "Ptr"))
            lastCursor := 0
        }
    }
}

; --- Cursor Color Info ---
global _ccActive := false
global _ccGUI := 0
global _ccTickFn := 0
global _ccLastHex := ""
global _ccOffsetX := 16
global _ccOffsetY := 20

HexToRGB(hex) {
    return {r: Integer("0x" SubStr(hex,1,2)), g: Integer("0x" SubStr(hex,3,2)), b: Integer("0x" SubStr(hex,5,2))}
}

GetCursorPosForCapture(&x, &y) {
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    x := NumGet(pt, 0, "Int")
    y := NumGet(pt, 4, "Int")
}

GetColorAtPhysical(x, y) {
    hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
    if !hDC
        return -1
    bgr := DllCall("GetPixel", "Ptr", hDC, "Int", x, "Int", y, "UInt")
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
    if bgr = 0xFFFFFFFF
        return -1
    return ((bgr & 0xFF) << 16) | (bgr & 0x00FF00) | ((bgr >> 16) & 0xFF)
}

GetColorUnderCursor() {
    old := DllCall("User32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    GetCursorPosForCapture(&x, &y)
    c := GetColorAtPhysical(x, y)
    if old
        DllCall("User32\SetThreadDpiAwarenessContext", "Ptr", old, "Ptr")
    if c = -1
        return "000000"
    return Format("{:06X}", c)
}

ToggleColorInfo(*) {
    global _ccActive, _ccGUI, _ccTickFn, _ccLastHex, _ccBtn, _ccBtnIB
    _ccActive := !_ccActive
    if _ccActive {
        _ccLastHex := ""
        if !IsObject(_ccGUI)
            CreateColorInfoGUI()
        _ccTickFn := ColorInfoTick
        SetTimer(_ccTickFn, 30)
        _ccGUI.Show("NoActivate")
        if IsObject(_ccBtnIB)
            _ccBtnIB.Opt("Background9C27B0 cFFFFFF")
        DebugLog("Color info ON")
    } else {
        SetTimer(_ccTickFn, 0)
        if IsObject(_ccGUI)
            _ccGUI.Hide()
        if IsObject(_ccBtnIB)
            _ccBtnIB.Opt("Background444444 cFFFFFF")
        DebugLog("Color info OFF")
    }
}

CreateColorInfoGUI() {
    global _ccGUI
    _ccGUI := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    _ccGUI.BackColor := "2D2D32"
    _ccGUI.SetFont("s9", "Consolas")
    _ccGUI.MarginX := 6
    _ccGUI.MarginY := 4
    _ccGUI.preview := _ccGUI.AddProgress("xm y+4 w36 h36", 100)
    _ccGUI.hexText := _ccGUI.AddText("xp+44 yp+2 w110 h16 cFFFFFF", "#000000")
    _ccGUI.rgbText := _ccGUI.AddText("xp yp+18 w110 h16 cAAAAAA", "RGB: 0,0,0")
}

ColorInfoTick(*) {
    global _ccActive, _ccGUI, _ccLastHex
    if !_ccActive
        return
    if !IsObject(_ccGUI) {
        _ccActive := false
        SetTimer(_ccTickFn, 0)
        return
    }
    hex := GetColorUnderCursor()
    if hex != _ccLastHex {
        _ccLastHex := hex
        rgb := HexToRGB(hex)
        _ccGUI.preview.Opt("c" hex)
        _ccGUI.hexText.Value := "#" hex
        _ccGUI.rgbText.Value := "RGB: " rgb.r "," rgb.g "," rgb.b
    }
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", pt)
    mx := NumGet(pt, 0, "Int")
    my := NumGet(pt, 4, "Int")
    _ccGUI.GetPos(,, &w, &h)
    global _ccOffsetX, _ccOffsetY
    x := mx + _ccOffsetX
    y := my + _ccOffsetY
    mon := GetMonitorFromPoint(mx, my)
    MonitorGetWorkArea(mon, &mL, &mT, &mR, &mB)
    if x + w > mR
        x := mx - w - _ccOffsetX
    if y + h > mB
        y := my - h - _ccOffsetY
    _ccGUI.Show("NoActivate x" x " y" y)
}

ShowColorInfoOffsetDialog(*) {
    global _ccOffsetX, _ccOffsetY
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Color Info Offset")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.AddText("xm", "X offset:")
    xEd := dlg.AddEdit("x+8 w60 c000000 BackgroundFFFFFF Number", _ccOffsetX)
    dlg.AddText("xm y+" S(4), "Y offset:")
    yEd := dlg.AddEdit("x+8 w60 c000000 BackgroundFFFFFF Number", _ccOffsetY)
    dlg.AddButton("xm y+" S(8) " w70 Default", "OK").OnEvent("Click", _CCSaveOffset.Bind(dlg, xEd, yEd))
    dlg.AddButton("x+10 w70", "Cancel").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize Center")
}

GetMonitorFromPoint(x, y) {
    count := MonitorGetCount()
    Loop count {
        MonitorGetWorkArea(A_Index, &L, &T, &R, &B)
        if x >= L && x <= R && y >= T && y <= B
            return A_Index
    }
    return 1
}

_CCSaveOffset(dlg, xEd, yEd, *) {
    global _ccOffsetX, _ccOffsetY
    try {
        _ccOffsetX := Integer(xEd.Value)
        _ccOffsetY := Integer(yEd.Value)
    } catch
        return
    IniWrite(_ccOffsetX, SETTINGS_FILE, "ColorInfo", "OffsetX")
    IniWrite(_ccOffsetY, SETTINGS_FILE, "ColorInfo", "OffsetY")
    dlg.Destroy()
}

; ============================================================
; GUI — Window Dragging
; ============================================================

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global ColorGUI, IB_GUI, LinkGUI, MainGUI
    if IsMyGui(hwnd) {
        MouseGetPos(,,, &ctrlHwnd, 2)
        if !ctrlHwnd
            PostMessage(0xA1, 2,,, "ahk_id " hwnd)
        else if IsObject(LinkGUI) && LinkGUI.HasProp("dragBottom") && ctrlHwnd = LinkGUI.dragBottom.Hwnd
            PostMessage(0xA1, 2,,, "ahk_id " hwnd)
        else if IsObject(IB_GUI) && IB_GUI.HasProp("dragBottom") && ctrlHwnd = IB_GUI.dragBottom.Hwnd
            PostMessage(0xA1, 2,,, "ahk_id " hwnd)
        else if IsObject(ColorGUI) && ColorGUI.HasProp("dragBottom") && ctrlHwnd = ColorGUI.dragBottom.Hwnd
            PostMessage(0xA1, 2,,, "ahk_id " hwnd)
        else if IsObject(MainGUI) && MainGUI.HasProp("dragBottom") && ctrlHwnd = MainGUI.dragBottom.Hwnd
            PostMessage(0xA1, 2,,, "ahk_id " hwnd)
    }
}

WM_EXITSIZEMOVE(wParam, lParam, msg, hwnd) {
    global IB_GUI, ColorGUI, LinkGUI, MainGUI
    if IsMyGui(hwnd)
        SaveGUIPositions()
}

IsMyGui(hwnd) {
    global IB_GUI, ColorGUI, LinkGUI, MainGUI
    return hwnd && hwnd = SafeGuiHwnd(IB_GUI)
        || hwnd && hwnd = SafeGuiHwnd(ColorGUI)
        || hwnd && hwnd = SafeGuiHwnd(LinkGUI)
        || hwnd && hwnd = SafeGuiHwnd(MainGUI)
}

SafeGuiHwnd(guiObj) {
    if !IsObject(guiObj)
        return 0
    try return guiObj.Hwnd
    catch
        return 0
}

IsGuiVisibleSafe(guiObj) {
    hwnd := SafeGuiHwnd(guiObj)
    return hwnd && DllCall("IsWindowVisible", "Ptr", hwnd)
}

; ============================================================
; GUI — Inbetween (IB) Bar
; ============================================================

CreateIBGui() {
    global IB_GUI, IB_Text, IB_LTInd, IB_Buttons, InbetweenData, IB_ModeBtn
    global IB_LockBtn, AutoSaveBtn, NavBtn, CapslockBtn, TabCombosBtn, ResetBtn, LWinBtn, _timerDisplay, _tmrPlay, _tmrPause, _rBtn, _saveBtn, _ccBtnIB

    IB_GUI := Gui("+AlwaysOnTop -Caption +ToolWindow")
    IB_GUI.BackColor := "1E1E1E"
    IB_GUI.SetFont("s" S(8) " cFFFFFF", "Segoe UI")

    btnW := S(20)
    btnH := S(18)
    gap := S(2)

    ; --- Row 1: LT indicator + IB text + Nav / Capslock / Tab / LWin ---
    IB_LTInd := IB_GUI.AddText("xm w" S(6) " h" S(22) " 0x200 BackgroundE53935")
    IB_Text := IB_GUI.AddText("x+0 yp w" S(116) " h" S(22) " 0x200 Center cFFFFFF Background252525", "50 |-----|-----|>")

    IB_ModeBtn := IB_GUI.AddText("x+" S(4) " yp w" S(28) " h" S(22) " Center +0x200 Background455A64 cFFFFFF", InbetweenModeLabel())
    IB_ModeBtn.SetFont("s" S(6) " Bold", "Segoe UI")
    IB_ModeBtn.OnEvent("Click", ToggleInbetweenMode)
    AddHoverPopup(IB_ModeBtn, "Toggle IB direction`nS>E: smaller layer above edit`nE>S: bigger layer above edit")

    NavBtn := IB_GUI.AddText("x+" S(6) " yp w" btnW " h" S(22) " Center +0x200 BackgroundE65100 cFFFFFF", "🖐")
    NavBtn.SetFont("s" S(7), "Segoe UI")
    NavBtn.OnEvent("Click", ToggleNav)
    AddHoverPopup(NavBtn, "Toggle Space Nav`n(Ctrl+F5)")

    CapslockBtn := IB_GUI.AddText("x+" S(4) " yp w" btnW " h" S(22) " Center +0x200 Background1565C0 cFFFFFF", "⇪")
    CapslockBtn.SetFont("s" S(7), "Segoe UI")
    CapslockBtn.OnEvent("Click", ToggleCapslock)
    AddHoverPopup(CapslockBtn, "Toggle Capslock LT mod`n(Ctrl+F6)")

    TabCombosBtn := IB_GUI.AddText("x+" S(4) " yp w" btnW " h" S(22) " Center +0x200 Background2E7D32 cFFFFFF", "Tab")
    TabCombosBtn.SetFont("s" S(6), "Segoe UI")
    TabCombosBtn.OnEvent("Click", ToggleTabCombos)
    AddHoverPopup(TabCombosBtn, "Toggle Tab combos`n(Ctrl+F7)")

    LWinBtn := IB_GUI.AddText("x+" S(4) " yp w" btnW " h" S(22) " Center +0x200 BackgroundFF6F00 cFFFFFF", "⊞")
    LWinBtn.SetFont("s" S(6), "Segoe UI")
    LWinBtn.OnEvent("Click", ToggleLWin)
    AddHoverPopup(LWinBtn, "Toggle LWin Right-click`n(Ctrl+F9)")

    ; --- Row 2: Inbetween number buttons + Lock / AutoSave / ColorInfo / Reset ---
    IB_Buttons := []
    i := 0
    for index, d in InbetweenData {
        RegExMatch(d.bar, "^\d+", &m)
        num := m[0]
        if i = 0
            btn := IB_GUI.AddText("xm y+" S(4) " w" btnW " h" btnH " Center +0x200", num)
        else
            btn := IB_GUI.AddText("x+" gap " yp w" btnW " h" btnH " Center +0x200", num)
        btn.SetFont("s" S(7) " Bold", "Segoe UI")
        btn.Opt("Background2A2A2A cCCCCCC")
        btn.index := index
        btn.OnEvent("Click", IB_SelectClick)
        IB_Buttons.Push(btn)
        i++
    }

    IB_LockBtn := IB_GUI.AddText("x+" S(6) " yp w" btnW " h" btnH " Center +0x200 Background2A2A2A cAAAAAA", "🔓")
    IB_LockBtn.SetFont("s" S(7), "Segoe UI")
    IB_LockBtn.OnEvent("Click", ToggleLTLock)
    AddHoverPopup(IB_LockBtn, "Toggle LT Lock`n(Ctrl+F2)")

    AutoSaveBtn := IB_GUI.AddText("x+" S(4) " yp w" btnW " h" btnH " Center +0x200 Background2A2A2A cAAAAAA", "💤")
    AutoSaveBtn.SetFont("s" S(7), "Segoe UI")
    AutoSaveBtn.OnEvent("Click", ToggleAutoSave)
    AddHoverPopup(AutoSaveBtn, "Toggle Auto Save`n(Ctrl+F4)")

    _ccBtnIB := IB_GUI.AddText("x+" S(4) " yp w" btnW " h" btnH " Center +0x200 Background444444 cFFFFFF", "◎")
    _ccBtnIB.SetFont("s" S(7), "Segoe UI")
    _ccBtnIB.OnEvent("Click", ToggleColorInfo)
    AddHoverPopup(_ccBtnIB, "Toggle Cursor Color Info")

    ResetBtn := IB_GUI.AddText("x+" S(4) " yp w" btnW " h" btnH " Center +0x200 Background6D28D9 cFFFFFF", "↺")
    ResetBtn.SetFont("s" S(8), "Segoe UI")
    ResetBtn.OnEvent("Click", ToggleReset)
    AddHoverPopup(ResetBtn, "Toggle Reset Keys`nON/OFF (Ctrl+F8)")

    ; --- Row 3: Timer / Stopwatch ---
    _timerDisplay := IB_GUI.AddText("xm y+" S(6) " w" S(80) " h" S(14) " 0x200 Center cFFFFFF Background333333", "00:00:00")
    _timerDisplay.SetFont("s" S(7) " cFFFFFF", "Consolas")
    _tmrPlay := IB_GUI.AddText("x+" S(2) " yp w" S(14) " h" S(14) " 0x200 Center cFFFFFF Background2E7D32", "▶")
    _tmrPlay.SetFont("s" S(6), "Segoe UI")
    _tmrPlay.OnEvent("Click", TimerToggle)
    AddHoverPopup(_tmrPlay, "Start Timer")
    _tmrPause := IB_GUI.AddText("xp yp w" S(14) " h" S(14) " 0x200 Center cFFFFFF BackgroundE65100 Hidden", "❚❚")
    _tmrPause.SetFont("s" S(6), "Segoe UI")
    _tmrPause.OnEvent("Click", TimerToggle)
    AddHoverPopup(_tmrPause, "Pause Timer")
    _rBtn := IB_GUI.AddText("x+" S(2) " yp w" S(14) " h" S(14) " 0x200 Center cFFFFFF BackgroundC62828", "■")
    _rBtn.SetFont("s" S(6), "Segoe UI")
    _rBtn.OnEvent("Click", TimerReset)
    AddHoverPopup(_rBtn, "Reset Timer")

    _saveBtn := IB_GUI.AddText("x+" S(2) " yp w" S(14) " h" S(14) " 0x200 Center cFFFFFF Background1565C0", "💾")
    _saveBtn.SetFont("s" S(6), "Segoe UI")
    _saveBtn.OnEvent("Click", TimerSave)
    AddHoverPopup(_saveBtn, "Save Timer Log")

    ; drag handle (remaining space on same row)
    IB_GUI.dragBottom := IB_GUI.AddText("x+" S(4) " yp w" S(118) " h" S(14) " +0x200 Background555555", "")

    ; --- Context menu ---
    IB_GUI.OnEvent("ContextMenu", IB_ContextMenu)
}

IB_SelectClick(btn, *) {
    SelectIB(btn.index)
}

InbetweenModeLabel() {
    global InbetweenMode
    return InbetweenMode = "Start > End" ? "S>E" : "E>S"
}

UpdateInbetweenModeButton() {
    global IB_ModeBtn, InbetweenMode
    if !IsObject(IB_ModeBtn)
        return
    IB_ModeBtn.Text := InbetweenModeLabel()
    IB_ModeBtn.Opt("Background" (InbetweenMode = "Start > End" ? "2E7D32" : "455A64") " cFFFFFF")
}

UpdateIBButtons() {
    global IB_Buttons, InbetweenData
    for btn in IB_Buttons {
        if !IsObject(btn)
            continue
        d := InbetweenData[btn.index]
        RegExMatch(d.bar, "^\d+", &m)
        btn.Text := m[0]
    }
}

SetInbetweenMode(mode, save := true) {
    global InbetweenMode, InbetweenData, InbetweenIndex, SETTINGS_FILE
    InbetweenMode := NormalizeInbetweenMode(mode)
    InbetweenData := BuildInbetweenData(InbetweenMode)
    UpdateIBButtons()
    UpdateInbetweenModeButton()
    UpdateIBGui(InbetweenIndex)
    if save
        IniWrite(InbetweenMode, SETTINGS_FILE, "IB", "Mode")
    DebugLog("IB mode set to " InbetweenMode)
}

ToggleInbetweenMode(*) {
    global InbetweenMode
    SetInbetweenMode(InbetweenMode = "Start > End" ? "End > Start" : "Start > End")
}

TimerToggle(*) {
    global _timerRunning, _timerStart, _timerElapsed, _timerDisplay, _tmrPlay, _tmrPause, _timerFocusPaused
    _timerRunning := !_timerRunning
    _timerFocusPaused := false
    if _timerRunning {
        _timerStart := A_TickCount
        SetTimer(TimerTick, 1000)
        TimerTick()
        _tmrPlay.Visible := false
        _tmrPause.Visible := true
        DebugLog("Timer started")
    } else {
        SetTimer(TimerTick, 0)
        _timerElapsed += A_TickCount - _timerStart
        _tmrPlay.Visible := true
        _tmrPause.Visible := false
        elapsed := _timerElapsed
        secs := Floor(elapsed / 1000)
        hrs := Format("{:02i}", Floor(secs / 3600))
        mins := Format("{:02i}", Floor(Mod(secs, 3600) / 60))
        scs := Format("{:02i}", Mod(secs, 60))
        DebugLog("Timer stopped at " hrs ":" mins ":" scs)
    }
}

TimerReset(*) {
    global _timerRunning, _timerStart, _timerElapsed, _timerDisplay, _tmrPlay, _tmrPause, _timerFocusPaused
    _timerRunning := false
    _timerFocusPaused := false
    _timerStart := 0
    _timerElapsed := 0
    _timerDisplay.Value := "00:00:00"
    SetTimer(TimerTick, 0)
    _tmrPlay.Visible := true
    _tmrPause.Visible := false
    DebugLog("Timer reset")
}

TimerTick(*) {
    global _timerRunning, _timerStart, _timerElapsed, _timerDisplay
    if !_timerRunning
        return
    elapsed := _timerElapsed + (A_TickCount - _timerStart)
    secs := Floor(elapsed / 1000)
    mins := Floor(secs / 60)
    secs := Mod(secs, 60)
    hrs := Floor(mins / 60)
    mins := Mod(mins, 60)
    _timerDisplay.Value := Format("{:02i}:{:02i}:{:02i}", hrs, mins, secs)
}

CheckCSPFocus(*) {
    global _timerRunning, _timerFocusPaused, _timerStart, _timerElapsed, _tmrPlay, _tmrPause
    static ourPID := DllCall("GetCurrentProcessId", "uint")
    try {
        activeHwnd := WinExist("A")
        activeExe := WinGetProcessName(activeHwnd)
        isCSP := activeExe = "CLIPStudioPaint.exe"
        if !isCSP {
            DllCall("GetWindowThreadProcessId", "ptr", activeHwnd, "uint*", &pid := 0)
            if pid = ourPID
                isCSP := true
        }
    } catch {
        isCSP := false
    }
    if !isCSP && _timerRunning && !_timerFocusPaused {
        _timerFocusPaused := true
        _timerRunning := false
        SetTimer(TimerTick, 0)
        _timerElapsed += A_TickCount - _timerStart
        _tmrPlay.Visible := true
        _tmrPause.Visible := false
        elapsed := _timerElapsed
        secs := Floor(elapsed / 1000)
        hrs := Floor(secs / 3600)
        mins := Floor(Mod(secs, 3600) / 60)
        scs := Mod(secs, 60)
        DebugLog("Timer auto-stopped at " Format("{:02i}:{:02i}:{:02i}", hrs, mins, scs) " (CSP focus lost)")
    } else if isCSP && _timerFocusPaused {
        _timerFocusPaused := false
        _timerRunning := true
        _timerStart := A_TickCount
        SetTimer(TimerTick, 1000)
        TimerTick()
        _tmrPlay.Visible := false
        _tmrPause.Visible := true
        DebugLog("Timer auto-resumed (CSP focus regained)")
    }
}

TimerSave(*) {
    global _timerElapsed, _timerDisplay, IB_GUI, _timerAskFileName
    if !_timerElapsed
        return
    static sDlg := 0
    if IsObject(sDlg) {
        try if sDlg.Hwnd {
            sDlg.Show()
            return
        }
    }
    sDlg := Gui("+AlwaysOnTop +ToolWindow", "Save Timer")
    sDlg.BackColor := "1E1F22"
    sDlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    sDlg.MarginX := S(16)
    sDlg.MarginY := S(16)

    sDlg.SetFont("s" S(28), "Segoe UI")
    sDlg.AddText("xm Center w" S(240), "⏱")
    sDlg.SetFont("s" S(10) " Bold", "Segoe UI")
    sDlg.AddText("xm y+" S(4) " Center cAAAAAA w" S(240), _timerDisplay.Value)
    sDlg.SetFont("s" S(9), "Segoe UI")
    sDlg.AddText("xm y+" S(8) " Center c888888 w" S(240), "Save timer log as...")

    sDlg.SetFont("s" S(9), "Segoe UI")
    sDlg.AddButton("xm y+" S(12) " w" S(72) " h" S(28) " Background1565C0 cFFFFFF", "PNG").OnEvent("Click", TimerSavePNG.Bind(sDlg))
    sDlg.AddButton("x+" S(6) " yp w" S(72) " h" S(28) " Background2E7D32 cFFFFFF", "TXT").OnEvent("Click", TimerSaveTXT.Bind(sDlg))
    sDlg.AddButton("x+" S(6) " yp w" S(72) " h" S(28), "Cancel").OnEvent("Click", (*) => sDlg.Destroy())
    sDlg.SetFont("s" S(8), "Segoe UI")
    sDlg.cbAsk := sDlg.AddCheckbox("xm y+" S(8) " Background1E1F22 cCCCCCC", "Input CSP file name")
    sDlg.cbAsk.Value := _timerAskFileName
    sDlg.cbAsk.OnEvent("Click", (*) => _timerAskFileName := sDlg.cbAsk.Value)
    sDlg.Show("w" S(272))
}

_TimerAskNameFolder() {
    global _timerNameResult
    _timerNameResult := ""
    timestamp := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    
    nameGui := Gui("+AlwaysOnTop +ToolWindow", "Timer File Name")
    nameGui.BackColor := "1E1F22"
    nameGui.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    nameGui.MarginX := S(16)
    nameGui.MarginY := S(16)
    
    nameGui.SetFont("s" S(28), "Segoe UI")
    nameGui.AddText("xm Center w" S(240), "⏱")
    nameGui.SetFont("s" S(10), "Segoe UI")
    nameGui.AddText("xm y+" S(4) " Center cAAAAAA w" S(240), "Enter a name for the timer files:")
    nameGui.SetFont("s" S(9), "Segoe UI")
    ne := nameGui.AddEdit("xm y+" S(8) " w" S(240) " h" S(24) " Background2A2A2A cFFFFFF -E0x200", timestamp)
    ne.SetFont("s" S(10), "Segoe UI")
    nameGui.AddButton("xm y+" S(10) " w" S(115) " h" S(30) " Background2E7D32 cFFFFFF Default", "OK").OnEvent("Click", (*) => (_timerNameResult := ne.Value, nameGui.Destroy()))
    nameGui.AddButton("x+" S(10) " yp w" S(115) " h" S(30), "Cancel").OnEvent("Click", (*) => nameGui.Destroy())
    nameGui.Show("w" S(272))
    nameGui.OnEvent("Close", (*) => nameGui.Destroy())
    WinWaitClose(nameGui)
    
    if _timerNameResult = ""
        return ""
    folder := FileSelect("D", A_MyDocuments, "Select folder to save timer files")
    if folder = ""
        return ""
    return folder "\" _timerNameResult
}

CaptureTimerToPNG(filepath, timerVal, now, date, day, cspName := "") {
    si := Buffer(24, 0)
    NumPut("uint", 1, si, 0)
    if DllCall("gdiplus\GdiplusStartup", "ptr*", &pToken := 0, "ptr", si, "ptr", 0) != 0
        return false

    w := 400
    h := 185
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &pImg := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", pImg, "ptr*", &pGfx := 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "ptr", pGfx, "int", 2)

    DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xffffffff, "ptr*", &pWhite := 0)
    DllCall("gdiplus\GdipFillRectangleI", "ptr", pGfx, "ptr", pWhite, "int", 0, "int", 0, "int", w, "int", h)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", pWhite)

    DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xff000000, "ptr*", &pBlack := 0)
    DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xff888888, "ptr*", &pGray := 0)

    DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Segoe UI", "ptr", 0, "ptr*", &pFam := 0)
    DllCall("gdiplus\GdipCreateFont", "ptr", pFam, "float", 36.0, "int", 0, "int", 0, "ptr*", &pBigFont := 0)
    DllCall("gdiplus\GdipCreateFont", "ptr", pFam, "float", 13.0, "int", 0, "int", 0, "ptr*", &pSmFont := 0)
    DllCall("gdiplus\GdipCreateFont", "ptr", pFam, "float", 10.0, "int", 0, "int", 0, "ptr*", &pXsFont := 0)
    DllCall("gdiplus\GdipDeleteFontFamily", "ptr", pFam)

    y := 10
    if cspName != "" {
        r := Buffer(16)
        NumPut("float", 20.0, "float", y + 0.0, "float", 360.0, "float", 18.0, r)
        DllCall("gdiplus\GdipDrawString", "ptr", pGfx, "wstr", "File: " cspName, "int", -1, "ptr", pSmFont, "ptr", r, "ptr", 0, "ptr", pGray)
        y += 22
    }
    r := Buffer(16)
    NumPut("float", 20.0, "float", y + 0.0, "float", 360.0, "float", 42.0, r)
    DllCall("gdiplus\GdipDrawString", "ptr", pGfx, "wstr", "Work Time: " timerVal, "int", -1, "ptr", pBigFont, "ptr", r, "ptr", 0, "ptr", pBlack)
    y += 50

    DllCall("gdiplus\GdipDrawString", "ptr", pGfx, "wstr", "------------------", "int", -1, "ptr", pXsFont, "ptr", r, "ptr", 0, "ptr", pGray)
    y += 4

    NumPut("float", 20.0, "float", y + 22.0, "float", 360.0, "float", 18.0, r)
    DllCall("gdiplus\GdipDrawString", "ptr", pGfx, "wstr", "Day: " day, "int", -1, "ptr", pSmFont, "ptr", r, "ptr", 0, "ptr", pBlack)
    NumPut("float", 20.0, "float", y + 44.0, "float", 360.0, "float", 18.0, r)
    DllCall("gdiplus\GdipDrawString", "ptr", pGfx, "wstr", "Save Time: " now, "int", -1, "ptr", pSmFont, "ptr", r, "ptr", 0, "ptr", pBlack)
    NumPut("float", 20.0, "float", y + 66.0, "float", 360.0, "float", 18.0, r)
    DllCall("gdiplus\GdipDrawString", "ptr", pGfx, "wstr", "Date: " date, "int", -1, "ptr", pSmFont, "ptr", r, "ptr", 0, "ptr", pBlack)

    DllCall("gdiplus\GdipDeleteFont", "ptr", pBigFont)
    DllCall("gdiplus\GdipDeleteFont", "ptr", pSmFont)
    DllCall("gdiplus\GdipDeleteFont", "ptr", pXsFont)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", pBlack)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", pGray)
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", pGfx)

    clsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid)
    result := false
    if DllCall("gdiplus\GdipSaveImageToFile", "ptr", pImg, "str", filepath, "ptr", clsid, "ptr", 0) = 0
        result := true
    DllCall("gdiplus\GdipDisposeImage", "ptr", pImg)
    DllCall("gdiplus\GdiplusShutdown", "ptr", pToken)
    return result
}

TimerSavePNG(dlg, *) {
    global IB_GUI, _timerAskFileName, _timerNameResult, _timerDisplay
    timestamp := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    docsDir := A_MyDocuments
    timerVal := _timerDisplay.Value
    now := FormatTime(, "HH:mm:ss")
    date := FormatTime(, "yyyy-MM-dd")
    day := FormatTime(, "dddd")
    if _timerAskFileName {
        basePath := _TimerAskNameFolder()
        if basePath = ""
            return
        filepath := basePath ".png"
        cspName := _timerNameResult
    } else {
        filepath := FileSelect("S", docsDir "\Timer_" timestamp ".png", "Save PNG", "PNG (*.png)")
        if filepath = ""
            return
        cspName := ""
    }
    if CaptureTimerToPNG(filepath, timerVal, now, date, day, cspName) {
        dlg.Destroy()
        ShowNotify("Timer", "PNG saved", "1565C0")
        DebugLog("Timer saved as PNG (" timerVal ")")
    } else {
        MsgBox("Failed to save PNG.", "Error", "Icon!")
    }
}

TimerSaveTXT(dlg, *) {
    global _timerDisplay, _timerAskFileName, _timerNameResult
    timestamp := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    docsDir := A_MyDocuments
    if _timerAskFileName {
        basePath := _TimerAskNameFolder()
        if basePath = ""
            return
        filepath := basePath ".txt"
        cspName := _timerNameResult
    } else {
        filepath := FileSelect("S", docsDir "\Timer_" timestamp ".txt", "Save TXT", "Text (*.txt)")
        if filepath = ""
            return
        cspName := ""
    }
    try {
        t := _timerDisplay.Value
        now := FormatTime(, "HH:mm:ss")
        date := FormatTime(, "yyyy-MM-dd")
        day := FormatTime(, "dddd")
        lines := ""
        if cspName != ""
            lines .= "File: " cspName "`n"
        lines .= "Work Time: " t "`n"
        lines .= "------------------`n"
        lines .= "Day: " day "`n"
        lines .= "Save Time: " now "`n"
        lines .= "Date: " date "`n"
        FileAppend(lines, filepath)
        dlg.Destroy()
        ShowNotify("Timer", "TXT saved", "2E7D32")
        DebugLog("Timer saved as TXT (" t ")")
    } catch as e {
        MsgBox("Failed to save TXT: " e.Message, "Error", "Icon!")
    }
}

IB_ContextMenu(guiObj, ctrl, item, isRightClick, x, y) {
    m := Menu()
    m.Add("Hide IB GUI", (*) => (IB_GUI.Hide(), IBVisible := false, IBManualHide := true,
        IsObject(MainGUI) && IsObject(MainGUI.btnIB) ? MainGUI.btnIB.Opt("BackgroundE53935 cFFFFFF") : "",
        DebugLog("IB hidden via context menu")))
    m.Add("Switch IB Direction", ToggleInbetweenMode)
    m.Add("Opacity...", ShowOpacitySlider.Bind("IB"))
    m.Add("Auto Save Interval...", SetAutoSaveInterval)
    m.Add("Debug Log", ShowDebugGUI)
    m.Show()
}

UpdateIBGui(index) {
    global IB_Text, IB_GUI, InbetweenData
    if !IsObject(IB_Text) || !IsObject(IB_GUI)
        return
    d := InbetweenData[index]
    IB_Text.Value := d.bar
    bg := d.HasOwnProp("color") ? d.color : "1E1E1E"
    IB_GUI.BackColor := bg
    IB_GUI.SetFont("cFFFFFF")
    IB_Text.SetFont()
}

IB_PositionGui() {
    global IB_GUI, IB_X, IB_Y, IB_Opacity
    if !IsObject(IB_GUI)
        return
    IB_GUI.Show("x" IB_X " y" IB_Y " NoActivate")
    if IB_Opacity < 255
        WinSetTransparent(IB_Opacity, IB_GUI)
}

; ============================================================
; GUI — Color Palette
; ============================================================

CreateColorGui() {
    global ColorGUI, ColorLayout
    ColorGUI := Gui("+AlwaysOnTop -Caption +ToolWindow")
    ColorGUI.BackColor := "1E1E1E"
    ColorGUI.SetFont("s" S(7) " cFFFFFF", "Segoe UI")

    ; drag handle at top
    ColorGUI.dragBottom := ColorGUI.AddText("xm w" S(25) " h" S(6) " +0x200 Background555555", "")

    ColorGUI.AddText("xm y+" S(4) " w" S(25) " Center cAAAAAA", "Fill")
    ColorGUI.SetFont("s" S(9) " Bold cFFFFFF", "Segoe UI")

    bw := S(25)
    bh := S(30)
    gap := S(4)
    isH := ColorLayout = "H"
    next  := isH ? "x+" gap " yp" : "xm y+" gap
    sep   := isH ? "x+" gap " yp w" S(1) " h" bh " Background555555" : "xm w" bw " h" S(1) " Background555555 y+" S(8)
    sepY  := isH ? "x+" gap " yp" : "xm y+" S(8)

    btn1 := ColorGUI.AddText("xm w" bw " h" bh " Center +0x200 BackgroundBF0000", "R")
    btn2 := ColorGUI.AddText(next " w" bw " h" bh " Center +0x200 Background2E7D32", "G")
    btn3 := ColorGUI.AddText(next " w" bw " h" bh " Center +0x200 Background1565C0", "B")
    btn4 := ColorGUI.AddText(next " w" bw " h" bh " Center +0x200 Background333333", "Tw")
    ColorGUI.AddText(sep)
    btn5 := ColorGUI.AddText(sepY " w" bw " h" bh " Center +0x200 Background777777", "D")
    btn6 := ColorGUI.AddText(sepY " w" bw " h" bh " Center +0x200 Background777777", "🔁")

    ColorGUI.AddText(sep)
    btn7 := ColorGUI.AddText(sepY " w" bw " h" bh " Center +0x200 BackgroundE91E63", "P")
    btn8 := ColorGUI.AddText(next " w" bw " h" bh " Center +0x200 Background00BCD4", "C")
    btn9 := ColorGUI.AddText(next " w" bw " h" bh " Center +0x200 BackgroundFF9800", "O")

    AddHoverPopup(btn1, "Red Line Fill")
    AddHoverPopup(btn2, "Green Line Fill")
    AddHoverPopup(btn3, "Blue Line Fill")
    AddHoverPopup(btn4, "Select Transparent")
    AddHoverPopup(btn5, "Deselect")
    AddHoverPopup(btn6, "Toggle Horizontal/Vertical")
    AddHoverPopup(btn7, "Pink Fill")
    AddHoverPopup(btn8, "Cyan Fill")
    AddHoverPopup(btn9, "Orange Fill")

    btn1.OnEvent("Click", (*) => SendColor("^+!c", "Red Line Fill", "Shift+Ctrl+Alt+C", "0xBF0000"))
    btn2.OnEvent("Click", (*) => SendColor("^+!v", "Green Line Fill", "Shift+Ctrl+Alt+V", "0x5CD377"))
    btn3.OnEvent("Click", (*) => SendColor("^+!b", "Blue Line Fill", "Shift+Ctrl+Alt+B", "0x487AE3"))
    btn4.OnEvent("Click", (*) => SendColor("^+!f", "Select Transparent", "Shift+Ctrl+Alt+F", "0x333333"))
    btn5.OnEvent("Click", (*) => SendColor("^d", "Deselect", "CTRL+D", "0x888888"))
    btn6.OnEvent("Click", (*) => ToggleColorLayout())
    btn7.OnEvent("Click", (*) => SendColor("^+!n", "Pink Fill", "Shift+Ctrl+Alt+N", "0xFF00FF"))
    btn8.OnEvent("Click", (*) => SendColor("^+!m", "Cyan Fill", "Shift+Ctrl+Alt+M", "0x00FFF0"))
    btn9.OnEvent("Click", (*) => SendColor("^+!{,}", "Orange Fill", "Shift+Ctrl+Alt+,", "0xFA9600"))

    ColorGUI.OnEvent("ContextMenu", Color_ContextMenu)
}

Color_ContextMenu(guiObj, ctrl, item, isRightClick, x, y) {
    m := Menu()
    m.Add("Hide Color GUI", (*) => (ColorGUI.Hide(), ColorGUIVisible := false, ColorManualHide := true,
        IsObject(MainGUI) && IsObject(MainGUI.btnColor) ? MainGUI.btnColor.Opt("BackgroundE53935 cFFFFFF") : "",
        DebugLog("Color hidden via context menu")))
    m.Add("Toggle Layout", ToggleColorLayout)
    m.Add("Toggle Cursor Color Info", ToggleColorInfo)
    m.Add("Color Info Offset...", ShowColorInfoOffsetDialog)
    m.Add("Opacity...", ShowOpacitySlider.Bind("Color"))
    m.Add("Debug Log", ShowDebugGUI)
    m.Show()
}

ToggleColorLayout(*) {
    global ColorLayout, ColorGUI, ColorGUIVisible, ColorGUI_X, ColorGUI_Y
    wasVisible := ColorGUIVisible
    if IsObject(ColorGUI)
        ColorGUI.GetPos(&ColorGUI_X, &ColorGUI_Y)
    ColorLayout := ColorLayout = "V" ? "H" : "V"
    DebugLog("Color Layout " (ColorLayout = "V" ? "H → V" : "V → H"))
    IniWrite(ColorLayout, SETTINGS_FILE, "Color", "Layout")
    if IsObject(ColorGUI)
        ColorGUI.Destroy()
    CreateColorGui()
    if wasVisible {
        ColorGUIVisible := true
        ColorGUI.Show("x" ColorGUI_X " y" ColorGUI_Y " NoActivate")
    }
}

PositionColorGui() {
    global ColorGUI, ColorGUI_X, ColorGUI_Y, Color_Opacity
    if !IsObject(ColorGUI)
        return
    ColorGUI.GetPos(,, &w, &h)
    ColorGUI.Show("x" ColorGUI_X " y" ColorGUI_Y " NoActivate")
    if Color_Opacity < 255
        WinSetTransparent(Color_Opacity, ColorGUI)
}

; ============================================================
; GUI — Link Launcher
; ============================================================

CreateLinkGUI() {
    global LinkGUI, LinkItems, _linkCollapsed
    LinkGUI := Gui("+AlwaysOnTop -Caption +ToolWindow")
    LinkGUI.BackColor := "1E1E1E"
    LinkGUI.SetFont("s" S(6) " cFFFFFF", "Segoe UI")

    bw := S(25)
    bh := S(30)

    LinkGUI.dragBottom := LinkGUI.AddText("xm w" bw " h" S(6) " +0x200 Background555555", "")
    LinkGUI.OnEvent("ContextMenu", LinkGUI_ContextMenu)

    curSection := 0
    sectionOrder := []
    sectionHeaders := Map()
    sectionControls := Map()
    allCtrls := []
    secBounds := Map()

    for idx, item in LinkItems {
        if !item.Get("enabled", true) && !item.Get("system", false)
            continue
        t := item.Get("type","")
        if t = "sep" {
            curSection++
            lbl := item.Get("label","")
            sepHdr := LinkGUI.AddText("xm y+" S(4) " w" bw " Center cAAAAAA +0x200 Background2A2A2A", " " lbl)
            sepHdr.SetFont("s" S(6) " cAAAAAA", "Segoe UI")
            sepHdr.OnEvent("Click", LinkToggleSection.Bind(curSection))
            sectionOrder.Push(curSection)
            sectionHeaders[curSection] := sepHdr
            sectionControls[curSection] := []
            secBounds[curSection] := [allCtrls.Length + 1, allCtrls.Length + 1]
            allCtrls.Push(sepHdr)
            continue
        }

        c := item.Get("color","455A64")
        icon := item.Get("icon","?")
        lbl := item.Get("label","")
        hov := item.Get("hover", lbl)
        btn := LinkGUI.AddText("xm y+" S(4) " w" bw " h" bh " Center +0x200 Background" c " cFFFFFF", icon)

        btn.SetFont("s" S(8), "Segoe UI")
        if hov != ""
            AddHoverPopup(btn, hov)

        if t = "system" {
            fn := item.Get("fn","")
            if fn = "ToggleMainWindow"
                btn.OnEvent("Click", (*) => ToggleMainWindow())
            else if fn = "ShowCSPGuide"
                btn.OnEvent("Click", (*) => ShowCSPGuide())
        } else if t = "action" {
            keys := item.Get("keys","")
            extra := item.Get("extra","")
            if keys != ""
                btn.OnEvent("Click", LinkActionClick.Bind(keys, lbl, "0x" c, extra))
        } else if t = "url" {
            target := item.Get("target","")
            if target != ""
                btn.OnEvent("Click", LinkRunTarget.Bind(target))
        } else if t = "script" {
            target := item.Get("target","")
            if target != ""
                btn.OnEvent("Click", LinkRunTarget.Bind(target))
        }

        ; Store control in current section (skip system — always visible)
        if sectionControls.Has(curSection) && t != "system"
            sectionControls[curSection].Push(btn)
        allCtrls.Push(btn)
        if secBounds.Has(curSection)
            secBounds[curSection][2] := allCtrls.Length
    }

    ; Store original Y positions and section heights
    origY := Map()
    for ctl in allCtrls {
        ctl.GetPos(&cx, &cy, &cw, &ch)
        origY[ctl] := [cy, ch]
    }

    secHeights := Map()
    for secIdx, bounds in secBounds {
        f := allCtrls[bounds[1]]
        l := allCtrls[bounds[2]]
        secHeights[secIdx] := origY[l][1] + origY[l][2] - origY[f][1]
    }

    ; Apply collapsed state (hide and move lower controls up)
    for secIdx, controls in sectionControls {
        collapsed := _linkCollapsed.Has(secIdx) && _linkCollapsed[secIdx]
        for ctl in controls
            ctl.Visible := !collapsed
    }
    LinkGUI._sectionControls := sectionControls
    LinkGUI._sectionHeaders := sectionHeaders
    LinkGUI._sectionOrder := sectionOrder
    LinkGUI._allCtrls := allCtrls
    LinkGUI._secBounds := secBounds
    LinkGUI._secHeights := secHeights
    LinkGUI._origY := origY
    LinkApplySectionLayout()
}

LinkToggleSection(secIdx, *) {
    global _linkCollapsed
    _linkCollapsed[secIdx] := !_linkCollapsed.Get(secIdx, false)
    LinkApplySectionLayout()
    DebugLog("Toggled section " secIdx " " (_linkCollapsed[secIdx] ? "collapsed" : "expanded"))
}

LinkApplySectionLayout() {
    global LinkGUI, _linkCollapsed
    if !IsObject(LinkGUI)
        return

    allCtrls := LinkGUI._allCtrls
    if !IsObject(allCtrls) || allCtrls.Length = 0
        return

    origY := LinkGUI._origY
    secBounds := LinkGUI._secBounds
    secHeights := LinkGUI._secHeights
    sectionControls := LinkGUI._sectionControls
    sectionHeaders := LinkGUI._sectionHeaders
    sectionOrder := LinkGUI._sectionOrder

    for ctl in allCtrls {
        ctl.Visible := true
        ctl.Move(, origY[ctl][1])
    }

    offsetAccum := 0
    for _, secIdx in sectionOrder {
        collapsed := _linkCollapsed.Get(secIdx, false)
        hdr := sectionHeaders.Get(secIdx, 0)
        headerH := IsObject(hdr) ? origY[hdr][2] : 0
        if collapsed {
            ctrls := sectionControls.Get(secIdx, [])
            for ctl in ctrls
                ctl.Visible := false
            if ctrls.Length > 0
                offsetAccum += secHeights[secIdx] - headerH
        }

        bounds := secBounds[secIdx]
        if bounds[2] < allCtrls.Length {
            Loop allCtrls.Length - bounds[2] {
                idx := bounds[2] + A_Index
                ctl := allCtrls[idx]
                ctl.Move(, origY[ctl][1] - offsetAccum)
            }
        }
    }

    visibleBottom := 0
    Loop allCtrls.Length {
        idx := allCtrls.Length - A_Index + 1
        ctl := allCtrls[idx]
        if ctl.Visible {
            ctl.GetPos(,, &_cw, &_ch)
            ctl.GetPos(&_cx, &_cy)
            visibleBottom := _cy + _ch
            break
        }
    }
    if visibleBottom > 0 {
        LinkGUI.GetPos(&gx, &gy, &gw, &gh)
        LinkGUI.Move(,, gw, visibleBottom + S(6))
    }
}

LinkGUI_ContextMenu(guiObj, ctrl, item, isRightClick, x, y) {
    if ctrl = guiObj.dragBottom
        return
    m := Menu()
    m.Add("Hide Link GUI", (*) => (LinkGUI.Hide(), LinkGUIVisible := false, LinkManualHide := true,
        IsObject(MainGUI) && IsObject(MainGUI.btnLink) ? MainGUI.btnLink.Opt("BackgroundE53935 cFFFFFF") : "",
        DebugLog("Link hidden via context menu")))
    m.Add("Opacity...", ShowOpacitySlider.Bind("Link"))
    m.Add("Debug Log", ShowDebugGUI)
    m.Show()
}

LinkActionClick(keys, lbl, color, extra, *) {
    SendColor(keys, lbl, "", color)
    if extra != ""
        Send(extra)
}

LinkRunTarget(target, *) {
    Run(target)
}

PositionLinkGUI() {
    global LinkGUI, LinkGUI_X, LinkGUI_Y, Link_Opacity
    if !IsObject(LinkGUI)
        return
    LinkGUI.GetPos(,, &w, &h)
    LinkGUI.Show("x" LinkGUI_X " y" LinkGUI_Y " NoActivate")
    if Link_Opacity < 255
        WinSetTransparent(Link_Opacity, LinkGUI)
}

; ============================================================
; PERSISTENCE — INI positions
; ============================================================

LoadGUIPositions() {
    global SETTINGS_FILE
    global IB_X, IB_Y
    global InbetweenMode, InbetweenData
    global ColorGUI_X, ColorGUI_Y, ColorLayout
    global LinkGUI_X, LinkGUI_Y
    global LT_X, LT_Y, LT_Color
    global Scale, Speed
    global IB_Opacity, Color_Opacity, Link_Opacity
    global AutoSaveInterval
    global _ccOffsetX, _ccOffsetY
    global _debugSaveOnExit

    if !FileExist(SETTINGS_FILE)
        return

    IB_X       := IniRead(SETTINGS_FILE, "IB",    "X",      IB_X)
    IB_Y       := IniRead(SETTINGS_FILE, "IB",    "Y",      IB_Y)
    InbetweenMode := NormalizeInbetweenMode(IniRead(SETTINGS_FILE, "IB", "Mode", InbetweenMode))
    InbetweenData := BuildInbetweenData(InbetweenMode)
    ColorGUI_X := IniRead(SETTINGS_FILE, "Color", "X",      ColorGUI_X)
    ColorGUI_Y := IniRead(SETTINGS_FILE, "Color", "Y",      ColorGUI_Y)
    ColorLayout:= IniRead(SETTINGS_FILE, "Color", "Layout", ColorLayout)
    LinkGUI_X  := IniRead(SETTINGS_FILE, "Link",  "X",      LinkGUI_X)
    LinkGUI_Y  := IniRead(SETTINGS_FILE, "Link",  "Y",      LinkGUI_Y)
    LT_X       := IniRead(SETTINGS_FILE, "LT",    "X",      LT_X)
    LT_Y       := IniRead(SETTINGS_FILE, "LT",    "Y",      LT_Y)
    LT_Color   := IniRead(SETTINGS_FILE, "LT",    "Color",  LT_Color)
    Scale      := Float(IniRead(SETTINGS_FILE, "Settings", "Scale", Scale))
    Speed      := Integer(IniRead(SETTINGS_FILE, "Settings", "Speed", Speed))
    if Scale < 0.5
        Scale := 0.5
    else if Scale > 1.5
        Scale := 1.5
    if Speed < 1
        Speed := 1
    else if Speed > 100
        Speed := 100
    IB_Opacity   := IniRead(SETTINGS_FILE, "Settings", "IB_Opacity", 255)
    Color_Opacity := IniRead(SETTINGS_FILE, "Settings", "Color_Opacity", 255)
    Link_Opacity  := IniRead(SETTINGS_FILE, "Settings", "Link_Opacity", 255)
    AutoSaveInterval := IniRead(SETTINGS_FILE, "Settings", "AutoSaveInterval", 60)
    _ccOffsetX := Integer(IniRead(SETTINGS_FILE, "ColorInfo", "OffsetX", 0))
    _ccOffsetY := Integer(IniRead(SETTINGS_FILE, "ColorInfo", "OffsetY", 0))
    _timerAskFileName := Integer(IniRead(SETTINGS_FILE, "Settings", "TimerAskFile", 1))
    _debugSaveOnExit := Integer(IniRead(SETTINGS_FILE, "Settings", "DebugSaveOnExit", 0))
}

SaveGUIPositions() {
    global SETTINGS_FILE
    global IB_GUI, ColorGUI, LinkGUI
    global IB_X, IB_Y, ColorGUI_X, ColorGUI_Y, LinkGUI_X, LinkGUI_Y
    global InbetweenMode
    global ColorLayout
    global Scale, Speed
    global _ccOffsetX, _ccOffsetY
    global _timerAskFileName
    global _debugSaveOnExit

    if IsObject(IB_GUI) {
        try {
            IB_GUI.GetPos(&_nx, &_ny)
            DebugLog("IB pos: was (" IB_X "," IB_Y "), now (" _nx "," _ny ")")
            IB_X := _nx, IB_Y := _ny
            IniWrite(IB_X, SETTINGS_FILE, "IB", "X")
            IniWrite(IB_Y, SETTINGS_FILE, "IB", "Y")
        }
    }
    IniWrite(InbetweenMode, SETTINGS_FILE, "IB", "Mode")
    if IsObject(ColorGUI) {
        try {
            ColorGUI.GetPos(&_nx, &_ny)
            DebugLog("Color pos: was (" ColorGUI_X "," ColorGUI_Y "), now (" _nx "," _ny ")")
            ColorGUI_X := _nx, ColorGUI_Y := _ny
            IniWrite(ColorGUI_X, SETTINGS_FILE, "Color", "X")
            IniWrite(ColorGUI_Y, SETTINGS_FILE, "Color", "Y")
        }
    }
    IniWrite(ColorLayout, SETTINGS_FILE, "Color", "Layout")
    if IsObject(LinkGUI) {
        try {
            LinkGUI.GetPos(&_nx, &_ny)
            DebugLog("Link pos: was (" LinkGUI_X "," LinkGUI_Y "), now (" _nx "," _ny ")")
            LinkGUI_X := _nx, LinkGUI_Y := _ny
            IniWrite(LinkGUI_X, SETTINGS_FILE, "Link", "X")
            IniWrite(LinkGUI_Y, SETTINGS_FILE, "Link", "Y")
        }
    }
    IniWrite(LT_Color, SETTINGS_FILE, "LT", "Color")
    IniWrite(Scale, SETTINGS_FILE, "Settings", "Scale")
    IniWrite(Speed, SETTINGS_FILE, "Settings", "Speed")
    IniWrite(IB_Opacity, SETTINGS_FILE, "Settings", "IB_Opacity")
    IniWrite(Color_Opacity, SETTINGS_FILE, "Settings", "Color_Opacity")
    IniWrite(Link_Opacity, SETTINGS_FILE, "Settings", "Link_Opacity")
    IniWrite(_timerAskFileName, SETTINGS_FILE, "Settings", "TimerAskFile")
    IniWrite(_debugSaveOnExit, SETTINGS_FILE, "Settings", "DebugSaveOnExit")
    IniWrite(_ccOffsetX, SETTINGS_FILE, "ColorInfo", "OffsetX")
    IniWrite(_ccOffsetY, SETTINGS_FILE, "ColorInfo", "OffsetY")
}

LoadConfigurablePaths() {
    global SETTINGS_FILE
    global PickerPath, FishbonePath, ResizerPath, SheetsURL, DriveURL
    global LT_ClickX, LT_ClickY, ColorClick1X, ColorClick1Y, ColorClick2X, ColorClick2Y
    global _timerAskFileName
    if !FileExist(SETTINGS_FILE)
        return
    PickerPath   := IniRead(SETTINGS_FILE, "Paths", "ColorPicker", PickerPath)
    FishbonePath := IniRead(SETTINGS_FILE, "Paths", "Fishbone",    FishbonePath)
    ResizerPath  := IniRead(SETTINGS_FILE, "Paths", "BatchResizer",ResizerPath)
    SheetsURL    := IniRead(SETTINGS_FILE, "Paths", "Sheets",      SheetsURL)
    DriveURL     := IniRead(SETTINGS_FILE, "Paths", "Drive",       DriveURL)
    LT_ClickX    := IniRead(SETTINGS_FILE, "Coords","LT_ClickX",   LT_ClickX)
    LT_ClickY    := IniRead(SETTINGS_FILE, "Coords","LT_ClickY",   LT_ClickY)
    ColorClick1X := IniRead(SETTINGS_FILE, "Coords","Color1X",     ColorClick1X)
    ColorClick1Y := IniRead(SETTINGS_FILE, "Coords","Color1Y",     ColorClick1Y)
    ColorClick2X := IniRead(SETTINGS_FILE, "Coords","Color2X",     ColorClick2X)
    ColorClick2Y := IniRead(SETTINGS_FILE, "Coords","Color2Y",     ColorClick2Y)
}

SaveConfigurablePaths() {
    global SETTINGS_FILE
    global PickerPath, FishbonePath, ResizerPath, SheetsURL, DriveURL
    global LT_ClickX, LT_ClickY, ColorClick1X, ColorClick1Y, ColorClick2X, ColorClick2Y
    IniWrite(PickerPath,   SETTINGS_FILE, "Paths",  "ColorPicker")
    IniWrite(FishbonePath, SETTINGS_FILE, "Paths",  "Fishbone")
    IniWrite(ResizerPath,  SETTINGS_FILE, "Paths",  "BatchResizer")
    IniWrite(SheetsURL,    SETTINGS_FILE, "Paths",  "Sheets")
    IniWrite(DriveURL,     SETTINGS_FILE, "Paths",  "Drive")
    IniWrite(LT_ClickX,    SETTINGS_FILE, "Coords", "LT_ClickX")
    IniWrite(LT_ClickY,    SETTINGS_FILE, "Coords", "LT_ClickY")
    IniWrite(ColorClick1X, SETTINGS_FILE, "Coords", "Color1X")
    IniWrite(ColorClick1Y, SETTINGS_FILE, "Coords", "Color1Y")
    IniWrite(ColorClick2X, SETTINGS_FILE, "Coords", "Color2X")
    IniWrite(ColorClick2Y, SETTINGS_FILE, "Coords", "Color2Y")
}

LinkItemsDefaults() {
    global LinkItems, PickerPath, FishbonePath, ResizerPath, SheetsURL, DriveURL
    LinkItems := []
    _LI(t, i, l, h, c, n, a*) {
        m := Map("type",t,"icon",i,"label",l,"hover",h,"color",c,"note",n)
        loop a.Length // 2
            m[a[A_Index * 2 - 1]] := a[A_Index * 2]
        return m
    }
    LinkItems.Push(_LI("sep","","Main","","",""))
    LinkItems.Push(_LI("system","◈","Main Ctl","Toggle Main Control`n(Alt+F1)","455A64","open main gui window","fn","ToggleMainWindow","system",true))
    LinkItems.Push(_LI("sep","","Guide","","",""))
    LinkItems.Push(_LI("system","?","Guide","Toolkit Guide`n(?)","9C27B0","open guide use","fn","ShowCSPGuide","system",true))
    LinkItems.Push(_LI("sep","","Action","","",""))
    LinkItems.Push(_LI("action","🕑","Worktime","Worktime Reset","32A0F5","reset worktime","keys","{Shift Down}{CTRL Down}{Alt Down}{\}{Shift Up}{CTRL Up}{Alt Up}","extra","{Enter}"))
    LinkItems.Push(_LI("action","🖼️","Canvas","Canvas Properties","DB133B","edit the canvas properties","keys","{Shift Down}{CTRL Down}{Alt Down}{=}{Shift Up}{CTRL Up}{Alt Up}"))
    LinkItems.Push(_LI("action","🎞","Timeline","Timeline Tool","B388FF","edit animation timeline","keys","{Shift Down}{Alt Down}{s}{Shift Up}{Alt Up}"))
    LinkItems.Push(_LI("action","「」","Crop","Crop Image","B59560","crop the image","keys","{Ctrl Down}{/}{Ctrl Up}"))
    LinkItems.Push(_LI("sep","","Link","","",""))
    LinkItems.Push(_LI("url","📊","Sheets","Google Sheets","0F9D58","open Google Sheets","target",SheetsURL))
    LinkItems.Push(_LI("sep","","Drive","","",""))
    LinkItems.Push(_LI("url","📁","Drive","Google Drive","4285F4","open Google Drive","target",DriveURL))
    LinkItems.Push(_LI("sep","","Script","","",""))
    LinkItems.Push(_LI("script","🎨","ColorPicker","Nastarxa Color Picker","E39A2D","run color picker tool","target",PickerPath))
    LinkItems.Push(_LI("script","🐟","Fishbone","Fishbone Inbetween","5E81AC","run fishbone inbetween tool","target",FishbonePath))
    LinkItems.Push(_LI("script","🖼","BatchResizer","Batch Image Resizer","7CB342","run batch image resizer","target",ResizerPath))
}

LoadLinkItems() {
    global SETTINGS_FILE, LinkItems
    LinkItemsDefaults()
    if !FileExist(SETTINGS_FILE)
        return
    cnt := IniRead(SETTINGS_FILE, "LinkItems", "count", 0)
    if cnt <= 0
        return
    userItems := []
    loop cnt {
        i := A_Index
        t := IniRead(SETTINGS_FILE, "LinkItems", i "_type", "")
        if t = ""
            continue
        m := Map("type", t)
        for key in ["icon","label","hover","note","color","keys","extra","target","enabled"] {
            v := IniRead(SETTINGS_FILE, "LinkItems", i "_" key, "")
            if v != ""
                m[key] := StrReplace(v, "\n", "`n")
        }
        userItems.Push(m)
    }
    ui := 1
    for idx, item in LinkItems {
        if item.Get("system", false) || item.Get("type","") = "system"
            continue
        if ui <= userItems.Length {
            LinkItems[idx] := userItems[ui]
            ui++
        }
    }
    while ui <= userItems.Length {
        if userItems[ui].Get("type","") != "system" {
            LinkItems.Push(userItems[ui])
        }
        ui++
    }
}

SaveLinkItems() {
    global SETTINGS_FILE, LinkItems
    cnt := 0
    for idx, item in LinkItems {
        if item.Get("type","") = "system"
            continue
        cnt++
        i := cnt
        IniWrite(item.Get("type",""), SETTINGS_FILE, "LinkItems", i "_type")
        for key in ["icon","label","hover","note","color","keys","extra","target","enabled"] {
            if item.Has(key) {
                v := item[key]
                if key = "keys" || key = "hover"
                    v := StrReplace(v, "`n", "\n")
                IniWrite(v, SETTINGS_FILE, "LinkItems", i "_" key)
            }
        }
    }
    IniWrite(cnt, SETTINGS_FILE, "LinkItems", "count")
}

; ============================================================
; FEATURES — Link Button Manager
; ============================================================

ShowLinkManager() {
    global LinkItems, SETTINGS_FILE
    dlg := Gui("+AlwaysOnTop +ToolWindow +Owner", "Link Button Manager")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")

    lv := dlg.AddListView("w" S(540) " r" S(14) " +Multi +ReadOnly NoSortHdr", ["#","Type","Icon","Name","Label","Note"])
    lv.SetFont("c000000", "Segoe UI")
    lv.OnEvent("DoubleClick", (*) => EditItem())
    lv.ModifyCol(1, S(24))
    lv.ModifyCol(2, S(55))
    lv.ModifyCol(3, S(35))
    lv.ModifyCol(4, S(130))
    lv.ModifyCol(5, S(85))
    lv.ModifyCol(6, S(190))

    RefreshList()

    ; Deep clone for Reset Selected
    _savedDefaults := []
    for item in LinkItems {
        m := Map()
        for k, v in item
            m[k] := v
        _savedDefaults.Push(m)
    }

    dlg.AddButton("xm w" S(53) " h" S(26), "▲ Up").OnEvent("Click", (*) => MoveItem(-1))
    dlg.AddButton("x+" S(6) " yp w" S(53) " h" S(26), "▼ Down").OnEvent("Click", (*) => MoveItem(1))
    dlg.AddButton("x+" S(8) " yp w" S(70) " h" S(26), "Add").OnEvent("Click", (*) => AddItem())
    dlg.AddButton("x+" S(6) " yp w" S(70) " h" S(26), "Edit").OnEvent("Click", (*) => EditItem())
    dlg.AddButton("x+" S(8) " yp w" S(60) " h" S(26), "Remove").OnEvent("Click", (*) => RemoveItem())
    dlg.AddButton("x+" S(6) " yp w" S(95) " h" S(26), "Reset Selected").OnEvent("Click", (*) => ResetSelected())
    dlg.AddButton("x+" S(6) " yp w" S(95) " h" S(26), "Reset All").OnEvent("Click", (*) => ResetAll())
    dlg.AddButton("xm y+" S(6) " w" S(112) " h" S(26), "ON/OFF").OnEvent("Click", (*) => ToggleItem())
    dlg.AddButton("x+" S(8) " yp w" S(70) " h" S(26) " Default", "Save").OnEvent("Click", (*) => DoSave())
    dlg.AddButton("x+" S(6) " yp w" S(70) " h" S(26), "Close").OnEvent("Click", (*) => dlg.Destroy())
    dlg.AddButton("x+" S(8) " yp w" S(60) " h" S(26) " Background4CAF50 cFFFFFF", "Apply").OnEvent("Click", (*) => DoApply())
    dlg.AddButton("x+" S(109) " yp w" S(95) " h" S(26) " c9C27B0", "❓ Keys Guide").OnEvent("Click", (*) => ShowKeysGuide())

    dlg.Show()

    AddItem() {
        item := LinkItemDialog(Map())
        if item {
            LinkItems.Push(item)
            SaveLinkItems()
            RebuildLinkGUI()
            RefreshList()
        }
    }

    EditItem() {
        r := lv.GetNext()
        if !r
            return
        idx := Integer(lv.GetText(r, 1))
        item := LinkItems[idx]
        if item.Get("system", false)
            return
        newItem := LinkItemDialog(item.Clone())
        if newItem {
            LinkItems[idx] := newItem
            SaveLinkItems()
            RebuildLinkGUI()
            RefreshList()
        }
    }

    RemoveItem() {
        rows := []
        r := 0
        while r := lv.GetNext(r)
            rows.Push(Integer(lv.GetText(r, 1)))
        if rows.Length = 0
            return
        if !RemovePrompt()
            return
        for i in rows {
            idx := rows[rows.Length - A_Index + 1]
            item := LinkItems[idx]
            if item.Get("system", false)
                continue
            LinkItems.RemoveAt(idx)
        }
        SaveLinkItems()
        RebuildLinkGUI()
        RefreshList()
    }

    RemovePrompt() {
        popup := Gui("+AlwaysOnTop +ToolWindow", "Remove Link Buttons")
        popup.BackColor := "1E1F22"
        popup.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
        popup.MarginX := S(14)
        popup.MarginY := S(14)
        popup.AddText("cFFD54F", "Remove selected link buttons?")
        result := false
        popup.AddButton("xm y+10 w" S(80) " h" S(26) " BackgroundE53935 cFFFFFF", "Yes").OnEvent("Click", (*) => (result := true, popup.Destroy()))
        popup.AddButton("x+8 yp w" S(80) " h" S(26), "No").OnEvent("Click", (*) => popup.Destroy())
        popup.Show("AutoSize")
        WinWaitClose(popup)
        return result
    }

    ToggleItem() {
        r := lv.GetNext()
        if !r
            return
        idx := Integer(lv.GetText(r, 1))
        item := LinkItems[idx]
        if item.Get("system", false)
            return
        item["enabled"] := !item.Get("enabled", true)
        RefreshList()
    }

    MoveItem(dir) {
        r := lv.GetNext()
        if !r
            return
        idx := Integer(lv.GetText(r, 1))
        ni := idx + dir
        if ni < 1 || ni > LinkItems.Length
            return
        tmp := LinkItems[idx]
        LinkItems[idx] := LinkItems[ni]
        LinkItems[ni] := tmp
        SaveLinkItems()
        RefreshList()
        lv.Modify(r + dir, "Select Focus")
    }

    ResetSelected() {
        rows := []
        r := 0
        while r := lv.GetNext(r)
            rows.Push(Integer(lv.GetText(r, 1)))
        if rows.Length = 0
            return
        if !ResetPrompt()
            return
        for i in rows {
            idx := rows[rows.Length - A_Index + 1]
            item := LinkItems[idx]
            if item.Get("system", false)
                continue
            if idx <= _savedDefaults.Length {
                def := _savedDefaults[idx]
                newItem := Map()
                for k, v in def
                    newItem[k] := v
                LinkItems[idx] := newItem
            } else {
                LinkItems.RemoveAt(idx)
            }
        }
        SaveLinkItems()
        RebuildLinkGUI()
        RefreshList()
    }

    ResetAll() {
        if !ResetPrompt()
            return
        LinkItemsDefaults()
        SaveLinkItems()
        RebuildLinkGUI()
        RefreshList()
    }

    DoSave() {
        SaveLinkItems()
        RebuildLinkGUI()
    }

    DoApply() {
        SaveLinkItems()
        RebuildLinkGUI()
        dlg.Destroy()
    }

    ResetPrompt() {
        popup := Gui("+AlwaysOnTop +ToolWindow", "Reset Link Buttons")
        popup.BackColor := "1E1F22"
        popup.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
        popup.MarginX := S(14)
        popup.MarginY := S(14)
        popup.AddText("cFFD54F", "Restore default link buttons?")
        popup.AddText("xm y+" S(4) " cAAAAAA", "This will remove all custom items.")
        result := false
        popup.AddButton("xm y+10 w" S(80) " h" S(26) " BackgroundE53935 cFFFFFF", "Yes").OnEvent("Click", (*) => (result := true, popup.Destroy()))
        popup.AddButton("x+8 yp w" S(80) " h" S(26), "No").OnEvent("Click", (*) => popup.Destroy())
        popup.Show("AutoSize")
        WinWaitClose(popup)
        return result
    }

    ShowKeysGuide(*) {
        guide := Gui("+AlwaysOnTop +ToolWindow", "Keys Guide")
        guide.BackColor := "1E1F22"
        guide.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
        guide.MarginX := S(14)
        guide.MarginY := S(14)
        guide.SetFont("s" S(10) " Bold", "Segoe UI")
        guide.AddText("xm", "Key Syntax Reference")
        guide.SetFont("s" S(9), "Segoe UI")
        guide.AddText("xm y+" S(6) " cAAAAAA", "Use AHK key notation inside {...}:")
        guide.AddText("xm y+" S(4), '  {LButton}        — Left mouse click')
        guide.AddText("xm y+" S(2), '  {RButton}        — Right mouse click')
        guide.AddText("xm y+" S(4) " cAAAAAA", "Modifier keys hold down until released:")
        guide.AddText("xm y+" S(2), '  {Shift Down}     — Press and hold Shift')
        guide.AddText("xm y+" S(2), '  {Shift Up}       — Release Shift')
        guide.AddText("xm y+" S(4) " cAAAAAA", "Key combinations (held together):")
        guide.AddText("xm y+" S(2), '  {Ctrl Down}{a}{Ctrl Up}  — Ctrl+A')
        guide.AddText("xm y+" S(4) " cAAAAAA", "Special keys:")
        guide.AddText("xm y+" S(2), "  {Enter}, {Tab}, {Esc}, {Space}")
        guide.AddText("xm y+" S(2), "  {F1}-{F12}, {1}-{0}, {a}-{z}")
        guide.AddText("xm y+" S(4) " cAAAAAA", "Extra keys (after): sent after main keys")
        guide.AddText("xm y+" S(2), '  e.g. {Enter} to confirm after shortcut')
        guide.AddButton("xm y+" S(10) " w" S(80) " h" S(26), "OK").OnEvent("Click", (*) => guide.Destroy())
        guide.Show("AutoSize")
    }

    RefreshList() {
        lv.Delete()
        for idx, item in LinkItems {
            enabled := item.Get("enabled", true)
            system := item.Get("system", false)
            icon := item.Get("icon","")
            note := item.Get("note","")
            if !enabled && !system {
                note := "DISABLED - " note
                icon := "⬤"
            }
            row := lv.Add("", idx, item.Get("type",""), icon, item.Get("hover",""), item.Get("label",""), note)
        }
    }
}

LinkItemDialog(existing) {
    if !IsObject(existing) || !existing.Has("type")
        existing := Map("type","action","icon","","label","","hover","","note","","color","455A64","keys","","extra","","target","")
    isNew := existing.Get("type","") = ""

    dlg := Gui("+AlwaysOnTop +Owner", isNew ? "Add Link Button" : "Edit Link Button")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")

    px := S(110)
    ew := S(250)

    dlg.AddText("xm", "Type:")
    ddl := dlg.AddDropDownList("x" px " yp w" ew " vType", ["action","url","script","sep"])
    t := existing.Get("type","action")
    ddl.Value := t = "url" ? 2 : t = "script" ? 3 : t = "sep" ? 4 : 1
    ddl.OnEvent("Change", (*) => ToggleType())

    dlg.AddText("xm y+" S(4), "Icon:")
    iconEd := dlg.AddEdit("x" px " yp w" ew " c000000 vIcon", existing.Get("icon",""))

    dlg.AddText("xm y+" S(4), "Color (hex):")
    colorEd := dlg.AddEdit("x" px " yp w" S(77) " c000000 vColor", existing.Get("color",""))
    c0 := dlg.AddText("x+" S(4) " yp w" S(22) " h" S(22) " +0x200 Background" (existing.Get("color","")!="" ? existing.Get("color","") : "455A64"), "")
    dlg.AddText("x+" S(4) " yp w" S(18) " h" S(22) " +0x200 BackgroundE53935 cFFFFFF Center", "R").OnEvent("Click", (*) => (colorEd.Value := "E53935", swatch(), colorEd.Focus()))
    dlg.AddText("x+" S(2) " yp w" S(18) " h" S(22) " +0x200 Background0F9D58 cFFFFFF Center", "G").OnEvent("Click", (*) => (colorEd.Value := "0F9D58", swatch(), colorEd.Focus()))
    dlg.AddText("x+" S(2) " yp w" S(18) " h" S(22) " +0x200 Background4285F4 cFFFFFF Center", "B").OnEvent("Click", (*) => (colorEd.Value := "4285F4", swatch(), colorEd.Focus()))
    dlg.AddText("x+" S(2) " yp w" S(18) " h" S(22) " +0x200 BackgroundE39A2D cFFFFFF Center", "O").OnEvent("Click", (*) => (colorEd.Value := "E39A2D", swatch(), colorEd.Focus()))
    dlg.AddText("x+" S(2) " yp w" S(18) " h" S(22) " +0x200 Background9C27B0 cFFFFFF Center", "V").OnEvent("Click", (*) => (colorEd.Value := "9C27B0", swatch(), colorEd.Focus()))
    dlg.AddText("x+" S(2) " yp w" S(18) " h" S(22) " +0x200 Background00BCD4 cFFFFFF Center", "C").OnEvent("Click", (*) => (colorEd.Value := "00BCD4", swatch(), colorEd.Focus()))
    dlg.AddText("x+" S(2) " yp w" S(18) " h" S(22) " +0x200 Background607D8B cFFFFFF Center", "Gr").OnEvent("Click", (*) => (colorEd.Value := "607D8B", swatch(), colorEd.Focus()))

    dlg.AddText("xm y+" S(4), "Label:")
    lblEd := dlg.AddEdit("x" px " yp w" ew " c000000 vLabel", existing.Get("label",""))

    dlg.AddText("xm y+" S(4), "Hover text:")
    hovEd := dlg.AddEdit("x" px " yp w" ew " c000000 vHover", existing.Get("hover",""))

    dlg.AddText("xm y+" S(4), "Note:")
    noteEd := dlg.AddEdit("x" px " yp w" ew " c000000 vNote", existing.Get("note",""))

    ; -- Contextual fields --
    dlg.AddText("xm y+" S(8) " w" S(350) " h1 Background444444  cFFD54F Section", "")  ; separator line
    sepLine := dlg.AddText("xm y+" S(2) " w" S(350) "  cffffff -Border", "Action: keystrokes to send")
    dlg.AddText("xm y+" S(8) " w" S(350) " h1 Background444444  cFFD54F", "")  ; separator line
    actKeysL := dlg.AddText("xm y+" S(6), "Keys:")
    actKeys  := dlg.AddEdit("x" px " yp w" ew " c000000", existing.Get("keys",""))
    actExtraL := dlg.AddText("xm y+" S(4), "Extra keys (after):")
    actExtra := dlg.AddEdit("x" px " yp w" ew " c000000", existing.Get("extra",""))
    urlPathL := dlg.AddText("xm y+" S(4)-56, "URL / Path:")
    urlPath  := dlg.AddEdit("x" px " yp w" S(ew - S(50)) " c000000 vUrlPath", existing.Get("target",""))
    browseBtn := dlg.AddButton("x+" S(4) " yp w" S(46) " h" S(22) " vBrowseBtn", "...")

    dlg.AddText("xm y-9", "")
    okBtn := dlg.AddButton("xm w" S(80) " h" S(26) " Default", "OK")
    caBtn := dlg.AddButton("x+" S(10) " yp w" S(80) " h" S(26), "Cancel")

    result := false

    ToggleType() {
        t := ddl.Text
        vis := t = "action"
        actKeysL.Visible := vis
        actKeys.Visible := vis
        actExtraL.Visible := vis
        actExtra.Visible := vis
        vis2 := t = "url" || t = "script"
        urlPathL.Visible := vis2
        urlPath.Visible := vis2
        browseBtn.Visible := t = "script"
        sepLine.Text := t = "action" ? "Keystrokes to send in CSP" : t = "url" ? "URL to open" : t = "script" ? "Script path to run" : "(no extra settings)"
        if t = "action"
            sepLine.Text := "Action: keystrokes to send"
        else if t = "url"
            sepLine.Text := "URL: web address to open"
        else if t = "script"
            sepLine.Text := "Script: .ahk / .exe path to run"
        else
            sepLine.Text := "Separator: section header, no extra settings"
        dlg.Show("AutoSize")
    }

    swatch(*) {
        c := colorEd.Value
        if RegExMatch(c, "^[0-9A-Fa-f]{1,6}$") {
            padded := c
            Loop 6 - StrLen(c)
                padded .= "0"
            c0.Opt("Background" padded)
            c0.Redraw()
        }
    }
    colorEd.OnEvent("Change", swatch)
    swatch()

    okBtn.OnEvent("Click", _OkClick)

    _OkClick(*) {
        result := Map(
            "type", ddl.Text,
            "icon", iconEd.Value,
            "label", lblEd.Value,
            "hover", hovEd.Value,
            "note", noteEd.Value,
            "color", colorEd.Value
        )
        t := ddl.Text
        if t = "action" {
            result["keys"] := actKeys.Value
            if actExtra.Value != ""
                result["extra"] := actExtra.Value
        } else if t = "url" || t = "script" {
            result["target"] := urlPath.Value
        }
        dlg.Destroy()
    }

    caBtn.OnEvent("Click", (*) => dlg.Destroy())

    browseBtn.OnEvent("Click", _BrowseClick)
    _BrowseClick(*) {
        f := FileSelect(3,, "Select script", "Scripts (*.ahk; *.exe)")
        if f != ""
            urlPath.Value := f
    }

    ToggleType()
    dlg.Show("AutoSize")
    WinWaitClose(dlg)
    return result
}

RebuildLinkGUI() {
    global LinkGUI, LinkGUI_X, LinkGUI_Y
    if IsObject(LinkGUI)
        LinkGUI.Destroy()
    CreateLinkGUI()
    PositionLinkGUI()
}

SelectIB(index) {
    global InbetweenIndex, LTLock
    if LTLock
        return ShowNotify("LT Lock", "🔒 Locked — IB disabled")
    InbetweenIndex := index
    d := InbetweenData[index]
    Send("^" index)
    Sleep 50
    Send("{Ctrl Down}{Shift Down}{Alt Down}{w}{Ctrl Up}{Shift Up}{Alt Up}")
    ShowNotify(d.bar, d.desc, d.color)
    UpdateIBGui(index)
}

; ============================================================
; FEATURES — Toggle commands
; ============================================================

ToggleLTLock(*) {
    global LTLock, IB_LockBtn
    LTLock := !LTLock
    if IsObject(IB_LockBtn) {
        IB_LockBtn.Text := LTLock ? "🔒" : "🔓"
        IB_LockBtn.Opt("Background" (LTLock ? "C62828" : "2A2A2A") " c" (LTLock ? "FFFFFF" : "AAAAAA"))
    }
    DebugLog("LT Lock " (LTLock ? "ON" : "OFF"))
    ShowNotify("LT Lock", LTLock ? "🔒 ON" : "🔓 OFF")
}

ToggleAutoSave(*) {
    global AutoSaveOn, AutoSaveBtn
    AutoSaveOn := !AutoSaveOn
    if IsObject(AutoSaveBtn) {
        AutoSaveBtn.Text := AutoSaveOn ? "💾" : "💤"
        AutoSaveBtn.Opt("Background" (AutoSaveOn ? "2E7D32" : "2A2A2A") " c" (AutoSaveOn ? "FFFFFF" : "AAAAAA"))
        AutoSaveBtn.Redraw()
    }
    DebugLog("Auto Save " (AutoSaveOn ? "ON" : "OFF"))
    ShowNotify("Auto Save", AutoSaveOn ? "ON (every 60s)" : "OFF")
}

ToggleNav(*) {
    global NavEnabled, NavBtn
    NavEnabled := !NavEnabled
    if IsObject(NavBtn) {
        NavBtn.Text := NavEnabled ? "🖐" : "🚫"
        NavBtn.Opt("Background" (NavEnabled ? "E65100" : "2A2A2A") " cFFFFFF")
    }
    ; reset auto-restore flag so manual toggle sticks
    CheckCSP._prevNav := false
    DebugLog("Navigation " (NavEnabled ? "ON" : "OFF"))
    ShowNotify("Navigation", NavEnabled ? "ON" : "OFF")
}

ToggleCapslock(*) {
    global CapslockEnabled, CapslockBtn
    CapslockEnabled := !CapslockEnabled
    if IsObject(CapslockBtn) {
        CapslockBtn.Text := CapslockEnabled ? "⇪" : "🚫"
        CapslockBtn.Opt("Background" (CapslockEnabled ? "1565C0" : "2A2A2A") " cFFFFFF")
    }
    CheckCSP._prevCaps := false
    DebugLog("Capslock " (CapslockEnabled ? "ON" : "OFF"))
    ShowNotify("Capslock", CapslockEnabled ? "ON" : "OFF")
}

ToggleTabCombos(*) {
    global TabCombosEnabled, TabCombosBtn
    TabCombosEnabled := !TabCombosEnabled
    if IsObject(TabCombosBtn) {
        TabCombosBtn.Text := TabCombosEnabled ? "Tab" : "🚫"
        TabCombosBtn.Opt("Background" (TabCombosEnabled ? "2E7D32" : "2A2A2A") " cFFFFFF")
    }
    CheckCSP._prevTab := false
    DebugLog("Tab Combos " (TabCombosEnabled ? "ON" : "OFF"))
    ShowNotify("Tab Combos", TabCombosEnabled ? "ON" : "OFF")
}

FirstRunWizard(*) {
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Nastarxa CSP Animator Toolkit — First Run")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.SetFont("s" S(11) " Bold", "Segoe UI")
    dlg.AddText("xm cFFFFFF", "Welcome to Nastarxa CSP Animator Toolkit!")
    dlg.SetFont("s" S(9) " norm", "Segoe UI")
    dlg.AddText("xm y+" S(6) " cAAAAAA", "This script adds productivity hotkeys and tools`nfor Clip Studio Paint.")
    dlg.AddText("xm y+" S(10) " cFFFFFF", "Before using, you need to calibrate:")
    dlg.AddText("xm y+" S(4) " cAAAAAA", "  • Light Table detection pixel (color matching)")
    dlg.AddText("xm y+" S(2) " cAAAAAA", "  • Click coordinates for LT Reset and LT Image Location")
    dlg.AddText("xm y+" S(2) " cAAAAAA", "  • (Optional) Script paths and URLs for the Link launcher")
    dlg.AddText("xm y+" S(10) " cFFFFFF", "Would you like to open the Settings window now?")
    result := false
    dlg.AddButton("xm y+" S(10) " w" S(100) " h" S(26) " Background4CAF50 cFFFFFF Default", "Yes").OnEvent("Click", (*) => (result := true, dlg.Destroy()))
    dlg.AddButton("x+" S(8) " yp w" S(100) " h" S(26), "No").OnEvent("Click", (*) => (result := false, dlg.Destroy()))
    dlg.Show("AutoSize")
    WinWaitClose(dlg)
    if result {
        ShowLTSettings()
        ShowNotify("First Run", "Configure LT pixel + click coords in Settings (⚙)")
    }
}

ToggleReset(*) {
    global ResetEnabled, ResetBtn
    ResetEnabled := !ResetEnabled
    if IsObject(ResetBtn) {
        ResetBtn.Text := ResetEnabled ? "↺" : "🚫"
        ResetBtn.Opt("Background" (ResetEnabled ? "6D28D9" : "2A2A2A") " cFFFFFF")
    }
    DebugLog("Reset Keys " (ResetEnabled ? "ON" : "OFF"))
    ShowNotify("Reset Keys", ResetEnabled ? "ON" : "OFF")
}

ToggleLWin(*) {
    global LWinEnabled, LWinBtn
    LWinEnabled := !LWinEnabled
    if IsObject(LWinBtn) {
        LWinBtn.Text := LWinEnabled ? "⊞" : "🚫"
        LWinBtn.Opt("Background" (LWinEnabled ? "FF6F00" : "2A2A2A") " cFFFFFF")
    }
    CheckCSP._prevLWin := false
    DebugLog("LWin Right-click " (LWinEnabled ? "ON" : "OFF"))
    ShowNotify("LWin Right-click", LWinEnabled ? "ON" : "OFF")
}

ShowCSPGuide() {
    guide := Gui("+AlwaysOnTop +ToolWindow", "Nastarxa CSP Animator Toolkit")
    guide.BackColor := "1E1F22"
    guide.SetFont("s10", "Segoe UI")
    guide.MarginX := 14
    guide.MarginY := 14

    guide.SetFont("s12 Bold", "Segoe UI")
    guide.AddText("cFFFFFF", "Nastarxa CSP Animator Toolkit — Guide")
    guide.SetFont("s9 norm", "Segoe UI")
    guide.AddText("xm y+4 c909090 w480",
        "Productivity hotkeys and automation for Clip Studio Paint.")

    content := "
    (

    The Nastarxa CSP Animator Toolkit is an AutoHotkey v2 script that
    supercharges Clip Studio Paint with custom hotkeys, automated
    actions, and productivity tools for animation workflows.

    Features:
      • Context-sensitive hotkeys (CSP-only, background, global)
      • Inbetween Bar — select inbetween ratios with Ctrl+1~7
      • Navigation — Space to pan, toggleable auto-hold
      • Light Table automation — pixel detection for LT state
      • Capslock modifier — holds Ctrl+Shift+Alt while pressed
      • Tab combos — Tab+1/2/3 for paper colors
      • Backtick (`) combos — inbetween types, layers, actions
      • Color Palette GUI — quick fill/swatch access
      • Layer shortcuts — new layers, opacity, visibility
      • Link Launcher — open tools, folders, URLs from GUI
      • Timer / Stopwatch — track work time with save (PNG/TXT)
      • Color Info — real-time hex/RGB picker under cursor
      • Auto Save — periodic file save (configurable interval)
      • Hotkey customization — edit/disable/import/export all keys
      • Opacity settings — transparency, UI scale, scroll power, reset
      • HK pause — temporarily disable all custom shortcuts
      • Debug Log — view script activity in real time
      • Hover tooltips — descriptions on all GUI buttons
      • Tool GUI toggle (^F1) — show/hide all tool GUIs
      • CSP crash monitor — prompts restart if CSP closes
      • Backup / Restore — full settings backup

    ── HOW TO USE ────────────────────────────────────────────

    Requirements:
      • AutoHotkey v2.0+ installed
      • Clip Studio Paint running
      • CSP Auto Actions Preset [Animation_action] and [Nastar] installed in CSP

    Getting Started:
      1. Run the script — it auto-detects CSP and activates
      2. Most hotkeys fire only when CSP is active (foreground)
      3. Use the Main GUI (Alt+F1) to toggle features on/off
      4. Open Hotkey Settings (⌨ button) to customize shortcuts
      5. Open LT Detection (⚙ button) to configure Light Table

    Main GUI buttons:
      ?  — this guide
      ⌨  — Hotkey Settings (browse, edit, import/export hotkeys)
      ⚙  — LT Detection Settings (pixel calibration, auto-save)
      🔗 — Link Button Manager (add/edit/reorder links)
      ⟲ — Reset GUI positions
      HK — pause/resume all custom shortcuts
      • Opacity opens transparency, UI scale, scroll power, and Reset
      • Right-click for opacity / debug / backup / restore

    Hotkey Settings tips:
      • Use Record to capture a key combo, or type directly
      • Prepend ^ (Ctrl), + (Shift), ! (Alt), # (Win)
      • Enter - (dash) to disable a hotkey
      • Click How to Use inside Hotkey Settings for details

    IB GUI controls:
      🖐 — toggle Navigation   ⇪ — toggle Capslock mod
      Tab — toggle Tab combos  ⊞ — toggle LWin mod
      S>E/E>S — toggle IB direction mode
      ↺ — reset stuck keys     ◎ — toggle Color Info
      🔓/🔒 — LT Lock          💤/💾 — Auto Save toggle
      ▶⏸⏹💾 — Timer controls (play, pause, reset, save)
      1~7 — select inbetween ratio
      Start > End: smaller layer above edit, bigger layer below
      End > Start: bigger layer above edit, smaller layer below
      🖐(orange) ⇪(blue) Tab(green) ↺(purple) — ON/OFF state
      • Right-click for opacity / context menu

    Color GUI buttons:
      R / G / B    — fill red, green, blue
      P / C / O    — fill pink, cyan, orange
      Tw           — select transparent
      D            — deselect
      🔁           — toggle horizontal/vertical layout
      • Right-click for opacity / context menu

    Link Launcher:
      • Default links: Worktime, Canvas, Timeline, Crop,
        Google Sheets/Drive, Color Picker, Fishbone, Resizer
      • Add/edit/remove/reorder links via Link Manager
      • Right-click any tool GUI for opacity / context menu
      • Right-click Main GUI for backup/restore config

    Hotkey categories (see list below):
      • Toggleable groups — Nav, Capslock, Tab, Reset, LWin
      • Always-on — inbetween bar, color palette, layers
      • Background — hotkeys when CSP is behind other windows

    ── INBETWEEN BAR ─────────────────────────────────────────

    Ctrl+1~7          Select inbetween type (bar shows ratio)
    Ctrl+F2 / Alt+L   Toggle LT lock
    Ctrl+F4           Toggle auto save (every 60s)
    Lock button       Locks light table when active
    Auto Save button  Saves file every 60 seconds

    ── NAVIGATION (toggleable) ───────────────────────────────

    Space             Pan (auto-hold LButton on press, release on key up)
    Ctrl+Space        Pan with Ctrl modifier
    Ctrl+Shift+Space  Quick Space tap (single press)
    Shift+Alt+Space   Pan with Shift+Alt modifier
    🖐 button / Ctrl+F5  Toggle navigation ON/OFF

    ── CAPSLOCK MOD (toggleable) ─────────────────────────────

    CapsLock          Holds Ctrl+Shift+Alt while pressed (LightTable 1-2-3)
    ⇪ button / Ctrl+F6  Toggle Capslock modifier ON/OFF

    ── TAB COMBOS (toggleable) ───────────────────────────────

    Tab+1             Paper purple
    Tab+2             Paper green
    Tab+3             Paper white
    Tab+`             Reset lighttable
    Tab button / Ctrl+F7  Toggle Tab combos ON/OFF

    ── BACKTICK COMBOS ───────────────────────────────────────

    Ctrl+`            Inbetween types
      CTRL+1          50 |-----|-----|>
      CTRL+2          S>E 66 |-------|---|> / E>S 33 |---|-------|>
      CTRL+3          S>E 33 |---|-------|> / E>S 66 |-------|---|>
      CTRL+4          S>E 75 |--------|--|> / E>S 25 |--|--------|>
      CTRL+5          S>E 25 |--|--------|> / E>S 75 |--------|--|>
      CTRL+6          S>E 60 |------|----|> / E>S 40 |----|------|>
      CTRL+7          S>E 40 |----|------|> / E>S 60 |------|----|>
 	
    Alt+`            Create New
      Alt+1          New Paper Layer
      Alt+2          New Raster Layer
      Alt+3          New Vector Layer
      Alt+4          New Colored Vector Layer
      Alt+5          New Dummy Layer
      Alt+6          Create Outline Layer for Coloring
      Alt+7          New Pink Vector Layer
      Alt+8          New Cyan Vector Layer
      Alt+9          New Orange Vector Layer
      Alt+0          New Animation Folder

    Shift+`          Quick Reference
      V              Flip Layer
      Shift+C        Reset Color
      Alt+C          Transparent Color
      Alt+V          Toggle Layer Visible
      Shift+B        Opacity 100
      Alt+B          Opacity 50
      Ctrl+Alt+B     Opacity 25
      Ctrl+B         Toggle Layer Color
      Shift+Alt+R    Select Red Line
      Shift+Alt+B    Select Blue Line
      Shift+Alt+G    Select Green Line
      Ctrl+Shift+Q   Set as Reference Layer
      Ctrl+Shift+F   Set as Draft Layer
      Ctrl+Shift+G   Clip to Layer Below
      Ctrl+Shift+R   Lock Layer
      Ctrl+Shift+E   Lock Layer Transparent
      Ctrl+Shift+W   Lock Animation Cel
      Ctrl+Shift+X   Delete Cel from Timeline
      Shift+X        Delete Cel from Lighttable
      Ctrl+Alt+D     Duplicate Layer
      Ctrl+Alt+G     Group Layer
      Ctrl+;         Rasterize Layer
      Capslock       LightTable
      Shift+Tab      Reset LightTable

    Ctrl+Shift+`     AutoAction
      Ctrl+Shift+1   Set Layer as Keyframe Color
      Ctrl+Shift+2   Set Layer as Reference Color
      Ctrl+Shift+3   Remove Layer Color
      Ctrl+Shift+4   Change Cel Color to Half (Green)
      Ctrl+Shift+5   Change Cel Color to Half (Purple)
      Ctrl+Shift+6   Activate Layer Color
      Ctrl+Shift+7   Deactivate Layer Color

    Ctrl+Alt+`       Animation
      Ctrl+Alt+W     Toggle Lighttable
      Alt+W          Toggle Onionskin
      Shift+Alt+W    Add Onionskin to Lighttable
      Shift+X        Delete Cel from Lighttable

    ── COLOR PALETTE ─────────────────────────────────────────

    R / G / B         Fill red/green/blue (Ctrl+Shift+Alt+C/V/B)
    Tw                Select transparent (Ctrl+Shift+Alt+F)
    D                 Deselect (Ctrl+D)
    P / C / O         Fill pink/cyan/orange (Ctrl+Shift+Alt+N/M/,)
    🔁                Toggle horizontal/vertical layout

    ── LAYER SHORTCUTS ───────────────────────────────────────

    Shift+1~8         New layer: Black, Red, Blue, Green, Pink,
                      Uranuri(Shadow), Paint, Rough
    Alt+1~9 / 0       New: Paper, Raster, Vector, Colored Vector,
                      Dummy, Outline, Pink/Cyan/Orange Vector, Folder
    Ctrl+Shift+1      Set layer keyframe color
    Ctrl+Shift+2      Set layer reference color
    Ctrl+Shift+3      Remove layer color
    Ctrl+Shift+4      Change cel color to half (Green)
    Ctrl+Shift+5      Change cel color to half (Purple)
    Ctrl+Shift+6      Activate layer color
    Ctrl+Shift+7      Deactivate layer color
    Shift+F1          Toggle tool GUIs

    ── QUICK ACTIONS ─────────────────────────────────────────

    Shift+B           Opacity 100
    Alt+B             Opacity 50
    Ctrl+Alt+B        Opacity 25
    Ctrl+B            Toggle layer color
    Alt+W             Toggle onion skin
    Alt+V             Toggle layer visibility
    X                 Swap brush primary/secondary
    Alt+C             Toggle brush transparent
    Shift+C           Reset color
    Ctrl+Alt+Shift+X  Delete layer
    Ctrl+Shift+X      Delete cel from timeline
    Shift+X           Delete cel from lighttable
    Alt+;             Transfer down vector + rasterize
    Ctrl+Alt+Shift+R  Transfer down vector
    Ctrl+Alt+Shift+E  Merge down layer
    Ctrl+Alt+Shift+T  Change color expression to gray
    Alt+Shift+Z       Move layer up
    Alt+Shift+X       Move layer down
    [                 Go to top layer
    ]                 Go to bottom layer
    Ctrl+Alt+D        Duplicate layer
    Ctrl+Alt+G        Create group folder
    Ctrl+Alt+Shift+G  UnGroup folder

    ── LINK LAUNCHER ─────────────────────────────────────────

    🕑 Worktime        Worktime reset
    🖼 Canvas           Canvas properties
    🎞 Timeline         Timeline tool
    「」 Crop           Crop image
    📊 Sheets          Open Google Sheets
    📁 Drive           Open Google Drive
    🎨 Color Picker    Open Nastarxa Color Picker
    🐟 Fishbone        Open Fishbone Inbetween Generator
    🖼 Batch Resizer    Open Batch Image Resizer

    ── IB GUI TOGGLE BUTTONS ────────────────────────────────

    🖐 (orange)       Navigation
    ⇪ (blue)          Capslock LT mod
    Tab (green)       Tab combos
    ↺ (purple)        Reset stuck modifier keys
    Each glows its own color when ON, dark OFF.

    ── RESET STUCK KEYS (toggleable) ─────────────────────────

    Ctrl+Alt+Shift+Space  Release all held modifiers
    ↺ button / Ctrl+F8    Toggle reset hotkey ON/OFF

    )"

    guide.SetFont("s9", "Consolas")
    guide.AddEdit("xm y+8 w520 h480 +ReadOnly +VScroll +Wrap Backgroundffffff c1E1F22", content)

    guide.AddButton("xm y+8 w" S(100) " h" S(28) " Background2196F3 cFFFFFF", "Recommended").OnEvent("Click", ShowCSPRecommended)
    btnClose := guide.AddButton("x+8 yp w100 h28", "Close")
    btnClose.Focus()
    btnClose.OnEvent("Click", (*) => guide.Destroy())
    
    guide.Show("w555 h592")
}

HK_HowToUse(*) {
    dlg := Gui("+AlwaysOnTop +ToolWindow", "How to Use — Hotkey Settings")
    dlg.BackColor := "1E1F22"

   dlg.SetFont("s10 Bold cFFFFFF", "Segoe UI")
    dlg.AddText("xm", "Hotkey Settings Help")

    dlg.SetFont("s8 norm cAAAAAA")
    dlg.AddText("xm y+2", "Manage and customize your shortcuts.")

    dlg.AddText("xm y+8 w430 h1 Background444444")

    ; LEFT COLUMN
    dlg.SetFont("s9 Bold cFFFFFF")
    dlg.AddText("xm y+10", "EDITING")

    dlg.SetFont("s9 norm cFFFFFF")
    dlg.AddText(
        "xm y+4 w180",
        "• Edit`n Opens the Edit Hotkey window to changethe selected hotkey.`n `n "
        "• ON / OFF`n Disables or re-enables the selected hotkey(s). Disabled hotkeys show `-` `n `n "
        "• Reset Selected`n Restores selected hotkey(s) to default.`n `n "
        "• Reset All`n Restores ALL hotkeys to defaults."
    )

    dlg.SetFont("s9 Bold cFFFFFF")
    dlg.AddText("xm y+10", "IMPORT / EXPORT")

    dlg.SetFont("s9 norm cFFFFFF")
    dlg.AddText(
        "xm y+4 w180",
        "• Export`nSaves your custom hotkeys to a file.`n`n"
        "• Import`nLoads custom hotkeys from a file.`n`n"
        "• Details`nShows info about the selected action."
    )

    ; RIGHT COLUMN
    x2 := S(220)

    dlg.SetFont("s9 Bold cFFFFFF")
    dlg.AddText("x" x2 " y63", "RECORDING")

    dlg.SetFont("s9 norm cFFFFFF")
    dlg.AddText(
        "x" x2 " y83 w190",
        "1. Click Record`n"
        "2. Press shortcut`n"
        "3. Apply"
    )

    dlg.SetFont("s9 Bold cFFFFFF")
    dlg.AddText("x" x2 " y143", "SUPPORTED FORMAT")

    dlg.SetFont("s9 norm cFFFFFF")
    dlg.AddText(
        "x" x2 " y163 w190",
        "Single Keys`n"
        "A, 1, Space, Tab, F1-F24`n`n"
        "Modifiers`n"
        "^ = Ctrl`n"
        "+ = Shift`n"
        "! = Alt`n"
        "# = Win`n`n"
        "Examples`n"
        "^c`n"
        "^+s`n"
        "^!+#t"
    )

    dlg.AddText("xm y+160 w430 h1 Background444444")

    dlg.SetFont("s9 norm cFFFF88")
    dlg.AddText("xm y+8", "Disable a hotkey by typing '-' (dash)")

    dlg.AddButton(
        "xm y+12 w240 h28",
        "Recommended CSP Shortcuts"
    ).OnEvent("Click", ShowCSPRecommended)
    
    dlg.btnClose := dlg.AddButton("x+8 yp w90 h28 Default","Close")

    dlg.btnClose.OnEvent("Click", (*) => dlg.Destroy())

    dlg.Show("AutoSize")
    dlg.btnClose.Focus()
}

ShowCSPRecommended(*) {
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Recommended CSP Shortcuts")
    dlg.BackColor := "F0F0F0"
    dlg.SetFont("s" S(9) " c202020", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)

    dlg.SetFont("s8", "Segoe UI")
    dlg.AddText("xm c6A6A6A", "Recommended CSP shortcut settings for using this script at its maximum potential.")
    dlg.SetFont("s" S(9), "Segoe UI")

    tabs := ["File", "Layer", "View/Draw", "Animation", "Workspace", "Tools", "Auto/Nastar"]
    tab := dlg.AddTab3("xm y+6 w" S(580) " h" S(420) " BackgroundFFFFFF c202020 ", tabs)
    dlg.SetFont("s9", "Consolas")

    loop 7 {
        tab.UseTab(A_Index)
        ed := dlg.AddEdit("xm y+1 w" S(580) " h" S(420) " +ReadOnly +VScroll +Wrap BackgroundFFFFFF c202020", "")
        ed.Value := RecContent(A_Index)
    }

    tab.UseTab(0)
    dlg.SetFont("s" S(9), "Segoe UI")

    dlg.btnClose := dlg.AddButton("xm yp+402 w" S(80) " h" S(26) " Default","Close")

    dlg.btnClose.OnEvent("Click", (*) => dlg.Destroy())

    dlg.Show("w" S(620) " h" S(495))
    dlg.btnClose.Focus()
}

RecContent(n) {
    static data := Map()
    if data.Count = 0
        _InitRecData(data)
    return data.Has(n) ? data[n] : ""
}

_InitRecData(data) {
    data[1] := "
    (LTrim

    ── File ───────────────────────────────────────────
    Ctrl+P                        Print
    Ctrl+K                        Preferences
    Ctrl+Shift+Alt+K              Shortcut Settings
    Ctrl+Shift+Alt+Y              Modifier Key Settings
    Ctrl+Z                        Undo
    Ctrl+Y                        Redo
    Ctrl+Shift+Z                  Alternate Redo
    Ctrl+X                        Cut
    Ctrl+C                        Copy
    F3                            Copy (alternate)
    Ctrl+V                        Paste
    F4                            Paste (alternate)
    Ctrl+Shift+V                  Paste to Shown Position
    Backspace                     Delete
    Ctrl+Del                      Delete (alternate)
    Ctrl+Backspace                Delete (alternate)
    Shift+Del                     Delete Outside Selection
    Shift+Backspace               Delete Outside Selection (alternate)
    Alt+Del                       Fill
    Alt+Backspace                 Fill (alternate)

    )"
    data[2] := "
    (LTrim

    ── Layer ───────────────────────────────────────────
    Ctrl+Shift+N                  New Raster Layer
    Ctrl+Alt+G                    Create Folder and Insert Layer
    Ctrl+Shift+Alt+G              Ungroup Layer Folder
    Del                           Delete Layer
    Home                          Delete Layer (alternate)
    Ctrl+Shift+Q                  Set as Reference Layer
    Ctrl+Shift+F                  Set as Draft Layer
    Ctrl+Shift+G                  Clip to Layer Below
    Ctrl+Shift+R                  Lock Layer
    Ctrl+Shift+E                  Lock Transparent Pixels
    Alt+V                         Show Layer
    F2                            Change Layer Name
    Ctrl+;                        Rasterize
    ;                             Transfer To Lower Layer
    Ctrl+Shift+Alt+E              Merge with Layer Below
    Shift+Alt+E                   Merge Selected Layers

    ══ Layer Order ════════════════════════════════════
    Shift+Alt+Z                   Up
    Shift+Alt+X                   Down
    [                             Layer Above
    ]                             Layer Below

    )"
    data[3] := "
    (LTrim

    ── View ───────────────────────────────────────────
    V                             Flip Horizontal
    -                             Rotate Left
    '                             Rotate Right
    Ctrl+Num+                     Zoom In
    Alt+Z                         Zoom In (alternate)
    Ctrl+=                        Zoom In (alternate)
    Ctrl+Num-                     Zoom Out
    Ctrl+Alt+0                    100%
    Ctrl+0                        Fit to Screen

    ══ Drawing Color ══════════════════════════════════
    X                             Switch Main/Sub Color
    Alt+C                         Switch Drawing Color and Transparent
    Shift+Alt+C                   Switch Between Main and Sub Color
    Shift+C                       Main Color → Black, Sub → White

    ══ Layer Properties ═══════════════════════════════
    Ctrl+B                        Switch Using Layer Color

    ══ Layer Palette ══════════════════════════════════
    Shift+W                       Open/Close All Folders

    )"
    data[4] := "
    (LTrim

    ── Animation / Timeline ──────────────────────────
    Alt+Q                         Play / Stop
    A                             Previous Frame
    D                             Next Frame
    Shift+A                       Create Timeline Label
    Shift+D                       Delete Timeline Label
    Shift+Alt+S                   Change Timeline Settings
    Alt+A                         Select Previous Cel
    Alt+D                         Select Next Cel
    S                             Assign Cel to Frame
    Shift+Alt+A                   Set as First Displayed Frame
    Shift+Alt+D                   Set as Last Displayed Frame

    ══ Onion Skin / Light Table ═══════════════════════
    Alt+W                         Enable Onion Skin
    Ctrl+Alt+W                    Enable Light Table
    Ctrl+Shift+W                  Lock Current Animation Cel as Editing Target
    Shift+Alt+W                   Register Onion Skin Images
    Shift+X                       Deregister Selected Image from LT
    Ctrl+Shift+Alt+1              Check Cel Motion by Key Input (1)
    Ctrl+Shift+Alt+2              Check Cel Motion by Key Input (2)
    Ctrl+Shift+Alt+3              Check Cel Motion by Key Input (3)

    )"
    data[5] := "
    (LTrim
    ── Workspace / Window ────────────────────────────
    Ctrl+Alt+1                    Timeline Palette
    Ctrl+Alt+2                    Layer Palette
    Ctrl+Alt+3                    Auto Action Palette
    Ctrl+Alt+4                    Sub View Palette
    Ctrl+Alt+5                    Navigator Palette

    ══ Transform ══════════════════════════════════════
    Ctrl+T                        Scale/Rotate
    Ctrl+Shift+T                  Free Transform

    ══ Corrections ════════════════════════════════════
    Ctrl+U                        Hue / Saturation / Luminosity
    Ctrl+I                        Reverse Gradient

    ══ Misc ═══════════════════════════════════════════
    Ctrl+Shift+Alt+=              Canvas Properties
    Ctrl+Shift+Alt+\              Canvas Work Time
    Ctrl+Shift+B                  Pick Screen Color

    )"
    data[6] := "
    (LTrim

    ── Tools ──────────────────────────────────────────
    Y                             Correct Line / Pinch / Simplify Vector
    B                             Brush / Decoration
    J                             Liquify / Blend
    W                             Auto Select
    M                             Selection Area
    U                             Figure
    C                             Eyedropper
    N                             Comic
    O                             Operation → Object
    K                             Operation → Move Layer
    L                             Operation → Light Table / Edit Timeline

    ══ Pen Tools ══════════════════════════════════════
    Q                             Dual Brush Thick / Curve / Mechanical / Animation Pen
    /                             Animation G-Pen
    F                             Curve No Pen Pressure
    R                             Waved Line / Simple Line

    ══ Bucket / Fill ══════════════════════════════════
    G                             Bucket RGB 0.0.0
    E                             Animation Eraser / Vector Eraser / Vector Cut

    )"
    data[7] := "
    (LTrim

    Need to use CSP Auto Actions Preset [Animation_action] and [Nastar]
    
    ── Animation Timing ──────────────────────────────
    Ctrl+1                        50 |---|---|>
    Ctrl+2                        33 End→Start / 66 Start→End
    Ctrl+3                        66 End→Start / 33 Start→End
    Ctrl+4                        25 End→Start / 75 Start→End
    Ctrl+5                        75 End→Start / 25 Start→End
    Ctrl+6                        40 End→Start / 60 Start→End
    Ctrl+7                        60 End→Start / 40 Start→End

    ══ Opacity ════════════════════════════════════════
    Shift+B                       Opacity 100
    Alt+B                         Opacity 50
    Ctrl+Alt+B                    Opacity 25

    ══ Color Selection ════════════════════════════════
    Shift+1 / 2 / 3 / 4 / 5       Black / Red / Blue / Green / Pink
    Shift+6 / 7 / 8               Uranuri / Paint / Rough
    Shift+0                       Bucket Uranuri

    ══ Layer Creation ═════════════════════════════════
    Alt+1                         New Paper Layer
    Alt+2                         New Raster Layer
    Alt+3                         New Vector Layer
    Alt+4                         New Colored Vector Layer
    Alt+5                         New Dummy Ref Layer
    Alt+6                         Create Outline Layer (For Coloring)
    Alt+7                         New Pink Vector Layer
    Alt+8                         New Cyan Vector Layer
    Alt+9                         New Orange Vector Layer
    Alt+0                         New Animation Folder

    ══ Color Layer Utilities ══════════════════════════
    Ctrl+Shift+1                  Set as Keyframe Color
    Ctrl+Shift+2                  Set as Reference Color
    Ctrl+Shift+3                  Remove Keyframe Color
    Ctrl+Shift+=                  Change LT Layer → Half Color (Green)
    Ctrl+Shift+-                  Change LT Layer → Half Color (Purple)
    Ctrl+Shift+5                  Change LT Layer → Normal
    Ctrl+Shift+6                  Layer Color Black
    Ctrl+Shift+7                  Change Paper Color Purple
    Ctrl+Shift+8                  Change Paper Color Green
    Ctrl+Shift+9                  Change Paper Color White

    ══ Color Line Selection ═══════════════════════════
    Ctrl+Shift+Alt+C              Select Red Line
    Ctrl+Shift+Alt+V              Select Green Line
    Ctrl+Shift+Alt+B              Select Blue Line
    Ctrl+Shift+Alt+F              Select Transparent
    Ctrl+Shift+Alt+T              Change Color Expression → Gray

    )"
}

ShowLTSettings() {
    global LT_X, LT_Y, LT_Color, LT_ClickX, LT_ClickY, ColorClick1X, ColorClick1Y, ColorClick2X, ColorClick2Y, _ccOffsetX, _ccOffsetY, AutoSaveInterval, SETTINGS_FILE
    static sGui := 0
    if IsObject(sGui) {
        try if sGui.Hwnd {
            sGui.Show()
            return
        }
    }
sGui := Gui("+AlwaysOnTop +ToolWindow", "LT Detection Settings")
sGui.BackColor := "1E1F22"
sGui.SetFont("s9 cFFFFFF", "Segoe UI")

sGui.MarginX := S(14)
sGui.MarginY := S(10)

leftW  := S(240)
rightX := S(300)
w      := S(510)

lblW   := S(65)
editW  := S(50)
btnW   := S(72)

; ==========================================================
; DETECTION PIXEL
; ==========================================================

sGui.AddText("xm cFFFFFF", "Detection Pixel")
sGui.AddText("xm y+2 w" leftW " h1 Background555555")

sGui.SetFont("s8 cFFFFFF", "Segoe UI")

sGui.AddText("xm y+8 w" lblW, "X:")
sGui.edX := sGui.AddEdit("x+4 yp w" editW " c000000 BackgroundFFFFFF", LT_X)

sGui.AddText("x+10 yp w20", "Y:")
sGui.edY := sGui.AddEdit("x+4 yp w" editW " c000000 BackgroundFFFFFF", LT_Y)

sGui.SetFont("s9 cFFFFFF", "Segoe UI")

sGui.AddText("xm y+10 w" lblW, "Expected:")
sGui.edColor := sGui.AddEdit(
    "x+4 yp w70 h20 c000000 BackgroundFFFFFF",
    Format("#{:06X}", LT_Color)
)

sGui.expBox := sGui.AddEdit(
    "x+6 yp w28 h20 ReadOnly Background" Format("{:06X}", LT_Color),
    ""
)
DllCall("uxtheme\SetWindowTheme", "ptr", sGui.expBox.Hwnd, "wstr", "", "ptr", 0)

sGui.expMatch := sGui.AddText("x+4 yp w20 cAAAAAA")

sGui.AddText("xm y+8 w" lblW, "Found:")

sGui.fndHex := sGui.AddText(
    "x+4 yp w70 h20 +0x200 +Border Background2D2D32 cAAAAAA",
    ""
)

sGui.fndBox := sGui.AddEdit(
    "x+6 yp w28 h20 ReadOnly BackgroundFFFFFF",
    ""
)
DllCall("uxtheme\SetWindowTheme", "ptr", sGui.fndBox.Hwnd, "wstr", "", "ptr", 0)

sGui.AddButton("xm y+10 w" btnW+78 " h24", "Test")
    .OnEvent("Click", TestLTCoords)

sGui.AddButton("xm y+10 w" btnW " h24", "Save")
    .OnEvent("Click", SaveLTDetect)

sGui.AddButton("x+6 yp w" btnW " h24", "Reset")
    .OnEvent("Click", ResetLTDetect)

; ==========================================================
; CLICK COORDINATES
; ==========================================================

sGui.SetFont("s9 cFFFFFF", "Segoe UI")

sGui.AddText("x" rightX " y10 cFFFFFF", "Click Coordinates")
sGui.AddText("x" rightX " y+2 w200 h1 Background555555")

sGui.SetFont("s8 cAAAAAA", "Segoe UI")
sGui.AddText("x" rightX " y+6", "Screen coordinates used by CSP.")
sGui.AddText("x" rightX " y+2", "Recalibrate if the window moves.")

sGui.SetFont("s8 cFFFFFF", "Segoe UI")

sGui.AddText("x" rightX " y+10 w60", "LT Reset")
sGui.AddText("xp+45 yp", "X:")
sGui.edLTX := sGui.AddEdit("x+6 yp w44 c000000 BackgroundFFFFFF", LT_ClickX)
sGui.AddText("x+6 yp", "Y:")
sGui.edLTY := sGui.AddEdit("x+6 yp w44 c000000 BackgroundFFFFFF", LT_ClickY)

sGui.AddText("x" rightX " y+10 w60", "Image 1")
sGui.AddText("xp+45 yp", "X:")
sGui.edC1X := sGui.AddEdit("x+6 yp w44 c000000 BackgroundFFFFFF", ColorClick1X)
sGui.AddText("x+6 yp", "Y:")
sGui.edC1Y := sGui.AddEdit("x+6 yp w44 c000000 BackgroundFFFFFF", ColorClick1Y)

sGui.AddText("x" rightX " y+10 w60", "Image 2")
sGui.AddText("xp+45 yp", "X:")
sGui.edC2X := sGui.AddEdit("x+6 yp w44 c000000 BackgroundFFFFFF", ColorClick2X)
sGui.AddText("x+6 yp", "Y:")
sGui.edC2Y := sGui.AddEdit("x+6 yp w44 c000000 BackgroundFFFFFF", ColorClick2Y)

sGui.AddButton("x" rightX " y+10 w" btnW " h24", "Save")
    .OnEvent("Click", SaveClickCoords)

sGui.AddButton("x+6 yp w" btnW " h24", "Reset")
    .OnEvent("Click", ResetClickCoords)

; ==========================================================
; COLOR OFFSET
; ==========================================================

sGui.SetFont("s9 cFFFFFF", "Segoe UI")

sGui.AddText("xm y+20", "Color Info Offset")
sGui.AddText("xm y+2 w" leftW " h1 Background555555")

sGui.SetFont("s8 cAAAAAA", "Segoe UI")
sGui.AddText("xm y+6", "Offset from cursor while following mouse.")

sGui.SetFont("s8 cFFFFFF", "Segoe UI")

sGui.AddText("xm y+8 w" lblW, "X:")
sGui.edCCX := sGui.AddEdit("xp+16 yp w" editW " c000000 BackgroundFFFFFF", _ccOffsetX)

sGui.AddText("x+10 yp", "Y:")
sGui.edCCY := sGui.AddEdit("x+6 yp w" editW " c000000 BackgroundFFFFFF", _ccOffsetY)

sGui.AddButton("xm y+10 w" btnW " h24", "Save")
    .OnEvent("Click", SaveColorOffset)

sGui.AddButton("x+6 yp w" btnW " h24", "Reset")
    .OnEvent("Click", ResetColorOffset)

; ==========================================================
; AUTO SAVE
; ==========================================================

sGui.SetFont("s9 cFFFFFF", "Segoe UI")

sGui.AddText("x" rightX " yp-78", "Auto Save")
sGui.AddText("x" rightX " y+2 w200 h1 Background555555")

sGui.SetFont("s8 cAAAAAA", "Segoe UI")
sGui.AddText("x" rightX " y+6", "Save CSP file every N seconds.")

sGui.SetFont("s8 cFFFFFF", "Segoe UI")

sGui.AddText("x" rightX " y+8", "Interval:")
sGui.edAutoSave := sGui.AddEdit(
    "x+6 yp w44 c000000 BackgroundFFFFFF",
    AutoSaveInterval
)

sGui.AddText("x+6 yp+1 cAAAAAA", "(10-3600)")

sGui.AddButton("x" rightX " y+17 w" btnW " h24", "Save")
    .OnEvent("Click", SaveAutoSaveInterval)

sGui.AddButton("x+6 yp w" btnW " h24", "Reset")
    .OnEvent("Click", ResetAutoSaveInterval)

; ==========================================================
; BOTTOM
; ==========================================================

sGui.AddText("xm y+18 w" (w - S(28)) " h1 Background444444")

sGui.AddButton("xm y+10 w80 h26", "Save All")
    .OnEvent("Click", SaveAllSettings)

sGui.AddButton("x+10 yp w80 h26", "Reset All")
    .OnEvent("Click", ResetLTCoords)

sGui.AddButton("x+10 yp w80 h26", "How To")
    .OnEvent("Click", (*) => ShowLTSettingsHelp())

sGui.AddButton("x+10 yp w80 h26", "OK")
    .OnEvent("Click", SaveLTCoords)

sGui.edX.OnEvent("Change", UpdateLTPreview)
sGui.edY.OnEvent("Change", UpdateLTPreview)
sGui.edColor.OnEvent("Change", UpdateLTPreview)

sGui.Show("w" w " h" S(390))
UpdateLTPreview(sGui.edX)
    UpdateLTPreview(sGui.edX)
}

TestLTCoords(ctrl, *) {
    global LT_Color, SETTINGS_FILE
    parentGui := ctrl.Gui
    val := RegExReplace(Trim(parentGui.edColor.Value), "[^0-9A-Fa-f]", "")
    if StrLen(val) = 0
        val := RegExReplace(Trim(parentGui.edColor.Text), "[^0-9A-Fa-f]", "")
    try expected := Integer("0x" val)
    catch
        expected := 0
    try c := PixelGetColor(Trim(parentGui.edX.Value), Trim(parentGui.edY.Value))
    catch
        c := 0
    parentGui.fndBox.Opt("Background" Format("{:06X}", c))
    parentGui.fndHex.Text := Format("#{:06X}", c)
    parentGui.expBox.Opt("Background" Format("{:06X}", expected))
    parentGui.expMatch.Text := (c = expected) ? "✓" : "✗"
    match := c = expected
    DllCall("InvalidateRect", "ptr", parentGui.Hwnd, "ptr", 0, "int", 1)
    DllCall("UpdateWindow", "ptr", parentGui.Hwnd)
    LT_Color := expected
    IniWrite(LT_Color, SETTINGS_FILE, "LT", "Color")
    popup := Gui("+AlwaysOnTop +ToolWindow", "LT Test")
    popup.BackColor := "1E1F22"
    popup.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    popup.MarginX := S(12)
    popup.MarginY := S(12)
    popup.AddText("xm", "Pixel at (" parentGui.edX.Value ", " parentGui.edY.Value "):")
    popup.SetFont("s" S(20) " Bold", "Segoe UI")
    clrHex := Format("#{:06X}", c)
    matchText := match ? "✓ Match!" : "✗ No Match"
    popup.AddText("xm y+8 c" (match ? "4CAF50" : "E53935"), clrHex "  " matchText)
    popup.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    popup.AddText("xm y+8", "Expected: " Format("#{:06X}", expected))
    popup.AddButton("xm y+10 w" S(80) " h" S(26), "OK").OnEvent("Click", (*) => popup.Destroy())
    popup.Show("AutoSize")
}

SaveLTCoords(ctrl, *) {
    global LT_X, LT_Y, LT_Color, LT_ClickX, LT_ClickY, ColorClick1X, ColorClick1Y, ColorClick2X, ColorClick2Y, _ccOffsetX, _ccOffsetY, AutoSaveInterval, SETTINGS_FILE
    _oldLTX := LT_X, _oldLTY := LT_Y, _oldAuto := AutoSaveInterval
    gui := ctrl.Gui
    try {
        LT_X := Integer(Trim(gui.edX.Value))
        LT_Y := Integer(Trim(gui.edY.Value))
        clr := RegExReplace(Trim(gui.edColor.Value), "[^0-9A-Fa-f]", "")
        LT_Color := clr != "" ? Integer("0x" clr) : 0
        LT_ClickX := Integer(Trim(gui.edLTX.Value))
        LT_ClickY := Integer(Trim(gui.edLTY.Value))
        ColorClick1X := Integer(Trim(gui.edC1X.Value))
        ColorClick1Y := Integer(Trim(gui.edC1Y.Value))
        ColorClick2X := Integer(Trim(gui.edC2X.Value))
        ColorClick2Y := Integer(Trim(gui.edC2Y.Value))
        _ccOffsetX := Integer(Trim(gui.edCCX.Value))
        _ccOffsetY := Integer(Trim(gui.edCCY.Value))
        n := Integer(gui.edAutoSave.Value)
        AutoSaveInterval := n < 10 ? 10 : n > 3600 ? 3600 : n
        SetTimer(DoAutoSave, AutoSaveInterval * 1000)
    } catch
        return SaveErrorPrompt()
    DebugLog("LT pixel (" _oldLTX "," _oldLTY ") → (" LT_X "," LT_Y "), auto-save " _oldAuto "s → " AutoSaveInterval "s")
    IniWrite(LT_X, SETTINGS_FILE, "LT", "X")
    IniWrite(LT_Y, SETTINGS_FILE, "LT", "Y")
    IniWrite(LT_Color, SETTINGS_FILE, "LT", "Color")
    IniWrite(LT_ClickX, SETTINGS_FILE, "Coords", "LT_ClickX")
    IniWrite(LT_ClickY, SETTINGS_FILE, "Coords", "LT_ClickY")
    IniWrite(ColorClick1X, SETTINGS_FILE, "Coords", "Color1X")
    IniWrite(ColorClick1Y, SETTINGS_FILE, "Coords", "Color1Y")
    IniWrite(ColorClick2X, SETTINGS_FILE, "Coords", "Color2X")
    IniWrite(ColorClick2Y, SETTINGS_FILE, "Coords", "Color2Y")
    IniWrite(_ccOffsetX, SETTINGS_FILE, "ColorInfo", "OffsetX")
    IniWrite(_ccOffsetY, SETTINGS_FILE, "ColorInfo", "OffsetY")
    IniWrite(AutoSaveInterval, SETTINGS_FILE, "Settings", "AutoSaveInterval")
    gui.Destroy()
}

ResetLTCoords(ctrl, *) {
    gui := ctrl.Gui
    gui.edX.Value := 2305
    gui.edY.Value := 172
    gui.edColor.Value := "#677187"
    gui.edLTX.Value := 2313
    gui.edLTY.Value := 123
    gui.edC1X.Value := 2444
    gui.edC1Y.Value := 856
    gui.edC2X.Value := 2444
    gui.edC2Y.Value := 951
    gui.edCCX.Value := 20
    gui.edCCY.Value := 20
    UpdateLTPreview(gui.edX)
}

ResetLTDetect(ctrl, *) {
    gui := ctrl.Gui
    gui.edX.Value := 2305
    gui.edY.Value := 172
    gui.edColor.Value := "#677187"
    UpdateLTPreview(gui.edX)
}

ResetClickCoords(ctrl, *) {
    gui := ctrl.Gui
    gui.edLTX.Value := 2313
    gui.edLTY.Value := 123
    gui.edC1X.Value := 2444
    gui.edC1Y.Value := 856
    gui.edC2X.Value := 2444
    gui.edC2Y.Value := 951
}

ResetColorOffset(ctrl, *) {
    gui := ctrl.Gui
    gui.edCCX.Value := 20
    gui.edCCY.Value := 20
}

UpdateLTPreview(ctrl, *) {
    parentGui := ctrl.Gui
    raw := RegExReplace(Trim(parentGui.edColor.Value), "[^0-9A-Fa-f]", "")
    if StrLen(raw) = 6 {
        try {
            expected := Integer("0x" raw)
            parentGui.expBox.Opt("Background" Format("{:06X}", expected))
        } catch
            parentGui.expBox.Opt("BackgroundFFFFFF")
    } else
        parentGui.expBox.Opt("BackgroundFFFFFF")
    DllCall("InvalidateRect", "ptr", parentGui.Hwnd, "ptr", 0, "int", 1)
    DllCall("UpdateWindow", "ptr", parentGui.Hwnd)
}

SaveLTDetect(ctrl, *) {
    global LT_X, LT_Y, LT_Color, SETTINGS_FILE
    _oldX := LT_X, _oldY := LT_Y
    gui := ctrl.Gui
    try {
        LT_X := Integer(Trim(gui.edX.Value))
        LT_Y := Integer(Trim(gui.edY.Value))
        clr := RegExReplace(Trim(gui.edColor.Value), "[^0-9A-Fa-f]", "")
        LT_Color := clr != "" ? Integer("0x" clr) : 0
    } catch
        return ShowNotify("LT Detection", "Invalid input")
    DebugLog("LT detect (" _oldX "," _oldY ") → (" LT_X "," LT_Y ")")
    IniWrite(LT_X, SETTINGS_FILE, "LT", "X")
    IniWrite(LT_Y, SETTINGS_FILE, "LT", "Y")
    IniWrite(LT_Color, SETTINGS_FILE, "LT", "Color")
}

SaveClickCoords(ctrl, *) {
    global LT_ClickX, LT_ClickY, ColorClick1X, ColorClick1Y, ColorClick2X, ColorClick2Y, SETTINGS_FILE
    _old := Map("LTx", LT_ClickX, "LTy", LT_ClickY, "C1x", ColorClick1X, "C1y", ColorClick1Y, "C2x", ColorClick2X, "C2y", ColorClick2Y)
    gui := ctrl.Gui
    try {
        LT_ClickX := Integer(Trim(gui.edLTX.Value))
        LT_ClickY := Integer(Trim(gui.edLTY.Value))
        ColorClick1X := Integer(Trim(gui.edC1X.Value))
        ColorClick1Y := Integer(Trim(gui.edC1Y.Value))
        ColorClick2X := Integer(Trim(gui.edC2X.Value))
        ColorClick2Y := Integer(Trim(gui.edC2Y.Value))
    } catch
        return ShowNotify("Click Coords", "Invalid input")
    DebugLog("Click coords LT (" _old["LTx"] "," _old["LTy"] ") → (" LT_ClickX "," LT_ClickY "), Color1 (" _old["C1x"] "," _old["C1y"] ") → (" ColorClick1X "," ColorClick1Y "), Color2 (" _old["C2x"] "," _old["C2y"] ") → (" ColorClick2X "," ColorClick2Y ")")
    IniWrite(LT_ClickX, SETTINGS_FILE, "Coords", "LT_ClickX")
    IniWrite(LT_ClickY, SETTINGS_FILE, "Coords", "LT_ClickY")
    IniWrite(ColorClick1X, SETTINGS_FILE, "Coords", "Color1X")
    IniWrite(ColorClick1Y, SETTINGS_FILE, "Coords", "Color1Y")
    IniWrite(ColorClick2X, SETTINGS_FILE, "Coords", "Color2X")
    IniWrite(ColorClick2Y, SETTINGS_FILE, "Coords", "Color2Y")
}

SaveColorOffset(ctrl, *) {
    global _ccOffsetX, _ccOffsetY, SETTINGS_FILE
    _oldX := _ccOffsetX, _oldY := _ccOffsetY
    gui := ctrl.Gui
    try {
        _ccOffsetX := Integer(Trim(gui.edCCX.Value))
        _ccOffsetY := Integer(Trim(gui.edCCY.Value))
    } catch
        return ShowNotify("Color Offset", "Invalid input")
    DebugLog("Color Info offset (" _oldX "," _oldY ") → (" _ccOffsetX "," _ccOffsetY ")")
    IniWrite(_ccOffsetX, SETTINGS_FILE, "ColorInfo", "OffsetX")
    IniWrite(_ccOffsetY, SETTINGS_FILE, "ColorInfo", "OffsetY")
}

SaveAutoSaveInterval(ctrl, *) {
    global AutoSaveInterval, SETTINGS_FILE
    gui := ctrl.Gui
    try {
        n := Integer(gui.edAutoSave.Value)
        AutoSaveInterval := n < 10 ? 10 : n > 3600 ? 3600 : n
        SetTimer(DoAutoSave, AutoSaveInterval * 1000)
        IniWrite(AutoSaveInterval, SETTINGS_FILE, "Settings", "AutoSaveInterval")
        DebugLog("Auto save interval set to " AutoSaveInterval "s")
    } catch
        return ShowNotify("Auto Save", "Invalid input")
}

ResetAutoSaveInterval(ctrl, *) {
    gui := ctrl.Gui
    gui.edAutoSave.Value := 60
}

SaveAllSettings(ctrl, *) {
    SaveLTDetect(ctrl)
    SaveClickCoords(ctrl)
    SaveColorOffset(ctrl)
    SaveAutoSaveInterval(ctrl)
}

ShowLTSettingsHelp(*) {
    popup := Gui("+AlwaysOnTop +ToolWindow", "How To — LT Detection Settings")
    popup.BackColor := "1E1F22"
    popup.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    popup.MarginX := S(14)
    popup.MarginY := S(14)

    txt := "
    (
This tool detects when Clip Studio Paint's Light Table toggle is active by reading a single pixel on screen.

Left column — Detection Pixel
  Point X/Y at a pixel that changes color when
  LT toggles. Set "Expected" to the ON-state color,
  then press "Test" to verify. "Found" shows the
  current pixel read.

Left column — Color Info offset
  When Color Info follows the cursor, these X/Y
  values add an offset from the cursor position.

Right column — Click Coordinates
  Screen positions where the script clicks to
  toggle LT or switch reference images.
  Recalibrate if CSP window moves.

  LT Reset  — reset LT view
  Image 1/2 — switch reference image

Right column — Auto Save
  Auto-saves the CSP file at a set interval.
  Range: 10–3600 seconds. Default: 60s.
    )"
    popup.AddText("xm w" S(380) " cFFFFFF", txt)
    popup.AddButton("xm y+10 w" S(80) " h" S(26) " Default", "OK").OnEvent("Click", (*) => popup.Destroy())
    popup.Show("AutoSize")
}

; ============================================================
; HOTKEY SETTINGS GUI
; ============================================================

ShowHotkeySettings() {
    global HotkeyDefs, _hkFilteredIndices
    static sGui := 0
    if IsObject(sGui) {
        try if sGui.Hwnd {
            sGui.Show()
            return
        }
        sGui := 0
    }
    sGui := Gui("+AlwaysOnTop +Resize +ToolWindow", "Hotkey Settings")
    sGui.BackColor := "1E1F22"
    sGui.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    sGui.OnEvent("Close", (*) => (sGui.Destroy(), sGui := 0))

    sGui.MarginY := S(12)
    sGui.SetFont("s" S(8), "Segoe UI")
    sGui.AddText("xm", "Search:")
    sGui.edFilter := sGui.AddEdit("x+8 yp w" S(200) " c000000 BackgroundFFFFFF", "")
    sGui.edFilter.OnEvent("Change", HK_ApplyFilter)
    sGui.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    sGui.AddButton("x+16 yp w" S(75) " h" S(22), "Export").OnEvent("Click", ExportHotkeys)
    sGui.AddButton("x+4 yp w" S(75) " h" S(22), "Import").OnEvent("Click", ImportHotkeys)
    sGui.AddButton("x+16 yp w" S(80) " h" S(22) " cFFFFFF", "How to Use").OnEvent("Click", HK_HowToUse)

    lv := sGui.AddListView("xm yp+30 w" S(680) " h" S(380) " Grid +Report", ["Action", "Hotkey", "Status"])
    lv.SetFont("s" S(9) " c000000", "Segoe UI")
    lv.OnEvent("DoubleClick", HK_EditItem)
    lv.ModifyCol(1, S(310))
    lv.ModifyCol(2, S(150))
    lv.ModifyCol(3, S(160))

    _hkFilteredIndices := []
    for i, d in HotkeyDefs {
        key := HK_Get(d.id, d.def)
        status := HK_Status(key, d.id)
        lv.Add(, d.desc, key, status)
        _hkFilteredIndices.Push(i)
    }

    sGui.AddButton("xm y+9 w" S(90) " h" S(26), "Edit...").OnEvent("Click", HK_EditItem)
    sGui.AddButton("x+8 yp w" S(90) " h" S(26), "ON/OFF").OnEvent("Click", HK_ToggleItem)
    sGui.AddButton("x+8 yp w" S(110) " h" S(26), "Reset Selected").OnEvent("Click", HK_ResetItem)
    sGui.AddButton("x+8 yp w" S(100) " h" S(26), "Reset All").OnEvent("Click", HK_ResetAll)
    sGui.AddButton("x+8 yp w" S(90) " h" S(26), "Details").OnEvent("Click", HK_ShowDetails)
    sGui.AddButton("x+8 yp w" S(75) " h" S(26) " Background4CAF50 cFFFFFF", "Save").OnEvent("Click", HK_SaveAll)
    sGui.AddButton("x+8 yp w" S(75) " h" S(26), "Close").OnEvent("Click", (*) => sGui.Destroy())
    sGui.lv := lv
    sGui.Show("w" S(700) " h" S(470))
}

HK_ApplyFilter(ctrl, *) {
    global HotkeyDefs, _hkFilteredIndices
    lv := ctrl.Gui.lv
    filter := Trim(ctrl.Value)
    lv.Delete()
    _hkFilteredIndices := []
    for i, d in HotkeyDefs {
        if filter != "" && !InStr(d.desc, filter) && !InStr(HK_Get(d.id, d.def), filter)
            continue
        key := HK_Get(d.id, d.def)
        status := HK_Status(key, d.id)
        lv.Add(, d.desc, key, status)
        _hkFilteredIndices.Push(i)
    }
}

HK_ToggleItem(ctrl, *) {
    global HotkeyDefs, _hkFilteredIndices, HK_Custom
    parentGui := ctrl.Gui
    lv := parentGui.lv
    rows := []
    r := 0
    while r := lv.GetNext(r)
        rows.Push(r)
    if rows.Length = 0 {
        HK_SelectPrompt()
        return
    }
    for row in rows {
        idx := _hkFilteredIndices[row]
        d := HotkeyDefs[idx]
        cur := HK_Get(d.id, d.def)
        if cur = "-"
            HK_Custom.Delete(d.id)
        else
            HK_Custom[d.id] := "-"
        key := HK_Get(d.id, d.def)
        lv.Modify(row, "Col2", key)
        lv.Modify(row, "Col3", HK_Status(key, d.id))
    }
    HK_UpdateDuplicates(lv)
}

HK_ShowDetails(ctrl, *) {
    global HotkeyDefs, _hkFilteredIndices
    parentGui := ctrl.Gui
    lv := parentGui.lv
    row := lv.GetNext()
    if !row {
        HK_SelectPrompt()
        return
    }
    idx := _hkFilteredIndices[row]
    d := HotkeyDefs[idx]
    cur := HK_Get(d.id, d.def)
    fnName := HasProp(d.fn, "Name") && d.fn.Name != "" ? d.fn.Name : "(inline)"
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Hotkey Details: " d.id)
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.AddText("", "Action:  " d.desc)
    dlg.AddText("xm y+4 cAAAAAA", "Group:   " d.group)
    dlg.AddText("xm y+4 cAAAAAA", "Fn:      " fnName)
    dlg.AddText("xm y+4 cAAAAAA", "Sends:   " (d.HasOwnProp("sends") ? d.sends : d.desc))
    dlg.AddText("xm y+4", "Default: " d.def)
    dlg.AddText("xm y+4", "Current: " (cur = "-" ? "(disabled)" : cur) (cur != d.def && cur != "-" ? " (custom)" : cur = d.def ? " (default)" : ""))
    dlg.AddText("xm y+4 c888888", "Key #:   " idx " / " HotkeyDefs.Length)
    dlg.AddButton("xm y+10 w" S(80) " h" S(26), "OK").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize")
}

HK_Status(key, id) {
    if key = "-"
        return "Disabled"
    s := HK_CheckDuplicate(id, key)
    return s = "" ? "Enabled" : s
}

HK_CheckDuplicate(id, key) {
    if key = "" || key = "-"
        return ""
    for d in HotkeyDefs {
        if d.id = id
            continue
        if HK_Get(d.id, d.def) = key
            return "⚠ " d.desc
    }
    return ""
}

HK_UpdateDuplicates(lv) {
    global HotkeyDefs, _hkFilteredIndices
    for lvRow, idx in _hkFilteredIndices {
        d := HotkeyDefs[idx]
        key := HK_Get(d.id, d.def)
        lv.Modify(lvRow, "Col3", HK_Status(key, d.id))
    }
}

HK_SelectPrompt() {
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Hotkey Settings")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.AddText("cAAAAAA", "Select a hotkey first.")
    dlg.AddButton("xm y+10 w" S(80) " h" S(26), "OK").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize")
}

SaveErrorPrompt() {
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Save Error")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.AddText("cE53935", "Invalid number in one of the fields.")
    dlg.AddButton("xm y+10 w" S(80) " h" S(26), "OK").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize")
}

HK_EditItem(ctrl, *) {
    global HotkeyDefs, _hkFilteredIndices
    parentGui := ctrl.Gui
    lv := parentGui.lv
    row := lv.GetNext()
    if !row {
        HK_SelectPrompt()
        return
    }
    d := HotkeyDefs[_hkFilteredIndices[row]]
    result := HK_ChordEditor(d)
    if result != "" {
        newKey := result
        if newKey = "" || newKey = d.def
            HK_Custom.Delete(d.id)
        else
            HK_Custom[d.id] := newKey
        lv.Modify(row, "Col2", HK_Get(d.id, d.def))
        dup := HK_Status(HK_Get(d.id, d.def), d.id)
        lv.Modify(row, "Col3", dup)
        HK_UpdateDuplicates(lv)
    }
}

HK_ChordEditor(d) {
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Edit Hotkey")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s9 cFFFFFF", "Segoe UI")
    dlg.MarginX := 14
    dlg.MarginY := 14

    dlg.AddText("xm", "Action: " d.desc)
    dlg.AddText("xm y+4 cAAAAAA", "Default: " d.def)
    dlg.AddText("xm y+10", "Hotkey:")
    ed := dlg.AddEdit("xm y+6 w276 c000000 BackgroundFFFFFF", HK_Get(d.id, d.def))
    ed.OnEvent("Change", (*) => (display.Text := ed.Value, applyBtn.Enabled := true))

    display := dlg.AddText("xm y+6 w188 h26 +0x200 Center cFFFFFF Background2D2D32", HK_Get(d.id, d.def))
    capBtn := dlg.AddButton("x+8 yp w80 h26", "Record")
    capBtn.OnEvent("Click", (*) => HK_CaptureKey(dlg, ed, display, capBtn))

    saved := false
    applyBtn := dlg.AddButton("xm y+10 w80 h26 cFFFFFF Background4CAF50", "Apply")
    applyBtn.OnEvent("Click", (*) => (
        saved := true,
        result := ed.Value,
        dlg.Destroy()
    ))
    dlg.AddButton("x+8 yp w80 h26", "Cancel").OnEvent("Click", (*) => dlg.Destroy())
    dlg.AddButton("x+28 yp w80 h26 cAAAAAA", "Reset").OnEvent("Click", (*) => (
        ed.Value := d.def,
        display.Text := d.def
    ))

    result := ""
    dlg.OnEvent("Close", (*) => (
        saved ? "" : (result := "")
    ))
    dlg.Show("AutoSize")
    WinWaitClose(dlg)
    return result
}

global _HK_CaptureDlg := 0

HK_CaptureKey(parentGui, ed, display, capBtn) {
    global _HK_CaptureDlg
    _HK_CaptureDlg := 0

    capBtn.Enabled := false
    capBtn.Text := "Recording..."
    ed.Opt("+ReadOnly")

    cDlg := Gui("+AlwaysOnTop +ToolWindow", "Capture Hotkey")
    cDlg.BackColor := "1E1F22"
    cDlg.SetFont("s9 cFFFFFF", "Segoe UI")
    cDlg.MarginX := 20
    cDlg.MarginY := 20

    cDlg.AddText("xm Center w227 cAAAAAA", "Press a key combination:")
    cDlg.SetFont("s14 Bold", "Segoe UI")
    cDlg.capDisplay := cDlg.AddText("xm y+10 w227 h36 +0x200 Center cFFFFFF Background2D2D32", "...")
    cDlg.SetFont("s9 norm", "Segoe UI")

    ; Modifier chain display (shows held modifiers in real-time)
    cDlg.chainDisplay := cDlg.AddText("xm y+4 w227 h20 +0x200 Center c888888 Background1E1F22", "")
    cDlg.SetFont("s9 norm", "Segoe UI")

    cDlg.chord := ""
    cDlg.isRecording := false
    cDlg.currentMods := ""
    _HK_CaptureDlg := cDlg
    closed := false

    ; Timer to poll modifier state for chain recording
    cDlg_ChainTimer(*) {
        if !IsObject(cDlg) || !cDlg.isRecording
            return
        modStr := ""
        if GetKeyState("Ctrl", "P")  modStr .= "^"
        if GetKeyState("Alt", "P")   modStr .= "!"
        if GetKeyState("Shift", "P") modStr .= "+"
        if GetKeyState("LWin", "P") || GetKeyState("RWin", "P") modStr .= "#"
        cDlg.currentMods := modStr
        if modStr != "" {
            cDlg.chainDisplay.Text := "Held: " . modStr
            cDlg.chainDisplay.Redraw()
        } else {
            cDlg.chainDisplay.Text := ""
        }
    }
    cDlg.chainTimerFn := cDlg_ChainTimer

    cDlg_Cleanup(*) {
        global _HK_CaptureDlg
        if closed
            return
        closed := true
        _HK_CaptureDlg := 0
        if cDlg.ih {
            cDlg.ih.Stop()
            cDlg.ih := 0
        }
        try SetTimer(cDlg.chainTimerFn, 0)
        capBtn.Enabled := true
        capBtn.Text := "Record"
        ed.Opt("-ReadOnly")
        try ed.Focus()
        try cDlg.Destroy()
    }

    cDlg_Apply(*) {
        if cDlg.chord != "" {
            ed.Value := cDlg.chord
            display.Text := cDlg.chord
        }
        cDlg_Cleanup()
    }

    cDlg_StartIH(*) {
        ih := InputHook("B", "{Esc}")
        ih.KeyOpt("{All}", "E")
        ih.OnEnd := HK_IH_End
        cDlg.ih := ih
        ih.Start()
    }

    cDlg_ToggleRecord(*) {
        if cDlg.isRecording {
            ; Stop recording and capture current state
            cDlg.isRecording := false
            if cDlg.ih {
                cDlg.ih.Stop()
                cDlg.ih := 0
            }
            try SetTimer(cDlg.chainTimerFn, 0)
            cDlg.recBtn.Text := "Record"
        } else {
            cDlg.chord := ""
            cDlg.capDisplay.Text := "..."
            cDlg.chainDisplay.Text := ""
            cDlg.currentMods := ""
            cDlg.applyBtn.Enabled := false
            cDlg.isRecording := true
            cDlg.recBtn.Text := "Stop"
            cDlg_StartIH()
            SetTimer(cDlg.chainTimerFn, 80)
        }
    }

    cDlg.recBtn := cDlg.AddButton("xm y+4 w70 h28", "Record")
    cDlg.recBtn.Enabled := true
    cDlg.recBtn.OnEvent("Click", cDlg_ToggleRecord)

    cDlg.applyBtn := cDlg.AddButton("x+8 yp w70 h28 cFFFFFF Background4CAF50", "Apply")
    cDlg.applyBtn.Enabled := false
    cDlg.applyBtn.OnEvent("Click", cDlg_Apply)

    cDlg.AddButton("x+8 yp w70 h28", "Cancel").OnEvent("Click", cDlg_Cleanup)
    cDlg.OnEvent("Close", cDlg_Cleanup)

    cDlg.Show("w265")
    cDlg.recBtn.Text := "Record"
}

HK_IH_End(ih) {
    global _HK_CaptureDlg
    if !IsObject(_HK_CaptureDlg) || !_HK_CaptureDlg.isRecording
        return
    if ih.EndReason = "EndKey" && ih.EndKey = "Esc" {
        _HK_CaptureDlg.isRecording := false
        _HK_CaptureDlg.recBtn.Text := "Record"
        _HK_CaptureDlg.recBtn.Enabled := true
        if _HK_CaptureDlg.HasProp("chainTimerFn")
            SetTimer(_HK_CaptureDlg.chainTimerFn, 0)
        return
    }
    if ih.EndReason != "EndKey"
        return
    key := ih.EndKey
    if key = ""
        return
    static modKeys := Map("Control","","Ctrl","","Alt","","Shift","","LWin","","RWin","")
    if !modKeys.Has(key) {
        prefix := ""
        mods := ih.EndMods
        if InStr(mods, "^")  prefix .= "^"
        if InStr(mods, "!")  prefix .= "!"
        if InStr(mods, "+")  prefix .= "+"
        if InStr(mods, "#")  prefix .= "#"
        _HK_CaptureDlg.chord := prefix key
        _HK_CaptureDlg.capDisplay.Text := _HK_CaptureDlg.chord
        _HK_CaptureDlg.applyBtn.Enabled := true
    }
    _HK_CaptureDlg.isRecording := false
    _HK_CaptureDlg.recBtn.Text := "Record"
    _HK_CaptureDlg.recBtn.Enabled := true
    if _HK_CaptureDlg.HasProp("chainTimerFn")
        SetTimer(_HK_CaptureDlg.chainTimerFn, 0)
    try _HK_CaptureDlg.ih.Stop()
    _HK_CaptureDlg.ih := 0
}



HK_ResetItem(ctrl, *) {
    global HotkeyDefs, _hkFilteredIndices, HK_Custom
    parentGui := ctrl.Gui
    lv := parentGui.lv
    rows := []
    r := 0
    while r := lv.GetNext(r)
        rows.Push(r)
    if rows.Length = 0 {
        HK_SelectPrompt()
        return
    }
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Reset Selected Hotkeys")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.AddText("cFFD54F", "Reset selected hotkeys to defaults?")
    result := false
    dlg.AddButton("xm y+10 w" S(80) " h" S(26) " BackgroundE53935 cFFFFFF", "Yes").OnEvent("Click", (*) => (result := true, dlg.Destroy()))
    dlg.AddButton("x+8 yp w" S(80) " h" S(26), "No").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize")
    WinWaitClose(dlg)
    if !result
        return
    for row in rows {
        idx := _hkFilteredIndices[row]
        d := HotkeyDefs[idx]
        HK_Custom.Delete(d.id)
        lv.Modify(row, "Col2", d.def)
        lv.Modify(row, "Col3", HK_Status(d.def, d.id))
    }
    HK_UpdateDuplicates(lv)
}

HK_ResetAll(ctrl, *) {
    global HotkeyDefs, _hkFilteredIndices, HK_Custom
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Reset All Hotkeys")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.AddText("cFFD54F", "Reset all hotkeys to defaults?")
    dlg.AddText("xm y+" S(4) " cAAAAAA", "This will remove all custom hotkey settings.")
    result := false
    dlg.AddButton("xm y+10 w" S(80) " h" S(26) " BackgroundE53935 cFFFFFF", "Yes").OnEvent("Click", (*) => (result := true, dlg.Destroy()))
    dlg.AddButton("x+8 yp w" S(80) " h" S(26), "No").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize")
    WinWaitClose(dlg)
    if !result
        return
    parentGui := ctrl.Gui
    lv := parentGui.lv
    HK_Custom := Map()
    for lvRow, idx in _hkFilteredIndices {
        d := HotkeyDefs[idx]
        lv.Modify(lvRow, "Col2", d.def)
        lv.Modify(lvRow, "Col3", HK_Status(d.def, d.id))
    }
}

HK_SaveAll(ctrl, *) {
    HK_Save()
    HK_ReapplyAll()
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Hotkey Settings")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.AddText("c4CAF50", "Hotkey settings saved and applied.")
    dlg.AddButton("xm y+10 w" S(80) " h" S(26) " Default", "OK").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize")
}

DoAutoSave() {
    global AutoSaveOn
    if AutoSaveOn && WinActive("ahk_exe CLIPStudioPaint.exe") {
        DebugLog("Auto save triggered")
        Send("^s")
    }
}

ToggleToolGUIs() {
    global ColorGUI, ColorGUIVisible, ColorGUI_X, ColorGUI_Y
    global LinkGUI, LinkGUIVisible, LinkGUI_X, LinkGUI_Y
    global IB_GUI, IBVisible, IB_X, IB_Y
    global GUIEnabled, GUIVisible

    if !GUIEnabled {
        SaveGUIPositions()
        if IsObject(ColorGUI) ColorGUI.GetPos(&ColorGUI_X, &ColorGUI_Y)
        if IsObject(IB_GUI)   IB_GUI.GetPos(&IB_X, &IB_Y)
        if IsObject(LinkGUI)  LinkGUI.GetPos(&LinkGUI_X, &LinkGUI_Y)
        if IsObject(ColorGUI) ColorGUI.Hide()
        if IsObject(IB_GUI)   IB_GUI.Hide()
        if IsObject(LinkGUI)  LinkGUI.Hide()
        DebugLog("All GUIs hidden")
        ColorGUIVisible := false
        LinkGUIVisible := false
        IBVisible := false
        GUIVisible := true
        GUIEnabled := true
    } else {
        if IsObject(ColorGUI) ColorGUI.Show("x" ColorGUI_X " y" ColorGUI_Y " NoActivate")
        if IsObject(IB_GUI)   IB_GUI.Show("x" IB_X " y" IB_Y " NoActivate")
        if IsObject(LinkGUI)  LinkGUI.Show("x" LinkGUI_X " y" LinkGUI_Y " NoActivate")
        DebugLog("All GUIs shown")
        ColorGUIVisible := true
        LinkGUIVisible := true
        IBVisible := true
        GUIVisible := false
        GUIEnabled := false
    }
}

CreateMainGui() {
    global MainGUI, IB_GUI, ColorGUI, LinkGUI
    global IBVisible, ColorGUIVisible, LinkGUIVisible
    global GUIEnabled
    global MainGUIVisible
    MainGUI := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "Main Control")
    MainGUI.BackColor := "1E1F22"
    MainGUI.SetFont("s" S(8) " cFFFFFF", "Segoe UI")
    MainGUI.MarginX := S(4)
    MainGUI.MarginY := S(6)
    MainGUI.OnEvent("ContextMenu", MainGUI_ContextMenu)

    dragLabel := MainGUI.AddText("xm w" S(135) " Center c777777 +0x200", "———— Main ————")
    dragLabel.OnEvent("Click", (*) => PostMessage(0x00A1, 2, 0, , "ahk_id " MainGUI.Hwnd))
    btnIB := MainGUI.AddText("xm w" S(30) " h" S(24) " Center +0x200 Background2A2A2A cFFFFFF", "IB")
    btnIB.SetFont("s" S(7) " Bold", "Segoe UI")
    btnIB.OnEvent("Click", (*) => ToggleMainGUI(1))

    btnLink := MainGUI.AddText("x+" S(4) " yp w" S(30) " h" S(24) " Center +0x200 Background2A2A2A cFFFFFF", "Link")
    btnLink.SetFont("s" S(7) " Bold", "Segoe UI")
    btnLink.OnEvent("Click", (*) => ToggleMainGUI(2))

    btnColor := MainGUI.AddText("x+" S(4) " yp w" S(32) " h" S(24) " Center +0x200 Background2A2A2A cFFFFFF", "Color")
    btnColor.SetFont("s" S(7) " Bold", "Segoe UI")
    btnColor.OnEvent("Click", (*) => ToggleMainGUI(3))

    btnClose := MainGUI.AddText("x+" S(4) " yp w" S(30) " h" S(24) " Center +0x200 BackgroundE53935 cFFFFFF", "✕")
    btnClose.SetFont("s" S(7) " Bold", "Segoe UI")
    AddHoverPopup(btnClose, "Close Main GUI")
    btnClose.OnEvent("Click", (*) => (MainGUI.Hide(), MainGUIVisible := false))

    MainGUI.AddText("xm y+" S(6) " w" S(136) " h" S(1) " +0x200 Background555555")

    ; second row
    btnGuide := MainGUI.AddText("xm y+" S(6) " w" S(24) " h" S(24) " Center +0x200 Background9C27B0 cFFFFFF", "?")
    btnGuide.SetFont("s" S(9) " Bold", "Segoe UI")
    btnGuide.OnEvent("Click", (*) => ShowCSPGuide())

    btnResetPos := MainGUI.AddText("x+" S(4) " yp w" S(24) " h" S(24) " Center +0x200 BackgroundE53935 cFFFFFF", "⟲")
    btnResetPos.SetFont("s" S(8) " Bold", "Segoe UI")
    AddHoverPopup(btnResetPos, "Reset GUI Positions")
    btnResetPos.OnEvent("Click", (*) => ResetGUIPositions())

    btnLinkMgr := MainGUI.AddText("x+" S(4) " yp w" S(24) " h" S(24) " Center +0x200 Background607D8B cFFFFFF", "🔗")
    btnLinkMgr.SetFont("s" S(7) " Bold", "Segoe UI")
    AddHoverPopup(btnLinkMgr, "Link Button Manager")
    btnLinkMgr.OnEvent("Click", (*) => ShowLinkManager())

    btnSettings := MainGUI.AddText("x+" S(4) " yp w" S(24) " h" S(24) " Center +0x200 Background455A64 cFFFFFF", "⚙")
    btnSettings.SetFont("s" S(7) " Bold", "Segoe UI")
    AddHoverPopup(btnSettings, "LT Detection Settings")
    btnSettings.OnEvent("Click", (*) => ShowLTSettings())

    btnHotkey := MainGUI.AddText("x+" S(4) " yp w" S(24) " h" S(24) " Center +0x200 Background455A64 cFFFFFF", "⌨")
    btnHotkey.SetFont("s" S(8) " Bold", "Segoe UI")
    AddHoverPopup(btnHotkey, "Hotkey Settings")
    btnHotkey.OnEvent("Click", (*) => ShowHotkeySettings())

    ; third row
    btnOpacity := MainGUI.AddText("xm y+" S(6) " w" S(42) " h" S(22) " Center +0x200 Background546E7A cFFFFFF", "Opacity")
    btnOpacity.SetFont("s" S(7) " Bold", "Segoe UI")
    AddHoverPopup(btnOpacity, "GUI Opacity Settings")
    btnOpacity.OnEvent("Click", (*) => ShowOpacitySlider("Main"))

    btnDebug := MainGUI.AddText("x+" S(5) " yp w" S(42) " h" S(22) " Center +0x200 Background546E7A cFFFFFF", "Debug")
    btnDebug.SetFont("s" S(7) " Bold", "Segoe UI")
    AddHoverPopup(btnDebug, "Debug Log")
    btnDebug.OnEvent("Click", (*) => ShowDebugGUI())

    btnHotkeys := MainGUI.AddText("x+" S(5) " yp w" S(42) " h" S(22) " Center +0x200 Background4CAF50 cFFFFFF", "HK")
    btnHotkeys.SetFont("s" S(7) " Bold", "Segoe UI")
    AddHoverPopup(btnHotkeys, "Pause / Resume all custom hotkeys")
    btnHotkeys.OnEvent("Click", (*) => ToggleHotkeysPause())

    MainGUI.dragTop := MainGUI.AddText("xm y+" S(6) " w" S(136) " h" S(6) " +0x200 Background555555", "")

    MainGUI.btnIB := btnIB
    MainGUI.btnLink := btnLink
    MainGUI.btnColor := btnColor
    MainGUI.btnHotkeys := btnHotkeys
    UpdateHotkeysPauseButton()
}

MainGUI_ContextMenu(guiObj, ctrl, item, isRightClick, x, y) {
    global MainGUIVisible
    m := Menu()
    m.Add("Hide Main GUI", (*) => (MainGUI.Hide(), MainGUIVisible := false))
    m.Add()
    m.Add("Opacity...", (*) => ShowOpacitySlider("Main"))
    m.Add("Pause / Resume Custom Hotkeys", ToggleHotkeysPause)
    m.Add("Debug Log", ShowDebugGUI)
    m.Add()
    m.Add("Backup Config...", BackupConfig)
    m.Add("Restore Config...", RestoreConfig)
    m.Show()
}

ToggleMainGUI(n) {
    global MainGUI, IB_GUI, ColorGUI, LinkGUI
    global IBVisible, ColorGUIVisible, LinkGUIVisible
    global IBManualHide, LinkManualHide, ColorManualHide
    global IB_Opacity, Color_Opacity, Link_Opacity
    if n = 1 {
        if IsObject(IB_GUI) {
            if IBVisible && !IBManualHide {
                IB_GUI.Hide()
                IBManualHide := true
            } else {
                IB_GUI.Show("NoActivate")
                IBManualHide := false
            }
            IBVisible := !(IBVisible && !IBManualHide)
            DebugLog("IB toggled " (IBManualHide ? "OFF" : "ON") " (opacity " IB_Opacity ")")
        }
        if IsObject(MainGUI) && IsObject(MainGUI.btnIB)
            MainGUI.btnIB.Opt("Background" (IBManualHide ? "E53935" : "4CAF50") " cFFFFFF")
    } else if n = 2 {
        if IsObject(LinkGUI) {
            if LinkGUIVisible && !LinkManualHide {
                LinkGUI.Hide()
                LinkManualHide := true
            } else {
                LinkGUI.Show("NoActivate")
                LinkManualHide := false
            }
            LinkGUIVisible := !(LinkGUIVisible && !LinkManualHide)
            DebugLog("Link toggled " (LinkManualHide ? "OFF" : "ON") " (opacity " Link_Opacity ")")
        }
        if IsObject(MainGUI) && IsObject(MainGUI.btnLink)
            MainGUI.btnLink.Opt("Background" (LinkManualHide ? "E53935" : "4CAF50") " cFFFFFF")
    } else if n = 3 {
        if IsObject(ColorGUI) {
            if ColorGUIVisible && !ColorManualHide {
                ColorGUI.Hide()
                ColorManualHide := true
            } else {
                ColorGUI.Show("NoActivate")
                ColorManualHide := false
            }
            ColorGUIVisible := !(ColorGUIVisible && !ColorManualHide)
            DebugLog("Color toggled " (ColorManualHide ? "OFF" : "ON") " (opacity " Color_Opacity ")")
        }
        if IsObject(MainGUI) && IsObject(MainGUI.btnColor)
            MainGUI.btnColor.Opt("Background" (ColorManualHide ? "E53935" : "4CAF50") " cFFFFFF")
    }
}

global CSP_DialogTitles := [
    "Preferences", "Change settings",
    "Canvas Properties", "Manage Workspace",
    "Register Workspace", "Manage fonts",
    "Command Bar Settings", "Modifier Key Settings",
    "Shortcut Settings",
    "New", "Open", "Save as",
    "Change Canvas Size", "Change Image Resolution",
    "Change page settings",
    "Change Layer Name", "Onion skin settings",
    "Exposure sheet", "Export animation cels",
    "Export webtoon", "Export settings for EPUB data",
    "Batch export", "Image sequence export settings",
    "Export (Single Layer)",
    "Print", "Print Settings",
    "Install path settings for OpenToonz",
    "Layer Property", "Tool Property",
    "Text Settings", "Story Editor",
    "Search Layer", "Material Properties",
    "Material properties",
    "Color settings", "Advanced color settings",
    "Advanced Tool Settings", "Add tool",
    "Tool", "Tool Group", "Tool Settings", "Tool Sliders", "Brush Size",
    "Sub Tool Detail", "Tool property", "Sub Tool",
    "Add from default", "Rename tool group", "Duplicate tool",
    "Create custom tool", "Import tool", "Export tool",
    "Reset to original defaults", "Migrate tool preference",
    "Color Wheel", "Color Slider", "Color Set",
    "Intermediate Color", "Approximate Color",
    "Color History", "Color Mixing",
    "Layer", "Layer Comps", "LayerComps",
    "Vector layer conversion", "New vector layer", "New Raster Layer",
    "New foil layer", "Select layer",
    "Timeline", "Manage timeline", "New timeline",
    "Animation cels", "Export layer comp",
    "All sides view",
    "Navigator", "Sub View",
    "History", "Auto Action",
    "Information", "Item bank", "Align/Distribute",
    "Material",
    "Gaussian blur", "Convert to Panorama", "Remove dust",
    "Adjust line width", "Spin blur", "Radial blur", "Motion blur",
    "Lens Blur", "Curved surface", "ZigZag", "Wave", "Twirl",
    "Ripple", "Polar coordinates", "Pinch", "Geometric distortion",
    "Fish-eye lens", "Brightness/Contrast",
    "Create Perspective Ruler", "Convert layer to file object",
    "Convert Layer", "Select Color Gamut", "Color profile preview",
    "Unsharp mask", "Perlin noise", "Retro film", "Pencil drawing",
    "Normal map", "Noise", "Mosaic", "Crystallize",
    "Chromatic aberration", "Artistic",
    "Hue/Saturation/Luminosity", "Edit gradient",
    "Gradient map", "Binarization", "Color balance",
    "Tone Curve", "Level Correction", "Posterization",
    "Simple tone settings",
    "New frame folder", "Choose body shape for 3D drawing figure",
    "Expand selected area", "Shrink selected area", "Blur border",
    "Workspace import settings", "Change frame rate",
    "Insert frame", "Delete frame",
    "Toei Animation Digital Exposure Sheet settings",
    "Go to specified frame", "Create track label",
    "Create timeline label", "Assign multiple cels",
    "Specific Page", "Add Page", "Import Page", "Replace page",
    "Combine Pages", "Split Pages",
    "Create story folder", "Print file name settings",
    "Prepare group work data", "Obtain group work data",
    "Group working", "Assign member",
    "Reflect change on group work data",
    "Discard change to work folder", "Unassign member",
    "Open conflicting file", "Resolve conflict",
    "Log", "Member's comment", "Group work settings",
    "Migrate", "Migrate tool preference",
    "Smart Smoothing", "Advanced Fill", "Shading Assist",
    "Outline Selection", "Change project settings",
    "Add to presets", "Export timelapse",
    "psd export settings", "Batch import",
    "WebP export settings", "Edit preset",
    "Watermark settings", "Export preview",
    "Print preview", "Quick Access",
    "Command Bar",
    "Add sub tool", "Adjust pen pressure", "Check adjusted settings",
    "Grid/Ruler bar settings", "Selection Launcher Settings",
    "Icon settings", "Color Match", "Colorize",
    "Font list settings", "Create mixing font",
    "Divide frame border equally", "On-screen area settings",
    "Add Page (Advanced)", "Find and Replace",
    "Export PDF format", "3D Preview for Binding",
    "Export fanzine printing data", "Export EPUB data",
    "EPUB advanced settings", "Go to timeline label",
    "2D camera folder",
    "Animated GIF export settings", "Animated sticker (APNG) export settings",
    "Animated WebP Export Settings", "Movie export settings",
    "Export settings for PaintMan:", "OpenToonz scene file export settings",
    "Audio export settings", "Check cel motion by key input",
    "Material:", "Import file",
    "Quick Access Setting", "Settings for",
    "Create new set", "Batch process",
    "Webtoon Story editor"
]

IsTyping() {
    try {
        title := WinGetTitle("ahk_exe CLIPStudioPaint.exe")
        for dlgName in CSP_DialogTitles
            if InStr(title, dlgName)
                return true
    }

    try {
        ctrlHwnd := ControlGetFocus("ahk_exe CLIPStudioPaint.exe")
        ctrlClass := WinGetClass("ahk_id " ctrlHwnd)
        if ctrlClass ~= "i)^(Edit|RichEdit)"
            return true
    }

    for dlgTitle in ["Edit Hotkey", "Hotkey Settings", "Capture Hotkey", "Edit Link Button", "Add Link Button", "LT Detection Settings"]
        if WinActive(dlgTitle)
            return true

    return false
}

; ============================================================
; MAIN HOTKEYS (only fire when CSP window is active)
ResetGUIPositions() {
    global IB_GUI, ColorGUI, LinkGUI, MainGUI
    global IB_X, IB_Y, ColorGUI_X, ColorGUI_Y, LinkGUI_X, LinkGUI_Y
    MonitorGetWorkArea(MonitorGetPrimary(), &mL, &mT, &mR, &mB)
    cX := (mL + mR) // 2
    cY := (mT + mB) // 2

    if IsObject(IB_GUI) {
        IB_GUI.GetPos(,, &w, &h)
        IB_X := cX - w // 2
        IB_Y := cY - h // 2 - 60
        IB_GUI.Show("x" IB_X " y" IB_Y " NoActivate")
    }
    if IsObject(ColorGUI) {
        ColorGUI.GetPos(,, &w, &h)
        ColorGUI_X := cX - w // 2 - 80
        ColorGUI_Y := cY + 60
        ColorGUI.Show("x" ColorGUI_X " y" ColorGUI_Y " NoActivate")
    }
    if IsObject(LinkGUI) {
        LinkGUI.GetPos(,, &w, &h)
        LinkGUI_X := cX + 80
        LinkGUI_Y := cY + 60
        LinkGUI.Show("x" LinkGUI_X " y" LinkGUI_Y " NoActivate")
    }
    if IsObject(MainGUI) {
        MainGUI.GetPos(,, &w, &h)
        MainGUI.Show("x" (cX - w // 2) " y" (cY - h // 2 + 60) " NoActivate")
    }
}

ToggleMainWindow() {
    global MainGUI, MainGUIVisible
    MainGUIVisible := !MainGUIVisible
    if MainGUIVisible
        MainGUI.Show("NoActivate")
    else
        MainGUI.Hide()
    DebugLog("Main GUI " (MainGUIVisible ? "shown" : "hidden"))
}

ToggleHotkeysPause(*) {
    global HotkeysPaused
    HotkeysPaused := !HotkeysPaused
    HK_ReapplyAll()
    UpdateHotkeysPauseButton()
    DebugLog("Custom hotkeys " (HotkeysPaused ? "paused" : "resumed"))
}

UpdateHotkeysPauseButton() {
    global MainGUI, HotkeysPaused
    if !IsObject(MainGUI) || !HasProp(MainGUI, "btnHotkeys")
        return
    MainGUI.btnHotkeys.Opt("Background" (HotkeysPaused ? "E53935" : "4CAF50") " cFFFFFF")
    MainGUI.btnHotkeys.Text := HotkeysPaused ? "OFF" : "HK"
}

; ============================================================
; GUI OPACITY SLIDER
; ============================================================

ShowOpacitySlider(target, *) {
    global IB_Opacity, Color_Opacity, Link_Opacity, Scale, Speed
    if target = "Main" {
        dlg := Gui("+AlwaysOnTop +ToolWindow", "GUI Opacity")
        dlg.BackColor := "1E1F22"
        dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
        dlg.MarginX := S(14)
        dlg.MarginY := S(14)
        v1 := OpacityValueToPercent(IB_Opacity)
        v2 := OpacityValueToPercent(Color_Opacity)
        v3 := OpacityValueToPercent(Link_Opacity)
        o1 := IB_Opacity, o2 := Color_Opacity, o3 := Link_Opacity
        scalePct := Max(50, Min(150, Round(Scale * 100)))
        origScale := Scale
        speedVal := Max(1, Min(100, Speed))
        origSpeed := speedVal
        saved := false
        resetState := (*) => (
            v1 := 100,
            v2 := 100,
            v3 := 100,
            scalePct := 100,
            speedVal := 15,
            s1.Value := v1,
            s2.Value := v2,
            s3.Value := v3,
            sScale.Value := scalePct,
            sSpeed.Value := speedVal,
            Speed := speedVal,
            SetOpacity("IB", 255, false),
            SetOpacity("Color", 255, false),
            SetOpacity("Link", 255, false),
            PreviewGuiScale(1.0)
        )
        dlg.AddText("xm", "IB GUI:")
        dlg.AddText("xm y+" S(4) " w" S(28) " cAAAAAA", "0%")
        s1 := dlg.AddSlider("x+" S(8) " yp w" S(200) " Range0-100 Tooltip", v1)
        dlg.AddText("x+" S(8) " yp w" S(38) " Right cAAAAAA", "100%")
        s1.OnEvent("Change", (*) => (
            v1 := s1.Value,
            SetOpacity("IB", OpacityPercentToValue(v1), false)
        ))
        dlg.AddText("xm y+" S(18), "Color GUI:")
        dlg.AddText("xm y+" S(4) " w" S(28) " cAAAAAA", "0%")
        s2 := dlg.AddSlider("x+" S(8) " yp w" S(200) " Range0-100 Tooltip", v2)
        dlg.AddText("x+" S(8) " yp w" S(38) " Right cAAAAAA", "100%")
        s2.OnEvent("Change", (*) => (
            v2 := s2.Value,
            SetOpacity("Color", OpacityPercentToValue(v2), false)
        ))
        dlg.AddText("xm y+" S(18), "Link GUI:")
        dlg.AddText("xm y+" S(4) " w" S(28) " cAAAAAA", "0%")
        s3 := dlg.AddSlider("x+" S(8) " yp w" S(200) " Range0-100 Tooltip", v3)
        dlg.AddText("x+" S(8) " yp w" S(38) " Right cAAAAAA", "100%")
        s3.OnEvent("Change", (*) => (
            v3 := s3.Value,
            SetOpacity("Link", OpacityPercentToValue(v3), false)
        ))
        dlg.AddText("xm y+" S(18), "UI Scale:")
        dlg.AddText("xm y+" S(4) " w" S(34) " cAAAAAA", "50%")
        sScale := dlg.AddSlider("x+" S(8) " yp w" S(200) " Range50-150 Tooltip", scalePct)
        dlg.AddText("x+" S(8) " yp w" S(42) " Right cAAAAAA", "150%")
        sScale.OnEvent("Change", (*) => (
            scalePct := sScale.Value,
            PreviewGuiScale(scalePct / 100.0)
        ))
        dlg.AddText("xm y+" S(18), "Scroll Power:")
        dlg.AddText("xm y+" S(4) " w" S(34) " cAAAAAA", "1")
        sSpeed := dlg.AddSlider("x+" S(8) " yp w" S(200) " Range1-100 Tooltip", speedVal)
        dlg.AddText("x+" S(8) " yp w" S(42) " Right cAAAAAA", "100")
        sSpeed.OnEvent("Change", (*) => (Speed := sSpeed.Value))
        dlg.AddButton("xm y+" S(22) " w" S(80) " h" S(26), "Save").OnEvent("Click", (*) => (
            saved := true,
            Speed := sSpeed.Value,
            SetOpacity("IB", OpacityPercentToValue(v1)),
            SetOpacity("Color", OpacityPercentToValue(v2)),
            SetOpacity("Link", OpacityPercentToValue(v3)),
            ApplyGuiScale(sScale.Value / 100.0),
            dlg.Destroy()
        ))
        dlg.AddButton("x+" S(6) " yp w" S(80) " h" S(26), "Reset").OnEvent("Click", (*) => resetState())
        dlg.AddButton("x+" S(6) " yp w" S(80) " h" S(26), "Close").OnEvent("Click", (*) => dlg.Destroy())
        dlg.OnEvent("Close", (*) => (
            saved ? "" : (
                Speed := origSpeed,
                PreviewGuiScale(origScale),
                SetOpacity("IB", o1, false),
                SetOpacity("Color", o2, false),
                SetOpacity("Link", o3, false)
            )
        ))
        dlg.Show("AutoSize")
        return
    }
    cur := target = "IB" ? IB_Opacity : target = "Color" ? Color_Opacity : Link_Opacity
    orig := cur
    pct := OpacityValueToPercent(cur)
    saved := false
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Opacity — " target)
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.AddText("xm", "Opacity:")
    dlg.AddText("xm y+" S(4) " w" S(28) " cAAAAAA", "0%")
    sl := dlg.AddSlider("x+" S(8) " yp w" S(200) " Range0-100 Tooltip", pct)
    dlg.AddText("x+" S(8) " yp w" S(38) " Right cAAAAAA", "100%")
    sl.OnEvent("Change", (*) => (
        pct := sl.Value,
        SetOpacity(target, OpacityPercentToValue(pct), false)
    ))
    dlg.AddText("xm y+" S(4), "Tip: Right-click any tool GUI for quick access")
    dlg.AddButton("xm y+" S(8) " w" S(80) " h" S(26), "Save").OnEvent("Click", (*) => (
        saved := true,
        SetOpacity(target, OpacityPercentToValue(pct)),
        dlg.Destroy()
    ))
    dlg.AddButton("x+" S(6) " yp w" S(80) " h" S(26), "Close").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => (
        saved ? "" : SetOpacity(target, orig, false)
    ))
    dlg.Show("AutoSize")
}

OpacityValueToPercent(value) {
    return Round((Integer(value) * 100) / 255)
}

OpacityPercentToValue(percent) {
    return Max(0, Min(255, Round((Integer(percent) * 255) / 100)))
}

SetOpacity(target, value, save := true) {
    global IB_Opacity, Color_Opacity, Link_Opacity, IB_GUI, ColorGUI, LinkGUI, SETTINGS_FILE
    if target = "IB" {
        IB_Opacity := value
        if IsObject(IB_GUI)
            WinSetTransparent(value, IB_GUI)
    } else if target = "Color" {
        Color_Opacity := value
        if IsObject(ColorGUI)
            WinSetTransparent(value, ColorGUI)
    } else if target = "Link" {
        Link_Opacity := value
        if IsObject(LinkGUI)
            WinSetTransparent(value, LinkGUI)
    }
    if save {
        IniWrite(value, SETTINGS_FILE, "Settings", target "_Opacity")
        DebugLog("Set " target " opacity to " value)
    }
}

PreviewGuiScale(newScale) {
    GuiScaleApply(newScale, false)
}

ApplyGuiScale(newScale) {
    GuiScaleApply(newScale, true)
}

GuiScaleApply(newScale, persist := true) {
    global Scale, MainGUI, IB_GUI, ColorGUI, LinkGUI
    global MainGUIVisible, IBVisible, ColorGUIVisible, LinkGUIVisible
    global IBManualHide, ColorManualHide, LinkManualHide

    newScale := Round(newScale * 100) / 100
    if newScale < 0.5
        newScale := 0.5
    else if newScale > 1.5
        newScale := 1.5
    if Abs(newScale - Scale) < 0.001 {
        if persist
            SaveGUIPositions()
        return
    }

    mainX := mainY := 0
    haveMainPos := false
    if IsObject(MainGUI) {
        MainGUI.GetPos(&mainX, &mainY)
        haveMainPos := true
    }

    Scale := newScale

    if IsObject(MainGUI)
        MainGUI.Destroy()
    if IsObject(IB_GUI)
        IB_GUI.Destroy()
    if IsObject(ColorGUI)
        ColorGUI.Destroy()
    if IsObject(LinkGUI)
        LinkGUI.Destroy()

    CreateMainGui()
    CreateIBGui()
    CreateColorGui()
    CreateLinkGUI()

    if MainGUIVisible {
        if haveMainPos
            MainGUI.Show("x" mainX " y" mainY " NoActivate")
        else
            MainGUI.Show("NoActivate")
    } else {
        MainGUI.Hide()
    }

    if IBVisible && !IBManualHide
        IB_PositionGui()
    else if IsObject(IB_GUI)
        IB_GUI.Hide()

    if ColorGUIVisible && !ColorManualHide
        PositionColorGui()
    else if IsObject(ColorGUI)
        ColorGUI.Hide()

    if LinkGUIVisible && !LinkManualHide
        PositionLinkGUI()
    else if IsObject(LinkGUI)
        LinkGUI.Hide()

    if persist {
        SaveGUIPositions()
        DebugLog("GUI scale set to " newScale)
    } else {
        DebugLog("Preview GUI scale set to " newScale)
    }
}

; ============================================================
; AUTO SAVE INTERVAL CONFIG
; ============================================================

SetAutoSaveInterval(*) {
    global AutoSaveInterval
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Auto Save Interval")
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.AddText("xm", "Interval in seconds (default 60):")
    ed := dlg.AddEdit("xm y+" S(6) " w" S(100) " c000000 BackgroundFFFFFF", AutoSaveInterval)
    dlg.AddButton("xm y+" S(8) " w" S(80) " h" S(26), "OK").OnEvent("Click", (*) => (
        n := Integer(ed.Value),
        n := n < 10 ? 10 : n > 3600 ? 3600 : n,
        AutoSaveInterval := n,
        SetTimer(DoAutoSave, n * 1000),
        IniWrite(n, SETTINGS_FILE, "Settings", "AutoSaveInterval"),
        DebugLog("Auto save interval set to " n "s"),
        dlg.Destroy()
    ))
    dlg.AddButton("x+" S(6) " yp w" S(80) " h" S(26), "Cancel").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize")
}

; ============================================================
; HOTKEY PROFILE EXPORT/IMPORT
; ============================================================

ExportHotkeys(*) {
    global HK_Custom, SETTINGS_FILE
    fn := FileSelect("S16", A_ScriptDir "\hotkey_profile.ini", "Export Hotkey Profile", "INI (*.ini)")
    if fn = ""
        return
    try {
        cnt := 0
        for id, val in HK_Custom {
            cnt++
            IniWrite(val, fn, "Hotkeys", id)
        }
        IniWrite(cnt, fn, "Hotkeys", "count")
        DebugLog("Exported " cnt " hotkeys to " fn)
        _HK_ResultPopup("Export", "Exported " cnt " custom hotkeys.", "4CAF50")
    } catch as e {
        _HK_ResultPopup("Export Error", "Export failed: " e.Message, "E53935")
    }
}

ImportHotkeys(*) {
    global HK_Custom
    fn := FileSelect("3", A_ScriptDir "\hotkey_profile.ini", "Import Hotkey Profile", "INI (*.ini)")
    if fn = ""
        return
    try {
        section := IniRead(fn, "Hotkeys")
        imported := 0
        for line in StrSplit(section, "`n") {
            if !InStr(line, "=")
                continue
            id := Trim(SubStr(line, 1, InStr(line, "=") - 1))
            val := Trim(SubStr(line, InStr(line, "=") + 1))
            if id = "count"
                continue
            HK_Custom[id] := val
            imported++
        }
        HK_ReapplyAll()
        DebugLog("Imported " imported " hotkeys from " fn)
        _HK_ResultPopup("Import", "Imported " imported " hotkeys.`nClose and reopen Hotkey Settings to refresh.", "4CAF50")
    } catch as e {
        _HK_ResultPopup("Import Error", "Import failed: " e.Message, "E53935")
    }
}

_HK_ResultPopup(title, msg, color) {
    dlg := Gui("+AlwaysOnTop +ToolWindow", title)
    dlg.BackColor := "1E1F22"
    dlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    dlg.MarginX := S(14)
    dlg.MarginY := S(14)
    dlg.AddText("c" color, msg)
    dlg.AddButton("xm y+10 w" S(80) " h" S(26) " Default", "OK").OnEvent("Click", (*) => dlg.Destroy())
    dlg.Show("AutoSize")
}

; ============================================================
; BACKUP / RESTORE CONFIG
; ============================================================

BackupConfig(*) {
    global SETTINGS_FILE
    ts := FormatTime(, "yyyyMMdd_HHmmss")
    bak := A_ScriptDir "\gui_settings_backup_" ts ".ini"
    try {
        FileCopy(SETTINGS_FILE, bak)
        DebugLog("Config backed up to " bak)
        _HK_ResultPopup("Backup", "Backup saved:`n" bak, "4CAF50")
    } catch as e {
        _HK_ResultPopup("Backup Error", "Backup failed: " e.Message, "E53935")
    }
}

RestoreConfig(*) {
    global SETTINGS_FILE
    fn := FileSelect("3", A_ScriptDir "\gui_settings_backup_*.ini", "Select backup to restore", "INI (*.ini)")
    if fn = ""
        return
    ; Custom confirmation dialog
    cDlg := Gui("+AlwaysOnTop +ToolWindow", "Restore Config")
    cDlg.BackColor := "1E1F22"
    cDlg.SetFont("s" S(9) " cFFFFFF", "Segoe UI")
    cDlg.MarginX := S(14)
    cDlg.MarginY := S(14)
    cDlg.AddText("cFFD54F", "Restore " fn "?")
    cDlg.AddText("xm y+" S(4) " cAAAAAA", "This will overwrite current settings.")
    result := false
    cDlg.AddButton("xm y+10 w" S(80) " h" S(26) " BackgroundE53935 cFFFFFF", "Yes").OnEvent("Click", (*) => (result := true, cDlg.Destroy()))
    cDlg.AddButton("x+8 yp w" S(80) " h" S(26), "No").OnEvent("Click", (*) => cDlg.Destroy())
    cDlg.Show("AutoSize")
    WinWaitClose(cDlg)
    if !result
        return
    try {
        FileCopy(fn, SETTINGS_FILE, 1)
        DebugLog("Config restored from " fn)
        _HK_ResultPopup("Restore", "Config restored. Restart the script for changes to take full effect.", "4CAF50")
    } catch as e {
        _HK_ResultPopup("Restore Error", "Restore failed: " e.Message, "E53935")
    }
}

; ============================================================
; CSP AUTO-RESTART MONITOR
; ============================================================

ToggleCSPMonitor(*) {
    global CSP_RestartMonitor
    CSP_RestartMonitor := !CSP_RestartMonitor
    DebugLog("CSP auto-restart " (CSP_RestartMonitor ? "ON" : "OFF"))
    ShowNotify("CSP Monitor", CSP_RestartMonitor ? "ON" : "OFF", CSP_RestartMonitor ? "0x4CAF50" : "0xE53935")
}
