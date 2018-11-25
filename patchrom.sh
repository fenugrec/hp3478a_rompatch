#!/bin/bash
#run as "patchrom <orig.bin> <patch.hex> <out.bin>
srec_cat $1 -bin $2 -intel -contradictory-bytes=warn -redundant-bytes=ignore -o $3 -bin