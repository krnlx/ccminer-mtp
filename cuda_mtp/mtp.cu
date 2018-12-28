

#include "argon2ref/argon2.h"
#include "merkletree/mtp.h"

#include <unistd.h>
#include "miner.h"
#include "cuda_helper.h"
#define memcost 4*1024*1024

extern void mtp_cpu_init(int thr_id, uint32_t threads);

extern uint32_t mtp_cpu_hash_32(int thr_id, uint32_t threads, uint32_t startNounce);

extern void mtp_setBlockTarget(int thr_id,const void* pDataIn, const void *pTargetIn, const void * zElement);
extern void mtp_fill(uint32_t d, const uint64_t *Block, uint32_t offset, uint32_t datachunk);
extern void mtp_fill_1b(int thr_id,uint64_t *Block, uint32_t block_nr);
extern void mtp_i_cpu(int thr_id, uint32_t *block_header);
extern uint8_t *mtp_init3(argon2_instance_t *instance, int thr_id);

#define HASHLEN 32
#define SALTLEN 16
#define PWD "password"
//#define MTP_L 64

static bool init[MAX_GPUS] = { 0 };
static __thread uint32_t throughput = 0;
static uint32_t JobId[MAX_GPUS] = {0};
//static  MerkleTree::Elements TheElements[MAX_GPUS];
static  MerkleTree ordered_tree[MAX_GPUS];
static  unsigned char TheMerkleRoot[MAX_GPUS][16];
static  argon2_context context[MAX_GPUS];
static argon2_instance_t instance[MAX_GPUS];


static std::vector<uint8_t*> MEM[MAX_GPUS];


//static pthread_mutex_t work_lock;
//static pthread_barrier_t barrier;
extern "C" int scanhash_mtp(int nthreads, int thr_id, struct work* work, uint32_t max_nonce, unsigned long *hashes_done, struct mtp* mtp)
{
//	if (work_restart[thr_id].restart) return 0;
//	unsigned char TheMerkleRoot[16];
	unsigned char mtpHashValue[32];

//	pthread_mutex_init(&work_lock, NULL);
//	pthread_barrier_init(&barrier, NULL, 1);
int real_maxnonce = UINT32_MAX / nthreads * (thr_id + 1);

//	MerkleTree::Elements TheElements; // = new MerkleTree;
//printf("the job_id from mtp %s\n",work->job_id+8);
	uint32_t *pdata = work->data;
	uint32_t *ptarget = work->target;
	const uint32_t first_nonce = pdata[19];
	int dev_id = device_map[thr_id];;
	if (opt_benchmark)
		ptarget[7] = 0x00ff;

		uint32_t diff = 5;
		uint32_t TheNonce;

	if (!init[thr_id])
	{

		cudaSetDevice(dev_id);
		
		cudaDeviceReset();
		cudaSetDeviceFlags(cudaDeviceScheduleBlockingSync);
//		cudaSetDeviceFlags(cudaDeviceScheduleYield);

//		int intensity = (device_sm[dev_id] >= 500 && !is_windows()) ? 17 : 16;
//		if (device_sm[device_map[thr_id]] == 500) intensity = 15;
		int intensity = 19;
		throughput = cuda_default_throughput(thr_id, 1U << intensity); // 18=256*256*4;
//		throughput =  1024*64;
		if (init[thr_id]) throughput = min(throughput, max_nonce - first_nonce);

		cudaDeviceProp props;
		cudaGetDeviceProperties(&props, dev_id);


		gpulog(LOG_INFO, thr_id, "Intensity set to %g, %u cuda threads", throughput2intensity(throughput), throughput);


		mtp_cpu_init(thr_id, throughput);

		init[thr_id] = true;

	}

	uint32_t _ALIGN(128) endiandata[20];
	((uint32_t*)pdata)[19] = (pdata[20]); // */0x00100000; // mtp version not the actual nonce
//	((uint32_t*)pdata)[19] = 0x1000;

	for (int k = 0; k < 20; k++) 
		endiandata[k] = pdata[k];
	
//	argon2_context context = init_argon2d_param((const char*)endiandata);
//	argon2_instance_t instance;
//	argon2_ctx_from_mtp(&context, &instance);
//printf("coming here\n");


//pthread_mutex_lock(&work_lock);

if (JobId[thr_id]!= work->data[17]){

gpulog(LOG_WARNING, thr_id, "filling memory");
//restart_threads();
//pthread_barrier_wait(&barrier);
if (JobId[thr_id]!=0)
	free_memory(&context[thr_id], (unsigned char *)instance[thr_id].memory, instance[thr_id].memory_blocks, sizeof(block));

//printf("coming here2\n");
	context[thr_id] = init_argon2d_param((const char*)endiandata);
	argon2_ctx_from_mtp(&context[thr_id], &instance[thr_id]);

for(int i=0;i<MEM[thr_id].size();i++)
	free(MEM[thr_id][i]);
//printf("filling memory\n");
//gpulog(LOG_WARNING, thr_id, "filled first blocks on cpu\n");
mtp_fill_1b(thr_id,instance[thr_id].memory[0 + 0].v,0 + 0);
mtp_fill_1b(thr_id,instance[thr_id].memory[0 + 1].v,0 + 1);

mtp_fill_1b(thr_id,instance[thr_id].memory[2 + 0].v,1048576 + 0);
mtp_fill_1b(thr_id,instance[thr_id].memory[2 + 1].v,1048576 + 1);
mtp_fill_1b(thr_id,instance[thr_id].memory[4 + 0].v,2097152 + 0);
mtp_fill_1b(thr_id,instance[thr_id].memory[4 + 1].v,2097152 + 1);
mtp_fill_1b(thr_id,instance[thr_id].memory[6 + 0].v,3145728 + 0);
mtp_fill_1b(thr_id,instance[thr_id].memory[6 + 1].v,3145728 + 1);
mtp_i_cpu(thr_id,instance[thr_id].block_header);

//	MerkleTree::Elements TheElements = mtp_init2(&instance[thr_id], thr_id);
	uint8_t * x =  mtp_init3(&instance[thr_id], thr_id);

//	ordered_tree[thr_id] = MerkleTree(TheElements, true);
      ordered_tree[thr_id] = MerkleTree(x, true);
//	gpulog(LOG_WARNING, thr_id, "filled blocks on GPU\n");

//for(;;);
	JobId[thr_id] = work->data[17];

	MerkleTree::Buffer root = ordered_tree[thr_id].getRoot();
//for(;;);
	std::copy(root.begin(), root.end(), TheMerkleRoot[thr_id]);
	MEM[thr_id]=ordered_tree[thr_id].getMem();
//	mtp_setBlockTarget(0,endiandata,ptarget,&TheMerkleRoot);
	mtp_setBlockTarget(thr_id, endiandata, ptarget, &TheMerkleRoot[thr_id]);

//for(int i=0;i<16;i++)printf("%x ",TheMerkleRoot[thr_id][i]);
//printf("\n");

//for(;;);



/*
const int datachunk = 512;
for (int i=0;i<((uint32_t)memcost/ datachunk) ;i++) {
uint64_t *Truc =(uint64_t *) malloc(128* datachunk*sizeof(uint64_t));
	
	for (int j=0;j<datachunk;j++)
		memcpy(&Truc[128*j],instance[thr_id].memory[datachunk*i+j].v,128*sizeof(uint64_t));

	mtp_fill(thr_id,Truc, i, datachunk);
//	mtp_fill(1, Truc, i, datachunk);
	free(Truc);
}
*/
gpulog(LOG_WARNING, thr_id, "memory filled %d chunks",MEM[thr_id].size());
}

//pthread_mutex_unlock(&work_lock);



	if (work_restart[thr_id].restart) goto TheEnd;
		pdata[19] = first_nonce;
//do  
	{
		int order = 0;
		uint32_t foundNonce;

		*hashes_done = pdata[19] - first_nonce + throughput;
//printf("first nonce %08x thr_id %08x\n", pdata[19],thr_id);

		foundNonce = mtp_cpu_hash_32(thr_id, throughput, pdata[19]);

		uint32_t _ALIGN(64) vhash64[8];
		if (foundNonce != UINT32_MAX)
		{

			block_mtpProof TheBlocksAndProofs[140];
			uint256 TheUint256Target[1];
			TheUint256Target[0] = ((uint256*)ptarget)[0];

			blockS nBlockMTP[MTP_L *2];
			unsigned char nProofMTP[MTP_L * 3 * 353 ];
			
			uint32_t is_sol = mtp_solver(thr_id, foundNonce, &instance[thr_id], nBlockMTP,nProofMTP, TheMerkleRoot[thr_id], mtpHashValue, ordered_tree[thr_id], endiandata,TheUint256Target[0]);

			if (is_sol==1 /*&& fulltest(vhash64, ptarget)*/) {
				int res = 1;
				work_set_target_ratio(work, vhash64);		

				pdata[19] =/*swab32*/(foundNonce);

/// fill mtp structure
				mtp->MTPVersion = 0x1000;
			for (int i=0;i<16;i++) 
				mtp->MerkleRoot[i] = TheMerkleRoot[thr_id][i];
			for (int i = 0; i<32; i++)
				mtp->mtpHashValue[i] = mtpHashValue[i];
			
			for (int j=0;j<(MTP_L * 2);j++)
				for (int i=0;i<128;i++)
				mtp->nBlockMTP[j][i]= nBlockMTP[j].v[i];
                int lenMax =0; 
				int len = 0;

				memcpy(mtp->nProofMTP, nProofMTP, sizeof(unsigned char)* MTP_L * 3 * 353);


//				printf("found a solution, nonce %08x\n",pdata[19]);
//				free_memory(&context, (unsigned char *)instance.memory, instance.memory_blocks, sizeof(block));
//				pthread_mutex_destroy(&work_lock);
				return res;

			} else {
				gpulog(LOG_WARNING, thr_id, "result for %08x does not validate on CPU!", foundNonce);
			}
		}
		work_set_target_ratio(work, vhash64);
/*
		if ((uint64_t)throughput + pdata[19] >= max_nonce) {
			pdata[19] = max_nonce;
			break;
		}
*/
		pdata[19] += throughput;

		if (pdata[19]>=real_maxnonce) {
			gpulog(LOG_WARNING, thr_id, "OUT OF NONCE %x >= %x", pdata[19], real_maxnonce);
			abort();
		}

//		be32enc(&endiandata[19], pdata[19]);
	}   
	//while (!work_restart[thr_id].restart && pdata[19]<0xffffffff && pdata[19]<real_maxnonce);


TheEnd:
//	free_memory(&context, (unsigned char *)instance.memory, instance.memory_blocks, sizeof(block));
	*hashes_done = pdata[19] - first_nonce;

//	ordered_tree.~MerkleTree();
//	TheElements.clear();
//	pthread_mutex_destroy(&work_lock);
	return 0;
}


