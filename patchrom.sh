#!/bin/bash
#run as "patchrom <orig.bin> <patch.hex> <patchoffset> <out.bin>
srec_cat $1 -bin $2 -intel -offset $3 -contradictory-bytes=warn -redundant-bytes=ignore -o temp.bin -bin
./ckfix temp.bin $4
rm temp.bin