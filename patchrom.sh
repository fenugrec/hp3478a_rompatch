#!/bin/bash
#run as "patchrom <orig.bin> <patch.hex> <out.bin>
srec_cat $1 -bin $2 -intel -contradictory-bytes=ignore -redundant-bytes=ignore -o temp.bin -bin
./ckfix temp.bin $3
rm temp.bin