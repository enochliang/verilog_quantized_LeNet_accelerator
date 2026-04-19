/* Copyright (c) 2011-2021 Columbia University, System Level Design Group */
/* SPDX-License-Identifier: Apache-2.0 */

#include <stdio.h>
#ifndef __riscv
#include <stdlib.h>
#endif

#include <esp_accelerator.h>
#include <esp_probe.h>
#include <fixed_point.h>

#include "pattern/weight.h"
#include "pattern/golden00.h"
#include "pattern/image00.h"

typedef int32_t token_t;


#define SLD_LENET 0x058
#define DEV_NAME "sld,lenet_rtl"

/* <<--params-->> */

//======================================
// TODO
// Modify these quantization scale to we provided.
const int32_t scale_CONV1 = 102;
const int32_t scale_CONV2 = 197;
const int32_t scale_CONV3 = 224;
const int32_t scale_FC1 = 248;
const int32_t scale_FC2 = 413;
//======================================

static unsigned mem_size;
token_t *mem;

/* Size of the contiguous chunks for scatter/gather */
#define CHUNK_SHIFT 20
#define CHUNK_SIZE BIT(CHUNK_SHIFT)
#define NCHUNK(_sz) ((_sz % CHUNK_SIZE == 0) ?		\
			(_sz / CHUNK_SIZE) :		\
			(_sz / CHUNK_SIZE) + 1)

/* User defined registers */
/* <<--regs-->> */
#define LENET_SCALE_CONV2_REG 0x50
#define LENET_SCALE_CONV3_REG 0x4c
#define LENET_SCALE_CONV1_REG 0x48
#define LENET_SCALE_FC2_REG 0x44
#define LENET_SCALE_FC1_REG 0x40

static int validate_buf()
{

	int i, j;
	int errors = 0;
	int total_errors = 0;
	
	// image
	for(i = 0 ; i < 256 ; i++){
		if(mem[20000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i, mem[20000+i], golden[i]);
			errors++;
		}
		else{
			
			//printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[20000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Image pass!\n");
	else
		printf("===> Conv1 fail!\n");
	total_errors += errors;
	errors = 0;

	// Conv1
	for(i = 256 ; i < 592 ; i++){
		if(mem[20000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-256, mem[20000+i], golden[i]);
			errors++;
		}
		else{
			//printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[20000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Conv1 pass!\n");
	else
		printf("===> Conv1 fail!\n");
	total_errors += errors;
	errors = 0;
	
	// Conv2
	for(i = 592 ; i < 692 ; i++){
		if(mem[20000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-592, mem[20000+i], golden[i]);
			errors++;
		}
		else{
			
			//printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[20000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Conv2 pass!\n");
	else
		printf("===> Conv2 fail!\n");
	total_errors += errors;
	errors = 0;
	
	// Conv3
	for(i = 692 ; i < 722 ; i++){
		if(mem[20000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-692, mem[20000+i], golden[i]);
			errors++;
		}
		else{
			
			//printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[20000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Conv3 pass!\n");
	else
		printf("===> Conv3 fail!\n");
	total_errors += errors;
	errors = 0;

	// FC1
	for(i = 722 ; i < 743 ; i++){
		if(mem[20000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-722, mem[20000+i], golden[i]);
			errors++;
		}
		else{
			
			//printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[20000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> FC1 pass!\n");
	else
		printf("===> FC1 fail!\n");
	total_errors += errors;
	errors = 0;
	
	// FC2
	for(i = 743 ; i < 753 ; i++){
		if(mem[20000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-743, mem[20000+i], golden[i]);
			errors++;
		}
		else{
			
			//printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[20000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> FC2 pass!\n");
	else
		printf("===> FC2 fail!\n");
	total_errors += errors;


	return total_errors;
}


static void init_buf ()
{
	// Weight
	int i, j;
	for(i = 0 ; i < 15760 ; i++){
		mem[i] = weight[i];
	}
	// Image
	for(i = 0 ; i < 256 ; i++){
		mem[20000+i] = image[i];
	}
	
}


int main(int argc, char * argv[])
{
	int i;
	int n;
	int ndev;
	struct esp_device *espdevs;
	struct esp_device *dev;
	unsigned done;
	unsigned **ptable;
	unsigned errors = 0;
	unsigned coherence;

	// Define DRAM size, please refer to spec to know the lease size.
	mem_size = 30000*sizeof(token_t);


	// Search for the device
	printf("Scanning device tree... \n");

	ndev = probe(&espdevs, VENDOR_SLD, SLD_LENET, DEV_NAME);
	if (ndev == 0) {
		printf("lenet not found\n");
		return 0;
	}

	for (n = 0; n < ndev; n++) {

		printf("**************** %s.%d ****************\n", DEV_NAME, n);

		dev = &espdevs[n];

		// Check DMA capabilities
		if (ioread32(dev, PT_NCHUNK_MAX_REG) == 0) {
			printf("  -> scatter-gather DMA is disabled. Abort.\n");
			return 0;
		}

		if (ioread32(dev, PT_NCHUNK_MAX_REG) < NCHUNK(mem_size)) {
			printf("  -> Not enough TLB entries available. Abort.\n");
			return 0;
		}

		// Allocate memory
		mem = aligned_malloc(mem_size);
		printf("  memory buffer base-address = %p\n", mem);

		// Alocate and populate page table
		ptable = aligned_malloc(NCHUNK(mem_size) * sizeof(unsigned *));
		for (i = 0; i < NCHUNK(mem_size); i++)
			ptable[i] = (unsigned *) &mem[i * (CHUNK_SIZE / sizeof(token_t))];

		printf("  ptable = %p\n", ptable);
		printf("  nchunk = %lu\n", NCHUNK(mem_size));

#ifndef __riscv
		for (coherence = ACC_COH_NONE; coherence <= ACC_COH_RECALL; coherence++) {
#else
		{
			
			coherence = ACC_COH_NONE;
#endif
			printf("  --------------------\n");
			printf("  Generate input...\n");
			init_buf();

			// Pass common configuration parameters
			iowrite32(dev, SELECT_REG, ioread32(dev, DEVID_REG));
			iowrite32(dev, COHERENCE_REG, coherence);

#ifndef __sparc
			iowrite32(dev, PT_ADDRESS_REG, (unsigned long long) ptable);
#else
			iowrite32(dev, PT_ADDRESS_REG, (unsigned) ptable);
#endif
			iowrite32(dev, PT_NCHUNK_REG, NCHUNK(mem_size));
			iowrite32(dev, PT_SHIFT_REG, CHUNK_SHIFT);

			// Use the following if input and output data are not allocated at the default offsets
			iowrite32(dev, SRC_OFFSET_REG, 0x0);
			iowrite32(dev, DST_OFFSET_REG, 0x0);

			// Pass accelerator-specific configuration parameters
			/* <<--regs-config-->> */
			
			iowrite32(dev, LENET_SCALE_CONV2_REG, scale_CONV2);
			iowrite32(dev, LENET_SCALE_CONV3_REG, scale_CONV3);
			iowrite32(dev, LENET_SCALE_CONV1_REG, scale_CONV1);
			iowrite32(dev, LENET_SCALE_FC2_REG, scale_FC2);
			iowrite32(dev, LENET_SCALE_FC1_REG, scale_FC1);

			// Flush (customize coherence model here)
			esp_flush(coherence);

			// Start accelerators
			printf("  Start...\n");
			iowrite32(dev, CMD_REG, CMD_MASK_START);

			// Wait for completion
			done = 0;
			while (!done) {
				done = ioread32(dev, STATUS_REG);
				done &= STATUS_MASK_DONE;
			}
			iowrite32(dev, CMD_REG, 0x0);

			printf("  Done\n");
			printf("  validating...\n");

			/* Validation */
			errors = validate_buf();
			if (errors)
				printf("[FAIL] There are some errors QQ\n");
			else
				printf("[PASS] Congratulation! All results are correct\n");
		}
		aligned_free(ptable);
		aligned_free(mem);
	}

	printf("110061644 Liang, Chien-Hsing\n");
	return 0;
}
