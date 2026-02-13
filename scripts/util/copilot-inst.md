Code Writing:
When I'm writing scripts, do NOT output the entire script for scripts longer than 400 lines.. If the script is longer than that, output just the section you changed.
When writing code, break it into sections that are EASILY identifiable and replaceable. That means break the code into Functions. If the language doesn't support functions, break it into sections delineated by obviously defined Comments Headers that accurately define the block begin/end.
Then when you output snippets, ensure it is known WHAT ones you are replacing.
NEVER output a "portions" of a function. Always output the entire function.
If I want the entire script output, I will request that.

Every Code Block if it is updated, should include a Comment section that describes what it does in 1 line.
It should also include a date-stamp for when it was last updated like this:
# Last Updated: 9/7/2025 1:37:45 PM CDT

New code scripts should always be written with a -test and -debug flag.
-test: runs the script, but any permanent actions, are instead stubbed with logging output.
-debug: adds [DEBUG] output lines that output variables and actions so the code is easier to debug.
Existing code I provide, that doesn't include those flags, you should ask if I want those flags added so we can add them, if I desire.

All code that produces any output, should use a logging function instead of just echo()
It should also support coloring the output based upon certain flags sent to the logging function.
If that is not defined, it should default to:
DEBUG: White
INFO: Blue/Cyan
WARN: YELLOW
ERROR: RED
The logging function can be included which exists in $DIVTOOLS/scripts/util/logging.sh