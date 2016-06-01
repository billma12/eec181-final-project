#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <ctype.h>


#define HW_REGS_BASE 0xC0000000
#define HW_REGS_SPAN 0x40000000
#define HW_REGS_MASK HW_REGS_SPAN - 1
#define ALT_LWFPGALVS_OFST 0xFF200000
#define H2F_AXI_OFST 0xC0000000 


//----------------- Function Prototypes ----------------------//

void init_sdram(void*);
void test_data(short*,int);
float sigmoid(float);
short step(short);
void layer1_calc(short* b1, short*w1, short *layer1, short* td, void * sdram_ptr, int* ready, int* done);
void layer2_calc(short* b2, short*w2, short* layer1, short* layer2);
void layer3_calc(float *wf, short* layer2, float* layer3);
int accuracy(float * layer3, int * labels, int k);
void labels_sdram(int * labels);
void reset_layers(short* layer1, short* layer2, float* layer3);
short negate(short weight);

//-------------------- Main -----------------------------//

int main(void){

   void *virtual_base;
    int fd;
    void * sdram;
    int * ready, * done;

    if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 ) {
    printf( "ERROR: could not open \"/dev/mem\"...\n" );
    return( 1 );
    }

    virtual_base = mmap(NULL, HW_REGS_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, HW_REGS_BASE);

    if( virtual_base == MAP_FAILED ) {
    printf( "ERROR: mmap() failed...\n" );
    close( fd );
    return( 1 );
    }

    sdram = virtual_base + ((unsigned long)(H2F_AXI_OFST + 0x00) & (unsigned long)(HW_REGS_MASK)); 

    ready = virtual_base + ((unsigned long)(ALT_LWFPGALVS_OFST + 0x90) & (unsigned long)(HW_REGS_MASK));

    done = virtual_base + ((unsigned long)(ALT_LWFPGALVS_OFST  + 0x80) & (unsigned long)(HW_REGS_MASK));


    *ready = 0; //initialize ready

    //------------------ pointer stuff -----------------//
    short * b1,*b2,*w1,*w2;
    short * layer1, *layer2, *td;

    float * wf, *layer3;
    int * labels;

    b1 = (short*)sdram;
    b2 = (short*)sdram + 200;
    w1 = (short*)sdram + 400;
    w2 = (short*)sdram + 39600;
    wf = (float*)sdram + 79600;

    layer1 = (short*)sdram + 200000;
    layer2 = (short*)sdram + 200200;
    layer3 = (float*)sdram + 200400;

    td = (short*)sdram + 150000; 
    labels = (int *)sdram + 400000;
   

    //-------------user input ---------------------// 
    int NUM_IMG;
    printf("how many images do you want to test: ");
    scanf("%d", &NUM_IMG);

    int k;
    int correct = 0;
    int i,j;
    
    //----------- start clock -----------------//
    clock_t start_init, start;
    float elapsed_init, elapsed;

    init_sdram(sdram);
    labels_sdram(labels); //comebine this to init_sdram later
  
    start = clock();

    //-----neural network-----//
    for(k = 1; k <= NUM_IMG; k++){
       
        test_data(td, k); // which image
       
        reset_layers(layer1,layer2,layer3);
        layer1_calc(b1,w1,layer1,td,sdram, ready, done);
        layer2_calc(b2,w2,layer1,layer2);
        layer3_calc(wf,layer2,layer3);

   
        if(accuracy(layer3, labels, k))
            correct++;
   }

    elapsed= ((float)(clock()-start))/CLOCKS_PER_SEC;
    //----------- end clock -------------------//

    float percent = (float)correct/NUM_IMG;
    printf("-----------------------------------\n\n");
    printf("%d out of %d correct. %f\n", correct, NUM_IMG, percent);
    printf("Time per sample: %f seconds\n\n\n", elapsed/NUM_IMG);
    
    return 0;
}//main()


void reset_layers(short* layer1, short* layer2, float* layer3){
    
    int i; 
    for(i=0; i< 200; i++){
        *(layer1 + i) = 0;
        *(layer2 + i) = 0;

	if(i<10) *(layer3 + i) = 0.0;
    }
}

void labels_sdram(int * labels){
    FILE * fd;
    int j;
   
    //printf("in labels_sdram\n"); 
    fd = fopen("samples400/labels.txt", "r");
    
    int value;
    if(fd == NULL){
        printf("labels fopen error");
        exit(1);
    }
    for(j = 0; j < 400; j++){ 
        fscanf(fd, "%d", &value);
        *(labels + j) = value;
    }
    fclose(fd);

    //print out labels
    //for(j = 0; j < 400; j++)
    //    printf("%d ", *(labels + j));
}

int accuracy(float * layer3, int * labels, int k){

    float max;
    int index;
    int i;

    max = 0;
    for(i=0; i < 10; i++){
        if(*(layer3 + i) > max){
            index = i;
            max = *(layer3 + i);
        }
    } 

    if((index+1) == *(labels + (k-1))){
	printf("\n");
        return 1;
    }
    else{
	printf(" Actual: %d. Predicted: %d\n", *(labels +(k-1)), index+1);
        return 0; 
    }
}

short negate(short weight)
{
	return (weight * -1) + (2 * (weight - 8));
    //this should turn variable weight into 2s complement 
    //e.g if weight is 0000_000_0000_1011 that is 13. 
    //But we want 1111_1111_1111_1011, which is -3 and the actual weight we want
}

void layer1_calc(short* b1, short*w1, short *layer1, short* td, void* sdram_ptr, int* ready, int* done){

    int i,j;

/*
    for(i=0; i<200; i++){
        for(j=0; j<784; j++){ 
            if(*(td + j) != 0.0)
                *(layer1 + i) += *(w1 + i*784 + j); 
        }
        *(layer1 + i) += *(b1 + i);
        *(layer1 + i) = step(*(layer1 + i));
    }
*/

/*
    short *img1, *img2, *img3, *img4, *img_temp;
    short *w5, *w2, *w3, *w4, *w1_temp;

    img1 = (short*) sdram_ptr + 500000;
    img2 = (short*) sdram_ptr + 500001;
  img3 = (short*) sdram_ptr + 500002;
  img4 = (short*) sdram_ptr + 500003;
  img_temp = (short*) sdram_ptr + 500004;
  w5 = (short*) sdram_ptr + 500005;
  w2 = (short*) sdram_ptr + 500006;
  w3 = (short*) sdram_ptr + 500007;
  w4 = (short*) sdram_ptr + 500008;
  w1_temp = (short*) sdram_ptr + 500009;
*/

/*
    short img1, img2, img3, img4, img_temp;
    short w5, w2, w3, w4, w1_temp;
    
    for(i=0;i<200;i++){
        for(j=0; j<196; j++){
            
                    if(*(td + j) != 0){ //if 4 straight 0 pixels, we can skip
                        
                        img_temp = *(td + j);                        
                        w1_temp = *(w1 + 196*i + j);

                        img1 = img_temp & 0x000F;
                        img2 = (img_temp & 0x00F0) >> 4;
                        img3 = (img_temp & 0x0F00) >> 8;
                        img4 = (img_temp & 0xF000) >> 12;
                        
                        
                        w5 = w1_temp & 0x000F;
                        if(w5 > 7) w5 = negate(w5);
                        
                        w2 = (w1_temp & 0x00F0) >> 4;
                        if(w2 > 7) w2 = negate(w2);
                        
                        w3 = (w1_temp & 0x0F00) >> 8;
                        if(w3 > 7) w3 = negate(w3);
                        
                        w4 = (w1_temp & 0xF000) >> 12;
                        w4 = 0x000F & w4; //need to mask w4 once more probably
                        if(w4 > 7) w4 = negate(w4);
                    
                        if(img1 != 0) *(layer1 + i) += w5; 
                        if(img2 != 0) *(layer1 + i) += w2;
                        if(img3 != 0) *(layer1 + i) += w3;
                        if(img4 != 0) *(layer1 + i) += w4;
                    }
        }
    }

*/
	*ready = 1;while(*done == 0){}*ready = 0;


	//printf("\n");for(i = 0; i <200; i++)printf("% hd ", *(layer1 + i));	


    for(i=0; i< 200; i++){
        *(layer1 + i) += *(b1 + i);
        *(layer1 + i) = step(*(layer1 + i));
    }
}


void layer2_calc(short* b2, short*w2, short* layer1, short* layer2){
    
    int i,j;
    
    for(i=0; i<200; i++){
        for(j=0; j<200; j++){ 
            if(*(layer1 + j) != 0)
                *(layer2 + i) += *(w2 + i*200 + j); 
        }
        *(layer2 + i) += *(b2 + i);
        *(layer2 + i) = step(*(layer2 + i));
    }
    //print layer2
    //        for(i = 0; i <200; i++)
    //                printf("%hd ", *(layer2 + i));

}


void layer3_calc(float *wf, short* layer2, float* layer3){
    
    int i,j;
    
    for(i=0; i<10; i++){
        for(j=0; j<200; j++){ 
            if(*(layer2 + j) != 0)
                *(layer3 + i) += *(wf + i*200 + j); 
        }
        *(layer3 + i) = sigmoid(*(layer3 + i));
    }
    //print layer3
    //        for(i = 0; i <10; i++)
    //            printf("%f ", *(layer3 + i));
}


void test_data(short* testdata, int j){
 
    FILE * fd; 
    char img[80];
 
    sprintf(img, "samples400/%d.txt", j); 

    printf("file is %s", img);

    fd = fopen(img, "r");

    if(fd == NULL){
        printf("fopen error %d", j);
        exit(1);
    }

/*    
    float num;

    for(j = 0;j<784;j++){
        fscanf(fd, "%f", &num);
        /(testdata + j) = num;

        if(num != 0.0)
            printf("1 ");
        else
            printf("0 ");
    } 

    printf("\n\n");
*/

    //Compress TD for FPGA
    
    int k = 0;
    int i = 0;
    short value = 0;
    short temp = 0;
    float fromImg = 0;
    int counter = 3;
    short zero = 0;
    short one = 1;
    
    for(k = 0; k <784; k++){ 
        fscanf(fd, "%f", &fromImg);

        if(fromImg != 0.0)
            value = one;
        else
            value = zero;

        value = value & 0x000F;
        temp += (value << (counter*4)); 

        if (counter == 0){
            *(testdata +  i) = temp; 
            value = 0;
            temp = 0;
            counter = 3;
            i++;
        }     
        else{
            counter--;
        }
    }


    fclose(fd);

    //print test_data
//   for(j = 0; j<196;j++)    printf("%hd ", *(testdata + j)); printf("\n\n\n\n");
    
}

void init_sdram(void* ptr){

    FILE *fd;
    short num;
    int i = 0, j = 0;
    printf("\n\nInitializing SDRAM w/ weights and biases...\n");
    
    //--------------- BIAS 1 ----------------//

    i = 0;
    //printf("bias 1 base: %d \n", i);
    fd = fopen("weights_bias/b1.txt", "r");

    if(fd == NULL){
        printf("b1 fopen error");
        exit(1);
    }
    while(fscanf(fd,"%hd", &num) == 1){
        *((short*)ptr + i) = num;
        i++;
    }
    fclose(fd);
   
    //--------------- BIAS 2 ----------------//

    i = 200;
    //printf("bias 2 base: %d \n", i);
    fd = fopen("weights_bias/b2.txt", "r");
    if(fd == NULL){
        printf("b2 fopen error");
        exit(1);
    }
    while(fscanf(fd,"%hd", &num) == 1){
        *((short*)ptr + i) = num;
        i++;
    }
    fclose(fd);

/*    //--------------- WEIGHT 1 ----------------//
    i = 400; 
    printf("weight 1 base: %d \n", i);
    fd = fopen("weights_bias/w1.txt", "r");
    if(fd == NULL){
        printf("w1 fopen error");
        exit(1);
    }
    while(fscanf(fd, "%hd", &num) == 1){
        *((short*)ptr + i) = num;
        i++;
    }
    fclose(fd);
*/
    //------------- Weight 1 Compressed -----------//

    i = 400;
    //printf("weight 1 base: %d \n", i);
    fd = fopen("weights_bias/w1.txt", "r");
    if(fd == NULL){
        printf("w1 fopen error");
        exit(1);
    }

    int k= 0;
    short temp = 0;
    short fromW1 = 0;
    int counter = 3;
    //int sdramIndex = 400;
   
    for(k = 0; k < 784*200; k++){
        fscanf(fd, "%hd", &fromW1);

        fromW1 = fromW1 & 0x000F;  
        temp += (fromW1 << (counter*4));

        if(counter == 0){
            *((short*)ptr + i) = temp;
            i++;
            temp = 0;
            counter = 3;
        }
        else{
            counter--;
        }
    }

    fclose(fd);

    //for(i=0; i<200; i++){ for(j=0; j<196; j++)printf("%hd ", *((short*)ptr + 400 + i*196 + j));printf("\n\n");}

    //--------------- WEIGHT 2 ----------------//
    i = 39600;
    //printf("weight 2 base: %d \n", i);
    fd = fopen("weights_bias/w2.txt", "r");
    if(fd == NULL){
        printf("w2 fopen error");
        exit(1);
    }
    while(fscanf(fd, "%hd", &num) == 1){
        *((short*)ptr + i) = num;
        i++;
    }
    fclose(fd);
    
    //--------------- WEIGHT FINAL ----------------//
    i = 79600;
    float num2;
    //printf("weight final base: %d \n", i);

    fd = fopen("weights_bias/wf_32.txt", "r"); //final weight is 32 bits to maintain accuracy
    if(fd == NULL){
        printf("wf fopen error");
        exit(1);
    }
    while(fscanf(fd, "%f", &num2) == 1){
        *((float*)ptr + i) = num2;
        i++;
    }
    fclose(fd);
 
    //print wf
    /*   
     for(i = 0; i<10; i++){
       for(j = 0; j<200; j++){
                printf("%f ", *(wf + i*200 + j));
           }
       printf("\n\n");
        }
    */

    //--------------- print --------------------------// 
    //printf("number of values written to sdram: %d\n\n", i); 

   printf("Done Initializing SDRAM\n\n\n");
} 

float sigmoid(float value){
    return 1/(1+exp(-value));
}

short step(short value){
    return (value > 0) ? 1: 0;
}
