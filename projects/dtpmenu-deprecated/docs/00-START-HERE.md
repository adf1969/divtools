# dtpmenu - Documentation Map & Usage Guide

## 🚀 Start Here Based on Your Need

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WHERE TO START?                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  📖 "Show me quick examples"                  → QUICK-REFERENCE.md         │
│                                                                             │
│  🔧 "I'm writing a bash script"              → BASH-INTEGRATION.md        │
│                                                                             │
│  ❓ "Can I capture the user's choice?"       → RETURN-VALUES.md           │
│                                                                             │
│  ⚠️ "My dialog isn't centered!"              → BASH-INTEGRATION.md        │
│                                               (Debugging section)            │
│                                                                             │
│  📚 "What's this project about?"             → README.md or               │
│                                               PROJECT-HISTORY.md            │
│                                                                             │
│  💻 "I want to read the code"                → dtpmenu.py                │
│                                               (300+ line docstring)         │
│                                                                             │
│  🗺️ "Show me the complete map"               → This file!                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Complete Documentation Structure

```
/home/divix/divtools/projects/dtpmenu/
│
├─ 📄 README.md ..................... PROJECT OVERVIEW & QUICK START
│  ├─ Why centering matters (⚠️ warning at top)
│  ├─ Quick start installation
│  ├─ Testing: bash projects/dtpmenu/demo_menu.sh
│  └─ Full reference for all 4 functions with patterns
│
├─ 🐍 dtpmenu.py .................... MAIN APPLICATION (Python)
│  └─ 300+ LINE DOCSTRING (read this!)
│     ├─ Critical integration warnings
│     ├─ Usage for each mode (menu, msgbox, yesno, inputbox)
│     ├─ All command-line flags
│     ├─ Environment setup
│     └─ Real-world examples
│
├─ 🔨 scripts/util/dt_pmenu_lib.sh ... BASH WRAPPER LIBRARY
│  └─ Wrapper functions with detailed comments:
│     ├─ pmenu_menu()
│     ├─ pmenu_msgbox()
│     ├─ pmenu_yesno()
│     └─ pmenu_inputbox()
│     └─ Each with PATTERN examples showing correct usage
│
├─ 📁 docs/ ......................... DETAILED DOCUMENTATION
│  │
│  ├─ 🔴 BASH-INTEGRATION.md (START HERE FOR SCRIPTS!)
│  │  │  200+ lines explaining:
│  │  ├─ TL;DR - Critical rules summary
│  │  ├─ Why command substitution breaks Textual (detailed)
│  │  ├─ Problem vs. solution code
│  │  ├─ 3 integration approach options
│  │  ├─ Working demo_menu.sh patterns
│  │  ├─ Debugging checklist
│  │  └─ Terminal control best practices table
│  │
│  ├─ 🟠 RETURN-VALUES.md (How to capture results)
│  │  │  Comprehensive guide:
│  │  ├─ Quick summary table (can capture what?)
│  │  ├─ Exit codes for all scenarios
│  │  ├─ Mode-specific return behavior
│  │  ├─ Chaining multiple dialogs
│  │  ├─ Real-world examples
│  │  └─ Testing exit codes
│  │
│  ├─ 🟡 QUICK-REFERENCE.md (Copy-paste code)
│  │  │  For busy developers:
│  │  ├─ Basic usage of all modes
│  │  ├─ Environment variables
│  │  ├─ What NOT to do
│  │  ├─ Quick debugging commands
│  │  └─ Installation step
│  │
│  ├─ 🟢 SOLUTION-SUMMARY.md (Why centering was broken)
│  │  │  For understanding the history:
│  │  ├─ Problem statement
│  │  ├─ Root cause analysis
│  │  ├─ Failed attempts (for learning)
│  │  ├─ The fix
│  │  └─ Key learnings
│  │
│  ├─ 🔵 PROJECT-HISTORY.md (Development timeline)
│  │  │  Complete project journey:
│  │  ├─ Centering breakthrough (updated!)
│  │  ├─ Project initialization
│  │  └─ Design decisions
│  │
│  ├─ 📋 DOCUMENTATION-INDEX.md (This complete overview)
│  │
│  └─ 📝 PRD.md (Original product requirements)
│
├─ 📂 demo_menu.sh .................. WORKING EXAMPLE
│  │  Interactive demo showing:
│  ├─ Menu selection
│  ├─ Message boxes
│  ├─ Yes/No dialogs
│  └─ Input boxes
│  │  RUN: bash projects/dtpmenu/demo_menu.sh
│
├─ 📂 test/ ......................... TEST SUITE
│  └─ test_centering_menu.py (reference implementation)
│
└─ 📂 install_dtpmenu_deps.sh ....... INSTALLATION SCRIPT
   │  RUN THIS FIRST:
   └─ bash projects/dtpmenu/install_dtpmenu_deps.sh
```

---

## Common Tasks & Where to Find Help

### "I want to add dtpmenu to my script"
1. **Read:** [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md) TL;DR section
2. **Copy:** Pattern from [QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md)
3. **Reference:** Function comments in `scripts/util/dt_pmenu_lib.sh`

### "I want to check what the user selected"
1. **Read:** [RETURN-VALUES.md](docs/RETURN-VALUES.md) relevant section
2. **Copy:** Example pattern for your mode (menu, yesno, msgbox, inputbox)
3. **Key point:** You CAN check exit codes, but NOT capture selection during execution

### "My menu isn't centered!"
1. **Check:** Did you use `choice=$(pmenu_menu ...)`? That's the problem!
2. **Read:** [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md) "The Problem" section
3. **Fix:** Use direct execution without `$()` or `>`
4. **Verify:** Confirm PMENU_H_CENTER=1 and PMENU_V_CENTER=1 are set

### "I want a quick code example"
→ [QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md) - Everything copy-paste ready

### "I need to understand what's happening"
→ [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md) - Deep dive into how Textual works

### "I want to know if this limitation is real"
→ [SOLUTION-SUMMARY.md](docs/SOLUTION-SUMMARY.md) - How the problem was solved

### "I'm confused about exit codes"
→ [RETURN-VALUES.md](docs/RETURN-VALUES.md) - Complete reference with examples

---

## The Most Important Rules

### Rule #1: NO Command Substitution During Execution
```bash
❌ WRONG - Breaks centering
choice=$(pmenu_menu "Title" "a" "Apple" "b" "Banana")

✅ CORRECT - Direct execution
pmenu_menu "Title" "a" "Apple" "b" "Banana"
```

### Rule #2: NO Output Redirection During Execution
```bash
❌ WRONG - Breaks centering
pmenu_menu "Title" "a" "Apple" > /tmp/result.txt

✅ CORRECT - Direct execution
pmenu_menu "Title" "a" "Apple"
```

### Rule #3: YES, You Can Check Exit Codes
```bash
pmenu_yesno "Confirm" "Delete?"
if [[ $? -eq 0 ]]; then
    echo "User said YES"
fi
```

### Rule #4: Set Environment Variables
```bash
export PMENU_H_CENTER=1    # Required for horizontal centering
export PMENU_V_CENTER=1    # Required for vertical centering
```

---

## Documentation by Audience

### For System Administrators
- **Quick Start:** [QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md)
- **Troubleshooting:** [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md) - Debugging section
- **Real Examples:** [RETURN-VALUES.md](docs/RETURN-VALUES.md) - Real-world examples section

### For Bash Script Developers
- **Must Read:** [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md)
- **Copy Patterns:** [QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md)
- **Return Values:** [RETURN-VALUES.md](docs/RETURN-VALUES.md)
- **Reference:** Comments in `scripts/util/dt_pmenu_lib.sh`

### For Python Developers
- **Full API:** dtpmenu.py docstring (300+ lines)
- **Architecture:** [PROJECT-HISTORY.md](docs/PROJECT-HISTORY.md)
- **Design Decisions:** [SOLUTION-SUMMARY.md](docs/SOLUTION-SUMMARY.md)

### For New Project Members
1. Read [README.md](README.md) - Project overview
2. Read [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md) - The "why"
3. Look at `demo_menu.sh` - Working code
4. Reference [QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md) - Patterns

---

## How to Never Waste Hours Again

1. **Before writing code:** Check [QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md) for your use case
2. **If something doesn't work:** Check [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md) debugging section
3. **If confused about results:** Check [RETURN-VALUES.md](docs/RETURN-VALUES.md)
4. **If you want deep understanding:** Read the docstring in dtpmenu.py

---

## Testing

Verify your installation and see dtpmenu in action:

```bash
# Quick test
cd /home/divix/divtools
bash projects/dtpmenu/demo_menu.sh

# In your own script
source "$DIVTOOLS/scripts/util/dt_pmenu_lib.sh"
export PMENU_H_CENTER=1 PMENU_V_CENTER=1
pmenu_yesno "Test" "Is this centered and colorful?"
```

---

## File Locations

| What | Path |
|------|------|
| Main app | `/home/divix/divtools/projects/dtpmenu/dtpmenu.py` |
| Bash wrapper | `/home/divix/divtools/scripts/util/dt_pmenu_lib.sh` |
| Documentation | `/home/divix/divtools/projects/dtpmenu/docs/` |
| Demo | `/home/divix/divtools/projects/dtpmenu/demo_menu.sh` |
| Setup | `/home/divix/divtools/projects/dtpmenu/install_dtpmenu_deps.sh` |

---

## Quick Links

📖 **Documentation Index:** This file (you are here)

🔴 **Integration Guide:** [BASH-INTEGRATION.md](docs/BASH-INTEGRATION.md)

🟠 **Return Values:** [RETURN-VALUES.md](docs/RETURN-VALUES.md)

🟡 **Quick Reference:** [QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md)

🟢 **Solution Summary:** [SOLUTION-SUMMARY.md](docs/SOLUTION-SUMMARY.md)

🔵 **Project History:** [PROJECT-HISTORY.md](docs/PROJECT-HISTORY.md)

📄 **README:** [README.md](README.md)

🐍 **Source Code:** [dtpmenu.py](dtpmenu.py)

🔨 **Wrapper:** [dt_pmenu_lib.sh](../../scripts/util/dt_pmenu_lib.sh)

---

**Last Updated:** 01/14/2026

**Status:** ✅ Complete Documentation Package - Comprehensive, searchable, with multiple entry points
