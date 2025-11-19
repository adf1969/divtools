# Log Message Parsing Implementation

## Summary

Updated both `log_msg()` in `.bash_profile` and `log()` in `logging.sh` to support advanced parsing syntax similar to existing script implementations. The functions now support modifiers for controlling output formatting.

## Supported Syntax

Both `log_msg()` and `log()` now support:

```bash
log_msg "SECTION" "message"           # Basic usage
log_msg "SECTION:TAG" "message"       # Custom color tag
log_msg "SECTION:!ts" "message"       # Suppress timestamp/tag (for .bash_profile)
log_msg "SECTION:raw" "message"       # Raw output (no tag, no formatting)
```

## Examples

### Basic Usage
```bash
log_msg "INFO" "Starting initialization"
log_msg "ERROR" "An error occurred"
```

### Custom Color Tags
```bash
log_msg "INFO:cyan" "This message uses cyan"
log_msg "STAR:green" "This message uses green"
log_msg "ERROR:red" "Error in red"
```

### Suppress Timestamp/Tag
The `!ts` modifier removes the section tag (useful in `.bash_profile` where output is already controlled):
```bash
log_msg "INFO:!ts" "Just the message content"
```

### Raw Output
The `raw` modifier outputs only the message text, no formatting:
```bash
log_msg "ERROR:raw" "Just the raw message"
```

## Implementation Details

### Parsing Logic
Both functions parse the section string by splitting on `:`:
```bash
"SECTION" → Uses SECTION color, includes tag
"SECTION:cyan" → Uses cyan color, includes tag
"SECTION:!ts" → Uses SECTION color, suppresses tag
"SECTION:raw" → Raw output only
```

### Color Support
- Built-in section colors (STAR, SAMBA, TMUX, INFO, ERROR, etc.)
- Custom color tags can override the section color
- Fallback to color_map for named colors
- Case-insensitive color names

### Verbosity Integration
The `.bash_profile` version respects `DT_VERBOSE` and `DT_VERBOSITY_LEVELS`:
- Messages only output if `DT_VERBOSE >= section_threshold`
- The logging.sh fallback doesn't enforce verbosity (respects `DEBUG_MODE` only)

## Cross-Compatibility

The implementations are kept in sync through:

1. **Primary**: `/home/divix/divtools/dotfiles/.bash_profile` (log_msg)
   - Used by default in interactive shells
   - Supports full verbosity control
   - Supports parsing modifiers

2. **Fallback**: `/home/divix/divtools/scripts/util/logging.sh` (log)
   - Used by scripts when .bash_profile not sourced
   - Provides same parsing functionality
   - Used as fallback by logging.sh wrapper

### Maintenance Notes
When adding new sections or colors:
1. Update the color case statement in BOTH functions
2. Update the color_map in BOTH files
3. Add new section to `DT_VERBOSITY_LEVELS` in `.bash_profile`
4. Update the section comments noting the sync point

## Testing

Both implementations tested and confirmed working:

✅ Basic usage with section tags
✅ Custom color tags
✅ Timestamp suppression (!ts)
✅ Raw output (raw modifier)
✅ Case-insensitive colors
✅ Fallback from logging.sh when .bash_profile not sourced
✅ Primary implementation from .bash_profile when sourced
✅ Verbosity filtering in .bash_profile version

## Usage in Scripts

Scripts can now use the enhanced syntax:

```bash
source $DIVTOOLS/scripts/util/logging.sh

# These all work with the same syntax now:
log_msg "INFO" "Basic message"
log_msg "INFO:!ts" "No timestamp"
log_msg "ERROR:raw" "Raw error"
```

The script will automatically use:
- `.bash_profile`'s `log_msg()` if the profile is already sourced
- `logging.sh`'s `log()` fallback if not sourced

Both support the same parsing syntax for consistency.
