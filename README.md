# History-Based Command Completion for Nushell

## Overview
A custom keybinding that triggers completions from your entire command history—suggesting arguments, paths, and values you've used before, regardless of which command they were used with.

## Key Difference from Existing Solutions
Unlike Carapace which shows all possible flags, this system only suggests options I've actually used. More importantly, it intelligently shares values across commands:
- **Paths and values** are command-agnostic and suggested everywhere
- **Flags and named parameters** are command-specific to avoid invalid suggestions

## Core Features

### Smart Suggestion Logic
The keybinding distinguishes between:
1. **Universal values** (paths, IPs, URLs, strings) - suggested across all commands
2. **Command-specific syntax** (flags, named parameters) - only suggested for their original command

This prevents suggesting `--verbose` from `ls` when typing `git`, while still allowing `/home/user/project` to be suggested anywhere.

### Storage and Suggestion Strategy

**Two-tier completion system:**

1. **Command-specific suggestions** (flags and named parameters):
   - Only suggest `--verbose` when typing `ls` commands
   - Only suggest `--recursive` when typing `cp` commands
   - Prevents invalid flag suggestions

2. **Universal value suggestions** (all argument values):
   - ALL values (paths, URLs, IPs, strings) are suggested globally
   - This includes values that were originally used with flags
   - Example: If you used `curl --output report.pdf`, then `report.pdf` is available everywhere

**Query logic:**
```nu
# For flag/param suggestions:
$arguments | where command_name == $current_command and argument_type in ['flag', 'named_param']

# For value suggestions:
$arguments | where argument_value != null | select argument_value value_type
```

## Implementation Details

### Database Structure
- Hook on each command execution parses and stores components
- SQLite table `command_arguments` stores one record per argument:
  - `id` (primary key)
  - `history_item_id` (foreign key to existing history)
  - `command_name` (the command that was executed)
  - `argument_type` (one of: 'flag', 'named_param', 'positional')
  - `argument_name` (flag or parameter name, e.g., "--verbose", "-o")
  - `argument_value` (the value, NULL for flags without values)
  - `position` (argument position in command: 1, 2, 3...)
  - `value_type` (Nushell's type system: path, int, string, etc.)
  - `created_at` (timestamp for tracking)

Examples of how commands are stored:

1. `git add file1 file2` → 2 records:
   ```nu
   [
     {argument_type: "positional", argument_value: "file1", position: 1, command_name: "git", value_type: "string"}
     {argument_type: "positional", argument_value: "file2", position: 2, command_name: "git", value_type: "string"}
   ]
   ```

2. `ls -la /home` → 2 records:
   ```nu
   [
     {argument_type: "flag", argument_name: "-la", argument_value: null, position: 1, command_name: "ls"}
     {argument_type: "positional", argument_value: "/home", position: 2, command_name: "ls", value_type: "path"}
   ]
   ```

3. `cp --recursive src/ dest/` → 3 records:
   ```nu
   [
     {argument_type: "flag", argument_name: "--recursive", argument_value: null, position: 1, command_name: "cp"}
     {argument_type: "positional", argument_value: "src/", position: 2, command_name: "cp", value_type: "path"}
     {argument_type: "positional", argument_value: "dest/", position: 3, command_name: "cp", value_type: "path"}
   ]
   ```

4. `curl --output file.txt --max-time 30 https://example.com` → 3 records:
   ```nu
   [
     {argument_type: "named_param", argument_name: "--output", argument_value: "file.txt", position: 1, command_name: "curl", value_type: "string"}
     {argument_type: "named_param", argument_name: "--max-time", argument_value: "30", position: 2, command_name: "curl", value_type: "int"}
     {argument_type: "positional", argument_value: "https://example.com", position: 3, command_name: "curl", value_type: "string"}
   ]
   ```

5. Complex pipeline example - `ls | grep foo | head -n 5` → 6 records:
   ```nu
   [
     # From 'ls' command
     {argument_type: "command", argument_value: null, position: 0, command_name: "ls"},
     # From 'grep' command
     {argument_type: "command", argument_value: null, position: 0, command_name: "grep"},
     {argument_type: "positional", argument_value: "foo", position: 1, command_name: "grep", value_type: "string"},
     # From 'head' command
     {argument_type: "command", argument_value: null, position: 0, command_name: "head"},
     {argument_type: "named_param", argument_name: "-n", argument_value: "5", position: 1, command_name: "head", value_type: "int"}
   ]
   ```

### Completion Menu
- Uses Nushell's custom menu feature for a dedicated completion interface
- Triggered by `Ctrl+Alt+h` keybinding
- Three-column display: value | type | source command
- Supplements (not replaces) existing completions
- Database location: `$nu.data-dir/history_completions.db`

### Integration with Existing Completers
The system is designed to augment external completion tools like Carapace or argc-completions:
- **External completers** provide comprehensive command-specific completions (all possible flags, subcommands)
- **This system** adds history-based intelligence on top:
  - Filters suggestions to only what you've actually used
  - Adds cross-command value reuse (paths, IPs, URLs used anywhere)
  - Applies usage-based ranking to sort all completions by relevance
- **Combined result**: Complete command awareness with personalized, history-informed suggestions

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
  - `complex_pipeline_ast.json` - Standard nested AST structure (preferred for parsing)
  - `complex_pipeline_ast_flattened.json` - Simplified linear token array
- **Generation command** (for creating test files): `ast --json (open <test_name>.nu) | save <test_name>_ast.json --force --raw`

The non-flattened AST format provides proper command structure:
- Separate `pipelines` array for semicolon-delimited commands
- Subexpressions marked with `Subexpression` type
- Clear command boundaries and argument attribution
- Preserves nested structures like `ls (pwd | path dirname) --all`

Parser approach:
```nu
def parse_history_command [ast: record] {
    # Each pipeline is a separate command (delimited by ; or newline)
    $ast.block.pipelines | each { |pipeline|
        parse_pipeline $pipeline
    }
}
```

#### Handling Complex Command Structures

**Piped commands**: Each pipeline element represents a command in a pipe chain. Commands are connected via pipe elements:
```nu
# Command: ls | grep foo | head -n 5
# AST structure: pipeline.elements contains 3 items, each with a pipe field (except first)
[
  {pipe: null, expr: {Call: {decl_id: 215, arguments: []}}},  # ls
  {pipe: {start: 263178, end: 263179}, expr: {Call: {...}}},  # grep foo
  {pipe: {start: 263212, end: 263213}, expr: {Call: {...}}}   # head -n 5
]
```

**Subexpressions**: Marked with `Subexpression` type in the AST:
```nu
# Command: ls (pwd | path dirname)
# The (pwd | path dirname) part appears as:
{expr: {Subexpression: 2525}}  # References a separate block ID
```

**Environment variables**: Appear as `Var` expressions:
```nu
# Command: echo $HOME
{expr: {Var: varId}}  # Variable reference by ID
```

**Quoted strings with spaces**: Stored as single String values:
```nu
# Command: echo "hello world"
{expr: {String: "hello world"}}  # Preserves spaces as single argument
```

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

## Future Enhancements

### Type System Integration
Future versions may leverage Nushell's type system to:
- Query command signatures to understand expected types at each position
- Match historical values by type (only suggest paths where paths are expected)
- Validate suggestions against command signatures before displaying

**Note:** Type checking is NOT implemented in the first iteration to keep the system simple. All values are suggested based on history alone without type validation.

### Advanced Ranking Algorithm
Future versions will implement a sophisticated scoring system:

```nu
def calculate_score [item: record, context: record] -> float {
    let base_score = 100.0
    
    # Recency boost (0-50 points)
    # Uses exponential decay over days
    let days_old = ((date now) - $item.created_at) / 1day
    let recency_score = 50.0 * (0.9 ** $days_old)
    
    # Frequency boost (0-30 points)
    # Logarithmic scale to prevent overwhelming frequent items
    let frequency_score = if $item.usage_count > 0 {
        30.0 * ((math log $item.usage_count) / (math log 100))
    } else { 0.0 }
    
    # Position match boost (0-20 points)
    # Higher score if used in same argument position
    let position_score = if $item.position == $context.current_position { 20.0 } else { 0.0 }
    
    # Command match boost (for flags only)
    let command_score = if $item.argument_type in ['flag', 'named_param'] {
        if $item.command_name == $context.current_command { 50.0 } else { -100.0 }
    } else { 0.0 }
    
    $base_score + $recency_score + $frequency_score + $position_score + $command_score
}
```

**Planned scoring components:**
- **Type compatibility**: Match suggestions to expected types
- **Context awareness**: Consider current directory and environment
- **Frequency tracking**: Popular arguments score higher (requires `usage_count` column)
- **Position matching**: Boost arguments used in same positions
- **Command success rate**: Prefer arguments from successful commands
- **Smart decay**: Balance recency with frequency

### Ranking Algorithm (v1 Implementation)
Simple recency-based sorting:
- Sort suggestions by `created_at` timestamp (most recent first)
- Limit to top 20-50 results
- This provides a good baseline that's easy to implement and understand

### Performance Optimizations
- Index frequently accessed columns
- Implement caching for common queries
- Periodic cleanup of old/unused entries

### Edge Case Handling

**Failed commands (exit_status != 0):**
- Store ALL commands regardless of exit status
- Failed commands often have valid arguments that are useful in other contexts
- Future enhancement: Add option to filter suggestions by command success rate

**Incomplete/interrupted commands:**
- Skip commands that were interrupted (Ctrl+C) or have no exit_status
- Only parse commands that actually executed to completion
- Prevents partial/malformed commands from polluting suggestions

**Large command histories:**
- Implement a rolling window (e.g., last 10,000 commands) or time-based limit (e.g., last 6 months)
- Set up periodic cleanup job to remove old entries
- Balance between history completeness and database performance

**Performance with large databases:**
- Create indexes on frequently queried columns:
  - `command_name` (for flag filtering)
  - `created_at` (for recency sorting)
  - `argument_value` (for value lookups)
- Limit result sets early in queries (e.g., `LIMIT 50`)
- Consider implementing query result caching for repeated lookups

**Special characters and parsing edge cases:**
- Properly escape SQL queries to handle quotes, spaces, special characters
- Handle empty argument values gracefully (store as NULL)
- Skip unparseable commands with error logging rather than crashing
- Test with complex command structures (aliases, functions, scripts)