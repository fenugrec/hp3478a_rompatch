/* ckfix
 * simple strategy: adjust last byte of ROM to make checksum work
 * (c) fenugrec 2018
 * GPLv3
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#include "stypes.h"

#define DEFAULT_OFILE "temp.bin"	//default output filename
#define ROMSIZE (8*1024)
u8 rombuf[ROMSIZE];

FILE *dbg_stream;

/** calculate "addc" sum of area
 *
 * to simulate what the original ROM does, the very last addition's carry
 * is never added to the total.
 */
static u8 calc_cks(u8 *buf, unsigned len) {
	u8 checksum;
	unsigned i;
	u32 sum32 = 0;

	for (i=0; i < (len - 1); i++) {
		sum32 += buf[i];
	}

	//simulate effect of adding with "addc" opcode
	checksum = (sum32 & 0xff) + ((sum32 >> 8) & 0xff) + ((sum32 >> 16) & 0xff);
	//and add last value, *without* its carry
	checksum += buf[len - 1];
	return checksum;
}

/** fix checksum of ROM loaded at *buf.
 * ret 0 if ok
 */
static int fixck_backend(u8 *buf, unsigned len) {
	u8 cks_orig, cks_new;

	//calc current sum
	cks_orig = calc_cks(buf, len);
	//adjust to bring sum to 0
	buf[len - 1] -= cks_orig;
	//printf("orig sum: 0x%02X\n", cks_orig);

	cks_new = calc_cks(buf, len);
	if (cks_new == 0) {
		return 0;
	}
	printf("checksum adjustment 0x%X failed, got 0x%02X !?\n", (unsigned) buf[len -1], cks_new);
	return -1;
}

/* sanity check to make sure algo is correct */
static void selftest(void) {
	u8 fakerom[3];
	unsigned val;

	for (val=0; val <= 0xFFFF; val++) {
		//endianness doesn't matter for this test 
		fakerom[0] = val >> 8;
		fakerom[1] = val & 0xFF;
		if (fixck_backend(fakerom, 3)) return;
	}
}


static void fixck(FILE *i_file, FILE *o_file) {

	/* load whole ROM */
	if (fread(rombuf,1,ROMSIZE,i_file) != ROMSIZE) {
		printf("trouble reading\n");
		return;
	}

	if (!fixck_backend(rombuf, ROMSIZE)) {
		printf("checksum fixed with lastbyte=0x%02X !\n", (unsigned) rombuf[ROMSIZE -1]);
	}

	fwrite(rombuf, 1, ROMSIZE, o_file);
	return;
}


int main(int argc, char * argv[]) {
	const char *ofn;	//output file name
	FILE *i_file, *o_file;

	printf(	"**** %s\n"
		"**** Fix checksum (strategy: rewrite last byte)\n"
		"**** (c) 2018 fenugrec\n", argv[0]);

	if (argc < 2) {
		printf("%s <in_file> [<out_file>]"
			"\n\tIf out_file is omitted, output is written to %s"
			"\n\tExample: %s dc118_orig.bin hackrom.bin\n", argv[0], DEFAULT_OFILE, argv[0]);
		return 0;
	}

	selftest();

	//input file
	if ((i_file=fopen(argv[1],"rb"))==NULL) {
		printf("error opening %s.\n", argv[4]);
		return 0;
	}

	//3 : output file
	if (argc >= 3) {
		ofn = argv[2];
	} else {
		ofn = DEFAULT_OFILE;
	}
	//open it
	if ((o_file=fopen(ofn,"wb"))==NULL) {
		printf("error opening %s.\n", ofn);
		fclose(i_file);
		return 0;
	}

	rewind(i_file);

	fixck(i_file,o_file);
	fclose(i_file);
	fclose(o_file);

	return 0;
}

