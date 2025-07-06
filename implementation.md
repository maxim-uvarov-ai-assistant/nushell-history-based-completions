# Implementation Plan: Nushell History-Based Completions

## Overview

This document outlines the implementation approach for building a history-based completion system for Nushell that provides intelligent completions from your entire command history. The system distinguishes between universal values (paths, IPs, strings) that can be suggested across all commands and command-specific syntax (flags, parameters) that are only suggested for their original command.

## Key Technical Insights

### 1. AST Parsing Strategy

**Use Flattened AST Format**:
- Command: `ast --flatten --json (open command.nu)`
- Output: Clean array of tokens with `content`, `shape`, and `span` fields
- Much easier to parse than nested AST structure

**Token Types for Completion**:
- `shape_internalcall`: Commands (`ls`, `git`, `path join`)
- `shape_flag`: Flags (`--all`, `--theme`)
- `shape_string`: String arguments and flag values
- `shape_int`: Numeric arguments
- `shape_variable`: Variable references (`$i`)
- `shape_pipe`: Pipeline separators (`|`)

### 2. History Database Structure

**SQLite Schema** (from `$nu.history-path`):
```sql
CREATE TABLE history (
    id INTEGER PRIMARY KEY,
    command_line TEXT,           -- Raw command to parse
    start_timestamp INTEGER,     -- For recency weighting
    session_id INTEGER,
    hostname TEXT,
    cwd TEXT,                    -- Context for path completions
    duration_ms INTEGER,         -- Performance weighting
    exit_status INTEGER,         -- Success filtering
    more_info TEXT
);
```

**Data Access**:
```nu
open $nu.history-path | query db 'select * from history limit 100'
```

### 3. Implementation Architecture

#### Phase 1: AST Parser
- Parse `command_line` using `ast --flatten --json`
- Extract command sequences and arguments
- Build structured representation of command usage

#### Phase 2: Completion Database
- SQLite database for storing parsed completions
- Core table structure (matching README.md specification):
  - `history_item_id` (foreign key to existing history)
  - `command_name` (used for filtering flags/params, ignored for values)
  - `flag` (switches like "--all", "-v")
  - `parameter_name` (named parameters like "--output", "--age")
  - `parameter_value` (values for named parameters)
  - `positional_arg` (positional arguments)
  - `arg_position` (1, 2, 3...)
  - `arg_type` (leverages Nushell's type system: path, int, string, etc.)

#### Phase 3: Completion Engine
- Smart suggestion logic:
  - **Universal values** (paths, IPs, URLs, strings) - suggested across all commands
  - **Command-specific syntax** (flags, named parameters) - only suggested for their original command
- Query completion database based on current context
- Rank suggestions by:
  - Type compatibility (from command signatures)
  - Recency (`start_timestamp`)
  - Frequency (usage count)
  - Success rate (`exit_status`)
  - Position in command
  - Context relevance (`cwd`)

#### Phase 4: Nushell Integration
- Custom keybinding that triggers intelligent queries:
  - For flags/parameters: filters by current command
  - For values: searches across entire history
- Hook on each command execution parses and stores components
- Integrates with Nushell's type system for smart filtering
- Real-time history parsing

## Data Flow

```
History DB → AST Parser → Completion DB → Completion Engine → Nushell
    ↑                                                              ↓
    └─────────────── New Commands ←─────────────────────────────────
```

## Example Parsing

**Input Command**:
```nu
ls /tmp --all | each {|i| $i.name} | first 5
```

**Flattened AST Extraction**:
- Command: `ls`
- Arguments: `/tmp`
- Flags: `--all`
- Pipeline: `each`, `first`
- Sub-arguments: `5`

**Completion Data Stored**:
- `ls` with flag `--all` (command-specific)
- Path `/tmp` (universal value - available for any command)
- `first` with positional argument `5` (command-specific)
- `each` with closure pattern (command-specific)

**Cross-Command Reuse**:
- `/tmp` path becomes available for: `cp`, `mv`, `cd`, `rm`, etc.
- `--all` flag only suggested for `ls` command
- `5` numeric value available for any command expecting integers

## Success Metrics

1. **Cross-Command Value Reuse**: Paths and values from any command available everywhere
2. **Command-Specific Accuracy**: Flags only suggested for their original commands
3. **Type-Aware Filtering**: Only suggest values compatible with expected types
4. **Speed**: Sub-100ms completion generation
5. **Learning**: Improves with usage over time
6. **Context**: Adapts to current directory and command pattern

## Technical Considerations

### Performance
- Cache parsed AST results
- Incremental history processing
- Efficient SQL queries with proper indexing

### Accuracy
- Handle command aliases and custom commands
- Context-aware filtering (file paths, command compatibility)
- Type-aware suggestions based on command signatures
- Smart distinction between universal values and command-specific syntax
- Prevent invalid cross-command flag suggestions

### User Experience
- Non-intrusive integration
- Configurable completion behavior
- Fallback to standard completions when needed

## Testing Strategy

Use `parser_test_cases/` directory:
- Complex pipeline examples
- AST output verification
- Completion accuracy testing
- Performance benchmarking

## Future Enhancements

1. **Cross-session learning**: Share completions across shell sessions
2. **Command prediction**: Suggest next commands in common workflows
3. **Error learning**: Avoid suggesting patterns that frequently fail
4. **Contextual awareness**: Project-specific completions based on directory
5. **Export/import**: Share completion databases between machines