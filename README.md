# worklist.vim


Allows you to easily keep track of a todo list in the form of lines in the code
that you wish to return to, stored in a quickfix list. Instead of leaving a
TODO comment or jumping to a TODO file and trying to explain the context,
simply add the line to the worklist and don't let yourself complete your
current task until all items in the worklist have been handled. Let the line
itself speak to the context of the item, or add a note to the item in the
worklist.

## Installation

Similar to any other vim plugin, use your preferred method. If you're new,
check out:

[vim-pathogen](https://github.com/tpope/vim-pathogen#readme) or
[vim-plug](https://github.com/junegunn/vim-plug) or
[:help packages](https://vimhelp.org/repeat.txt.html#packages)

## Features

- Easily add/remove lines to the list using `:WorklistAdd` and `:WorklistRemove`.
  No need to enter a TODO comment or switch to another file.
- Mark entries as "completed" using `:WorklistToggle` and they will be skipped
  by the `:cn` and `:cp` family of commands.
    - Allows you to easily keep a record of what you've done and what's still
      left to do.
- Add a note to an entry using `:WorklistNote` and it will be shown in a popup
  when browsing the list in the quickfix window.
- Easily add the worklist after your current position in the quickfix stack and
  show it using `:WorklistShow`.
- The worklist will be updated even if it isn't the current quickfix list being
  shown, allowing you to move on to other quickfix lists then use the
  `:chistory`, `:cnewer`, and `:colder` family of commands to jump back to the
  worklist.
    - Alternatively, can just use `:WorklistShow` again.
- Save and load your worklist using `:WorklistSave` and `:WorklistLoad`.
    - Easily keep a different worklist e.g. for each git branch.

## Usage

See `doc/worklist.txt` (or `:help worklist` from vim after installing) for
commands and configuration.

## Demo

Here's an asciicast which briefly demos some of the functionality provided by
this plugin:

[![asciicast](https://asciinema.org/a/Z0iu59cdsqpTmGOGGtIoeluJa.svg)](https://asciinema.org/a/Z0iu59cdsqpTmGOGGtIoeluJa)
