Write a bash script named:
  comfy_chk_loras.sh
  ~~
That does the following:
Accepts the following args:
* file to check
--lora-path <loras-path> root path to loras

As well as standard -test and -debug.
For every arg, implement a -<single-letter> if possible.
ANd implement - and -- versions of the full named args. eg --lora-path and -lora-path

The Script:
Opens that file to check, searches for EVERY entry formatted as <lora:file:str>
Checks and sees if that "file" exists ANYWHERE in the sub-folders of loras-path.
If it does, it prints:
<file>: Found in <path to lora file>

If it does NOT find it, it prints:
<file>: NOT FOUND (print this in red)

The file may also have sections formatted like this:
====
section 0: Positive
---
section 0: Negative
===
section 1: Positive
---
section 1: Negative
===

Etc.
Essentially, 
=== delimit sections, 
and --- delimit positive/negative within that section.


If the file does have those delimiters, when outputing the results, group them like this:
Section 0:
  <file>: Found in <path to lora file>

Section 1:
  <file>: NOT FOUND (print this in red)

And so on.