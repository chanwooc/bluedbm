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

typedef unsigned int uint;

FTLBRAMTestRequestProxy *device;
pthread_mutex_t ftlReqMutex;
int map[4096][64];
uint tmp_seg=0, tmp_logblk=0;
uint num_errors=0;

class FTLBRAMTestIndication : public FTLBRAMTestIndicationWrapper
{

	public:
		FTLBRAMTestIndication(uint id) : FTLBRAMTestIndicationWrapper(id){}
		virtual void translateDone(uint valid, uint bus, uint chip, uint block, uint page, uint cnt) {
			if (valid) {

				fprintf(stderr, "Translation success\t: %u %u %u %u, cycle=%u\n", bus,chip,block,page,cnt);
				int mapping_entry = map[tmp_seg][tmp_logblk];
				if (mapping_entry == -1)
				{
					fprintf(stderr, "Map updated\n");
					map[tmp_seg][tmp_logblk] = block;
				}
				else if (mapping_entry != (int)block)
				{
					fprintf(stderr, "Error! Map=%u, Block=%u\n", mapping_entry, block);
					num_errors++;
				}
				else
				{
					fprintf(stderr, "Expected! Map=Block=%u\n", mapping_entry);
				}

			} else {
				fprintf(stderr, "Translation failed:  cycle=%u\n", cnt);
			}
			pthread_mutex_unlock(&ftlReqMutex);
		}
};


void translate(uint lpa)
{
	pthread_mutex_lock(&ftlReqMutex);

	uint seg = lpa >> 14;
	uint page = ( lpa - (seg<<14) ) >> 6;
	uint logblk = lpa & 0x3F;

	uint channel = logblk % 8;
	uint chip    = logblk / 8;

	int mapping_entry = map[seg][logblk];
	tmp_seg = seg;
	tmp_logblk = logblk;

	fprintf(stderr, "Translation request: lpa=%u\n", lpa);
	if (mapping_entry == -1)
		fprintf(stderr, "Translation should be\t: %u %u ? %u\n", channel, chip, page);
	else
		fprintf(stderr, "Translation should be\t: %u %u %d %u\n", channel, chip, mapping_entry, page);

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

	pthread_mutex_init(&ftlReqMutex, NULL);

	for (int ii = 0; ii < 4096; ii++)
		for (int jj=0; jj<64; jj++)
			map[ii][jj]=-1;

	for (int llpa=0; llpa <= 0x3FFFFFF; llpa++)
	{
		translate(llpa);
	}

}
