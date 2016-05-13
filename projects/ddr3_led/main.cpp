#include <stdio.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <monkit.h>
#include <semaphore.h>

//#include <list>
#include <time.h>

//#include "StdDmaIndication.h"
//#include "MemServerRequest.h"
//#include "MMURequest.h"
#include "dmaManager.h"

#include "DDRLedIndication.h"
#include "DDRLedRequest.h"

DDRLedRequestProxy *device;

class DDRLedIndication : public DDRLedIndicationWrapper
{

	public:
		DDRLedIndication(unsigned int id) : DDRLedIndicationWrapper(id){}

		virtual void readDone(unsigned int data_high, unsigned int data_low, unsigned int cnt) {
			fprintf(stderr, "READ: %x%x @ cnt %d\n", data_high, data_low, cnt);
		}
};

void write(unsigned int addr, unsigned int data_high, unsigned int data_low)
{
	fprintf(stderr, "WRITE_REQ: @%x: %x%x\n", addr, data_high, data_low);
	device->write(addr, data_high, data_low);
}

void readReq(unsigned int addr)
{
	fprintf(stderr, "READ_REQ:  @%x\n", addr);
	device->readReq(addr);
}

int main(int argc, const char **argv)
{
	fprintf(stderr, "Initializing...\n");

	device = new DDRLedRequestProxy(IfcNames_DDRLedRequestS2H);
	DDRLedIndication deviceIndication(IfcNames_DDRLedIndicationH2S);

	long actualFrequency=0;
	long requestedFrequency=1e9/MainClockPeriod;
	int status = setClockFrequency(0, requestedFrequency, &actualFrequency);
	fprintf(stderr, "Requested Freq: %5.2f, Actual Freq: %5.2f, status=%d\n"
			,(double)requestedFrequency*1.0e-6
			,(double)actualFrequency*1.0e-6,status);

	unsigned int arg1, arg2, arg3;
	int ret;
	while(1) {
		fprintf(stderr, "0: write_req, 1:read_req\n");
		ret = scanf("%u", &arg1);
		if (arg1==0){
			fprintf(stderr, "WRITE: addr data_high low\n");
			ret = scanf("%u %u %u",&arg1,&arg2,&arg3);
			if (ret>0) write(arg1,arg2,arg3);
		}
		else if(arg1==1) {
			fprintf(stderr, "READ_REQ: addr\n");
			ret = scanf("%u",&arg1);
			if (ret>0) readReq(arg1);
		}
		else {
			fprintf(stderr, "invalid command\n");
		}
	}
}
