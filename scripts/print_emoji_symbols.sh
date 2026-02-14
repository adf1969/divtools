#!/bin/bash

echo "Construction Emojis"
#!/bin/bash


for ((code=0x2600; code<=0x26FF; code++)); do
    printf "%08x\n" "$code"
done | awk '
{
  printf "%c   ", strtonum("0x"$1)
  if (++count % 10 == 0) printf "\n"
}
END { print "" }
'

echo ""
echo "Weather, Building, Transport Emojis"
for ((code=0x1F300; code<=0x1F5FF; code++)); do
    printf "%08x\n" "$code"
done | awk '
{
  printf "%c   ", strtonum("0x"$1)
  if (++count % 10 == 0) printf "\n"
}
END { print "" }
'
