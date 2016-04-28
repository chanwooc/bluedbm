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

#include "EchoIndication.h"
#include "EchoRequest.h"

EchoRequestProxy *device;

class EchoIndication : public EchoIndicationWrapper
{

	public:
		EchoIndication(unsigned int id) : EchoIndicationWrapper(id){}

		virtual void readDone(unsigned int data_high, unsigned int data_low) {
			fprintf(stderr, "READ: %x%x\n", data_high, data_low);
		}
};

void write(unsigned int addr_high, unsigned int addr_low, unsigned int data_high, unsigned int data_low)
{
	fprintf(stderr, "WRITE_REQ: @%x%x: %x%x\n", addr_high, addr_low, data_high, data_low);
	device->write(addr_high, addr_low, data_high, data_low);
}

void readReq(unsigned int addr_high, unsigned int addr_low)
{
	fprintf(stderr, "READ_REQ:  @%x%x\n", addr_high, addr_low);
	device->readReq(addr_high, addr_low);
}

int main(int argc, const char **argv)
{
	fprintf(stderr, "Initializing...\n");

	device = new EchoRequestProxy(IfcNames_EchoRequestS2H);
	EchoIndication deviceIndication(IfcNames_EchoIndicationH2S);

	long actualFrequency=0;
	long requestedFrequency=1e9/MainClockPeriod;
	int status = setClockFrequency(0, requestedFrequency, &actualFrequency);
	fprintf(stderr, "Requested Freq: %5.2f, Actual Freq: %5.2f, status=%d\n"
			,(double)requestedFrequency*1.0e-6
			,(double)actualFrequency*1.0e-6,status);

	fprintf(stderr, "0: write_req, 1:read_req\n");
	unsigned int arg1, arg2, arg3, arg4;
	int ret;
	while(1) {
		fprintf(stderr, "0: write_req, 1:read_req\n");
		ret = scanf("%u", &arg1);
		if (arg1==0){
			fprintf(stderr, "WRITE: addr_high low data_high low\n");
			ret = scanf("%u %u %u %u",&arg1,&arg2,&arg3,&arg4);
			if (ret>0) write(arg1,arg2,arg3,arg4);
		}
		else if(arg1==1) {
			fprintf(stderr, "READ_REQ: addr_high low\n");
			ret = scanf("%u %u",&arg1,&arg2);
			if (ret>0) readReq(arg1,arg2);
		}
		else {
			fprintf(stderr, "invalid command\n");
		}

	}
}
