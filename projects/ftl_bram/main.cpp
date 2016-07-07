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

FTLBRAMTestRequestProxy *device;

typedef unsigned int uint;

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

	uint arg1;
	int ret;
	while(1) {
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
	}
}
