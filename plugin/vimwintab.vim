" Vimwintab
"
" A plugin that adds IDE-like tabs to Vim, which allows you to have regular
" tabs you are used to in every window you want to.
"
" Created by bozon joe.
" https://github.com/boson-joe
"
" ':h VWTLicense' in Vim or open the 'license.txt' file in the root directory
" of this plugin to read the license this software is distributed on.
"
" ':h VWTUserGuide' in Vim or go to the link below to view the User Guide.
" https://github.com/boson-joe/vimwintab/wiki/Vimwintab-User-Guide



" ---------- Customisable values

" modes in which plugin operates. The following modes are supported:

"   fullauto - add a buffer to a window if 
"              the buffer is entered from this window.
"   halfman  - add a buffer to a window if
"              the new buffer is created from this window.
"   fullman  - add a buffer to a window if
"              user directly asks for that.
let s:wintab_mode               = get(g:, "wintab_mode", "fullauto")

" whether need to go to newly opened tab, or
" remain at the current one. 0 - no, non-0 - yes.
let s:wintab_go_to_new_tab      = get(g:, "wintab_go_to_new_tab", 0)

" whether need to catch layout upon Vim startup.
" 0 - no, non-0 - yes.
let s:wintab_vim_startup        = get(g:, "wintab_vim_startup", 0)

" how borders of every tab would look like.
" need to be a string.
let s:wintab_tab_left_border    = get(g:, "wintab_tab_left_border",  "<<")
let s:wintab_tab_right_border   = get(g:, "wintab_tab_right_border", ">>")

" width of space between tabs.
" you can make it negative, of course, but what's the point?
let s:wintab_tab_space          = get(g:, "wintab_tab_space", 1)

" how blank tabs (that shows that there are other tabs
" to the left or right of the bar that do not fit into it)
" would look like.
let s:wintab_tab_blank          = get(g:, "wintab_tab_blank", "...")

" highlighting for different tabs
let s:wintab_tab_hi_regular     = get(g:, "wintab_tab_hi_regular",  "Pmenu")
let s:wintab_tab_hi_selected    = get(g:, "wintab_tab_hi_selected", "PmenuSel")
let s:wintab_tab_hi_blank       = get(g:, "wintab_tab_hi_blank",    "Pmenu")

" time in milliseconds when data structures will be updated
" and tabs redrawn after VWT_HandleWinResize() is called.
" cannot resize without timer as Vim updates info about some
" windows with delay so it is hard to catch with au.
let s:wintab_resize_timer       = get(g:, "wintab_resize_timer", 20)



" ---------- User Interface

function s:VWT_SetCommands()
    " Add / delete windows.
    :command -nargs=? VWTAddWindow call <SID>VWT_AddWin(<f-args>)
    :command -nargs=? VWTDelWindow call <SID>VWT_DelWin(<f-args>)

    " Add / delete bufs.
    :command -nargs=* VWTAddBufToTabBar call <SID>VWT_AddBufToTabBar(<f-args>)
    :command VWTDeleteCurTabFromBar     call <SID>VWT_DeleteCurTabFromBar()

    " Change display of tab bars.
    :command VWTShowCurTabBar call <SID>VWT_HideShowTabBar(win_getid(), function("popup_show"))
    :command VWTHideCurTabBar call <SID>VWT_HideShowTabBar(win_getid(), function("popup_hide"))

    :command VWTShowAllTabBars call <SID>VWT_HideShowAllTabBars(function("popup_show"))
    :command VWTHideAllTabBars call <SID>VWT_HideShowAllTabBars(function("popup_hide"))

    :command -nargs=? VWTToggleTabBar call <SID>VWT_ToggleTabBar(<f-args>)
    :command VWTToggleAllTabBars      call <SID>VWT_ToggleAllTabBars()

    " Move around a tab bar.
    :command VWTSlideLeft  call <SID>VWT_SlideTabsBar(win_getid(), s:wintab_slide_left)
    :command VWTSlideRight call <SID>VWT_SlideTabsBar(win_getid(), s:wintab_slide_right)
    :command VWTGoTabLeft  call <SID>VWT_MoveCurTab(win_getid(), s:wintab_slide_left)
    :command VWTGoTabRight call <SID>VWT_MoveCurTab(win_getid(), s:wintab_slide_right)

    " Change plugin values.
    :command -nargs=1 VWTChangeMode call <SID>VWT_ChangeMode(<f-args>)

    " Reset plugin.
    :command VWTReset call <SID>VWT_Reset()

    " Disable the plugin.
    :command VWTDisable call <SID>VWT_Disable()

    " Redraw tab bars.
    :command VWTRedraw  call <SID>VWT_Redraw()
endfunction
" Enable the plugin if it is disabled.
:command VWTEnable  call <SID>VWT_Enable()
eval <SID>VWT_SetCommands()



" ---------- Main Datastructures

" contains currently opened windows
let s:wins_open = {}

" contains parameters of windows
" key - winid, value - list of the parameters below.
let s:wins_info = {}
function s:VWT_InitWinsInfoValue()
    return  {   "x":    0,
            \   "y":    0,
            \   "w":    0,
            \   "h":    0, }
endfunction

" contains info about buffers associated with each window
" key - winid, value - another dict, that has bufnr as key
"                      and tabid as value
let s:wins_bufs = {}
function s:VWT_InitWinsBufsValue()
    return {}
endfunction

" contains tabs info for a given window.
" key - winid, value - another dict with the values below.
let s:wins_tabs = {}
function s:VWT_InitWinsTabsValue()
    return  {   "tabs_ids":     [], 
            \   "tabline_w":    0,
            \   "firsttab":     0,
            \   "lasttab":      -1,
            \   "firstblank":   0, 
            \   "lastblank":    0,    
            \   "curtab":       0, }
endfunction

" contains info about windows associated with each buffer
" key - bufnr, value - another dict, that has winid as key
"                      and value of 0 for each window
let s:bufs_wins = {}
function s:VWT_InitBufsWinsValue()
    return {}
endfunction



" ---------- Internal Controls

" value needed to delete closed windows from data structures.
let s:prev_win_id = -1

" values to determine direction of tab bar movements.
let s:wintab_slide_left  = -1
let s:wintab_slide_right = 1

" value to determine if the autocommands should be loaded. Set to 0 if the
" user wants to disable the plugin.
let s:wintab_load_au = 1

" non-0 if plugin is disabled. 0 if operational.
let s:wintab_plugin_disabled = 0

" ---------- In case you want to read the code

" Welcome to the code section, adventurer. Before you start,
" there are a few things I need to tell you to comfort your
" journey:
"   1) + 0 everywhere is me being paranoid about values not
"   being integers (this casts strings to ints);
"   2) Vim does not let you know the types of different
"   windows upon their creation reliably. That means that
"   when WinNew event fires, there is a chance that newly
"   created window doesn't have a correct type that you can
"   check. So windows are firstly added, and then either
"   confirmed, or deleted from datastructures;
"   3) No events to catch resize and changes of layout (say
"   switching windows), so handing that is a huge workaround. 



" ---------- General Helpers

function s:VWT_RemoveDictListItem(dict, key, item)
    if !has_key(a:dict, a:key)
        return 1
    endif

    let i_list  = a:dict[a:key]
    let idx     = index(i_list, a:item)
    if -1 == idx
        return 2
    endif

    eval remove(i_list, idx)
    if empty(i_list)
        eval remove(a:dict, a:key)
    endif

    return 0
endfunction

function s:VWT_RemoveDictDictItem(dict, key, item)
    if !has_key(a:dict, a:key)
        return 1
    endif

    let i_dict          = a:dict[a:key]
    if !has_key(i_dict, a:item)
        return 2
    endif

    eval remove(i_dict, a:item)
    "if empty(i_dict)
    "    eval remove(a:dict, a:key)
    "endif

    return 0
endfunction

function s:VWT_ProcessExecutedCmd(matches, Callback)
    let cmd = getcmdline()

    for m in a:matches
        if matchstr(cmd, m) != ""
            eval a:Callback()
            return 0
        endif  
    endfor

    return 1
endfunction

function s:VWT_CorrectBufAndWinTypes(bufnr, winid)
    let bufnr   = a:bufnr + 0
    let winid   = a:winid + 0

    let wt      = win_gettype(winid)
    let bt      = getbufvar(bufnr, "&buftype")
    
    let wi          = getwininfo(winid)[0]
    let is_terminal = wi.terminal
    let is_quickfix = wi.quickfix
    let is_loclist  = wi.loclist
    let is_ft_qf    = 0
    if exists("#filetype")
       let ft = &filetype
       if ft ==? "qf"
           let is_ft_qf = 1
       endif
    let bufname = bufname(bufnr)
    

    if wt !=? "" || bt !=? "" || is_terminal || is_quickfix || is_loclist 
                \|| is_ft_qf || !buflisted(bufnr)
        return 0
    else
        return 1
    endif
endfunction

function s:VWT_ChangeMode(how)
    let s:wins_open = {} 
    let s:wins_info = {} 
    let s:wins_bufs = {} 
    let s:wins_tabs = {} 
    let s:bufs_wins = {} 

    let s:wintab_mode               = get(a:how, "mode",            s:wintab_mode)
    let s:wintab_go_to_new_tab      = get(a:how, "new_tab",         s:wintab_go_to_new_tab)
    let s:wintab_tab_left_border    = get(a:how, "left_b",          s:wintab_tab_left_border)
    let s:wintab_tab_right_border   = get(a:how, "right_b",         s:wintab_tab_right_border)
    let s:wintab_tab_space          = get(a:how, "tab_space",       s:wintab_tab_space)
    let s:wintab_tab_blank          = get(a:how, "tab_blank",       s:wintab_tab_blank)
    let s:wintab_tab_hi_regular     = get(a:how, "tab_hi_r",        s:wintab_tab_hi_regular)
    let s:wintab_tab_hi_selected    = get(a:how, "tab_hi_s",        s:wintab_tab_hi_selected)
    let s:wintab_tab_hi_blank       = get(a:how, "tab_hi_b",        s:wintab_tab_hi_blank)
    let s:wintab_resize_timer       = get(a:how, "resize_timer",    s:wintab_resize_timer)

    eval popup_clear()    
    eval <SID>VWT_AutogroupSetter()
    eval <SID>VWT_HandleVimStartup() 
    return 0
endfunction

function s:VWT_Disable()
    unlet s:wins_open 
    unlet s:wins_info 
    unlet s:wins_bufs 
    unlet s:wins_tabs 
    unlet s:bufs_wins 

    let s:wintab_load_au = 0
    eval <SID>VWT_AutogroupSetter()
    eval <SID>VWT_DeleteCommands()
    eval popup_clear()

    let s:wintab_plugin_disabled = 1
endfunction

function s:VWT_Reset()
    call <SID>VWT_ChangeMode( {} )
endfunction

function s:VWT_Enable()
    if !s:wintab_plugin_disabled
        return
    endif

    call <SID>VWT_ChangeMode( {} )
    call <SID>VWT_SetCommands()
    let s:wintab_plugin_disabled = 0
endfunction

function s:VWT_Redraw()
    call <SID>VWT_HandleWinResize()
endfunction

function s:VWT_DeleteCommands()
    delc VWTAddWindow
    delc VWTDelWindow
    delc VWTAddBufToTabBar
    delc VWTDeleteCurTabFromBar
    delc VWTShowCurTabBar
    delc VWTHideCurTabBar
    delc VWTShowAllTabBars
    delc VWTHideAllTabBars
    delc VWTToggleTabBar
    delc VWTToggleAllTabBars     
    delc VWTSlideLeft 
    delc VWTSlideRight
    delc VWTGoTabLeft 
    delc VWTGoTabRight
    delc VWTChangeMode
    delc VWTReset
    delc VWTDisable
    delc VWTRedraw 
endfunction



" ---------- Windows

" Helpers
function s:VWT_GetWinInfo(winid)
    let winid    = a:winid + 0
    let ret      = <SID>VWT_InitWinsInfoValue()
    let winpos   = win_screenpos(winid)
    let ret["x"] = winpos[1]
    let ret["y"] = winpos[0]
    let ret["w"] = winwidth(winid)
    let ret["h"] = winheight(winid)

    return ret 
endfunction

function s:VWT_UpdateCurWinInfo()
    let cur_win_id  = win_getid() + 0
    let s:wins_info[cur_win_id] = <SID>VWT_GetWinInfo(cur_win_id)
endfunction

function s:VWT_WinNrToId(index, winnr)
    let winid   = win_getid(a:winnr) + 0
    let ret     = ""
    if winid != 0
        let ret = winid 
    endif
    return ret + 0
endfunction

" Add a window
function s:VWT_HandleWinAddition(winid, where)
    let winid   = a:winid + 0
    if a:where["open"] 
        let s:wins_open[winid] = 1 
    endif
    if a:where["info"] 
        let s:wins_info[winid] = <SID>VWT_GetWinInfo(winid)
    endif
    if a:where["bufs"] 
        let s:wins_bufs[winid] = <SID>VWT_InitWinsBufsValue()
    endif
    if a:where["tabs"] 
        let s:wins_tabs[winid] = <SID>VWT_InitWinsTabsValue()
    endif
endfunction

" If the type of a window or a buffer is wrong, the window is still
" added to wins_open and wins_info structs, as the window's dimensions
" are still needed to position other tab bars correctly on the screen.
" Addition to wins_bufs and wins_tabs could be false positive as Vim
" doesn't provide a reliable way to check the window's type upon its
" creation.
function s:VWT_HandleNewWindow(winid)
    let winid   = a:winid + 0
    if has_key(s:wins_open, winid)
        return 1
    endif

    let wi      = getwininfo(winid)[0]
    let bufnr   = wi.bufnr + 0
    let win_add_info = {"open":1, "info":1, "bufs":0, "tabs":0}
    if <SID>VWT_CorrectBufAndWinTypes(bufnr, winid)
        let win_add_info["bufs"] = 1
        let win_add_info["tabs"] = 1
    endif

    eval <SID>VWT_HandleWinAddition(winid, win_add_info)
    eval <SID>VWT_HandleWinResize() 
    return 0
endfunction

function s:VWT_AddWin(...)
    let winid = get(a:000, 0, win_getid())
    eval <SID>VWT_HandleNewWindow(winid)
endfunction

function s:VWT_HandleVimStartup()
    let w_list     = map(range(1, winnr('$')), function("<SID>VWT_WinNrToId")) 
    let cur_win_id = win_getid() + 0
    for w in w_list
        if win_gotoid(w)
            eval <SID>VWT_HandleNewWindow(w)
            eval <SID>VWT_HandleBufAddition(winbufnr(w), w)
        endif
    endfor 
    eval win_gotoid(cur_win_id)
    let s:prev_win_id = cur_win_id
endfunction

" Delete a window
" If the plugin finds that the type of newly added window is wrong,
" it will delete such a window from wins_bufs and wins_tabs structs.
function s:VWT_HandleWinDeletion(winid, what)
    let winid   = a:winid + 0

    if a:what["bufs"]+0 && a:what["tabs"]+0 && has_key(s:wins_bufs, winid)
        let bufs_list   = s:wins_bufs[winid]
        for [b, i] in items(bufs_list)
            eval <SID>VWT_RemoveBufFromWin(b, winid)
        endfor 
        "if empty(bufs_list) && has_key(s:wins_bufs, winid)
        if has_key(s:wins_bufs, winid)
            eval remove(s:wins_bufs, winid)
        endif
        if has_key(s:wins_tabs, winid)
            eval remove(s:wins_tabs, winid)
        endif
    endif

    if a:what["open"]+0 && a:what["info"]+0 && has_key(s:wins_open, winid)
        eval remove(s:wins_open, winid)
        eval remove(s:wins_info, winid)
    endif
    
    if a:what["resize"]
        eval <SID>VWT_HandleWinResize()
    endif
endfunction

function s:VWT_DelWin(...)
    let winid = get(a:000, 0, win_getid())
    eval <SID>VWT_HandleWinDeletion(winid, 
                \ {"open":1,"info":1,"bufs":1,"tabs":1,"resize":0} )
endfunction

" This will fire after a window is added and will check if the window
" or buffer are of correct types, and delete them if not. As the window 
" is still displayed, it is not deleted from wins_bufs and wins_tabs as
" its dimensions are taken into account when tab bars at other windows are
" positioned on the screen.
function s:VWT_HandleWrongWin()
    let cur_win_id  = win_getid() + 0
    let wi          = getwininfo(cur_win_id)[0]
    let bufnr       = wi.bufnr + 0
    if has_key(s:wins_open, cur_win_id) &&
       \ !<SID>VWT_CorrectBufAndWinTypes(bufnr, cur_win_id)

        let win_del_info = {"open":0, "info":0, "bufs":1, "tabs":1, "resize":0}
        eval <SID>VWT_HandleWinDeletion(cur_win_id, win_del_info)
        if has_key(s:bufs_wins, bufnr) && empty(s:bufs_wins[bufnr])
            eval remove(s:bufs_wins, bufnr)
        endif
        return 1
    endif
    return 0
endfunction

" Control a window

" No WinDeleted event, so simulating it with prev_win_id global variable.
" If the window with this id is no more, then delete it from structs and
" resize.
function s:VWT_HandleWinLeaving()
    let need_to_resize = 0

    if s:prev_win_id != -1 && empty(getwininfo(s:prev_win_id))
       let win_del_info = {"open":1, "info":1, "bufs":1, "tabs":1, "resize":1}
       eval <SID>VWT_HandleWinDeletion(s:prev_win_id, win_del_info)
       let need_to_resize = 1
    endif

    let s:prev_win_id = win_getid() + 0
endfunction

" Sometimes Vim doesn't know what updated dimensions of windows are after some
" types of windows are deleted (after command window is closed, for example,
" dimensions are not updated timely, and after quickfix is they are updated 
" with incorrect heights. So deferring resizing until better times.
function s:VWT_HandleWinResize()
    eval timer_start(s:wintab_resize_timer, function("<SID>VWT_ResizeUponTimer"))
endfunction

" Main resize function. It also cleans garbage info left from closed windows
" (if any).
function s:VWT_ResizeUponTimer(timer_id)
    " screw the timer id, ahaha

    for [k, v] in items(s:wins_info)
        let new_w_info = <SID>VWT_GetWinInfo(k+0)
        if new_w_info["w"] == -1 || new_w_info["h"] == -1
            let win_del_info = {"open":1,"info":1,"bufs":1,"tabs":1,"resize":0}
            eval <SID>VWT_HandleWinDeletion(k, win_del_info)
        elseif new_w_info != v
            let s:wins_info[k]  = new_w_info
            if has_key(s:wins_tabs, k)
                let w_tabs  = s:wins_tabs[k]
                let cur_t   = w_tabs["curtab"]
                let max     = len(w_tabs["tabs_ids"])-1
                let first_t = w_tabs["firsttab"]
                let blank_l = 0
                if w_tabs["firstblank"] != 0
                    let blank_l += len(s:wintab_tab_blank)
                endif
                if w_tabs["lastblank"] != 0
                    let blank_l += len(s:wintab_tab_blank)
                endif
                let cur_w   = blank_l
                let recalc  = <SID>VWT_CalculateNewFirstTab(k, cur_t, first_t, cur_w)
                let first_t = recalc[0]
                let cur_w   += recalc[1]
                let last_t  = <SID>VWT_CalculateNewLastTab(k, cur_t+1, max, cur_w)[0]
                eval <SID>VWT_HandleTabsRedraw(k, first_t, last_t)
            endif
        endif
    endfor
endfunction



" ---------- Buffers

" Adding a buffer
function s:VWT_HandleBufAddition(bufnr, winid)
    let bufnr = a:bufnr + 0
    let winid = a:winid + 0

    if !has_key(s:wins_open, winid)
        return 1
    endif
    
    if !has_key(s:wins_bufs, winid)
        return 2
    endif

    if has_key(s:wins_bufs[winid], bufnr)
        return 3
    endif

    if !<SID>VWT_CorrectBufAndWinTypes(bufnr, winid) 
        return 4
    endif

    if 0 == <SID>VWT_AddBufToWin(bufnr, winid)
        eval <SID>VWT_HandleNewTab(bufnr, winid)
    else
        return 5
    endif

    return 0
endfunction

function s:VWT_AddBufToWin(bufnr, winid)
    let bufnr = a:bufnr + 0
    let winid = a:winid + 0

    if bufnr == -1 || winid == 0
        return 1
    endif

    if !has_key(s:wins_bufs, winid)
        let s:wins_bufs[winid] = {}
    endif

    let cur_win_buf_dict    = s:wins_bufs[winid]

    if !has_key(cur_win_buf_dict, bufnr)
        let cur_win_buf_dict[bufnr] = -1
        if !has_key(s:bufs_wins, bufnr)
            let s:bufs_wins[bufnr] = {}
        endif
        let cur_buf_win_dict        = s:bufs_wins[bufnr]
        let cur_buf_win_dict[winid] = 0
    else
        return 2
    endif

    return 0
endfunction

" If you add a buffer to a window from another window in fullauto mode,
" the current buffer of the window you are adding the buffer into will
" be added to the window you are adding the buffer from, as it is visited
" by Vim, so the event is triggered. Other modes do not have this behaviour. 
function s:VWT_AddBufToTabBar(...)
    if len(a:000) > 2
        return 1
    endif

    let winid = get(a:000, 1, win_getid())
    if !has_key(s:wins_open, winid)
        return 2
    endif

    let bufnr = get(a:000, 0, getwininfo(winid)[0].bufnr)

    eval <SID>VWT_HandleBufAddition(bufnr, winid)
endfunction

" Deleting a buffer
function s:VWT_HandleBufDeletion(bufnr, winid)
    let bufnr = a:bufnr + 0
    let winid = a:winid + 0
    if bufnr == -1 || winid == 0
        return
    endif
   
    let w_tabs = s:wins_tabs[winid] 
    eval <SID>VWT_RemoveBufFromWin(bufnr, winid)

    let n_first = w_tabs["firsttab"]
    let n_last  = <SID>VWT_CalculateNewLastTab(winid, n_first, 
                    \ len(w_tabs["tabs_ids"])-1,0)[0]
    eval <SID>VWT_HandleTabsRedraw(winid, n_first, n_last)
endfunction

function s:VWT_RemoveBufFromWin(bufnr, winid)
    let bufnr = a:bufnr + 0
    let winid = a:winid + 0
    if bufnr == -1 || winid == 0
        return
    endif
    eval <SID>VWT_HandleTabDeletion(bufnr, winid)

    eval <SID>VWT_RemoveDictDictItem(s:wins_bufs, winid, bufnr)
    eval <SID>VWT_RemoveDictDictItem(s:bufs_wins, bufnr, winid)

    if has_key(s:bufs_wins, bufnr) && empty(s:bufs_wins[bufnr])
        eval remove(s:bufs_wins, bufnr)
    endif

endfunction

function s:VWT_HandleBufWipeout(bufnr)
    let bufnr = a:bufnr + 0
    eval <SID>VWT_DeleteBufFromAllWins(bufnr)
endfunction

function s:VWT_DeleteBufFromAllWins(bufnr)
    let bufnr = a:bufnr + 0
    if bufnr == -1 || !has_key(s:bufs_wins, bufnr)
        return
    endif

    let w_dict = s:bufs_wins[bufnr]
    for [w, lala] in items(w_dict)
        eval <SID>VWT_HandleBufDeletion(bufnr, w)    
    endfor
endfunction

" Control buffers
function s:VWT_HandleCTRLOCTRLI()
    let cur_win_id  = win_getid() + 0
    let wi          = getwininfo(cur_win_id)[0]
    let bufnr       = wi.bufnr + 0
    if has_key(s:wins_bufs, cur_win_id) && 
     \ has_key(s:wins_bufs[cur_win_id], bufnr)
        eval <SID>VWT_HandleCurTabChange(index(s:wins_tabs[cur_win_id]["tabs_ids"],
                    \ s:wins_bufs[cur_win_id][bufnr]), cur_win_id)
        return 1
    endif
    return 0
endfunction



" ---------- Tabs

" Helpers
" CalculateNew... functions return a list, where the first index is for a new
" position, and the second one is for a width from an anchor point till new
" position.
function s:VWT_CalculateNewFirstTab(winid, lasttab, min_first, start_cur_w)
    let winid    = a:winid
    let w_tabs   = s:wins_tabs[winid]
    let tabs_l   = w_tabs["tabs_ids"]

    let tabs_len = len(tabs_l)
    
    if tabs_len == 0
        return
    endif

    let lasttab  = a:lasttab + 0
    let max_w    = s:wins_info[winid]["w"]

    let cur_w    = a:start_cur_w + 0
    let firsttab = lasttab
    let min_f    = a:min_first + 0
    while cur_w <= max_w && firsttab >= min_f
        let cur_w    += (popup_getpos(tabs_l[firsttab]).width+s:wintab_tab_space)
        let firsttab -= 1 
    endwhile
    
    let firsttab += 1
    if cur_w > max_w
        let cur_w    -= (popup_getpos(tabs_l[firsttab]).width+s:wintab_tab_space)
        let firsttab += 1
    endif
    return [firsttab, cur_w]
endfunction

function s:VWT_CalculateNewLastTab(winid, firsttab, max_last, start_cur_w)
    let winid    = a:winid
    let w_tabs   = s:wins_tabs[winid]
    let tabs_l   = w_tabs["tabs_ids"]
    let tabs_len = len(tabs_l)
    
    if tabs_len == 0
        return
    endif

    let firsttab = a:firsttab + 0
    let max_w    = s:wins_info[winid]["w"]

    let cur_w    = a:start_cur_w + 0
    let lasttab  = firsttab
    let max_l    = a:max_last + 0
    while cur_w <= max_w && lasttab <= max_l
        let cur_w   += (popup_getpos(tabs_l[lasttab]).width + s:wintab_tab_space)
        let lasttab += 1 
    endwhile
    
    let lasttab -= 1
    if cur_w > max_w
        let cur_w   -= (popup_getpos(tabs_l[lasttab]).width + s:wintab_tab_space)
        let lasttab -= 1
    endif

    return [lasttab, cur_w]
endfunction

" Create and add a tab
function s:VWT_HandleNewTab(bufnr, winid)
    let winid   = a:winid + 0
    let bufnr   = a:bufnr + 0
    let tabname = <SID>VWT_GetTabName(bufnr)
    let tabid   = <SID>VWT_CreateTab(winid, tabname)
    let w_tabs  = s:wins_tabs[winid]

    eval add(w_tabs["tabs_ids"], tabid)
    eval <SID>VWT_AssociateBufWithTab(bufnr, tabid, winid)

    let need_to_redraw = 0
    if <SID>VWT_PositionTab(winid, tabid)
        let w_tabs["lasttab"] += 1
    else
        eval popup_hide(tabid)
        let need_to_redraw = 1
    endif

    let n_last      = w_tabs["lasttab"]
    let n_first     = w_tabs["firsttab"]

    if s:wintab_go_to_new_tab
        let n_last      = len(w_tabs["tabs_ids"]) - 1
        let n_first     = <SID>VWT_CalculateNewFirstTab(winid, n_last, 0, 0)[0]
        let new_t_idx   = index(w_tabs["tabs_ids"], tabid)
        eval <SID>VWT_MakeTabCurrent(new_t_idx, winid)
    else
        eval <SID>VWT_HandleCurTabChange(w_tabs["curtab"], winid)
        let need_to_redraw = 0
    endif
   
    if need_to_redraw
        eval <SID>VWT_HandleTabsRedraw(winid, n_first, n_last)
    endif
endfunction

function s:VWT_GetTabName(bufnr)
    let bufname = fnamemodify(bufname(a:bufnr + 0), ":t")
    if bufname ==? ""
        let bufname = "unnamed"
    endif
    let tabname = s:wintab_tab_left_border . 
                \ bufname . 
                \ s:wintab_tab_right_border

    return tabname
endfunction

function s:VWT_HandleBufNameChange()
    let winid   = win_getid() + 0
    if !has_key(s:wins_tabs, winid)
        return 1
    endif

    let wi      = getwininfo(winid)[0]
    let bufnr   = wi.bufnr + 0
    let w_tabs  = s:wins_tabs[winid]
    let tabid   = s:wins_bufs[winid][bufnr]
    let newname = <SID>VWT_GetTabName(bufnr)

    eval popup_settext(tabid, newname)

    let n_first = w_tabs["firsttab"]
    let n_last  = <SID>VWT_CalculateNewLastTab(winid,n_first,
                \ len(w_tabs["tabs_ids"])-1,0)[0]

    eval <SID>VWT_HandleTabsRedraw(winid, n_first, n_last)
endfunction

function s:VWT_CreateTab(winid, text)
    return popup_create(a:text, {})
endfunction

function s:VWT_AssociateBufWithTab(bufnr, tabid, winid)
    let bufnr = a:bufnr + 0
    let tabid = a:tabid + 0
    let winid = a:winid + 0

    if !has_key(s:wins_bufs, winid)
        return 1
    endif
    let b_dict = s:wins_bufs[winid]

    if has_key(b_dict, bufnr) && b_dict[bufnr] != -1
        return 2
    endif
    let b_dict[bufnr] = tabid
    return 0
endfunction

" Delete a tab
function s:VWT_HandleTabDeletion(bufnr, winid)

    let bufnr  = a:bufnr + 0
    let winid  = a:winid + 0

    if !has_key(s:wins_bufs, winid)
        return 1
    endif
    let b_dict = s:wins_bufs[winid]

    if !has_key(b_dict, bufnr)
        return 2
    endif
    let tabid   = b_dict[bufnr]

    let w_tabs  = s:wins_tabs[winid]
    let tabs_l  = w_tabs["tabs_ids"]
    let p_idx   = index(tabs_l, tabid)
    if p_idx < w_tabs["firsttab"] 
        let w_tabs["firsttab"] -= 1
    endif
    if p_idx < w_tabs["lasttab"] || w_tabs["lasttab"] == len(tabs_l)-1
        let w_tabs["lasttab"]  -= 1 
    endif

    eval remove(w_tabs["tabs_ids"], p_idx)
    eval popup_close(tabid) 
    return 0
endfunction

function s:VWT_DeleteCurTabFromBar()
    let winid   = win_getid() + 0
    let wi      = getwininfo(winid)[0]
    let bufnr   = wi.bufnr + 0
    
    if !has_key(s:wins_tabs, winid)
        return
    endif

    let w_tabs  = s:wins_tabs[winid]
    let tabs_l  = w_tabs["tabs_ids"]
    let tabid   = s:wins_bufs[winid][bufnr]
    let tabidx  = index(tabs_l, tabid)
    
    eval <SID>VWT_RemoveBufFromWin(bufnr, winid)

    if len(tabs_l) == 0
        let w_tabs["lasttab"]   = -1
        let w_tabs["curtab"]    = 0
        let w_tabs["tabline_w"] = 0
        return
    endif

    let new_cur_tab = tabidx
    while new_cur_tab >= len(tabs_l)
        let new_cur_tab -= 1
    endwhile

    let w_tabs["curtab"] = new_cur_tab        
    eval <SID>VWT_HandleCurTabChange(new_cur_tab, winid)
    eval popup_close(tabid)

    let n_first = w_tabs["firsttab"]
    let n_last  = <SID>VWT_CalculateNewLastTab(winid, n_first, len(tabs_l)-1, 0)[0]
    eval <SID>VWT_HandleTabsRedraw(winid, n_first, n_last)
endfunction

" Visualize tabs
function s:VWT_HandleTabsRedraw(winid, firsttab, lasttab)
    let winid = a:winid+0
    eval <SID>VWT_HandleTabBlanks(winid, a:firsttab+0, a:lasttab+0)
    eval <SID>VWT_RedrawTabsBar  (winid, a:firsttab+0, a:lasttab+0) 
endfunction

function s:VWT_PositionTab(winid, tabid)
    let return_code = 1
    let winid       = a:winid + 0
    let tabid       = a:tabid + 0
    let wi          = <SID>VWT_GetWinInfo(winid)
    let w_tabs      = s:wins_tabs[winid]
    let tlw         = w_tabs["tabline_w"]
    let bufnamelen  = popup_getpos(tabid).width 

    if tlw + bufnamelen > wi["w"]
        let return_code = 0
    else
        let offset = 1
        eval popup_move(a:tabid, 
                \ { "line": wi["y"] + wi["h"] - offset, 
                \   "col": tlw + wi["x"]})
        eval popup_show(tabid)
        let w_tabs["tabline_w"] += (bufnamelen + s:wintab_tab_space)
    endif

    return return_code
endfunction

function s:VWT_RedrawTabsBar(winid, newfirsttab, newlasttab)
    let winid           = a:winid + 0
    let w_tabs          = s:wins_tabs[winid]
    let tabs_l          = w_tabs["tabs_ids"]
    let w_tabs["tabline_w"]  = 0

    if len(tabs_l) == 0
       return
    endif

    eval <SID>VWT_RedrawBlanks(winid, "f")

    let idx = a:newfirsttab
    while idx > w_tabs["firsttab"]
        eval popup_hide(tabs_l[w_tabs["firsttab"]])
        let w_tabs["firsttab"] += 1 
    endwhile
    let w_tabs["firsttab"] = idx
    while idx <= a:newlasttab
        let cur_tab = tabs_l[idx]
        if !<SID>VWT_PositionTab(winid, cur_tab)
            let idx += 1
            break
        endif
        let idx += 1
    endwhile
    let real_new_lasttab = idx - 1
    let end_of_while = w_tabs["lasttab"]
    if end_of_while > len(tabs_l) - 1 
        let end_of_while = len(tabs_l) - 1
    endif
    while idx <= end_of_while
        eval popup_hide(tabs_l[idx])
        let idx += 1
    endwhile
    let w_tabs["lasttab"] = real_new_lasttab

    eval <SID>VWT_RedrawBlanks(winid, "l")
endfunction

function s:VWT_RedrawBlanks(winid, what_blank)
    let winid   = a:winid + 0
    let w_tabs  = s:wins_tabs[winid] 
    let tabs_l  = w_tabs["tabs_ids"]

    if w_tabs["firstblank"]+0 && a:what_blank ==? "f"
        eval <SID>VWT_PositionTab(winid, w_tabs["firstblank"])
    endif

    if w_tabs["lastblank"]+0  && a:what_blank ==? "l"
        let max_w = <SID>VWT_GetWinInfo(winid)["w"] 
        let free_width = max_w - w_tabs["tabline_w"]
        while free_width < strchars(s:wintab_tab_blank)
            let tab_to_hide   = tabs_l[w_tabs["lasttab"]]
            let p_w             = popup_getpos(tab_to_hide)["width"]
            eval popup_hide(tab_to_hide)
            let w_tabs["lasttab"]   -= 1
            let w_tabs["tabline_w"] -= (p_w + s:wintab_tab_space)
            let free_width           = max_w - w_tabs["tabline_w"]
        endwhile
        eval <SID>VWT_PositionTab(winid, w_tabs["lastblank"])
    endif
endfunction

function s:VWT_HandleTabBlanks(winid, firsttab, lasttab)
    let winid   = a:winid + 0
    let tabs_l  = s:wins_tabs[winid]["tabs_ids"]

    if len(tabs_l) == 0
        return
    endif

    let head = 0
    let tail = 0
    
    if a:firsttab+0 == 0
        let head = 1
    endif
    
    if a:lasttab+0 == len(tabs_l) - 1
        let tail = 1
    endif

    if head + tail
        eval <SID>VWT_DeleteTabBlanks(winid, head, tail)
    endif

    eval <SID>VWT_AddTabBlanks(winid, !head, !tail)
endfunction

function s:VWT_AddTabBlanks(winid, head, tail)
    let winid  = a:winid + 0
    let w_tabs = s:wins_tabs[winid]

    if a:head+0 && !w_tabs["firstblank"]
        let w_tabs["firstblank"] = <SID>VWT_CreateTab(winid, s:wintab_tab_blank)
        eval popup_setoptions(w_tabs["firstblank"], 
                \ {"highlight": s:wintab_tab_hi_blank})
    endif

    if a:tail+0 && !w_tabs["lastblank"]
        let w_tabs["lastblank"]  = <SID>VWT_CreateTab(winid, s:wintab_tab_blank)
        eval popup_setoptions(w_tabs["lastblank"], 
                \ {"highlight": s:wintab_tab_hi_blank})
    endif
endfunction

function s:VWT_DeleteTabBlanks(winid, head, tail)
    let winid  = a:winid + 0
    let w_tabs = s:wins_tabs[winid]

    if a:head+0 && w_tabs["firstblank"]
        eval popup_close(w_tabs["firstblank"])
        let w_tabs["firstblank"] = 0
    endif 

    if a:tail+0 && w_tabs["lastblank"]
        eval popup_close(w_tabs["lastblank"])
        let w_tabs["lastblank"] = 0
    endif 
endfunction

function s:VWT_SlideTabsBar(winid, direction)
    let winid       = a:winid + 0
    let w_tabs      = s:wins_tabs[winid]
    let newfirsttab = w_tabs["firsttab"] + a:direction
    let newlasttab  = w_tabs["lasttab"]  + a:direction

    if newfirsttab >= 0 && newlasttab < len(w_tabs["tabs_ids"])
        eval <SID>VWT_HandleTabsRedraw(winid, newfirsttab, newlasttab)
    endif
endfunction

function s:VWT_MoveCurTab(winid, where)
    let winid       = a:winid + 0
    let w_tabs      = s:wins_tabs[winid]
    let tabs_l      = w_tabs["tabs_ids"]
    let cur_t       = w_tabs["curtab"]
    let new_cur_t   = cur_t + a:where

    if new_cur_t < 0
        eval <SID>VWT_HandleCurTabChange(len(tabs_l)-1, winid)
    elseif new_cur_t >= len(tabs_l)
        eval <SID>VWT_HandleCurTabChange(0, winid)
    else
        eval <SID>VWT_HandleCurTabChange(new_cur_t, winid)
    endif

endfunction

function s:VWT_HandleCurTabChange(new_cur_tab_idx, winid)
    let ncti    = a:new_cur_tab_idx + 0
    let winid   = a:winid + 0
    let w_tabs  = s:wins_tabs[winid]
    let tabs_l  = w_tabs["tabs_ids"]
    let n_first = w_tabs["firsttab"]
    let n_last  = w_tabs["lasttab"] 

    if ncti < w_tabs["firsttab"]
        let n_first = ncti
        let n_last  = <SID>VWT_CalculateNewLastTab(winid, n_first, len(tabs_l)-1,0)[0]
        eval <SID>VWT_HandleTabsRedraw(winid, n_first, n_last)
    elseif ncti > w_tabs["lasttab"]
        let n_last  = ncti 
        let n_first = <SID>VWT_CalculateNewFirstTab(winid, n_last, 0, 0)[0]
        eval <SID>VWT_HandleTabsRedraw(winid, n_first, n_last)
    endif

    eval <SID>VWT_MakeTabCurrent(ncti, winid)    

    let cur_tab_id = tabs_l[ncti] 
    let bufs = s:wins_bufs[winid] 
    for [k,v] in items(bufs)
        if v == cur_tab_id
            eval execute("buffer" . k)
            break
        endif
    endfor
endfunction

function s:VWT_MakeTabCurrent(new_cur_tab_idx, winid)
    let ncti    = a:new_cur_tab_idx + 0
    let winid   = a:winid + 0
    let w_tabs  = s:wins_tabs[winid]
    let tabs_l  = w_tabs["tabs_ids"]
  
    eval popup_setoptions(tabs_l[w_tabs["curtab"]], 
                \ {"highlight": s:wintab_tab_hi_regular})
    eval popup_setoptions(tabs_l[ncti], 
                \ {"highlight": s:wintab_tab_hi_selected})

    let w_tabs["curtab"] = ncti
endfunction

function s:VWT_HideShowTabBar(winid, Callback)
    let winid   = a:winid + 0
    let w_tabs  = s:wins_tabs[winid]
    let tabs_l  = w_tabs["tabs_ids"]
    let idx     = w_tabs["firsttab"]
    let last    = w_tabs["lasttab"]
    
    let wi      = s:wins_info[winid]
    if wi["h"] <= 0 && wi["w"] <= 0
        return 1
    endif

    while idx <= last
        eval a:Callback(tabs_l[idx])
        let idx += 1
    endwhile
endfunction

function s:VWT_HideShowAllTabBars(Callback)
    for [k, v] in items(s:wins_tabs)
        eval <SID>VWT_HideShowTabBar(k, a:Callback)
    endfor 
endfunction

function s:VWT_ToggleTabBar(...)
    let winid = get(a:000, 0, win_getid())    
    if !has_key(s:wins_open, winid) || !has_key(s:wins_tabs, winid)
        return 1
    endif
    
    let w_tabs   = s:wins_tabs[winid] 
    let tabid    = w_tabs["tabs_ids"][w_tabs["curtab"]]
    let callback = "popup_show" 
    if popup_getpos(tabid)["visible"]
        let callback = "popup_hide" 
    endif
    
    eval <SID>VWT_HideShowTabBar(winid, function(callback))
endfunction

function s:VWT_ToggleAllTabBars()
    for [k,v] in items(s:wins_tabs)
        eval <SID>VWT_ToggleTabBar(k)
    endfor 
endfunction



" ---------- Autocommands

function s:VWT_AutogroupSetter()
    augroup wintabaugroup
        autocmd!
        
        if !s:wintab_load_au
            let s:wintab_load_au = 1
            return
        endif

        " Catching initial layout upon Vim startup.
        if s:wintab_vim_startup
            autocmd VimEnter
                        \ * call <SID>VWT_HandleVimStartup()
        endif

        " Adding windows into dicts.
        if s:wintab_mode ==? "fullauto" || s:wintab_mode ==? "halfman"
            autocmd WinNew
                        \ * call <SID>VWT_HandleNewWindow(win_getid())
        endif

        " Catching wrong windows and buffers.
        autocmd TerminalOpen,CmdWinEnter,FileType,BufEnter
                    \ * call <SID>VWT_HandleWrongWin()

        " Simulating WinDeletion event. 
        autocmd WinEnter
                    \ * call <SID>VWT_HandleWinLeaving()
        autocmd CmdWinLeave
                    \ * call <SID>VWT_HandleWinDeletion(win_getid(),
                    \       {"open":1, "info":1, "bufs":1, "tabs":1, "resize":1}) |

        " Windows resized.
        autocmd CmdwinLeave,CmdlineLeave
                    \ * call <SID>VWT_ProcessExecutedCmd(["res[ize]"],
                    \ function("<SID>VWT_HandleWinResize"))
        autocmd CmdwinLeave,CmdlineLeave
                    \ * call <SID>VWT_ProcessExecutedCmd(["clo[se]", "q[uit]", "hid[e]"],
                    \ function("<SID>VWT_HandleWinResize"))
        autocmd OptionSet 
                    \ window,winheight,winwidth call <SID>VWT_HandleWinResize()
        autocmd VimResized
                    \ * call <SID>VWT_HandleWinResize()
        
        " Adding buffers.
        if s:wintab_mode ==? "fullauto"
            autocmd BufEnter
                        \ * call <SID>VWT_HandleBufAddition (expand('<abuf>'), 
                        \                           win_getid())
        elseif s:wintab_mode ==? "halfman"
            autocmd BufNew
                        \ * call <SID>VWT_HandleBufAddition (expand('<abuf>'), 
                        \                           win_getid())
        endif
       
        " Handling jumping from one buffer to another. 
        autocmd BufEnter
                    \ * call <SID>VWT_HandleCTRLOCTRLI()

        " Deleting buffers.
        autocmd BufUnload 
                    \ * call <SID>VWT_HandleBufWipeout(expand('<abuf>'))

        " Renaming buffers.
        autocmd BufFilePost
                    \ * call <SID>VWT_HandleBufNameChange()
    augroup END
endfunction
call <SID>VWT_AutogroupSetter()



" ---------- Debug

function s:VWT_EchoAllWinsInfo()
    for w in items(s:wins_info)
        echom w
    endfor
endfunction

function s:VWT_EchoAllWinsBufs()
    for w in items(s:wins_bufs)
        echom w
    endfor
endfunction

function s:VWT_EchoAllBufsWins()
    for w in items(s:bufs_wins)
        echom w
    endfor
endfunction

function s:VWT_EchoTabsInfo()
    for [w, i] in items(s:wins_bufs)
        echom "For winid" w ": "
        echom "    Buffers are" s:wins_bufs[w]
        echom "    Tabs are" s:wins_tabs[w] 
    endfor
endfunction

function s:VWT_EchoAllWinInfo(winid)
    let winid = a:winid
    echom "Winid is" winid
    if has_key(s:wins_open, winid)
        echom "wins_open -" s:wins_open[winid]
    endif
    if has_key(s:wins_bufs, winid)
        echom "wins_bufs -" s:wins_bufs[winid]
    endif
    if has_key(s:wins_tabs, winid)
        echom "wins_tabs -" s:wins_tabs[winid]
    endif
    if has_key(s:wins_info, winid)
        echom "wins_info -" s:wins_info[winid]
    endif
endfunction

function s:VWT_DebugInfo()
    eval <SID>VWT_EchoAllWinsInfo()
    eval <SID>VWT_EchoAllWinsBufs()
    eval <SID>VWT_EchoAllBufsWins()
    eval <SID>VWT_EchoTabsInfo()
endfunction

