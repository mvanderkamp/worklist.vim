" Vim global plugin that provides a quickfix todo list based on source lines.
" Maintainer: Michael van der Kamp
" License: Same as vim

if exists('g:loaded_worklist') || &cp || version < 800
    finish
endif
let g:loaded_worklist = 1

" Prepare options
let g:worklist_autoload = get(g:, 'worklist_autoload', v:true)
let g:worklist_autosave = get(g:, 'worklist_autosave', v:true)
let g:worklist_incomplete_text = get(g:, 'worklist_incomplete_text', '[ ]')
let g:worklist_complete_text = get(g:, 'worklist_complete_text', '[X]')
let g:worklist_dir = get(g:, 'worklist_dir', $HOME .. '/.vim')
let g:worklist_file = get(g:, 'worklist_file', 'worklist.json')
let g:worklist_popup_maxwidth = get(g:, 'worklist_popup_maxwidth', 60)
let g:worklist_qf_maxheight = get(g:, 'worklist_qf_maxheight', 10)

" This is the list of quickfix items which defines the 'worklist'
let s:worklist = []
let s:last_line = -1
let s:notewinid = -1

" Add the current file and line number as a worklist item
function! s:WorklistAdd(note='')
    if &filetype == 'qf'
        echohl | echo 'Unabled to add quickfix entries to the worklist.' | echohl None
    endif
    let [bufnum, lnum, col, off, curswant] = getcurpos()
    let curfile = expand('%:p')
    call add(s:worklist, {
                \   'filename': curfile,
                \   'lnum': lnum,
                \   'col': col,
                \   'note': a:note,
                \   'text': trim(getline(lnum)),
                \   'valid': v:true,
                \ })
    call s:WorklistUpdateIfCurrent('$')
endfunction

" Used to provide the custom formatting for the worklist items
function! s:WorklistQfTextFunc(info)
    let lines = []
    for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
        let item = s:worklist[idx]
        let text = fnamemodify(item.filename, ':p:.')

        if item.valid
            let text ..= '|' .. g:worklist_incomplete_text .. '|'
        else
            let text ..= '|' .. g:worklist_complete_text .. '|'
        endif

        let text ..= trim(item.text)

        call add(lines, text)
    endfor
    return lines
endfunction

" Display the worklist in the quickfix window
"
" action: Passed as the action argument to setqflist
" idx: Passed as the idx entry to the {what} argument of setqflist
function! s:WorklistShowQf(action=' ', idx=1)
    call s:WorklistUpdate(a:action, a:idx)
    let l:height = min([g:worklist_qf_maxheight, len(s:worklist)])
    if l:height > 0
        execute 'copen ' .. l:height
        call s:WorklistShowNotePopup(v:true)
    else
        echohl Error | echo 'Worklist is empty' | echohl None
    endif
endfunction

" Only update the worklist, don't force it to be visible
function! s:WorklistUpdate(action=' ', idx=1)
    call setqflist([], a:action, {
                \   'title': 'worklist',
                \   'context': 'worklist',
                \   'items': s:worklist,
                \   'idx': a:idx,
                \   'quickfixtextfunc': '<SID>WorklistQfTextFunc',
                \ })
endfunction

" Toggle whether the current item in the worklist is 'completed'
function! s:WorklistToggle()
    if &filetype != 'qf'
        echohl Error | echo 'Can only complete worklist items in the quickfix window!' | echohl None
        return
    elseif getqflist({'title': 1}).title != 'worklist'
        echohl Error | echo 'The current quickfix window is not the worklist!' | echohl None
        return
    endif
    let item = line('.') - 1
    let s:worklist[item].valid = !s:worklist[item].valid
    call s:WorklistUpdate('r', item + 1)
endfunction

" Add a note to this worklist item
"
" note: note to save for the current worklist item. If empty, prompt for one.
function! s:WorklistNote(note='')
    if &filetype != 'qf'
        echohl Error | echo 'Can only add notes to worklist items in the quickfix window!' | echohl None
        return
    elseif getqflist({'title': 1}).title != 'worklist'
        echohl Error | echo 'The current quickfix window is not the worklist!' | echohl None
        return
    endif

    let item = line('.') - 1

    if empty(a:note)
        call inputsave()
        let s:worklist[item].note = input('Set worklist note: ', get(s:worklist[item], 'note', ''))
        call inputrestore()
    else
        let s:worklist[item].note = a:note
    endif

    call s:WorklistShowQf('r', item + 1)
endfunction

" Show a popup with the note for the current worklist item
function! s:WorklistShowNotePopup(force=v:false)
    if getqflist({'title': 1}).title == 'worklist'
        let index = line('.') - 1
        if index == s:last_line && !a:force
            return
        endif
        let s:last_line = index
        call s:WorklistCloseNotePopup()

        let item = s:worklist[index]
        if !empty(get(item, 'note', ''))
            let s:notewinid = popup_atcursor(item.note, {
                        \   'border': [1, 1, 1, 1],
                        \   'borderchars': [' '],
                        \   'moved': [index + 1, 0, 999],
                        \   'maxwidth': g:worklist_popup_maxwidth,
                        \ })
            call setwinvar(s:notewinid, '&showbreak', 'NONE')
            call setwinvar(s:notewinid, '&linebreak', 1)
        endif
    endif
endfunction

" Close the note popup
function! s:WorklistCloseNotePopup()
    call popup_close(s:notewinid)
endfunction

" Remove the current item from the worklist
function! s:WorklistRemove()
    if &filetype != 'qf'
        echohl Error | echo 'Can only remove worklist items in the quickfix window!' | echohl None
        return
    elseif getqflist({'title': 1}).title != 'worklist'
        echohl Error | echo 'The current quickfix window is not the worklist!' | echohl None
        return
    endif
    let item = line('.') - 1
    call remove(s:worklist, item)
    call s:WorklistUpdate('r', item)
endfunction

" Compares two worklist items. Used for sorting.
function! s:WorklistSort_cmpfunc(left, right)
    let lname = fnamemodify(a:left.filename, ':p:.')
    let rname = fnamemodify(a:right.filename, ':p:.')
    if lname < rname
        return -1
    elseif lname > rname
        return 1
    endif

    " Filenames are equal, use line number
    return float2nr(ceil(a:left.lnum - a:right.lnum))
endfunction

" Sort the worklist according to file name then line number
function! s:WorklistSort()
    call sort(s:worklist, 'WorklistSort_cmpfunc')
    call s:WorklistUpdateIfCurrent()
endfunction

" If the worklist is the current quickfix list, update it.
function! s:WorklistUpdateIfCurrent(idx=1)
    let qlist = getqflist({'title': 1})
    if qlist.title == 'worklist'
        call s:WorklistUpdate('r', a:idx)
    endif
endfunction

" Get the full worklist file path
function! s:WorklistFile(filename)
    return g:worklist_dir .. '/' .. a:filename
endfunction

" Save the worklist
function! s:WorklistSave(filename=g:worklist_file)
    if empty(a:filename)
        let l:filename = g:worklist_file
    else
        let l:filename = a:filename
    endif
    let g:worklist_file = l:filename
    let dest = s:WorklistFile(l:filename)
    let data = json_encode(s:worklist)
    call writefile([data], dest)
endfunction

" Load the worklist
function! s:WorklistLoad(filename=g:worklist_file)
    if empty(a:filename)
        let l:filename = g:worklist_file
    else
        let l:filename = a:filename
    endif
    let g:worklist_file
    let dest = s:WorklistFile(l:filename)
    if filereadable(dest)
        let data = json_decode(readfile(dest)[0])
        let s:worklist = data
    else
        echohl Error | echo 'No worklist file has been saved yet, unable to load.' | echohl None
    endif
    call s:WorklistUpdateIfCurrent()
endfunction

" autoload
if g:worklist_autoload
    augroup worklist_autoload_autocmds
        autocmd!
        autocmd VimEnter * call WorklistLoad(v:true)
    augroup END
endif

" autosave
if g:worklist_autosave
    augroup worklist_autosave_autocmds
        autocmd!
        autocmd VimLeave * call s:WorklistSave()
    augroup END
endif

function! s:WorklistStartPopupAutocmds()
    if &filetype != 'qf'
        return
    endif
    augroup worklist_popup_autocmds
        autocmd!
        autocmd CursorMoved <buffer> call s:WorklistShowNotePopup()
        autocmd BufEnter <buffer> call s:WorklistShowNotePopup(v:true)
        autocmd BufLeave <buffer> call s:WorklistCloseNotePopup()
    augroup END
endfunction

augroup worklist_window_autocmds
    autocmd!
    autocmd FileType qf call s:WorklistStartPopupAutocmds()
augroup END

" Define ex commands for the primary functions
command! -nargs=* WorklistAdd call <SID>WorklistAdd("<args>")
command! -nargs=? WorklistLoad call <SID>WorklistLoad("<args>")
command! -nargs=* WorklistNote call <SID>WorklistNote("<args>")
command! WorklistRemove call <SID>WorklistRemove()
command! -nargs=? WorklistSave call <SID>WorklistSave("<args>")
command! WorklistSort call <SID>WorklistSort()
command! WorklistToggle call <SID>WorklistToggle()
command! WorklistShow call <SID>WorklistShowQf()
