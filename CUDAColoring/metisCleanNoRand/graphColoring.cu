#include "graphColoring.h"


__device__ unsigned int numOfConflicts = 0;

//----------------------- SDO improved -----------------------//
//
// Author: Shusen & Pascal
// returns the degree of that node
int __device__ degree(int vertex, int *degreeList){
	return degreeList[vertex];
}



// Author: Shusen & Pascal
// saturation of a vertex
int __device__ saturation(int vertex, int *adjacencyList, int *graphColors, int maxDegree, int start, int end){
	int saturation = 0;	
	int colors[256];
	for (int j=0; j<256; j++)
		colors[j] = 0;
	
	
	for (int i=0; i<maxDegree; i++){
		if (adjacencyList[vertex*maxDegree + i] < start)
			continue;
		
		if (adjacencyList[vertex*maxDegree + i] > end)
			break;
		
		if (adjacencyList[vertex*maxDegree + i] != -1)
			//colors[ graphColors[vertex] ] = 1;			// at each colored set the array to 1
			colors[ graphColors[adjacencyList[vertex*maxDegree + i]] ] = 1;			// at each colored set the array to 1
		else
			break;
	}
	
	
	for (int i=1; i<maxDegree+1; i++)					// count the number of 1's but skip uncolored
		if (colors[i] == 1)
			saturation++;
	
	return saturation;
}




// Author: Shusen & Pascal
// colors the vertex with the min possible color
int __device__ color(int vertex, int *adjacencyList, int *graphColors, int maxDegree, int numColored, int start, int end, int disp){
	int colors[256];
	for (int j=0; j<246; j++)
		colors[j] = 0;
	
	
	if (graphColors[vertex] == 0)
		numColored++;
	
	for (int i=0; i<maxDegree; i++){						// set the index of the color to 1
		
		// Limits color checking to subgraph
		/*
		 if (adjacencyList[vertex*maxDegree + i] < start)
		 continue;
		 
		 if (adjacencyList[vertex*maxDegree + i] > end)
		 break;
		 */
		
		if (adjacencyList[vertex*maxDegree + i] != -1)
			colors[  graphColors[  adjacencyList[vertex*maxDegree + i]  ]  ] = 1;
		else 
			break;
	}
	
	
	for (int i=1; i<maxDegree+1; i++)					// nodes still equal to 0 are unassigned
		if (colors[i] != 1){
			if (disp == 0){
				graphColors[vertex] = i;
				break;
			}
			else
				disp--;
		}
	
	return numColored;
}





// Author: Shusen & Pascal
// does the coloring
__global__ void colorGraph_SDO(int *adjacencyList, int *graphColors, int *degreeList, int sizeGraph, int maxDegree, 
								int *startPartitionListD, int *endPartitionListD)//, int *randomListD)
{
	int start, end, partitionIndex;
	int subGraphSize, numColored = 0;
	int satDegree, max, index;
	int randomCount = 0;
	
	//subGraphSize = sizeGraph/(gridDim.x * blockDim.x);
	//start = (sizeGraph/gridDim.x * blockIdx.x) + (subGraphSize * threadIdx.x);
	//end = start + subGraphSize;
	
	partitionIndex = (blockIdx.x * blockDim.x) + threadIdx.x;
	start = startPartitionListD[partitionIndex];
	end = endPartitionListD[partitionIndex];
	subGraphSize = end - start;
	
	while (numColored < subGraphSize){
		randomCount++;
		randomCount = randomCount%10;
		
		max = -1;
		
		for (int i=start; i<end; i++){
			if (graphColors[i] == 0)			// not colored
			{
				satDegree = saturation(i,adjacencyList,graphColors, maxDegree, start, end);
				
				if (satDegree > max){
					max = satDegree;
					index = i;				
				}
				
				if (satDegree == max){
					if (degree(i,degreeList) > degree(index,degreeList))
						index = i;
				}
				
				
			}
			//numColored = color(index,adjacencyList,graphColors, maxDegree, numColored, start, end, randomListD[partitionIndex*10 + randomCount]);
			numColored = color(index,adjacencyList,graphColors, maxDegree, numColored, start, end, 0);
		}
	}
}



__global__ void colorGraphBis_SDO(int *adjacencyList, int *graphColors, int *degreeList, int sizeGraph, int maxDegree, 
									int *startPartitionListD, int *endPartitionListD)//, int *randomListD)
{
	int start, end, partitionIndex;
	int subGraphSize, numColored = 0;
	int satDegree, max, index;
	int randomCount = 0;
	
	//subGraphSize = sizeGraph/(gridDim.x * blockDim.x);
	//start = (sizeGraph/gridDim.x * blockIdx.x) + (subGraphSize * threadIdx.x);
	//end = start + subGraphSize;
	partitionIndex = (blockIdx.x * blockDim.x) + threadIdx.x;
	start = startPartitionListD[partitionIndex];
	end = endPartitionListD[partitionIndex];
	subGraphSize = end - start;
	
	
	
	
	while (numColored < subGraphSize){
		max = -1;
		randomCount++;
		randomCount = randomCount%10;
		
		for (int i=start; i<end; i++){
			if (graphColors[i] == 0)			// not colored
			{
				satDegree = saturation(i,adjacencyList,graphColors, maxDegree, start, end);
				
				if (satDegree > max){
					max = satDegree;
					index = i;				
				}
				
				if (satDegree == max){
					if (degree(i,degreeList) > degree(index,degreeList))
						index = i;
				}
			}
			
			//numColored = color(index, adjacencyList, graphColors, maxDegree, numColored, start, end, randomListD[partitionIndex*10 + randomCount]);
			numColored = color(index,adjacencyList,graphColors, maxDegree, numColored, start, end, 0);
		}
	}
}



__global__ void conflictSolveSDO(int *adjacencyList, int *conflict, int *graphColors, int *degreeList, 
								int sizeGraph, int maxDegree, int *startPartitionListD, int *endPartitionListD){//, int *randomListD){
	int start, end, index, partitionIndex;
	int subGraphSize, numColored = 0;
	int satDegree, max;
	int randomCount = 0;
	
	//subGraphSize = sizeGraph/(gridDim.x * blockDim.x);
	//start = (sizeGraph/gridDim.x * blockIdx.x) + (subGraphSize * threadIdx.x);
	//end = start + subGraphSize;
	
	partitionIndex = (blockIdx.x * blockDim.x) + threadIdx.x;
	start = startPartitionListD[partitionIndex];
	end = endPartitionListD[partitionIndex];
	subGraphSize = end - start;
	
	
	// Set their color to 0
	for (int i=0; i<numOfConflicts; i++)
		graphColors[conflict[i]-1] = 0;
    
	
    while (numColored < numOfConflicts){
        max = -1;
        randomCount++;
		randomCount = randomCount%10;
        
        for (int i=0; i<numOfConflicts; i++){
			int vertex = conflict[i]-1;
            if (graphColors[vertex] == 0)                        // not colored
            {
				satDegree = saturation(i,adjacencyList,graphColors, maxDegree, start, end);
				
                if (satDegree > max){
                    max = satDegree;
                    index = vertex;                              
                }
				
                if (satDegree == max){
                    if (degree(vertex,degreeList) > degree(index,degreeList))
                        index = vertex;
                }
				
				//numColored = color(index,adjacencyList,graphColors, maxDegree, numColored, start, end, randomListD[partitionIndex*10 + randomCount]);
				numColored = color(index,adjacencyList,graphColors, maxDegree, numColored, start, end, 0);
            }else{
				numColored++;
			}
			
			
        }
    }
}





//----------------------- First Fit Adjacency List -----------------------//
//
// Author: Pascal
// First Fit
__global__ void colorGraph_FF(int *adjacencyListD, int *colors, int size, int maxDegree, int *startPartitionListD, int *endPartitionListD){
	int i, j, start, end, partitionIndex;
	int subGraphSize, numColors = 0;
	
	//subGraphSize = size/(gridDim.x * blockDim.x);
	//start = (size/gridDim.x * blockIdx.x) + (subGraphSize * threadIdx.x);
	//end = start + subGraphSize;
	
	partitionIndex = (blockIdx.x * blockDim.x) + threadIdx.x;
	start = startPartitionListD[partitionIndex];
	end = endPartitionListD[partitionIndex];
	subGraphSize = end - start;
	
	int degreeArray[100];
	for(i=start; i<end; i++)
	{
		for(j=0; j<maxDegree; j++)
			degreeArray[j] = j+1;
		
		
		for (j=0; j<maxDegree; j++){
			int vertexNeigh = i*maxDegree + j;
			
			if (adjacencyListD[vertexNeigh] != -1){
				if (colors[ adjacencyListD[vertexNeigh] ] != 0)
					degreeArray[ colors[adjacencyListD[vertexNeigh]] -1 ] = 0;
			}
			else
				break;
		}
		
		
		for(j=0; j<maxDegree; j++)
			if(degreeArray[j] != 0){
				colors[i] = degreeArray[j];
				break;
			}
		
		if(colors[i] > numColors)
			numColors = colors[i];		
	}
}



//----------------------- Detects conflicts -----------------------//
//





// Author: Peihong
__global__ void conflictsDetection(int *adjacentListD, int *boundaryListD, int *colors, int *conflictD, long size, int boundarySize, int maxDegree){
	int idx = blockIdx.x*blockDim.x + threadIdx.x;
	int i, j;
	
	
	if (idx < boundarySize){
		i = boundaryListD[idx];
		conflictD[idx] = 0;
		for (int k=0; k < maxDegree; k++)
		{
			j = adjacentListD[i*maxDegree + k];
			if (j>i && (colors[i] == colors[j]))
			{
				//conflictD[idx] = min(i,j)+1;	
				conflictD[idx] = i+1;	
				
				colors[i] = 0;				// added!!!!!!!!
			}		
		}
	}
}



// Temporary only: will have to be merged in conflictsDetection as a counting reduction operation!!!
void conflictCount(int *conflictD, int *conflictListD, int boundaryCount){
	int conflictCount = 0;
	
	for (int i=0; i< boundaryCount; i++)
	{
		int node = conflictD[i];
		
		if (node >= 1)
		{
			conflictListD[conflictCount] = node;
			conflictCount++;
		}
	}
	
}

//----------------------- Main -----------------------//

extern "C"
void cudaGraphColoring(int *adjacentList, int *boundaryList, int *graphColors, int *degreeList, int *conflict, int boundarySize, 
						int maxDegree, int graphSize, int passes, int subsizeBoundary, int _gridSize, int _blockSize, 
						int *startPartitionList, int *endPartitionList)//, int *randomList, int numRand)
{
	int *adjacentListD, *colorsD, *conflictD, *boundaryListD, *degreeListD, *conflictListD, *startPartitionListD, *endPartitionListD, *randomListD;     
	int gridsize = ceil((float)boundarySize/(float)subsizeBoundary);
	int blocksize = subsizeBoundary;
	int *numConflicts;
	
	cudaEvent_t start_col, start_confl, stop_col, stop_confl, start_mem, stop_mem;         
    float elapsedTime_memory, elapsedTime_col, elapsedTime_confl; 
	
	
	cout << "In cuda" << endl;
	
	//-------------- memory transfer -----------------!
	cudaEventCreate(&start_mem); 
    cudaEventCreate(&stop_mem); 
    cudaEventRecord(start_mem, 0); 
	
	
	cudaMalloc((void**)&adjacentListD, graphSize*maxDegree*sizeof(int));
	cudaMalloc((void**)&colorsD, graphSize*sizeof(int));
	cudaMalloc((void**)&conflictD, boundarySize*sizeof(int));
	cudaMalloc((void**)&boundaryListD, boundarySize*sizeof(int));
	cudaMalloc((void**)&degreeListD, graphSize*sizeof(int));
	cudaMalloc((void**)&numConflicts, 1*sizeof(int));
	cudaMalloc((void**)&conflictListD, boundarySize*sizeof(int));
	cudaMalloc((void**)&startPartitionListD, _gridSize*_blockSize*sizeof(int));
	cudaMalloc((void**)&endPartitionListD, _gridSize*_blockSize*sizeof(int));
	//cudaMalloc((void**)&randomListD, numRand*sizeof(int));
	
	cout << "Cuda memory alloc done" << endl;
	
	cudaMemcpy(adjacentListD, adjacentList, graphSize*maxDegree*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(colorsD, graphColors, graphSize*sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(boundaryListD, boundaryList, boundarySize*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(degreeListD, degreeList, graphSize*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(startPartitionListD, startPartitionList, _gridSize*_blockSize*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(endPartitionListD, endPartitionList, _gridSize*_blockSize*sizeof(int), cudaMemcpyHostToDevice);
	//cudaMemcpy(randomListD, randomList, numRand*sizeof(int), cudaMemcpyHostToDevice);
	
	cudaMemset(conflictListD, 0, boundarySize*sizeof(int));
	
	cout << "Cuda memory copy done" << endl;
	
	
	cudaEventRecord(stop_mem, 0); 
    cudaEventSynchronize(stop_mem); 
	
	
	
	
	dim3 dimGrid_col(_gridSize);
	dim3 dimBlock_col(_blockSize);
	
	dim3 dimGrid_confl(gridsize);
	dim3 dimBlock_confl(blocksize);
	
	
	
	
	//-------------- Sequential Graph coloring -----------------!
	cudaEventCreate(&start_col); 
    cudaEventCreate(&stop_col); 
    cudaEventRecord(start_col, 0); 
	
	
	//colorGraph_FF<<<dimGrid_col, dimBlock_col>>>(adjacentListD, colorsD, graphSize, maxDegree);				// First Fit
	colorGraph_SDO<<<dimGrid_col, dimBlock_col>>>(adjacentListD, colorsD, degreeListD, 
											graphSize, maxDegree, startPartitionListD, endPartitionListD);//, randomListD);		// SDO improved
	
	
	cudaEventRecord(stop_col, 0); 
    cudaEventSynchronize(stop_col); 
	
	
	
	
	
	for (int times=1; times<passes; times++){
		//-------------- Conflict resolution -----------------!
		cudaEventCreate(&start_confl); 
		cudaEventCreate(&stop_confl); 
		cudaEventRecord(start_confl, 0); 
		
		conflictsDetection<<<dimGrid_confl, dimBlock_confl>>>(adjacentListD, boundaryListD, colorsD, conflictD, graphSize, boundarySize, maxDegree);
		
		cudaEventRecord(stop_confl, 0); 
		cudaEventSynchronize(stop_confl); 
		
		
		cudaEventCreate(&start_col); 
		cudaEventCreate(&stop_col); 
		cudaEventRecord(start_col, 0); 
		
		conflictSolveSDO<<<dimGrid_col, dimBlock_col>>>(adjacentListD, conflictListD, colorsD, degreeListD, graphSize, 
														maxDegree, startPartitionListD, endPartitionListD);//, randomListD);
		
		cudaEventRecord(stop_col, 0); 
		cudaEventSynchronize(stop_col); 
	}
	
	
	cudaEventCreate(&start_confl); 
    cudaEventCreate(&stop_confl); 
    cudaEventRecord(start_confl, 0); 
	
	conflictsDetection<<<dimGrid_confl, dimBlock_confl>>>(adjacentListD, boundaryListD, colorsD, conflictD, graphSize, boundarySize, maxDegree);
	
	cudaEventRecord(stop_confl, 0); 
    cudaEventSynchronize(stop_confl); 
	
	
	
	//-------------- Cleanup -----------------!
	cudaMemcpy(graphColors, colorsD, graphSize*sizeof(int), cudaMemcpyDeviceToHost);
	cudaMemcpy(conflict, conflictD, boundarySize*sizeof(int), cudaMemcpyDeviceToHost);
	
	
	
	cudaEventElapsedTime(&elapsedTime_memory, start_mem, stop_mem); 
	cudaEventElapsedTime(&elapsedTime_col, start_col, stop_col); 
	cudaEventElapsedTime(&elapsedTime_confl, start_confl, stop_confl); 
	
	cout << "GPU timings ~ Memory transfer: " << elapsedTime_memory  << " ms     Coloring: " 
	<< elapsedTime_col << " ms    Conflict: " << elapsedTime_confl << " ms" << endl; 
	
	
	cudaFree(adjacentListD);
	cudaFree(colorsD);
	cudaFree(conflictD);
	cudaFree(boundaryListD);
	cudaFree(startPartitionListD);
	cudaFree(endPartitionListD);
	//cudaFree(randomListD);
}

