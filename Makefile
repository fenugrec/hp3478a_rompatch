# to compile everything, gcc and and an assembler are required.
# I use 'asl' from http://john.ccac.rwth-aachen.de:8000/as/
#

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
PATCHLIST = 01_ADtest.hex 02_ADcomms.hex 03_ckdis.hex 04_relmode_h.hex

all: $(TGTLIST) $(PATCHLIST)

ckfix:	ckfix.c

%.p : %.asm
	$(ASL) $(ASLFLAGS) $< -o $@
	$(PLIST) $@

%.hex : %.p
	$(P2HEX) $(P2FLAGS) $<

clean:
	rm -f *.o
	rm -f $(TGTLIST) $(PATCHLIST)
