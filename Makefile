# to compile everything, gcc and and an assembler are required.
# I use 'asl' from http://john.ccac.rwth-aachen.de:8000/as/
#
# To produce the .crk files, srecord and pycrk is required e.g.
# https://github.com/pR0Ps/pycrk
#
# since those are more or less common packages, "make all" will not generate crk files by default.

CC = gcc
BASICFLAGS = -std=gnu11 -Wall -Wextra -Wpedantic
OPTFLAGS = -g
CFLAGS = $(BASICFLAGS) $(OPTFLAGS)

# flags for asl assembler
ASL = asl
ASLFLAGS = -q
P2HEX = p2hex
P2FLAGS = -k
PLIST = plist

TGTLIST = ckfix
PATCHLIST = 01_ADtest 02_ADcomms 03_ckdis 04_relmode_h

ORIG_ROM = dc118_orig.bin

all: $(TGTLIST) $(PATCHLIST:=.hex)

crk: $(PATCHLIST:=.crk)

ckfix:	ckfix.c

%.p : %.asm
	$(ASL) $(ASLFLAGS) $< -o $@
	$(PLIST) $@


# give a per-patch offset arg to p2hex since we can't do that in the .asm (asl limitation)

%.hex : %.p
	touch $(<:.p=.phex_args)
	$(P2HEX) $(P2FLAGS) $< -R `cat $(<:.p=.phex_args)`

%.crk : %.hex
	sh patchrom.sh $(ORIG_ROM) $< 0 patched_roms/dc118_$(<:.hex=.bin)
	crk-generate $(ORIG_ROM) patched_roms/dc118_$(<:.hex=.bin) -o crk_patches/$(<:.hex=.crk)

clean:
	rm -f *.o
	rm -f $(TGTLIST) $(PATCHLIST:=.hex)
	rm -f crk_patches/$(PATCHLIST:=.crk)
	rm -f patched_roms/*.bin
