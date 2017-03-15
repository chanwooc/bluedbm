#include <stdio.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <monkit.h>
#include <semaphore.h>

#include <time.h>

#include <queue>

#include "dmaManager.h"

#include "FlashIndication.h"
#include "FlashRequest.h"

#define SEGNUM 4
#define VERBOSE true
#define BLKOFFSET 510
//#define WRITE
#define READ
#define READ_WAIT 256*256

#define BLOCKS_PER_CHIP 100//4096
#define CHIPS_PER_BUS 8
#define NUM_BUSES 8

#define FPAGE_SIZE (8192)
#define FPAGE_SIZE_VALID (8192)
#define NUM_TAGS 64 //64
#define NUM_TAGS2 128 //64

typedef enum {
	UNINIT,
	ERASED,
	WRITTEN,
	BAD
} FlashStatusT;

typedef struct {
	bool busy;
	int bus;
	int chip;
	int block;
	int page;
} TagTableEntry;

typedef struct {
	bool eraseIssued;
	bool badFromErase; // ERASE_ERROR from controller
	bool badFromRead;  // ERASE_DONE but when read other than -1 comes out
} BadBlockEntry;

BadBlockEntry badBlockTable[NUM_BUSES][CHIPS_PER_BUS][BLOCKS_PER_CHIP];


std::queue<int> readTagQueue;

//8k * 128
size_t dstAlloc_sz = FPAGE_SIZE * NUM_TAGS2 *sizeof(unsigned char);
size_t srcAlloc_sz = FPAGE_SIZE * NUM_TAGS2 *sizeof(unsigned char);
int dstAlloc;
int srcAlloc;
unsigned int ref_dstAlloc;
unsigned int ref_srcAlloc;
unsigned int* dstBuffer;
unsigned int* srcBuffer;
unsigned int* readBuffers[NUM_TAGS2];
unsigned int* writeBuffers[NUM_TAGS2];
TagTableEntry readTagTable[NUM_TAGS2];
TagTableEntry writeTagTable[NUM_TAGS2];
TagTableEntry eraseTagTable[NUM_TAGS2];
FlashStatusT flashStatus[NUM_BUSES][CHIPS_PER_BUS][BLOCKS_PER_CHIP];

// for Table 
#define NUM_BLOCKS 4096
#define NUM_SEGMENTS NUM_BLOCKS
#define NUM_CHANNELS 8
#define NUM_CHIPS 8
#define NUM_LOGBLKS (NUM_CHANNELS*NUM_CHIPS)

size_t blkmapAlloc_sz = sizeof(uint16_t) * NUM_SEGMENTS * NUM_LOGBLKS; // 512KB
uint16_t (*blkmap)[NUM_CHANNELS*NUM_CHIPS]; // 4096*64
uint16_t (*blkmgr)[NUM_CHIPS][NUM_BLOCKS];  // 8*8*4096

bool testPassed = false;
bool verbose = VERBOSE;
int num_err = 0;
int curReadsInFlight = 0;
int curWritesInFlight = 0;
int curErasesInFlight = 0;

pthread_mutex_t flashReqMutex = PTHREAD_MUTEX_INITIALIZER;
FlashRequestProxy *device;

double timespec_diff_sec( timespec start, timespec end ) {
	double t = end.tv_sec - start.tv_sec;
	t += ((double)(end.tv_nsec - start.tv_nsec)/1000000000L);
	return t;
}

unsigned int hashAddrToData(int bus, int chip, int blk, int word) {
	return ((bus<<24) + (chip<<20) + (blk<<4) + word);
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
				fprintf(stderr, "LOG: **ERROR: read data mismatch! tag=%d, %d %d %d, Expected: %x, read: %x\n", tag, e.bus, e.chip, e.block, goldenData, readBuffers[tag][word]);
				numErrors++;
				pass = false;
			}
		}
		if (numErrors==0) {
			fprintf(stderr, "LOG: Read data check passed on tag=%d!\n", tag);
		}
	}
	else if (flashStatus[e.bus][e.chip][e.block]==ERASED) {
		// only check first word. It may return 0 if bad block, or -1 if erased
		if (readBuffers[tag][0]==(unsigned int)-1) {
			fprintf(stderr, "LOG: Read check pass on erased block @%d %d %d 0!\n", e.bus, e.chip, e.block);
			badBlockTable[e.bus][e.chip][e.block].badFromRead = false;
		}
		else if (readBuffers[tag][0]==0) {
			fprintf(stderr, "LOG: Warning: potential bad block, read erased data 0 @%d %d %d 0!\n", e.bus, e.chip, e.block);
			badBlockTable[e.bus][e.chip][e.block].badFromRead = true;
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

bool checkReadData2(int tag) {
	TagTableEntry e = readTagTable[tag];
	unsigned int goldenData = hashAddrToData(e.bus, e.chip, e.block, 0);

	if (goldenData != readBuffers[tag][0]) {
		fprintf(stderr, "LOG: **readdone: read data MISMATCH! tag=%d, %d %d %d %d Expected: %x, read: %x\n", tag, e.bus, e.chip, e.block, e.page, goldenData, readBuffers[tag][0]);
	} else {
		if(verbose) fprintf(stderr, "LOG: **readdone: read data SUCCESS!! tag=%d, %d %d %d %d \n", tag, e.bus, e.chip, e.block, e.page);
	}
	return true;
}

class FlashIndication : public FlashIndicationWrapper
{
	public:
		FlashIndication(unsigned int id) : FlashIndicationWrapper(id){}

		virtual void readDone(unsigned int tag) {
//			portalCacheFlush(dstAlloc, readBuffers[tag], FPAGE_SIZE, 0);
//			portalCacheFlush(dstAlloc, dstBuffer, dstAlloc_sz, 0);

//			if ( verbose ) {
//				printf( "LOG: pagedone received: tag=%d inflight=%d \n", tag, curReadsInFlight );
//				fflush(stdout);
//			}

			//check 
//			tempPassed = checkReadData(tag);

			pthread_mutex_lock(&flashReqMutex);
			if ( readTagTable[tag].busy == false ) {
				fprintf(stderr, "LOG: **ERROR: received unused buffer read done (ACK duplicate?) tag=%d\n", tag);
				//tempPassed = false;
				num_err++;
//				checkReadData2(tag);
			} else {
				readTagTable[tag].busy = false;
				readTagQueue.push(tag);
//				if (checkReadData2(tag)) {
					curReadsInFlight --;
//				}
			}
			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void writeDone(unsigned int tag) {
			if ( verbose ) {
				printf("LOG: writedone: tag=%d\n", tag); fflush(stdout);
			}

			//TODO probably should use a diff lock
			pthread_mutex_lock(&flashReqMutex);
			curWritesInFlight--;
			if ( curWritesInFlight < 0 ) {
				fprintf(stderr, "LOG: **ERROR: Write requests in flight cannot be negative %d\n", curWritesInFlight );
				curWritesInFlight = 0;
			}
			if ( writeTagTable[tag].busy == false ) {
				fprintf(stderr, "LOG: **ERROR: received unused buffer Write done %d\n", tag);
				testPassed = false;
			}
			writeTagTable[tag].busy = false;
			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void eraseDone(unsigned int tag, unsigned int status) {
			pthread_mutex_lock(&flashReqMutex);

			int bus = eraseTagTable[tag].bus;
			int chip = eraseTagTable[tag].chip;
			int block = eraseTagTable[tag].block;

			if (status == 0) {
				printf("LOG: eraseSuccess, tag=%d @%d %d %d 0\n", tag, bus, chip, block); fflush(stdout);
			} else {
				printf("LOG: eraseFailed,  tag=%d @%d %d %d 0\n", tag, bus, chip, block); fflush(stdout);
			}

			badBlockTable[bus][chip][block].eraseIssued = true;
			badBlockTable[bus][chip][block].badFromErase = status? true:false;

			curErasesInFlight--;
			if ( curErasesInFlight < 0 ) {
				fprintf(stderr, "LOG: **ERROR: erase requests in flight cannot be negative %d\n", curErasesInFlight );
				curErasesInFlight = 0;
			}
			if ( eraseTagTable[tag].busy == false ) {
				fprintf(stderr, "LOG: **ERROR: received unused tag erase done %d\n", tag);
				testPassed = false;
			}

			eraseTagTable[tag].busy = false;

			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void debugDumpResp (unsigned int debug0, unsigned int debug1,  unsigned int debug2, unsigned int debug3, unsigned int debug4, unsigned int debug5) {
			//uint64_t cntHi = debugRdCntHi;
			//uint64_t rdCnt = (cntHi<<32) + debugRdCntLo;
			fprintf(stderr, "LOG: DEBUG DUMP: gearSend = %d, gearRec = %d, aurSend = %d, aurRec = %d, readSend=%d, writeSend=%d\n", debug0, debug1, debug2, debug3, debug4, debug5);
		}

		virtual void debugDumpResp2 (unsigned int debug0, unsigned int debug1, unsigned int val) {
			fprintf(stderr, "LOG: DEBUG DUMP: readPageSent = %u, readPageDone = %u, flag = %x, numerr = %d\n", debug0, debug1, val, num_err);
		}
};

int getNumReadsInFlight() { return curReadsInFlight; }
int getNumWritesInFlight() { return curWritesInFlight; }
int getNumErasesInFlight() { return curErasesInFlight; }

//TODO: more efficient locking
int waitIdleEraseTag() {
	int tag = -1;
	while ( tag < 0 ) {
	pthread_mutex_lock(&flashReqMutex);
		for ( int t = 0; t < NUM_TAGS; t++ ) {
			if ( !eraseTagTable[t].busy ) {
				eraseTagTable[t].busy = true;
				tag = t;
				break;
			}
		}
	pthread_mutex_unlock(&flashReqMutex);
	}
	return tag;
}


//TODO: more efficient locking
int waitIdleWriteBuffer() {
	int tag = -1;
	while ( tag < 0 ) {
	pthread_mutex_lock(&flashReqMutex);
		for ( int t = 0; t < NUM_TAGS; t++ ) {
			if ( !writeTagTable[t].busy) {
				writeTagTable[t].busy = true;
				tag = t;
				break;
			}
		}
	pthread_mutex_unlock(&flashReqMutex);
	}
	return tag;
}



//TODO: more efficient locking
int waitIdleReadBuffer() {
//	int tag = -1;
//	while ( tag < 0 ) {
//	pthread_mutex_lock(&flashReqMutex);
//		for ( int t = 0; t < NUM_TAGS; t++ ) {
//			if ( !readTagTable[t].busy ) {
//				readTagTable[t].busy = true;
//				tag = t;
//				break;
//			}
//		}
//	pthread_mutex_unlock(&flashReqMutex);
//	}
//	return tag;
//
	int tag = -1;
	while (tag<0) {
		pthread_mutex_lock(&flashReqMutex);
		if(!readTagQueue.empty()) {
			tag = readTagQueue.front();
			readTagTable[tag].busy = true;
			readTagQueue.pop();
		}
		pthread_mutex_unlock(&flashReqMutex);
	}
	return tag;
}


void eraseBlock(int bus, int chip, int block, int tag) {
	pthread_mutex_lock(&flashReqMutex);
	curErasesInFlight ++;

	flashStatus[bus][chip][block] = ERASED;
	eraseTagTable[tag].bus = bus;
	eraseTagTable[tag].chip = chip;
	eraseTagTable[tag].block = block;

	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending erase block request with tag=%d @%d %d %d 0\n", tag, bus, chip, block );
	device->eraseBlock(bus,chip,block,tag);
}


void writePage(int bus, int chip, int block, int page, int tag) {
	pthread_mutex_lock(&flashReqMutex);

	curWritesInFlight ++;
	flashStatus[bus][chip][block] = WRITTEN;

	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending write page request with tag=%d @%d %d %d %d\n", tag, bus, chip, block, page );
	device->writePage(bus,chip,block,page,tag);
}

void readPage(int bus, int chip, int block, int page, int tag) {
	pthread_mutex_lock(&flashReqMutex);
	curReadsInFlight ++;
	readTagTable[tag].bus = bus;
	readTagTable[tag].chip = chip;
	readTagTable[tag].block = block;
	readTagTable[tag].page = page;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending read page request with tag=%d @%d %d %d %d\n", tag, bus, chip, block, page );
	device->readPage(bus,chip,block,page,tag);
}


int main(int argc, const char **argv)
{
	testPassed=true;
	fprintf(stderr, "Initializing DMA...\n");

	device = new FlashRequestProxy(IfcNames_FlashRequestS2H);
	FlashIndication deviceIndication(IfcNames_FlashIndicationH2S);
	DmaManager *dma = platformInit();

	fprintf(stderr, "Main::allocating memory...\n");
	
	srcAlloc = portalAlloc(srcAlloc_sz, 0);
	dstAlloc = portalAlloc(dstAlloc_sz, 0);
	srcBuffer = (unsigned int *)portalMmap(srcAlloc, srcAlloc_sz);
	dstBuffer = (unsigned int *)portalMmap(dstAlloc, dstAlloc_sz);

	fprintf(stderr, "dstAlloc = %x\n", dstAlloc); 
	fprintf(stderr, "srcAlloc = %x\n", srcAlloc); 
	printf( "Done initializing hw interfaces\n" ); fflush(stdout);

	ref_dstAlloc = dma->reference(dstAlloc);
	ref_srcAlloc = dma->reference(srcAlloc);

	device->setDmaWriteRef(ref_dstAlloc);
	device->setDmaReadRef(ref_srcAlloc);

	for (int t = 0; t < NUM_TAGS; t++) {
		readTagTable[t].busy = false;
		writeTagTable[t].busy = false;
		int byteOffset = t * FPAGE_SIZE;
		readBuffers[t] = dstBuffer + byteOffset/sizeof(unsigned int);
		writeBuffers[t] = srcBuffer + byteOffset/sizeof(unsigned int);

		readTagQueue.push(t);
	}

	for (int blk=0; blk < BLOCKS_PER_CHIP; blk++) {
		for (int c=0; c < CHIPS_PER_BUS; c++) {
			for (int bus=0; bus< NUM_BUSES; bus++) {
				flashStatus[bus][c][blk] = UNINIT;
				badBlockTable[bus][c][blk].eraseIssued = false;
			}
		}
	}

	for (int t = 0; t < NUM_TAGS; t++) {
		for ( unsigned int i = 0; i < FPAGE_SIZE/sizeof(unsigned int); i++ ) {
			readBuffers[t][i] =  0xEEEE0000 + i;
			writeBuffers[t][i] = 0xBBBB0000 + i;
		}
	}

	long actualFrequency=0;
	long requestedFrequency=1e9/5;
	int status = setClockFrequency(0, requestedFrequency, &actualFrequency);
	fprintf(stderr, "Requested Freq: %5.2f, Actual Freq: %5.2f, status=%d\n"
			,(double)requestedFrequency*1.0e-6
			,(double)actualFrequency*1.0e-6,status);

	device->start(0);
	device->setDebugVals(0,0); //flag, delay

	device->debugDumpReq(0);
	device->debugDumpReq2(0);
	sleep(1);

	timespec start, now;
	clock_gettime(CLOCK_REALTIME, & start);

#if defined(WRITE)
	printf( "WRITE PAGES STARTED!\n" ); fflush(stdout);
	for (unsigned int lpa=0; lpa < (SEGNUM<<14); lpa++) {
		if (lpa%(1<<6) == 0){
			fprintf(stderr, "# %d\n", lpa/(1<<6));
			usleep(100);
		}

		unsigned int bus, chip, blk, page;
		bus = lpa & 7;
		chip = (lpa >> 3) & 7;
		blk = (lpa >> 14) + BLKOFFSET;
		page = (lpa >> 6) & 0xFF;

		int freeTag = waitIdleWriteBuffer();
		writeBuffers[freeTag][0] = hashAddrToData(bus, chip, blk, 0);
		portalCacheFlush(srcAlloc, writeBuffers[freeTag], FPAGE_SIZE, 1); // should be flushed

		writePage(bus, chip, blk, page, freeTag);
	}

	printf( "WRITE PAGES FINISHED!\n" ); fflush(stdout);
#endif

#if defined(READ)

	printf( "READ MANY PAGES STARTED!\n" ); fflush(stdout);
	for (unsigned int lpa=0; lpa < (SEGNUM<<14); lpa++) {
		unsigned int bus, chip, blk, page;
		bus = lpa & 7;
		chip = (lpa >> 3) & 7;
		blk = (lpa >> 14) + BLKOFFSET;
		page = (lpa >> 6 ) & 0xFF;

		readPage(bus, chip, blk, page, waitIdleReadBuffer());


// 		if (lpa%(READ_WAIT) == ((READ_WAIT)-1))
// 		{
// 			usleep(100);
// //			int elapsed = 0;
// //			while (true) {
// //				usleep(100);
// //				if(elapsed == 0) {
// //					elapsed = 10000;
// //					fprintf(stderr, "Current lpa = %u \n", lpa);
// //				//	device->debugDumpReq2(0);
// //				} else {
// //					elapsed--;
// //				}
// //
// //				if (getNumReadsInFlight() == 0) break;
// //			}
// 		}
	}

	printf( "READ PAGES FINISHED!\n" ); fflush(stdout);
#endif

	clock_gettime(CLOCK_REALTIME, & now);

	int elapsed = 0;
	while (true) {
		usleep(100);
		if (elapsed == 0) {
			elapsed=10000;
			device->debugDumpReq(0);
			device->debugDumpReq2(0);
		}
		else {
			elapsed--;
		}
		if ( getNumReadsInFlight() == 0 ) break;
	}
	fprintf(stderr, "LOG: finished reading from page! %f\n", timespec_diff_sec(start, now) );

	device->debugDumpReq(0);
	device->debugDumpReq2(0);

	sleep(2);
}
