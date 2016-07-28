#include <stdio.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <monkit.h>
#include <semaphore.h>

#include <time.h>

#include "dmaManager.h"

#include "AFTLBRAMTestIndication.h"
#include "AFTLBRAMTestRequest.h"

#define NUM_BLOCKS 4096
#define NUM_SEGMENTS NUM_BLOCKS
#define NUM_CHANNELS 8
#define NUM_CHIPS 8
#define NUM_LOGBLKS (NUM_CHANNELS*NUM_CHIPS)

AFTLBRAMTestRequestProxy *device;

typedef unsigned int uint;

size_t blkmapAlloc_sz = sizeof(uint16_t) * NUM_SEGMENTS * NUM_LOGBLKS;
int blkmapAlloc;
uint ref_blkmapAlloc;
uint16_t (*blkmap)[NUM_CHANNELS*NUM_CHIPS]; // 4096*64
uint16_t (*blkmgr)[NUM_CHIPS][NUM_BLOCKS];  // 8*8*4096


class AFTLBRAMTestIndication : public AFTLBRAMTestIndicationWrapper
{

	public:
		AFTLBRAMTestIndication(uint id) : AFTLBRAMTestIndicationWrapper(id){}
		virtual void translateSuccess(uint op, uint bus, uint chip, uint block, uint page, uint cnt) {
			fprintf(stderr, "Success: op%u %u %u %u %u, cycle=%u\n", op,bus,chip,block,page,cnt);
		}
		virtual void translateFailure(uint op, uint cnt) {
			fprintf(stderr, "Failure: op%u, cycle=%u\n", op,cnt);
		}
		virtual void uploadDone()
		{
			fprintf(stderr, "Map Upload(Host->FPGA) done!\n");
		}

		virtual void downloadDone()
		{
			fprintf(stderr, "Map Download(FPGA->Host) done!\n");
		}
};

void translate(uint op, uint lpa)
{
	uint seg = lpa >> 14;
	uint page = ( lpa - (seg<<14) ) >> 6;
	uint logblk = lpa & 0x3F;

	uint channel = logblk % 8;
	uint chip    = logblk / 8;

	fprintf(stderr, "Translation request: op=%u lpa=%u\n", op, lpa);
	fprintf(stderr, "Translation segment=%u\n", seg);
	fprintf(stderr, "Translation logblk=%u\n", logblk);
	fprintf(stderr, "Translation should be: %u %u ? %u\n", channel, chip, page);

	device->translate(op, lpa);
}

int main(int argc, const char **argv)
{
	fprintf(stderr, "Initializing...\n");

	device = new AFTLBRAMTestRequestProxy(IfcNames_AFTLBRAMTestRequestS2H);
	AFTLBRAMTestIndication deviceIndication(IfcNames_AFTLBRAMTestIndicationH2S);

	long actualFrequency=0;
	long requestedFrequency=1e9/MainClockPeriod;
	int status = setClockFrequency(0, requestedFrequency, &actualFrequency);
	fprintf(stderr, "Requested Freq: %5.2f, Actual Freq: %5.2f, status=%d\n"
			,(double)requestedFrequency*1.0e-6
			,(double)actualFrequency*1.0e-6,status);

	fprintf(stderr, "DMA init & Allocating memory...\n");
	DmaManager *dma = platformInit();
	
	blkmapAlloc = portalAlloc(blkmapAlloc_sz*2, 0);
	char *tmpPtr = (char*)portalMmap(blkmapAlloc, blkmapAlloc_sz*2);
	blkmap      = (uint16_t(*)[NUM_CHANNELS*NUM_CHIPS]) (tmpPtr);
	blkmgr      = (uint16_t(*)[NUM_CHIPS][NUM_BLOCKS])  (tmpPtr+blkmapAlloc_sz);

	fprintf(stderr, "blkmapAlloc = %x\n", blkmapAlloc); 

	portalCacheFlush(blkmapAlloc, blkmap, blkmapAlloc_sz*2, 1);

	ref_blkmapAlloc = dma->reference(blkmapAlloc);

	device->setDmaRef(ref_blkmapAlloc);

	uint arg1,arg2;

	int i,j,k;
	//uint16_t (*blkmap)[NUM_CHANNELS*NUM_CHIPS]; // 4096*64
	for (i = 0; i<4096; i++)
		for (j =0; j<64; j++)
#ifndef BSIM
			blkmap[i][j] = 0x0;
#else
			blkmap[i][j] = 0x8000;
#endif

	//uint16_t (*blkmgr)[NUM_CHIPS][NUM_BLOCKS];  // 8*8*4096
	for (i = 0; i<8; i++)
		for (j=0; j<8; j++)
			for (k=0; k<4096; k++)
#ifndef BSIM
				blkmgr[i][j][k] = 0xCC;
#else
				blkmgr[i][j][k] = 0x80CC;
#endif


	blkmap[0][1] = (1 << 14) | 32 ;

#ifndef BSIM
	blkmgr[0][0][31] = 0xAB;
	blkmgr[0][0][24] = 0xAF;
#else
	blkmgr[0][0][31] = 0x80AB;
	blkmgr[0][0][24] = 0x80AF;
#endif

	int ret;
	while(1) {
		fprintf(stderr, "1: translation, 2: Download map, 3: Upload map \n");
		ret = scanf("%u", &arg1);
		
		if (ret>0) {
			switch(arg1) {
				case 1:
					fprintf(stderr, "Enter OP & LPA: \n");
					ret = scanf("%u %u", &arg1, &arg2);
					if (ret>0) {
						if (arg2<=0x3FFFFFF){
							translate(arg1,arg2);
						}
						else {
							fprintf(stderr, "invalid LPA: should be less than 0x3FFFFFF\n");
						}
					}
					break;

				case 2:
					device->downloadMap();
					break;

				case 3:
					device->uploadMap();
					break;

				default:
					fprintf(stderr, "Invalid selection\n");
			}
		}
	}
}
