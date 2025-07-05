# History-Based Command Completion for Nushell

## Overview
A custom keybinding that triggers completions from your entire command history—suggesting arguments, paths, and values you've used before, regardless of which command they were used with.

## Key Difference from Existing Solutions
Unlike Carapace which shows all possible flags, this system only suggests options I've actually used. More importantly, it intelligently shares values across commands:
- **Paths and values** are command-agnostic and suggested everywhere
- **Flags and named parameters** are command-specific to avoid invalid suggestions

## Implementation

### Smart Suggestion Logic
The keybinding distinguishes between:
1. **Universal values** (paths, IPs, URLs, strings) - suggested across all commands
2. **Command-specific syntax** (flags, named parameters) - only suggested for their original command

This prevents suggesting `--verbose` from `ls` when typing `git`, while still allowing `/home/user/project` to be suggested anywhere.

### Database Structure
- Hook on each command execution parses and stores components
- Separate SQLite table stores arguments with context:
  - `history_item_id` (foreign key to existing history)
  - `command_name` (used for filtering flags/params, ignored for values)
  - `flag` (switches) (e.g., "--all", "-v")
  - `parameter_name` (named parameters) (e.g., "--output", "--age")
  - `parameter_value` (values for named parameters) (e.g., "filename", "25")
  - `positional_arg` (positional arguments) (e.g., "arg1", "arg2")
  - `arg_position` (1, 2, 3...)
  - `arg_type` (leverages Nushell's type system: path, int, string, etc.)

### Type-Aware Completions
The system can leverage Nushell's command signatures:
- Query command signatures to understand expected types at each position
- Match historical values by type (only suggest paths where paths are expected)
- Validate suggestions against command signatures before displaying

### Completion Menu
- Custom keybinding triggers intelligent queries:
  - For flags/parameters: filters by current command
  - For values: searches across entire history
- Integrates with Nushell's type system for smart filtering
- Prioritizes based on:
  - Type compatibility (from command signatures)
  - Recency of use
  - Frequency of use
  - Position in command

### What Gets Tracked Globally
- All paths ever typed (from `cp`, `mv`, `ls`, `cd`, etc.)
- All flags and their values across all commands
- All positional arguments from any command
- Common values like IP addresses, URLs, file patterns

## Use Cases

### Cross-Command Path Reuse
The main power: reuse arguments from ANY previous command:
```
cp ~/documents/report.pdf ~/backup/
# Later with a different command:
mv ~/<keybinding>  # Suggests: ~/documents/report.pdf
rm ~/<keybinding>  # Also suggests: ~/backup/
```

### Universal Value Suggestions
Values used anywhere become available everywhere:
```
ssh user@192.168.1.100
# Later:
ping <keybinding>  # Suggests: 192.168.1.100
curl http://<keybinding>  # Suggests: 192.168.1.100
```

### Pattern Recognition Across Commands
```
git checkout feature/new-api
# Later:
git branch -d <keybinding>  # Suggests: feature/new-api
# But also:
echo "Working on <keybinding>"  # Also suggests: feature/new-api
```

The system doesn't limit suggestions to command-specific history—it treats your entire command history as a pool of reusable values.

## Development Resources

### Parser Test Cases (`parser_test_cases/`)
This directory contains test commands and their corresponding AST outputs for developing the command parser:

- **Complex pipeline example**: `complex_pipeline.nu` demonstrates a sophisticated command with variable assignment, subexpressions, flags, closures, and pipelines
- **AST outputs**: Both regular and flattened AST formats are provided
  - `complex_pipeline_ast.json` - Standard nested AST structure
  - `complex_pipeline_ast_flattened.json` - Simplified linear token array (preferred for parsing)
- **Generation command**: `ast --flatten --json (open <test_name>.nu) | save <test_name>_ast_flattened.json --force --raw`

The flattened AST format provides clean token arrays with `content`, `shape`, and `span` fields, making it easier to extract:
- Commands (`shape_internalcall`)
- Flags (`shape_flag`) 
- String/numeric values (`shape_string`, `shape_int`)
- Variables (`shape_variable`)
- Pipeline structure (`shape_pipe`)

### History Structure (`history_structure/`)
Documentation and examples of Nushell's history database structure:

- **SQLite schema**: Complete field descriptions for the history table
- **Sample data**: `history_structure.json` with real history entries
- **Access patterns**: How to query the history database for parsing

Key fields for completion system:
- `command_line`: Raw command text to parse with AST
- `start_timestamp`: For recency-based ranking
- `exit_status`: Filter successful vs failed commands
- `cwd`: Context for path-based suggestions
