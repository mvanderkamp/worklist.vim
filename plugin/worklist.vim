" Vim global plugin that provides a quickfix todo list based on source lines.
" Maintainer: Michael van der Kamp
" License: Same as vim

if exists('g:loaded_worklist') || &compatible || v:version < 800
    finish
endif
let g:loaded_worklist = 1


" Prepare options. See doc for explanation. There's unfortunately no
" satisfactory documentation generator for vim that I have found.
let g:worklist_autoload        = get(g:, 'worklist_autoload',        v:true)
let g:worklist_autosave        = get(g:, 'worklist_autosave',        v:true)
let g:worklist_incomplete_text = get(g:, 'worklist_incomplete_text', '[ ]')
let g:worklist_complete_text   = get(g:, 'worklist_complete_text',   '[X]')
let g:worklist_dir             = get(g:, 'worklist_dir',             '')
let g:worklist_file            = get(g:, 'worklist_file',            'worklist.json')
let g:worklist_popup_maxwidth  = get(g:, 'worklist_popup_maxwidth',  60)
let g:worklist_qf_maxheight    = get(g:, 'worklist_qf_maxheight',    10)


if g:worklist_dir == ''
    " Find the first directory in runtimepath that exists and use that. Bit of
    " a hack.
    for entry in split(&runtimepath, ',')
        if isdirectory(entry)
            let g:worklist_dir = entry
            echo 'Saving worklist files to ' .. entry
            break
        endif
    endfor
endif

" This is the list of quickfix items which defines the 'worklist'
let s:worklist = []

" Keep track of which quickfix list is used for the most recent worklist, so
" we can keep it up to date.
let s:worklist_id = -1

" Track the entry in the worklist that is currently selected
let s:last_idx = 0

" Window ID of the note popup window
let s:notewinid = -1


function! s:EchoError(msg) abort
    echohl Error
    echo a:msg
    echohl None
endfunction


function! s:InQuickfix() abort
    return &filetype ==? 'qf'
endfunction


function! s:IsCurrentQuickfix() abort
    return stridx(getqflist({'title': 1}).title, 'worklist') == 0
endfunction


""
" Checks whether the current file and line number already has an entry in the
" worklist.
""
function! s:EntryIndex(filename, lnum, text) abort
    let index = 0
    for entry in s:worklist
        if entry.filename == a:filename
                    \ && entry.lnum == a:lnum
                    \ && entry.text == a:text
            " ugh
            return index
        endif
        let index += 1
    endfor
    return -1
endfunction


" Add the current file and line number as a worklist item
function! s:Add(note='') abort
    if s:InQuickfix()
        call s:EchoError('Unable to add quickfix entries to the worklist.')
        return
    endif
    let lnum = line('.')
    let filename = expand('%:p')
    let text = trim(getline(lnum))
    let index = s:EntryIndex(filename, lnum, text)
    let what = {
        \   'filename': filename,
        \   'lnum': lnum,
        \   'text': text,
        \   'valid': v:true,
        \ }

    " Only update the note if one was provided
    if ! empty(trim(a:note))
        let what.note = a:note
    endif

    if index < 0
        call add(s:worklist, what)
        let index = len(s:worklist) - 1
        echo 'Worklist entry added'
    else
        call extend(s:worklist[index], what, 'force')
        echo 'Worklist entry updated'
    endif

    call s:Update('r', index + 1)
    return index
endfunction


" Used to provide the custom formatting for the worklist items
function! s:QfTextFunc(info) abort
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
function! s:ShowQf() abort
    call s:Update(' ')
    let l:height = min([g:worklist_qf_maxheight, len(s:worklist)])
    if l:height > 0
        execute 'copen ' .. l:height
        call s:ShowNotePopup(v:true)
    else
        call s:EchoError('Worklist is empty')
    endif
endfunction


" Only update the worklist, don't force it to be visible
function! s:Update(action='r', idx='') abort
    let title = 'worklist: ' .. s:File(g:worklist_file)

    if s:worklist_id == -1
        " The worklist has not yet been loaded into a quickfix list, need to
        " do so. The ' ' action accomplishes this.
        let l:action = ' '
    elseif a:action == ' ' && getqflist({'title': 0}).title == title
        let l:action = 'r'
    else
        " The worklist exists in a quickfix list, so 'r' and 'a' actions are
        " acceptable, as well as the ' ' action.
        let l:action = a:action
    endif

    let what = {
        \   'title': title,
        \   'context': title,
        \   'items': s:worklist,
        \   'quickfixtextfunc': function('<SID>QfTextFunc'),
        \ }

    if s:worklist_id != -1
        let what.idx = get(getqflist({'id': s:worklist_id, 'idx': 0}), 'idx', 0)
    endif

    if ! empty(a:idx)
        let what.idx = a:idx
    endif

    if action == ' '
        call setqflist([], l:action, what)
        let s:worklist_id = getqflist({'id': 0}).id
    else
        let what.id = s:worklist_id
        call setqflist([], l:action, what)
    endif
endfunction


" Toggle whether the current item in the worklist is 'completed'
function! s:Toggle() abort
    if !s:InQuickfix()
        call s:EchoError('Can only complete worklist items in the quickfix window!')
        return
    elseif !s:IsCurrentQuickfix()
        call s:EchoError('The current quickfix window is not the worklist!')
        return
    endif

    let index = line('.') - 1
    if index >= len(s:worklist)
        return
    endif

    let s:worklist[index].valid = !s:worklist[index].valid
    call s:Update('r', index + 1)
endfunction


" Add a note to this worklist item
"
" note: note to save for the current worklist item. If empty, prompt for one.
function! s:Note(note='') abort
    if !s:InQuickfix()
        let index = s:Add()
    else
        if !s:IsCurrentQuickfix()
            call s:EchoError('The current quickfix window is not the worklist!')
            return
        endif
        let index = line('.') - 1
    endif

    if index >= len(s:worklist)
        return
    endif

    if empty(a:note)
        call inputsave()
        echohl Question
        let s:worklist[index].note = input('Set worklist note: ',
                    \ get(s:worklist[index], 'note', ''))
        echohl None
        call inputrestore()
    else
        let s:worklist[index].note = a:note
    endif

    call s:Update('r', index + 1)

    if s:InQuickfix()
        call s:ShowNotePopup(v:true)
    endif
endfunction


" Show a popup with the note for the current worklist item
function! s:ShowNotePopup(force=v:false) abort
    if s:IsCurrentQuickfix()
        let index = line('.') - 1
        if index >= len(s:worklist) || (index == s:last_idx && !a:force)
            return
        endif
        let s:last_idx = index
        call s:CloseNotePopup()

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
function! s:CloseNotePopup() abort
    call popup_close(s:notewinid)
endfunction


" Remove the current item from the worklist
function! s:Remove() abort
    if !s:InQuickfix()
        call s:EchoError('Can only remove worklist items in the quickfix window!')
        return
    elseif !s:IsCurrentQuickfix()
        call s:EchoError('The current quickfix window is not the worklist!')
        return
    endif

    let index = line('.') - 1
    if index >= len(s:worklist)
        return
    endif

    call remove(s:worklist, index)
    call s:Update('r', index)
endfunction


" Compares two worklist items. Used for sorting.
function! s:Sort_cmpfunc(left, right) abort
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
function! s:Sort() abort
    call sort(s:worklist, '<SID>Sort_cmpfunc')
    call s:Update('r', 1)
endfunction


" Get the full worklist file path
function! s:File(filename) abort
    return g:worklist_dir .. '/' .. a:filename
endfunction


" Save the worklist
function! s:Save(filename=g:worklist_file) abort
    if empty(a:filename)
        let l:filename = g:worklist_file
    else
        let l:filename = a:filename
    endif
    let g:worklist_file = l:filename
    let dest = s:File(l:filename)
    let data = json_encode(s:worklist)
    call writefile([data], dest)
endfunction


" Load the worklist
function! s:Load(filename=g:worklist_file) abort
    if empty(a:filename)
        let l:filename = g:worklist_file
    else
        let l:filename = a:filename
    endif
    if g:worklist_autosave && g:worklist_file != l:filename
        call s:Save()
    endif
    let g:worklist_file = l:filename
    let dest = s:File(l:filename)
    if filereadable(dest)
        let data = json_decode(readfile(dest)[0])
        let s:worklist = data
    else
        call s:EchoError('No worklist file has been saved yet, unable to load.')
        let s:worklist = []
    endif
    call s:Update(' ', 1)
endfunction


" autoload
if g:worklist_autoload
    augroup worklist_autoload_autocmds
        autocmd!
        autocmd VimEnter * call s:Load()
    augroup END
endif


" autosave
if g:worklist_autosave
    augroup worklist_autosave_autocmds
        autocmd!
        autocmd VimLeave * call s:Save()
    augroup END
endif


function! s:StartPopupAutocmds() abort
    if getqflist({'winid': 0}).winid != win_getid()
        return
    endif
    augroup worklist_popup_autocmds
        autocmd!
        autocmd CursorMoved <buffer> call s:ShowNotePopup()
        autocmd BufEnter <buffer> call s:ShowNotePopup(v:true)
        autocmd BufLeave <buffer> call s:CloseNotePopup()
    augroup END
endfunction


augroup worklist_window_autocmds
    autocmd!
    autocmd FileType qf call s:StartPopupAutocmds()
augroup END


" Define ex commands for the primary functions
command! -nargs=* WorklistAdd call <SID>Add("<args>")
command! -nargs=? WorklistLoad call <SID>Load("<args>")
command! -nargs=* WorklistNote call <SID>Note("<args>")
command! WorklistRemove call <SID>Remove()
command! -nargs=? WorklistSave call <SID>Save("<args>")
command! WorklistSort call <SID>Sort()
command! WorklistToggle call <SID>Toggle()
command! WorklistShow call <SID>ShowQf()
