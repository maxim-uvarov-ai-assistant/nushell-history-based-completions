I would like to be able to create a keybinding, that will raise a list of context aware (or context agnostic) completions, based on my history.

So it would know, which arguments I used recently, which flags, which options and their params. 

On each command in the repl, there will be triggered a hook, that will parse command, and populate the table in sqlite history database. 

During the entering of the next command, when keybinding is pressed, it will trigger a custom menu with list of suggested ordered completions.
