//gcc minuimus_swf_helper.c -o minuimus_swf_helper -lz zopfli/deflate.c zopfli/lz77.c zopfli/hash.c zopfli/tree.c zopfli/squeeze.c zopfli/blocksplitter.c zopfli/cache.c zopfli/katajainen.c zopfli/util.c zopfli/zlib_container.c -lm -O3
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "zlib.h"
#include "zopfli/zlib_container.h"
#include<sys/wait.h> 

//#include <lzma.h>
//#include <assert.h>
//#include "easylzma/compress.h"  
void processtags(uint8_t *data, uint32_t *totallen);
void processresource(uint8_t *data, uint32_t len, uint32_t *reduction);
uint32_t load_from_file(uint8_t *dest, char *filename, uint32_t max_size);
int call_external(char *argv[]);
uint32_t counter;

int main (int argc, char *argv[]){

  if (argc != 2 && argc != 4){
    printf("  minuimus_swf_helper is intended to be used by minuimus.pl. But, if you do want to run it manually:\n");
    printf("    minuimus_swf_helper <infile> - Analyse a file without writing any output file.\n");
    printf("    minuimus_swf_helper <command> <infile> [outfile]\n    Command:\n      d - Decompress\n      z - Compress with zopfli.\n");
    printf("    It is permitted to set infile and outfile equal, but remember some flash files will emerge from this program slightly larger.\n");
    exit(1);
  }

  char *inname;
  char overwrite_mode=0;
  if(argc==2)
    inname=argv[1];
  if(argc==4){
    inname=argv[2];
    overwrite_mode=(!strcmp(argv[2],argv[3]));
    if(overwrite_mode)
      printf("  minuimus_swf_helper: Infile == outfile. Will overwrite only if smaller.\n.");
  }
  FILE *infile=fopen(inname, "rb");
  if(!infile){
    fprintf(stderr, "  minuimus_swf_helper: Unable to open input file %s\n", argv[2]);
    exit(1);
  }
  uint8_t header[4]; //SWF header that we need consists of four eight-bit ints, then one  32-bit little-endian int.
  uint32_t ufilesize; //Here's the 32-bit one.
  uint32_t cfilesize;

  if((fread(header, 4, 1, infile) != 1 )||
     (fread(&ufilesize, 4, 1, infile) != 1)){
    fprintf(stderr, "  minuimus_swf_helper: Failed reading input file.\n");
    exit(1);
  }
  fseek(infile, 0, SEEK_END);
  cfilesize=ftell(infile);
  if(header[1] != 'W' || header[2] != 'S'){
    fprintf(stderr, "  minuimus_swf_helper: Opened input file, but it does not appear to be a flash file - header signature not found.\n");
    exit(1);
  }

  if(header[0] != 'F' && header[0] != 'C' && header[0] != 'Z'){
    fprintf(stderr, "  minuimus_swf_helper: Opened input file, but the compression type is not recognised. Probably not a flash file.\n");
    exit(1);
  }
    printf("  minuimus_swf_helper: Opened input SWF %s. Compression type %c, version %u, uncompressed size %u, compressed size %u.\n", inname, header[0], header[3], ufilesize, cfilesize);
  if(header[0] == 'F'  && (cfilesize != ufilesize)){
    fprintf(stderr, "  minuimus_swf_helper: Uncompressed file, but actual file size does not match that in the header. File may be damaged.\n");
    exit(1);
  }
  uint8_t *cdata=malloc(cfilesize-8);
  uint8_t *udata=malloc(ufilesize-8);
  fseek(infile, 8, SEEK_SET);
  size_t ret=fread(cdata, cfilesize-8, 1, infile);
  fclose(infile);
  if(ret != 1){
    fprintf(stderr, "  minuimus_SWf_helper: Unable to read input data.\n");
    exit(1);
  }
  printf("  minuimus_swf_helper: Input data read.\n");

  if(header[0] == 'F')
    memcpy(udata, cdata, cfilesize-8);
  if(header[0] == 'C'){
      if(header[3]<6){
        fprintf(stderr, "  minuimus_swf_helper: Cannot DEFLATE-compress SWF file version <6. (To force version, set the fourth byte to 0x06).\n");
        exit(1);
      }
      uint64_t destLen=ufilesize-8;
      int err=uncompress(udata, &destLen, cdata, cfilesize-8);
      if(err){
        if(err==Z_BUF_ERROR)
          fprintf(stderr,"  minuimus_swf_helper: DEFLATE stream too long for allocated memory. Damaged file?\n");
        if(err==Z_DATA_ERROR)
          fprintf(stderr,"  minuimus_swf_helper: DEFLATE stream appears corrupt. Possible damaged SWF.\n");
        if(err==Z_MEM_ERROR)
          fprintf(stderr,"  minuimus_swf_helper: Insufficient memory.\n");
        exit(1);
      }
  }
  if(header[0] == 'Z'){
    fprintf(stderr, "  minuimus_swf_helper: LZMA compression not yet supported.\n");
    exit(1);
  }

  printf("  minuimus_swf_helper: Decompression successful.\n");

  if(argc==3){
    printf("  minuimus_swf_helper: Tests passed, this appears to be a valid and intact SWF file.\n");
    exit(0);
  }

  ufilesize-=8;
  processtags(udata, &ufilesize);
  ufilesize+=8;
  if(argc==2)
    exit(0);

  size_t newLen=0; //Length of the new output SWF, not including the eight uncompressed header bytes.
  if(argv[1][0]=='d'){
    header[0]='F';
    newLen=ufilesize-8;
    FILE *outfile=fopen(argv[3], "wb");
    if(!outfile){
      fprintf(stderr, "  minuimus_swf_helper: Unable to open output file.\n");
      exit(1);
    }
    fwrite(header, 4, 1, outfile);
    fwrite(&ufilesize, 4, 1, outfile);
    fwrite(udata, newLen, 1, outfile);
    fclose(outfile);
    exit(0);
  }
  if(argv[1][0]=='z'){
    header[0]='C';
    ZopfliOptions options;
    ZopfliInitOptions(&options);
    options.blocksplitting=0;
    size_t compressedlen=cfilesize-8;
    free(cdata);
    printf("  minuimus_swf_helper: Compressing %u bytes with Zopfli.\n", ufilesize-8);
    uint8_t *recompressed;
    ZopfliZlibCompress(&options, udata, ufilesize-8, &recompressed, &newLen);
    printf("  minuimus_swf_helper: Compressed. %lu bytes. (Was %u)\n", newLen+8, cfilesize);
    if(overwrite_mode && (cfilesize<=(newLen+8))){
      printf("  minuimus_swf_helper: No space saving achieved. Exiting without writing output.\n");
      exit(0);
    }
    FILE *outfile=fopen(argv[3], "wb");
    if(!outfile){
      fprintf(stderr, "  minuimus_swf_helper: Unable to open output file.\n");
      exit(1);
    }
    fwrite(header, 4, 1, outfile);
    fwrite(&ufilesize, 4, 1, outfile);
    fwrite(recompressed, newLen, 1, outfile);
    fclose(outfile);
    exit(0);
  }

  if(argv[1][0]=='l'){
    fprintf(stderr, "  minuimus_swf_helper: LZMA output is not yet supported.\n"); //Not for lack of trying, but the SWF spec is a bit vague as to which flavor of LZMA.
    exit(1);
  }
/*    header[0]='Z';
    if(header[3]<13)
      header[3]=13;
   // size_t compressedlen=cfilesize-8;
//    free(cdata);
    printf("  minuimus_swf_helper: Compressing %u bytes with LZMA.\n", ufilesize-8);
    uint8_t *recompressed;
    size_t newLen=0;

  lzma_options_lzma opt_lzma1;
  lzma_lzma_preset(&opt_lzma1, LZMA_PRESET_DEFAULT);

  lzma_filter filters[] = {
    { .id = LZMA_FILTER_LZM1, .options = &opt_lzma1 },
    { .id = LZMA_VLI_UNKNOWN, .options = NULL },
  };

//  if(LZMA_OK != lzma_raw_buffer_encode(filters, NULL, udata, ufilesize-8, cdata, &newLen, cfilesize-8)){
int ret=lzma_stream_buffer_encode (filters, LZMA_CHECK_NONE, NULL, udata, ufilesize-8, cdata, &newLen, ufilesize-8);
  if(LZMA_OK != ret){

      fprintf(stderr, "  minuimus_swf_helper: Error %u in LZMA compression.\n", ret);
      exit(1);
    };
    printf("  minuimus_swf_helper: Compressed. %lu bytes.\n", newLen);
//    cfilesize+=8;
    fwrite(header, 4, 1, outfile);
    fwrite(&ufilesize, 4, 1, outfile);
    fwrite(cdata, newLen, 1, outfile);
    fclose(outfile);
    exit(0);*/

}



void processtags(uint8_t *data, uint32_t *totallen){
  uint16_t header;
  uint16_t tagtype;
  uint32_t taglen;
  //First we need to skip some fields in the header. Easily done, but one of them is variable-length.
  //So it's that, then two uint16_t values. The tag data - what we need - is after that.
  uint8_t bits=(data[0]&0xF8)>>3;
//  printf("  minuimus_swf_helper: RECT bit len %u.\n", bits);
  bits=bits*4;
  if(bits&0x07)
    bits+=8;
  bits=(bits>>3)+1;
//  printf("  minuimus_swf_helper: RECT len %u.\n", bits);
  data+=bits+4;
  uint32_t tagdatalen=*totallen-bits-4; //The length of the tag data.
  uint8_t *abort=data+tagdatalen; //Used to abort in case of a truncated file, which has no end-marker tag.


  uint32_t offset=0;
  do{
    memcpy(&header, data+offset, 2);
    tagtype=(header&0xFFC0)>>6;
    if(tagtype == 0){ //End of file marker.
      return;
    }
    header=header&0x003F;
    if(header<0x3F){ //Short-type tag: Of no interest to this program.
      offset+=header+2;
      continue;
    }
    memcpy(&taglen, data+offset+2, 4);
    uint32_t nextoff=offset+taglen+6;
//    printf("  Tag type %u len %u.\n", tagtype, taglen);
    if(tagtype==21){
      printf("  minuimus_swf_helper: Embedded image resource identified (%u bytes).\n", taglen);
      uint32_t reduction=0;
      processresource(data+offset+8, taglen-2, &reduction);
      if(reduction){
        printf("  minuimus_swf_helper:   Reduced by %u bytes.\n", reduction);
        memcpy(data+nextoff-reduction, data+nextoff, *totallen-nextoff);
        *totallen-=reduction;
        nextoff-=reduction;
        taglen-=reduction;
        memcpy(data+offset+2, &taglen, 4);
      }
    }
    offset=nextoff;
  }while(data+offset<abort);
  fprintf(stderr, "  minuimus_swf_helper: No end tag found. Damaged SWF?\n");
  exit(1);
}

void processresource(uint8_t *data, uint32_t len, uint32_t *reduction){
  //Returns 0 on fail, or the new size otherwise.
  uint8_t badbytes[4]={0xff, 0xd9, 0xff, 0xd8};
  if(!memcmp(data, badbytes, 4)){
    printf("  minuimus_swf_helper:   Patching borderline-standard-compliant JPEG wrapper.\n");
    memcpy(data, data+4, len-4);
    *reduction=4;
    len-=4;
  }
  uint8_t key_jpeg[2]={0xff, 0xd8};
  uint8_t key_png[8]={0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
  uint8_t key_gif[6]={0x47, 0x49, 0x46, 0x38, 0x39, 0x61};
  uint8_t tempfilename[100];
  if(!memcmp(data, key_jpeg, 2)){
    printf("  minuimus_swf_helper:   Identified JPEG resource.\n");
    sprintf(tempfilename, "/tmp/miniumus-swf-temp-%u-%u.jpg", getpid(), counter++);
  }
  else if(!memcmp(data, key_png, 8)){
    printf("  minuimus_swf_helper:   Identified PNG resource.\n");
    sprintf(tempfilename, "/tmp/miniumus-swf-temp-%u-%u.jpg", getpid(), counter++);
  }
  else if(!memcmp(data, key_gif, 6)){
    printf("  minuimus_swf_helper:   Identified GIF resource (Unsupported, ignoring).\n");
    sprintf(tempfilename, "/tmp/miniumus-swf-temp-%u-%u.gif", getpid(), counter++);
    return;
  }
  else{
    printf("  minuimus_swf_helper:   Unknown resource type. Ignoring.\n");
    return;
  }
  FILE *tempfile=fopen(tempfilename, "wb");
  fwrite(data, len, 1, tempfile);
  fclose(tempfile);
  if(!memcmp(data, key_jpeg, 2)){
    char *callparms[6]={ "/usr/bin/jpegoptim", "--all-progressive", "-q", "--strip-com", tempfilename, 0 };
    call_external(callparms);
  }
  if(!memcmp(data, key_png, 8)){
    char *callparms[7]={"/usr/bin/optipng", "-quiet", "-o6", "-nc", "-nb", tempfilename, 0};
    call_external(callparms);
    char *callparms2[5]={"/usr/bin/advdef","-z4","-q", tempfilename, 0};
    call_external(callparms2);
  }
  int newsize=load_from_file(data, tempfilename, len);
  if(!newsize){
    printf("  minuimus_swf_helper:   Optimisation unsuccessful.\n");
    return;
  }
  *reduction+=len-newsize;
//exit(1);	
}

uint32_t load_from_file(uint8_t *dest, char *filename, uint32_t max_size){
  FILE *readfrom=fopen(filename, "rb");
  fseek(readfrom, 0, SEEK_END);
  uint32_t filelen=ftell(readfrom);
  if(filelen>=max_size){
    fclose(readfrom);
    remove(filename);
    return(0);
  }
  fseek(readfrom, 0, SEEK_SET);
  if(fread(dest, filelen, 1, readfrom) != 1){
    fprintf(stderr, "  minuimus_swf_helper:    Failed to read optimised file.\n");
    fclose(readfrom);
    remove(filename);
  }
  fclose(readfrom);
  remove(filename);

  return(filelen);
}

int call_external(char *argv[]) {
  //Not using pipes this time, as minuimus_pdf_helper did. Too many ugly issues involving buffering when I tried that.
  pid_t pid = fork();
  if(pid==-1){
    fprintf(stderr, "  Fork failed calling external program.\n  As the most likely cause of this problem is resource exhaustion, minuimus_swf_helper with now abort in order to free resources.\n  The needs of the many.\n.");
    exit(1);
  }
  if (pid == 0) {
    printf("  minuimus_swf_helper:   Calling %s\n", argv[0]);
    execv(argv[0], argv);
    fprintf(stderr, "  minuimus_swf_helper: Failed to call external program.\n");
    exit(1);
  }
    wait(NULL);
}


/*
Test conducted on an archive of flash games, without support for GIF or LZMA compression.
$ du --apparent-size  -b .
7125434544	.

$ ../minuimus.pl *

$ du --apparent-size  -b .
7088515013	.

Reduced to 99.48%. Pathetic.

*/
