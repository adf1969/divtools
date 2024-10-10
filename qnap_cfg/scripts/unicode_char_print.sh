#!/bin/bash

# Function to print a range of Unicode characters
print_unicode_range() {
  start=$1
  end=$2
  for ((i=start; i<=end; i++)); do
    printf "\\u$(printf %04x $i) "
  done
  echo
}

echo "Testing Unicode Characters:"

# Basic Latin (U+0020 to U+007F)
echo "Basic Latin:"
print_unicode_range 0x0020 0x007F

# Latin-1 Supplement (U+0080 to U+00FF)
echo "Latin-1 Supplement:"
print_unicode_range 0x0080 0x00FF

# Box Drawing (U+2500 to U+257F)
echo "Box Drawing:"
print_unicode_range 0x2500 0x257F

# Block Elements (U+2580 to U+259F)
echo "Block Elements:"
print_unicode_range 0x2580 0x259F

# Geometric Shapes (U+25A0 to U+25FF)
echo "Geometric Shapes:"
print_unicode_range 0x25A0 0x25FF

# Arrows (U+2190 to U+21FF)
echo "Arrows:"
print_unicode_range 0x2190 0x21FF

# Mathematical Operators (U+2200 to U+22FF)
echo "Mathematical Operators:"
print_unicode_range 0x2200 0x22FF

# Miscellaneous Symbols (U+2600 to U+26FF)
echo "Miscellaneous Symbols:"
print_unicode_range 0x2600 0x26FF

# Dingbats (U+2700 to U+27BF)
echo "Dingbats:"
print_unicode_range 0x2700 0x27BF

echo "Unicode character test complete."

