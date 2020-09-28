
if exists('did_worklist_vim') || &cp || version < 700
    finish
endif
let did_worklist_vim = 1

" Prepare options
let g:worklist_incomplete_text = get(g:, 'worklist_incomplete_text', '[ ]')
let g:worklist_complete_text = get(g:, 'worklist_complete_text', '[X]')
let g:worklist_dir = get(g:, 'worklist_dir', $HOME .. '/.vim')
let g:worklist_file = get(g:, 'worklist_file', '.worklist.json')
let g:worklist_persist = get(g:, 'worklist_persist', v:true)

" This is the list of quickfix items which defines the 'worklist'
let s:worklist = []

" Add the current file and line number as a worklist item
function! WorklistAdd()
    let [bufnum, lnum, col, off, curswant] = getcurpos()
    let curfile = expand('%:p')
    call add(s:worklist, {
                \   'filename': curfile,
                \   'lnum': lnum,
                \   'col': col,
                \   'note': '',
                \   'text': getline(lnum),
                \   'valid': v:true,
                \ })
    call WorklistUpdateIfCurrent()
endfunction

" Used to provide the custom formatting for the worklist items
function! WorklistQfTextFunc(info)
    let lines = []
    for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
        let item = s:worklist[idx]
        let text = fnamemodify(item.filename, ':p:.')

        if item.valid
            let text ..= '|' .. g:worklist_incomplete_text .. '|'
        else
            let text ..= '|' .. g:worklist_complete_text .. '|'
        endif

        let text ..= item.text

        call add(lines, text)
    endfor
    return lines
endfunction

" Display the worklist in the quickfix window
"
" action: Passed as the action argument to setqflist
function! WorklistShowQf(action=' ')
    call WorklistUpdate(a:action)
    let l:height = min([10, len(s:worklist)])
    if l:height > 0
        execute 'copen ' .. l:height
    else
        echohl Error | echo 'No worklist items' | echohl None
    endif
endfunction

" Only update the worklist, don't force it to be visible
function! WorklistUpdate(action=' ')
    call setqflist([], a:action, {
                \   'title': 'worklist',
                \   'context': 'worklist',
                \   'items': s:worklist,
                \   'quickfixtextfunc': 'WorklistQfTextFunc',
                \ })
endfunction

" Toggle whether the current item in the worklist is 'completed'
function! WorklistToggle()
    if &filetype != 'qf'
        echohl Error | echo 'Can only complete worklist items in the quickfix window!' | echohl None
        return
    elseif getqflist({'title': 1}).title != 'worklist'
        echohl Error | echo 'The current quickfix window is not the worklist!' | echohl None
        return
    endif
    let item = line('.') - 1
    let s:worklist[item].valid = !s:worklist[item].valid
    call WorklistShowQf('r')
    execute string(item + 1)
endfunction

" Show a note for this line instead of the code
function! WorklistNote()
    if &filetype != 'qf'
        echohl Error | echo 'Can only add notes to worklist items in the quickfix window!' | echohl None
        return
    elseif getqflist({'title': 1}).title != 'worklist'
        echohl Error | echo 'The current quickfix window is not the worklist!' | echohl None
        return
    endif

    let item = line('.') - 1

    call inputsave()
    let s:worklist[item].note = input('Set worklist note: ')
    call inputrestore()

    call WorklistShowQf('r')
endfunction

let s:last_line = -1

" Show a popup with the note for the current worklist item
function! WorklistShowNotePopup()
    if getqflist({'title': 1}).title == 'worklist'
        let index = line('.') - 1
        if index == s:last_line
            return
        endif
        let s:last_line = index

        let item = s:worklist[index]
        if !empty(get(item, 'note', ''))
            let notewinid = popup_atcursor(item.note, {
                        \   'border': [1, 1, 1, 1],
                        \   'borderchars': [' '],
                        \   'moved': [index + 1, 0, 999],
                        \ })
        endif
    endif
endfunction

" Remove the current item from the worklist
function! WorklistRemove()
    if &filetype != 'qf'
        echohl Error | echo 'Can only remove worklist items in the quickfix window!' | echohl None
        return
    elseif getqflist({'title': 1}).title != 'worklist'
        echohl Error | echo 'The current quickfix window is not the worklist!' | echohl None
        return
    endif
    let item = line('.') - 1
    call remove(s:worklist, item)
    call WorklistShowQf('r')
    execute string(item)
endfunction

" Compares two worklist items. Used for sorting.
function! WorklistSort_cmpfunc(left, right)
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
function! WorklistSort()
    call sort(s:worklist, 'WorklistSort_cmpfunc')
    call WorklistUpdateIfCurrent()
endfunction

" If the worklist is the current quickfix list, update it.
function! WorklistUpdateIfCurrent()
    if getqflist({'title': 1}).title == 'worklist'
        call WorklistUpdate('r')
    endif
endfunction

" Get the full worklist file path
function! WorklistFile()
    return g:worklist_dir .. '/' .. g:worklist_file
endfunction

" Save the worklist
function! WorklistSave()
    let dest = WorklistFile()
    let data = json_encode(s:worklist)
    call writefile([data], dest)
endfunction

" Load the worklist
function! WorklistLoad(silent = v:false)
    let dest = WorklistFile()
    if filereadable(dest)
        let data = json_decode(readfile(dest)[0])
        let s:worklist = data
    elseif !a:silent
        echohl Error | echo 'No worklist file has been saved yet, unable to load.' | echohl None
    endif
    call WorklistUpdateIfCurrent()
endfunction

" autosave and autoload
if g:worklist_persist
    augroup worklist_persist_autocmds
        autocmd!
        autocmd VimEnter * call WorklistLoad(v:true)
        autocmd VimLeave * call WorklistSave()
    augroup END
endif

function! WorklistStartPopupAutocmds()
    if &filetype != 'qf'
        return
    endif
    augroup worklist_popup_autocmds
        autocmd!
        autocmd CursorMoved <buffer> call WorklistShowNotePopup()
    augroup END
endfunction

augroup worklist_window_autocmds
    autocmd!
    autocmd FileType qf call WorklistStartPopupAutocmds()
augroup END

" Define ex commands for the primary functions
command! WorklistAdd    call WorklistAdd()
command! WorklistLoad   call WorklistLoad()
command! WorklistNote   call WorklistNote
command! WorklistRemove call WorklistRemove()
command! WorklistSave   call WorklistSave()
command! WorklistSort   call WorklistSort()
command! WorklistToggle call WorklistToggle()
