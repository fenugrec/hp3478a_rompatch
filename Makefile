CC = gcc
BASICFLAGS = -std=gnu11 -Wall -Wextra -Wpedantic
OPTFLAGS = -g
CFLAGS = $(BASICFLAGS) $(OPTFLAGS)

TGTLIST = ckfix

all: $(TGTLIST)

ckfix:	ckfix.c

clean:
	rm -f *.o
	rm -f $(TGTLIST)
