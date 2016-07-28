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

#include "FlashIndication.h"
#include "FlashRequest.h"

#define BLOCKS_PER_CHIP 32
#define CHIPS_PER_BUS 8 // 8
#define NUM_BUSES 8 // 8

#define FPAGE_SIZE (8192*2)
#define FPAGE_SIZE_VALID (8224)
#define NUM_TAGS 128



typedef enum {
	UNINIT,
	ERASED,
	WRITTEN
} FlashStatusT;

typedef struct {
	bool busy;
	int bus;
	int chip;
	int block;
} TagTableEntry;

FlashRequestProxy *device;

pthread_mutex_t flashReqMutex;
pthread_cond_t flashFreeTagCond;

//8k * 128
size_t dstAlloc_sz = FPAGE_SIZE * NUM_TAGS *sizeof(unsigned char);
size_t srcAlloc_sz = FPAGE_SIZE * NUM_TAGS *sizeof(unsigned char);
int dstAlloc;
int srcAlloc;
unsigned int ref_dstAlloc;
unsigned int ref_srcAlloc;
unsigned int* dstBuffer;
unsigned int* srcBuffer;
unsigned int* readBuffers[NUM_TAGS];
unsigned int* writeBuffers[NUM_TAGS];
TagTableEntry readTagTable[NUM_TAGS];
TagTableEntry writeTagTable[NUM_TAGS];
TagTableEntry eraseTagTable[NUM_TAGS];
FlashStatusT flashStatus[NUM_BUSES][CHIPS_PER_BUS][BLOCKS_PER_CHIP];

// for Table 
#define NUM_BLOCKS 4096
#define NUM_SEGMENTS NUM_BLOCKS
#define NUM_CHANNELS 8
#define NUM_CHIPS 8
#define NUM_LOGBLKS (NUM_CHANNELS*NUM_CHIPS)

size_t blkmapAlloc_sz = sizeof(uint16_t) * NUM_SEGMENTS * NUM_LOGBLKS;
int blkmapAlloc;
uint ref_blkmapAlloc;
uint16_t (*blkmap)[NUM_CHANNELS*NUM_CHIPS]; // 4096*64
uint16_t (*blkmgr)[NUM_CHIPS][NUM_BLOCKS];  // 8*8*4096


bool testPassed = false;
bool verbose = true;
int curReadsInFlight = 0;
int curWritesInFlight = 0;
int curErasesInFlight = 0;

double timespec_diff_sec( timespec start, timespec end ) {
	double t = end.tv_sec - start.tv_sec;
	t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
	return t;
}


unsigned int hashAddrToData(int bus, int chip, int blk, int word) {
	return ((bus<<24) + (chip<<20) + (blk<<16) + word);
}


bool checkReadData(int tag) {
	TagTableEntry e = readTagTable[tag];
    bool pass = true;
	unsigned int goldenData;
	if (flashStatus[e.bus][e.chip][e.block]==WRITTEN) {
		int numErrors = 0;
		for (unsigned int word=0; word<FPAGE_SIZE_VALID/sizeof(unsigned int); word++) {
			goldenData = hashAddrToData(e.bus, e.chip, e.block, word);
			if (goldenData != readBuffers[tag][word]) {
				fprintf(stderr, "LOG: **ERROR: read data mismatch! tag=%d, %d %d %d, word=%d, Expected: %x, read: %x\n", tag, e.bus, e.chip, e.block, word, goldenData, readBuffers[tag][word]);
				numErrors++;
				pass = false;
			}
		}
		if (numErrors==0) {
			fprintf(stderr, "LOG: Read data check passed on tag=%d!\n", tag);
		}
	}
	else if (flashStatus[e.bus][e.chip][e.block]==ERASED) {
		//only check first word. It may return 0 if bad block, or -1 if erased
		//int numErrors = 0;
		//for (unsigned int word=0; word<FPAGE_SIZE_VALID/sizeof(unsigned int); word++) {
		//	if (readBuffers[tag][word]!=(unsigned int)-1) {
		//		fprintf(stderr, "LOG: **ERROR: erased data mismatch! tag=%d, word=%d, read=%x\n",tag,word,readBuffers[tag][word]);
		//		pass = false;
		//	}
	
		//}
		//if (numErrors==0) {
		//	fprintf(stderr, "LOG: Read check pass on erased block! tag=%d\n",tag);
		//}
		if (readBuffers[tag][0]==(unsigned int)-1) {
			fprintf(stderr, "LOG: Read check pass on erased block!\n");
		}
		else if (readBuffers[tag][0]==0) {
			fprintf(stderr, "LOG: Warning: potential bad block, read erased data 0\n");
			pass = false;
		}
		else {
			fprintf(stderr, "LOG: **ERROR: read data mismatch! Expected: ERASED, read: %x\n", readBuffers[tag][0]);
			pass = false;
		}
	}
	else {
		fprintf(stderr, "LOG: **ERROR: flash block state unknown. Did you erase before write?\n");
		pass = false;
	}
    return pass;
}

class FlashIndication : public FlashIndicationWrapper
{

	public:
		FlashIndication(unsigned int id) : FlashIndicationWrapper(id){}

		virtual void readDone(unsigned int tag, unsigned int status) {
			printf("LOG: readdone: tag=%d status=%d; inflight=%d\n", tag, status, curReadsInFlight );
			fflush(stdout);

			pthread_mutex_lock(&flashReqMutex);
			curReadsInFlight --;
			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void writeDone(unsigned int tag, unsigned int status) {
			printf("LOG: writedone: tag=%d status=%d; inflight=%d\n", tag, status, curWritesInFlight );
			fflush(stdout);

			pthread_mutex_lock(&flashReqMutex);
			curWritesInFlight --;
			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void eraseDone(unsigned int tag, unsigned int status) {
			printf("LOG: eraseDone, tag=%d, status=%d\n", tag, status); fflush(stdout);
			pthread_mutex_lock(&flashReqMutex);
			curErasesInFlight--;
			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void debugDumpResp (unsigned int debug0, unsigned int debug1,  unsigned int debug2, unsigned int debug3, unsigned int debug4, unsigned int debug5) {
			//uint64_t cntHi = debugRdCntHi;
			//uint64_t rdCnt = (cntHi<<32) + debugRdCntLo;
			fprintf(stderr, "LOG: DEBUG DUMP: gearSend = %d, gearRec = %d, aurSend = %d, aurRec = %d, readSend=%d, writeSend=%d\n", debug0, debug1, debug2, debug3, debug4, debug5);
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




int getNumReadsInFlight() { return curReadsInFlight; }
int getNumWritesInFlight() { return curWritesInFlight; }
int getNumErasesInFlight() { return curErasesInFlight; }

//int lastErase = NUM_TAGS-1;
//int lastRead = NUM_TAGS-1;
//int lastWrite = NUM_TAGS-1;

//TODO: more efficient locking
int waitIdleEraseTag() {
	int tag = -1;
	while ( tag < 0 ) {
	pthread_mutex_lock(&flashReqMutex);

		for ( int t = 0; t < NUM_TAGS; t++ ) {
		//for ( int t = (lastErase==NUM_TAGS-1)?0:lastErase+1; t < NUM_TAGS; t++ ) {
			if ( !eraseTagTable[t].busy ) {
				eraseTagTable[t].busy = true;
				tag = t;
				//lastErase = t;
				break;
			}
		}
	pthread_mutex_unlock(&flashReqMutex);
		/*
		if (tag < 0) {
			pthread_cond_wait(&flashFreeTagCond, &flashReqMutex);
		}
		else {
			pthread_mutex_unlock(&flashReqMutex);
			return tag;
		}
		*/
	}
	return tag;
}


//TODO: more efficient locking
int waitIdleWriteBuffer() {
	int tag = -1;
	while ( tag < 0 ) {
	pthread_mutex_lock(&flashReqMutex);

		for ( int t = 0; t < NUM_TAGS; t++ ) {
		//for ( int t = (lastWrite==NUM_TAGS-1)?0:lastWrite+1; t < NUM_TAGS; t++ ) {
			if ( !writeTagTable[t].busy) {
				writeTagTable[t].busy = true;
				tag = t;
				//lastWrite=t;
				break;
			}
		}
	pthread_mutex_unlock(&flashReqMutex);
		/*
		if (tag < 0) {
			pthread_cond_wait(&flashFreeTagCond, &flashReqMutex);
		}
		else {
			pthread_mutex_unlock(&flashReqMutex);
			return tag;
		}
		*/
	}
	return tag;
}



//TODO: more efficient locking
int waitIdleReadBuffer() {
	int tag = -1;
	while ( tag < 0 ) {
	pthread_mutex_lock(&flashReqMutex);

		for ( int t = 0; t < NUM_TAGS; t++ ) {
		//for ( int t = (lastRead==NUM_TAGS-1)?0:lastRead+1; t < NUM_TAGS; t++ ) {
			if ( !readTagTable[t].busy ) {
				readTagTable[t].busy = true;
				tag = t;
				//lastRead=t;
				break;
			}
		}
	pthread_mutex_unlock(&flashReqMutex);
		/*
		if (tag < 0) {
			pthread_cond_wait(&flashFreeTagCond, &flashReqMutex);
		}
		else {
			pthread_mutex_unlock(&flashReqMutex);
			return tag;
		}
		*/
	}
	return tag;
}


void eraseBlock(uint32_t tag, uint32_t lpa) {
	pthread_mutex_lock(&flashReqMutex);
	curErasesInFlight ++;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending erase blk request with tag=%u @%u\n", tag, lpa );
	device->eraseBlock(tag, lpa);
}

void writePage(uint32_t tag, uint32_t lpa) {
	pthread_mutex_lock(&flashReqMutex);
	curWritesInFlight ++;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending write page request with tag=%u @%u\n", tag, lpa );
	device->readPage(tag, lpa, tag*FPAGE_SIZE);
}

void readPage(uint32_t tag, uint32_t lpa) {
	pthread_mutex_lock(&flashReqMutex);
	curReadsInFlight ++;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending read page request with tag=%u @%u\n", tag, lpa );
	device->readPage(tag, lpa, tag*FPAGE_SIZE);
}

int main(int argc, const char **argv)
{
	testPassed=true;
	fprintf(stderr, "Initializing DMA...\n");

	device = new FlashRequestProxy(FlashRequestS2H);
	FlashIndication deviceIndication(FlashIndicationH2S);
    DmaManager *dma = platformInit();

	fprintf(stderr, "Main::allocating memory...\n");
	
	srcAlloc = portalAlloc(srcAlloc_sz, 0);
	dstAlloc = portalAlloc(dstAlloc_sz, 0);
	srcBuffer = (unsigned int *)portalMmap(srcAlloc, srcAlloc_sz);
	dstBuffer = (unsigned int *)portalMmap(dstAlloc, dstAlloc_sz);

	blkmapAlloc = portalAlloc(blkmapAlloc_sz*2, 0);
	char *tmpPtr = (char*)portalMmap(blkmapAlloc, blkmapAlloc_sz*2);
	blkmap      = (uint16_t(*)[NUM_CHANNELS*NUM_CHIPS]) (tmpPtr);
	blkmgr      = (uint16_t(*)[NUM_CHIPS][NUM_BLOCKS])  (tmpPtr+blkmapAlloc_sz);

	fprintf(stderr, "dstAlloc = %x\n", dstAlloc); 
	fprintf(stderr, "srcAlloc = %x\n", srcAlloc); 
	fprintf(stderr, "blkmapAlloc = %x\n", blkmapAlloc); 
	
	pthread_mutex_init(&flashReqMutex, NULL);
	pthread_cond_init(&flashFreeTagCond, NULL);

	printf( "Done initializing hw interfaces\n" ); fflush(stdout);

	//portalExec_start();
	printf( "Done portalExec_start\n" ); fflush(stdout);

	portalCacheFlush(dstAlloc, dstBuffer, dstAlloc_sz, 1);
	portalCacheFlush(srcAlloc, srcBuffer, srcAlloc_sz, 1);
	portalCacheFlush(blkmapAlloc, blkmap, blkmapAlloc_sz*2, 1);

	ref_dstAlloc = dma->reference(dstAlloc);
	ref_srcAlloc = dma->reference(srcAlloc);
	ref_blkmapAlloc = dma->reference(blkmapAlloc);

	device->setDmaWriteRef(ref_dstAlloc);
	device->setDmaReadRef(ref_srcAlloc);
	device->setDmaMapRef(ref_blkmapAlloc);

	for (int t = 0; t < NUM_TAGS; t++) {
		readTagTable[t].busy = false;
		writeTagTable[t].busy = false;
		int byteOffset = t * FPAGE_SIZE;
		readBuffers[t] = dstBuffer + byteOffset/sizeof(unsigned int);
		writeBuffers[t] = srcBuffer + byteOffset/sizeof(unsigned int);
	}
	
	for (int blk=0; blk < BLOCKS_PER_CHIP; blk++) {
		for (int c=0; c < CHIPS_PER_BUS; c++) {
			for (int bus=0; bus< NUM_BUSES; bus++) {
				flashStatus[bus][c][blk] = UNINIT;
			}
		}
	}

	for (int t = 0; t < NUM_TAGS; t++) {
		for ( unsigned int i = 0; i < FPAGE_SIZE/sizeof(unsigned int); i++ ) {
			readBuffers[t][i] = 0xDEADBEEF;
			writeBuffers[t][i] = 0xBEEFDEAD;
		}
	}

	long actualFrequency=0;
	long requestedFrequency=1e9/MainClockPeriod;
	int status = setClockFrequency(0, requestedFrequency, &actualFrequency);
	fprintf(stderr, "Requested Freq: %5.2f, Actual Freq: %5.2f, status=%d\n"
			,(double)requestedFrequency*1.0e-6
			,(double)actualFrequency*1.0e-6,status);

	device->start(0);
	device->setDebugVals(0,0); //flag, delay

	device->debugDumpReq(0);
	sleep(1);
	device->debugDumpReq(0);
	sleep(1);

	for (int t = 0; t < NUM_TAGS; t++) {
		for ( unsigned int i = 0; i < FPAGE_SIZE/sizeof(unsigned int); i++ ) {
			readBuffers[t][i] = 0xDEADBEEF;
		}
	}


	//// map test ///

	int i,j,k;
	//uint16_t (*blkmap)[NUM_CHANNELS*NUM_CHIPS]; // 4096*64
	for (i = 0; i<4096; i++)
		for (j =0; j<64; j++)
#ifndef BSIM
			blkmap[i][j] = 0x0;
#else
			blkmap[i][j] = 0x8000;
#endif

	printf( "MAP UPLOAD!\n" ); fflush(stdout);
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
	blkmap[0][2] = (1 << 14) | 32 ;
	blkmap[0][5] = (1 << 14) | 32 ;

#ifndef BSIM
	blkmgr[0][0][31] = 0xAB;
	blkmgr[0][0][24] = 0xAF;
#else
	blkmgr[0][0][31] = 0x80AB;
	blkmgr[0][0][24] = 0x80AF;
#endif

	device->uploadMap();


	int tmp,tmp2;
	printf( "put any int to start test\n" );
	do { 
		tmp2 =  scanf( "%d", &tmp);
	} while (!(tmp2 > 0));


	timespec start, now;
	clock_gettime(CLOCK_REALTIME, & start);

	printf( "TEST READ!\n" ); fflush(stdout);
	for (int repeat = 0; repeat < 1; repeat++){
		for (unsigned int lpa = 0; lpa < 10; lpa++){
			readPage(waitIdleReadBuffer(), lpa);
		}
	}
	
	while (true) {
		usleep(100);
		if ( getNumReadsInFlight() == 0 ) break;
	}

	int elapsed = 0;
	while (true) {
		usleep(100);
		if (elapsed == 0) {
			elapsed=10000;
			device->debugDumpReq(0);
		}
		else {
			elapsed--;
		}
		if ( getNumReadsInFlight() == 0 ) break;
	}
	device->debugDumpReq(0);

	clock_gettime(CLOCK_REALTIME, & now);
	fprintf(stderr, "LOG: finished reading from page! %f\n", timespec_diff_sec(start, now) );

	sleep(2);
}
