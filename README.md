# worklist.vim


Allows you to easily keep track of a todo list in the form of lines in the code
that you wish to return to. Instead of leaving a TODO comment or jumping to a
TODO file and trying to explain the context, simply add the line to the
worklist and don't let yourself complete your current task until all items in
the worklist have been handled. Let the line itself speak to the context of the
item, or add a note to the item in the worklist.

## Installation

Similar to any other vim plugin, use your preferred method. If you're new,
check out:

[vim-pathogen](https://github.com/tpope/vim-pathogen#readme) or
[vim-plug](https://github.com/junegunn/vim-plug) or
[:help packages](https://vimhelp.org/repeat.txt.html#packages)

## Commands

`:WorklistAdd`
    To be called from a source window, _not_ the worklist. Adds the current
    source line under the cursor to the worklist.

`:WorklistLoad`
    Loads the worklist that is saved at `g:worklist_dir/g:worklist_file`

`:WorklistSave`
    Saves a worklist at `g:worklist_dir/g:worklist_file`

`:WorklistSort`
    Sorts the worklist by absolute path and line number.

`:WorklistToggle`
    To be called while in the quickfix window and it is showing the worklist.
    Toggles the "completion" state of the worklist item under the cursor.
    Completed items will be skipped over when using quickfix navigation
    commands such as `:cnext` and `:cprev`.

`:WorklistNote`
    To be called while in the quickfix window and it is showing the worklist.
    Opens a prompt which lets you add a note to clarify the current worklist
    item. Notes for the current item will be shown in a popup window when in
    the worklist.

`:WorklistRemove`
    To be called while in the quickfix window and it is showing the worklist.
    Removes the current item from the worklist.


# Configuration

The text that is shown to indicate an incomplete item can be defined with
`g:worklist_incomplete_text` (default: `'[ ]'`):

    `let g:worklist_incomplete_text = '○'`

The text that is shown to indicate a complete item can be defined with
`g:worklist_complete_text` (default: `'[X]'`):

    `let g:worklist_complete_text = '☻'`

The directory where a worklist file given by `worklist-file` will be saved can
be defined with `g:worklist_dir` (default: `$HOME .. '/.vim'`):

    `let g:worklist_dir = $HOME .. '/.config/vim'`

The name of the worklist file to use when saving/loading from `worklist-dir`
can be defined with `g:worklist_file` (default: `'.worklist.json'`):

    `let g:worklist_file = '.my-other-worklist.json'`

The worklist at `g:worklist_dir/g:worklist_file` is autoloaded and autosaved
by default when entering and leaving vim. To disable this functionality, set
`g:worklist_persist` to `v:false` (default: `v:true`):

    `let g:worklist_persist = v:false`
