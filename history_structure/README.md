# Nushell History Structure

This directory contains documentation and examples of Nushell's history database structure.

## History Database Schema

Nushell stores command history in a SQLite database. Each history entry contains the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `id` | Integer | Unique identifier for the history entry |
| `command_line` | String | The complete command that was executed |
| `start_timestamp` | Integer | Unix timestamp (milliseconds) when command started |
| `session_id` | Integer | Unique identifier for the shell session |
| `hostname` | String | Machine hostname where command was executed |
| `cwd` | String | Current working directory when command was run |
| `duration_ms` | Integer | Command execution time in milliseconds |
| `exit_status` | Integer | Exit code (0 = success, non-zero = error) |
| `more_info` | String/Null | Additional metadata (typically null) |

## Example History Entries

See `history_structure.json` for sample history entries showing the actual data structure.

## Usage for Completion System

For our history-based completion system, the most relevant fields are:

- **`command_line`**: The raw command to parse for extracting arguments and flags
- **`cwd`**: Context for path-based completions
- **`start_timestamp`**: For recency-based prioritization
- **`exit_status`**: To favor successful commands over failed ones
- **`duration_ms`**: Could be used to deprioritize slow commands

The `command_line` field will be parsed using Nushell's AST to extract:
- Command names
- Flag names and values
- Positional arguments
- Variable assignments
- Pipeline structures

## Data Access

History can be accessed via:
```nu
open $nu.history-path | query db 'select * from history limit 10'
```

Note: The history database is SQLite format, not directly readable as JSON.