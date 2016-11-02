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

#include "FlashIndication.h"
#include "FlashRequest.h"

//#define FPAGE_SIZE (8192*2)
//#define FPAGE_SIZE_VALID (8224)
#define FPAGE_SIZE (8192)
#define FPAGE_SIZE_VALID (8192)
#define NUM_TAGS 64//128

// for Table 
#define NUM_BLOCKS 4096
#define NUM_SEGMENTS NUM_BLOCKS
#define NUM_CHANNELS 8
#define NUM_CHIPS 8
#define NUM_LOGBLKS (NUM_CHANNELS*NUM_CHIPS)
#define NUM_PAGES_PER_BLK 256

typedef enum {
	UNINIT,
	ERASED,
	WRITTEN
} FlashStatusT;

typedef struct {
	bool busy;
	int lpa;
} TagTableEntry;

FlashRequestProxy *device;

pthread_mutex_t flashReqMutex;
pthread_cond_t flashFreeTagCond;

//8k * 128 (Actually using 8 KB per page)
size_t dstAlloc_sz = FPAGE_SIZE * NUM_TAGS * sizeof(unsigned char);
size_t srcAlloc_sz = FPAGE_SIZE * NUM_TAGS * sizeof(unsigned char);

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
FlashStatusT flashStatus[NUM_SEGMENTS*NUM_PAGES_PER_BLK*NUM_LOGBLKS];

size_t blkmapAlloc_sz = sizeof(uint16_t) * NUM_SEGMENTS * NUM_LOGBLKS;
int blkmapAlloc;
unsigned int ref_blkmapAlloc;
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

unsigned int hashAddrToData(int lpa, int word) {
	int seg = lpa >> 14;
	int logblk = lpa | 0x3F;

	// [seg][logblk-6bit][word-12bit]
	return (seg<<18) + (logblk<<12) + word;
}

bool checkReadData(int tag) {
	TagTableEntry e = readTagTable[tag];
    bool pass = true;

	unsigned int goldenData;
	if (flashStatus[e.lpa]==WRITTEN) {
		int numErrors = 0;
		for (unsigned int word=0; word<FPAGE_SIZE_VALID/sizeof(unsigned int); word++) {
			goldenData = hashAddrToData(e.lpa, word);
			if (goldenData != readBuffers[tag][word]) {
				fprintf(stderr, "LOG: **ERROR: read data mismatch! tag=%d, lpa=%d, word=%d, Expected: %x, read: %x\n", tag, e.lpa, word, goldenData, readBuffers[tag][word]);
				numErrors++;
				pass = false;
				break;
			}
		}

		if (numErrors==0) {
			fprintf(stderr, "LOG: Read data check passed on tag=%d!\n", tag);
		}
	}
	else if (flashStatus[e.lpa]==ERASED) {
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

class FlashIndication: public FlashIndicationWrapper {
	public:
		FlashIndication(unsigned int id) : FlashIndicationWrapper(id){}

		virtual void readDone(unsigned int tag, unsigned int status) {
//			bool tempPassed = true;
			printf("LOG: readdone: tag=%d inflight=%d status=%d\n", tag, curReadsInFlight, status );
			fflush(stdout);

			//check
//			tempPassed = checkReadData(tag);

			pthread_mutex_lock(&flashReqMutex);
			curReadsInFlight --;

//			if ( tempPassed == false ) {
//				testPassed = false;
//				printf("LOG: **ERROR: check read data failed @ tag=%d\n",tag);
//			}
//			if ( curReadsInFlight < 0 ) {
//				fprintf(stderr, "LOG: **ERROR: Read requests in flight cannot be negative %d\n", curReadsInFlight );
//				curReadsInFlight = 0;
//			}
			if ( readTagTable[tag].busy == false ) {
				fprintf(stderr, "LOG: **ERROR: received unused buffer read done (duplicate) tag=%d\n", tag);
				testPassed = false;
			}
			readTagTable[tag].busy = false;

			pthread_mutex_unlock(&flashReqMutex);
		}

		virtual void writeDone(unsigned int tag, unsigned int status) {
			printf("LOG: writedone: tag=%d inflight=%d\n", tag, curWritesInFlight );
			fflush(stdout);
			pthread_mutex_lock(&flashReqMutex);
			curWritesInFlight --;
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
			printf("LOG: eraseDone, tag=%d, status=%d\n", tag, status); fflush(stdout);
			if (status != 0) {
				fprintf(stderr, "LOG: **ERROR: Possible Bad Block with tag = %d\n", tag);
			}
			pthread_mutex_lock(&flashReqMutex);
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

		virtual void uploadDone () {
			fprintf(stderr, "Map Upload(Host->FPGA) done!\n");
		}

		virtual void downloadDone () {
			fprintf(stderr, "Map Download(FPGA->Host) done!\n");
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
			if ( !writeTagTable[t].busy) {
				writeTagTable[t].busy = true;
				tag = t;
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
			if ( !readTagTable[t].busy ) {
				readTagTable[t].busy = true;
				tag = t;
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
	flashStatus[lpa] = WRITTEN;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending write page request with tag=%u @%u\n", tag, lpa );
	device->writePage(tag, lpa, tag * FPAGE_SIZE);
}

void readPage(uint32_t tag, uint32_t lpa) {
	pthread_mutex_lock(&flashReqMutex);
	curReadsInFlight ++;
	readTagTable[tag].lpa = lpa;
	pthread_mutex_unlock(&flashReqMutex);

	if ( verbose ) fprintf(stderr, "LOG: sending read page request with tag=%u @%u\n", tag, lpa );
	device->readPage(tag, lpa, tag*FPAGE_SIZE);
}

int readFTLfromFile (const char* path, void* ptr) {
	FILE *fp;
	fp = fopen(path, "r");

	if (fp) {
		size_t read_size = fread( ptr, blkmapAlloc_sz*2, 1, fp);
		fclose(fp);
		if (read_size == 0)
		{
			fprintf(stderr, "error reading %s\n", path);
			return -1;
		}
	} else {
		fprintf(stderr, "error reading %s: file not exist\n", path);
		return -1;
	}

	return 0; // success
}

int writeFTLtoFile (const char* path, void* ptr) {
	FILE *fp;
	fp = fopen(path, "w");

	if (fp) {
		size_t write_size = fwrite( ptr, blkmapAlloc_sz*2, 1, fp);
		fclose(fp);
		if (write_size==0)
		{
			fprintf(stderr, "error writing %s\n", path);
			return -1;
		}
	} else {
		fprintf(stderr, "error writing %s: file not exist\n", path);
		return -1;
	}

	return 0; // success
}

int main(int argc, const char **argv)
{
	testPassed=true;

	fprintf(stderr, "Initializing Connectal & DMA...\n");

	device = new FlashRequestProxy(IfcNames_FlashRequestS2H);
	FlashIndication deviceIndication(IfcNames_FlashIndicationH2S);
    DmaManager *dma = platformInit();

	fprintf(stderr, "Main::allocating memory...\n");
	
	// Memory for DMA
	srcAlloc = portalAlloc(srcAlloc_sz, 0);
	dstAlloc = portalAlloc(dstAlloc_sz, 0);
	srcBuffer = (unsigned int *)portalMmap(srcAlloc, srcAlloc_sz); // Host->Flash Write
	dstBuffer = (unsigned int *)portalMmap(dstAlloc, dstAlloc_sz); // Flash->Host Read

	// Memory for FTL
	blkmapAlloc = portalAlloc(blkmapAlloc_sz * 2, 0);
	char *ftlPtr = (char*)portalMmap(blkmapAlloc, blkmapAlloc_sz * 2);
	blkmap      = (uint16_t(*)[NUM_LOGBLKS]) (ftlPtr);  // blkmap[Seg#][LogBlk#]
	blkmgr      = (uint16_t(*)[NUM_CHIPS][NUM_BLOCKS])  (ftlPtr+blkmapAlloc_sz); // blkmgr[Bus][Chip][Block]

	fprintf(stderr, "dstAlloc = %x\n", dstAlloc); 
	fprintf(stderr, "srcAlloc = %x\n", srcAlloc); 
	fprintf(stderr, "blkmapAlloc = %x\n", blkmapAlloc); 
	
	pthread_mutex_init(&flashReqMutex, NULL);
	pthread_cond_init(&flashFreeTagCond, NULL);

	printf( "Done initializing hw interfaces\n" ); fflush(stdout);

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
		eraseTagTable[t].busy = false;

		int byteOffset = t * FPAGE_SIZE;
		readBuffers[t] = dstBuffer + byteOffset/sizeof(unsigned int);
		writeBuffers[t] = srcBuffer + byteOffset/sizeof(unsigned int);
	}

	for (int lpa=0; lpa < NUM_SEGMENTS*NUM_LOGBLKS*NUM_PAGES_PER_BLK; lpa++) {
		flashStatus[lpa] = UNINIT;
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

	printf( "Start!\n" ); fflush(stdout);
	device->start(0);
	device->setDebugVals(0,0); //flag, delay

	device->debugDumpReq(0);
	sleep(1);

	printf( "Read initial FTL table from table.dump.0\n" ); fflush(stdout);
	// Read Initial FTL table
	if (readFTLfromFile("table.dump.0", ftlPtr) != 0) {
		fprintf(stderr, "Read Failure\n");
		return -1;
	}
	printf( "Done reading table.dump.0\n" ); fflush(stdout);

	printf( "MAP Upload to HW!\n" ); fflush(stdout);
	device->uploadMap();
	sleep(1);

	timespec start, now;
	clock_gettime(CLOCK_REALTIME, & start);

//	printf( "Test Write!\n" ); fflush(stdout);
//
//	for (int logblk = 0; logblk < NUM_LOGBLKS; logblk++){
//		// test only 128 segments due to some bad blocks (cannot allocate full 4096 segments)
//		for (int segnum = 0; segnum < 2; segnum++) { // 2 segment only for now
//			// assuming page_ofs = 0
//			int lpa = (segnum<<14) + logblk;
//			int freeTag = waitIdleWriteBuffer();
//
//			// fill write memory
//			for (unsigned int w=0; w<FPAGE_SIZE_VALID/sizeof(unsigned int); w++) {
//				writeBuffers[freeTag][w] = hashAddrToData(lpa, w);
//			}
//
//			writePage(freeTag, lpa);
//		}
//	}
//
//	while (true) {
//		usleep(100);
//		if ( getNumWritesInFlight() == 0 ) break;
//	}
//
//	// read back Map and Save to table.dump.1
//	device->downloadMap(); // read table from FPGA
//	if(writeFTLtoFile("table.dump.0", ftlPtr) != 0) {
//		fprintf(stderr, "Write Failure\n");
//		return -1;
//	}
//	sleep(1);
//	printf( "Done writing table.dump.0\n" ); fflush(stdout);

	printf( "Test Read!\n" ); fflush(stdout);
	
//	for (int logblk = 0; logblk < NUM_LOGBLKS; logblk++){
//		// test only 1024 segments due to some bad blocks (cannot allocate full 4096 segments)
//		for (int segnum = 0; segnum < 1024; segnum++) {
//			// assuming page_ofs = 0
//			int lpa = (segnum<<14) + logblk;
//			readPage(waitIdleReadBuffer(), lpa);
//		}
//	}
	for (int lpa = 0; lpa < 2<<14; lpa++) {
		readPage(waitIdleReadBuffer(), lpa);
	}

	while (true) {
		usleep(100);
		if ( getNumReadsInFlight() == 0 ) break;
	}

//	printf( "Test Erase!\n" ); fflush(stdout);
//	for (int logblk = 0; logblk < NUM_LOGBLKS; logblk++){
//		// test only 1024 segments due to some bad blocks (cannot allocate full 4096 segments)
//		for (int segnum = 0; segnum < 1024; segnum++) {
//			// assuming page_ofs = 0
//			int lpa = (segnum<<14) + logblk;
//			eraseBlock(waitIdleEraseTag(), lpa);
//		}
//	}
//
//	while (true) {
//		usleep(100);
//		if ( getNumErasesInFlight() == 0 ) break;
//	}

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
