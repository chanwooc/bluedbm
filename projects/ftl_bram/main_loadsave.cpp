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

#include "FTLBRAMTestIndication.h"
#include "FTLBRAMTestRequest.h"

#define NUM_BLOCKS 4096
#define NUM_SEGMENTS NUM_BLOCKS
#define NUM_CHANNELS 8
#define NUM_CHIPS 8
#define NUM_LOGBLKS (NUM_CHANNELS*NUM_CHIPS)

FTLBRAMTestRequestProxy *device;

typedef unsigned int uint;

size_t blkmapAlloc_sz = sizeof(uint16_t) * NUM_SEGMENTS * NUM_LOGBLKS;
int blkmapAlloc;
uint ref_blkmapAlloc;
//void* mapPointer, blkmgrPointer;
uint16_t (*blkmap)[NUM_CHANNELS*NUM_CHIPS]; // 4096*64
uint16_t (*blkmgr)[NUM_CHIPS][NUM_BLOCKS];  // 8*8*4096


class FTLBRAMTestIndication : public FTLBRAMTestIndicationWrapper
{

	public:
		FTLBRAMTestIndication(uint id) : FTLBRAMTestIndicationWrapper(id){}
		virtual void translateDone(uint valid, uint bus, uint chip, uint block, uint page, uint cnt) {
			if (valid) {
				fprintf(stderr, "Translation success: %u %u %u %u, cycle=%u\n", bus,chip,block,page,cnt);

			} else {
				fprintf(stderr, "Translation failed:  cycle=%u\n", cnt);
			}
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

void translate(uint lpa)
{
	uint seg = lpa >> 14;
	uint page = ( lpa - (seg<<14) ) >> 6;
	uint logblk = lpa & 0x3F;

	uint channel = logblk % 8;
	uint chip    = logblk / 8;

	fprintf(stderr, "Translation request: lpa=%u\n", lpa);
	fprintf(stderr, "Translation segment=%u\n", seg);
	fprintf(stderr, "Translation logblk=%u\n", logblk);
	fprintf(stderr, "Translation should be: %u %u ? %u\n", channel, chip, page);

	device->translate(lpa);
}

int main(int argc, const char **argv)
{
	fprintf(stderr, "Initializing...\n");

	device = new FTLBRAMTestRequestProxy(IfcNames_FTLBRAMTestRequestS2H);
	FTLBRAMTestIndication deviceIndication(IfcNames_FTLBRAMTestIndicationH2S);

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

	uint arg1;

	for (int i = 0; i<4096; i++)
		for (int j =0; j<64; j++)
			blkmap[i][j] = 0xabab;

	blkmap[0][0] = 0xbeef;

	int ret;
	while(1) {
		fprintf(stderr, "1: translation, 2: Download map, 3: Upload map \n");
		ret = scanf("%u", &arg1);
		
		if (ret>0) {
			switch(arg1) {
				case 1:
					fprintf(stderr, "Enter LPA: \n");
					ret = scanf("%u", &arg1);
					if (ret>0) {
						if (arg1<=0x3FFFFFF){
							translate(arg1);
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
