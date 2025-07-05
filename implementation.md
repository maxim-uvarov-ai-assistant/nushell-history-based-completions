# Implementation Plan: Nushell History-Based Completions

## Overview

This document outlines the implementation approach for building a history-based completion system for Nushell using AST parsing and SQLite history analysis.

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
- Tables:
  - `commands`: Command usage frequency
  - `flags`: Flag usage per command
  - `arguments`: Positional arguments per command
  - `contexts`: Path/context associations

#### Phase 3: Completion Engine
- Query completion database based on current context
- Rank suggestions by:
  - Recency (`start_timestamp`)
  - Frequency (usage count)
  - Success rate (`exit_status`)
  - Context relevance (`cwd`)

#### Phase 4: Nushell Integration
- Custom completion hook
- Keybinding integration
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

**Completion Data**:
- `ls` often used with `--all` flag
- `ls` often followed by `each` in pipelines
- `/tmp` is a common path argument for `ls`
- `first` commonly takes numeric arguments

## Success Metrics

1. **Accuracy**: Relevant suggestions for current context
2. **Speed**: Sub-100ms completion generation
3. **Learning**: Improves with usage over time
4. **Context**: Adapts to current directory and command pattern

## Technical Considerations

### Performance
- Cache parsed AST results
- Incremental history processing
- Efficient SQL queries with proper indexing

### Accuracy
- Handle command aliases and custom commands
- Context-aware filtering (file paths, command compatibility)
- Type-aware suggestions based on command signatures

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