#!/bin/bash
#run as "patchrom <orig.bin> <patch.hex> <patchoffset> <out.bin>
#
# for debugging patches : try -contradictory-bytes=ignore
srec_cat $1 -bin $2 -intel -offset $3 -contradictory-bytes=ignore -redundant-bytes=ignore -o temp.bin -bin
./ckfix temp.bin $4
rm temp.bin