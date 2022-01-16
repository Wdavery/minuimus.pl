#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "zlib.h"
#include "zopfli/zlib_container.h"
//#define MAX_UNCOMPRESSED 1024*1024*10


int unFakeGrey(uint32_t len, uint8_t *subpixels); //Identifies 'fake grey' - 24-bit RGB images that are really greyscale, and thus can be converted to 8-bit.

int main(int argc, char *argv[]){

  if(argc<2){
    printf("  Usage: minuimus_def_helper <file> [mode]\nTakes a raw DEFLATE stream in a file, recompress with Zopfli, writes it out. Not much to it.\n         This is a helper program used by Minuimus.pl for processing PDF files. Modes other than 0 should only be touched by people very familiar with PDF's internal image representation.\n");
//    printf("  Alternative: minuimus_def_helper <file> [offset-len] ... [offset-len]\n             In this mode, operates on multiple independent DEFLATE streams at once.\n);
    return(0);
  }
  int operating_mode=0; //0: Default, optimise DEFLATE stream.
                        //1: Attempt RGB to Y conversion. This is possible only under very specific conditions.
                        //   Note that in this mode, a return value of 2 indicates that conversion was successful.
  if(argc>2){
    operating_mode=atoi(argv[2]);
  }
  FILE *input_file=fopen(argv[1],"rb");
  if(!input_file){
    printf("  minuimus_def_helper: Unable to open input file.\n");
    return(-1);
  }
  fseek(input_file, 0,SEEK_END);
  off_t filesize=ftello(input_file);
  fseek(input_file, 0, SEEK_SET);
  void *loadedfile=malloc(filesize);
  if(!loadedfile){
    fprintf(stderr, "minuimus_def_helper: Failed to allocate memory when reading file.\n");
    return(-1);
  }
  size_t ret=fread(loadedfile, 1, filesize, input_file);
  if(ret!=filesize){
    fprintf(stderr, "minuimus_def_helper: Failed to read file into memory.\n");
    return(-1);
  }
  fclose(input_file);
  uint32_t uncompressed_buffer_len=filesize*20;
  if(uncompressed_buffer_len<1024*1024*25)
     uncompressed_buffer_len=1024*1024*25;
  void *decompressed=malloc(uncompressed_buffer_len);
  if(!decompressed){
      fprintf(stderr,"Unable to allocate scratch buffer. Most likely insufficient free memory.\n");
      return(-1);
  }
//  uint8_t decompressed[MAX_UNCOMPRESSED];
  uLongf destLen=uncompressed_buffer_len;
  int err=uncompress(decompressed, &destLen, loadedfile, filesize);
  if(err){
    if(err==Z_BUF_ERROR)
      fprintf(stderr,"DEFLATE stream too long for allocated memory.\n");
    if(err==Z_DATA_ERROR)
      fprintf(stderr,"DEFLATE stream appears corrupt..\n");
    if(err==Z_MEM_ERROR)
      fprintf(stderr,"Insufficient memory.\n");
//    free(decompressed);
    return(-1);
  }
  int isFakeGrey=0;
  if(operating_mode==1){
    isFakeGrey=unFakeGrey(destLen, decompressed);
    if(isFakeGrey){
      destLen=destLen/3;
    }
  }
  ZopfliOptions options;
  ZopfliInitOptions(&options);
  uint8_t *zopfli_output=0;
  size_t zopfli_size=0;
  void *recompressed;
  size_t newLen=0;
  ZopfliZlibCompress(&options, decompressed, destLen, (unsigned char**)&recompressed, &newLen);
  if(!newLen){
    return(1);
  }
  if(newLen>=filesize) //No saving.
    return(0);

  //All recompressed! Now to write it back out again.

  FILE *outfile=fopen(argv[1], "wb");
  if(!outfile){
    printf("  minuimus_def_helper: Unable to open output file.\n");
    return(-1);
  }
  fwrite(recompressed, 1, newLen, outfile);
  fclose(outfile);
  if(isFakeGrey)
    return(2);
  return(0);
}

int unFakeGrey(uint32_t len, uint8_t *subpixels){
  if(len % 3)
    return(0); //Odd, as all RGB images should be a multiple of three.
  uint32_t pos;
  for(pos=0;pos<len;pos+=3){
    if((subpixels[pos] != subpixels[pos+1]) || (subpixels[pos] != subpixels[pos+2]))
      return(0);
  }
  uint32_t pixels=len/3;
  for(pos=0;pos<pixels;pos+=1){
     subpixels[pos]=subpixels[pos*3];
  }
  return(1);
}
