// gcc cab_analyze.c -o cab_analyze -O3

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>



struct CFHEADER{
  uint8_t signature[4];
  uint8_t reserved1;
  uint32_t cbCabinet;
  uint32_t reserved2;
  uint32_t coffFiles;
  uint32_t reserved3;
  uint8_t versionMinor;
  uint8_t versionMajor;
  uint16_t cFolders; //Note that in cab terminology, a folder is actually a block of compressed data, which is internally broken into smaller blocks.
  uint16_t cFiles;
  uint16_t flags;
  uint16_t setID;
  uint16_t iCabinet;
};

struct CFHEADER_EXTENDED{
  uint16_t cbCFHeader;
  uint8_t cbCFFolder;
  uint8_t cbCFData;
};

struct CFFOLDER{
  uint32_t coffCabStart;
  uint16_t cCFDATA;
  uint16_t typeCompress;
};

struct CFFILE{
  uint32_t cbFile;
  uint32_t cbFolderStart;
  uint16_t iFolder;
  uint16_t date;
  uint16_t time;
  uint16_t attribs;
  //There is actually one more field, but it's variable-length.
};

struct CFDATA{
  uint32_t csum;
  uint16_t cbData;
  uint16_t cbUncomp; //Here we see the greatest limitation of the CAB files: This 16-bit field means that you will never get more than 64KiB of data in a CFDATA. But you still can't decompress the blocks independently.
};

int isnulls(uint8_t *data, uint16_t count);
void copy_CFDATA(FILE *infile, FILE *outfile, uint16_t cCFData, uint16_t compression, uint16_t skip);
size_t fread2(void * ptr, size_t size, size_t count, FILE * stream );
uint8_t is_little_endian();

FILE *outfile=NULL; //Making these global so the error-handling code can clean them up.
char *outfilename;

int main(int argc, char *argv[]){

  if(!is_little_endian()){
    printf("cab_analyze is written for litte-endian architecture only. Sorry.\n");
    return(1);
  }

  if(argc<2 || argc>3){ //I had to rewrite this to use the US spelling, not wanting to confuse the larger country with my Britishness.
    printf("The cab_analyze program displays information on the internal structure of Microsoft CAB files, as used in Windows driver packages and some software installers.\n");
    printf("These are not to be confused with Installshield CAB, which is a completely different file that just has the same extension.\n\n");
    printf("  Usage: cab_analyze [in-file.cab] <out-file.cab>\n\nIf a second file is specified, analyze_cab will reconstruct the data of the input file into the output file.\n");
    printf("This will sometimes reduce the size of the CAB file slightly, by removing the empty space usually reserved for adding signing information.\n");
    printf("The reconstructon will be abandoned if the input CAB has any application-specific extensions present, or is signed.\n");
    return(0);
  }

  struct CFHEADER fileheader;
  struct CFHEADER_EXTENDED fileheader_extended;
  FILE *cabfile=fopen(argv[1], "rb");

  if(!cabfile){
    fprintf(stdout, "Unable to open file %s\n", argv[1]);
    return(1);
  }
  fseek(cabfile, 0, SEEK_END);
  uint32_t filesize=ftell(cabfile);
  fseek(cabfile, 0, SEEK_SET);

  fread2(&fileheader, sizeof(struct CFHEADER), 1, cabfile);
  if(!memcmp(fileheader.signature, "ISc(", 4)){
    printf("  File signature indicates an Installshield CAB file. This format is completely unrelated to the Microsoft CAB file, despite the identical extensions.\n");
    return(1);
  }
  if(memcmp(fileheader.signature, "MSCF", 4)){
    fprintf(stdout, "Signature bytes invalid: Not an MS CAB file.\n");
    return(1);
  }
  printf("  Expected size: %08u   Files:  %05u   Folders: %05u   Flags: %04u\n", fileheader.cbCabinet, fileheader.cFiles, fileheader.cFolders, fileheader.flags);
  printf("  Version: %u.%u\n", fileheader.versionMajor, fileheader.versionMinor);

  if(fileheader.flags & 0x0003){
    fprintf(stdout, "File is a multi-volume CAB. This software supports only single-volume CAB files.\n");
    return(1);
  }
  if(fileheader.flags & 0x0004){
    printf("  CAB file has additional space reserved for capabilities not documented in the CAB format. This usually means the cab is signed.\n");
    fread2(&fileheader_extended, sizeof(struct CFHEADER_EXTENDED), 1, cabfile);
    printf("  File: %05u   Folder: %03u   Data: %03u\n", fileheader_extended.cbCFHeader, fileheader_extended.cbCFFolder, fileheader_extended.cbCFData);
  }else{
    memset(&fileheader_extended, 0, sizeof(struct CFHEADER_EXTENDED));
  }

  if(fileheader.cbCabinet<filesize){
    printf("  File is larger than it should be (%u vs %u). That's odd. Continuing anyway.\n", filesize, fileheader.cbCabinet);
  }
  if(fileheader.cbCabinet>filesize){
    printf("  File is smaller than it should be. Likely truncated. Aborting analysis.\n");
    return(1);
  }
  if(fileheader.coffFiles > filesize){
    printf("  Files offset is greater than the size of the cab. Either seriously corrupted, or not a CAB file.\n");
    return(1);
  }

  
  if(argc==3){
    outfilename=argv[2];
  }

  if(fileheader_extended.cbCFHeader){
    uint8_t *reserved_data=malloc(fileheader_extended.cbCFHeader);
    fread2(reserved_data, fileheader_extended.cbCFHeader, 1, cabfile);
    if(isnulls(reserved_data, fileheader_extended.cbCFHeader))
      printf("  The reserved data is all zeros. This usually means the cab was created with space reserved in the header for later insertion of cryptographic signing.\n");
    else
      if(outfilename){
        fprintf(stderr, "  Cab contains reserved application-specific data. This may indicate a signed file, or may indicate something else. As a precaution, compaction will not be attempted for this cab file.\n");
        return(1);
      }
    if((outfilename) &&(fileheader_extended.cbCFFolder || fileheader_extended.cbCFData)){
      fprintf(stderr, "  Cab contains reserved application-specific folder or data-block data. As a precaution, compaction will not be attempted for this cab file.\n");
      return(1);
    }
    free(reserved_data);
  }


  if(outfilename){
    printf("  Attempting reconstruction to file %s.\n", outfilename);
    outfile=fopen(outfilename, "wb");
    if(!outfile){
      fprintf(stdout, "  Unable to open output file %s\n", argv[1]);
      return(1);
    }
    //If we're doing the restructuring thing, here's how. Certain data structures have to be calculated before others can be written.
    //a CAB files can be arranged as header-folders-data-files, or as header-folders-files-data. Both arrangements are valid.
    //But from a calculation perspective, header-folders-files-data is slightly easier.
    //So:
    // 1. Calculate the offset for the files. Once that is known, you can leave space for the header and folders parts.
    // 2. Now write the data part. Make sure to record the offset each new chunk of data goes at.
    // 3. Once that information is known, write the folders and the header.
  }

  uint16_t n;
  uint32_t filesOffset=fileheader.coffFiles;
  struct CFFOLDER *folders=malloc(sizeof(struct CFFOLDER)*fileheader.cFolders);
  for(n=0; n<fileheader.cFolders; n++){
    fread2(&folders[n], sizeof(struct CFFOLDER), 1, cabfile);
    if(fileheader_extended.cbCFFolder) fseek(cabfile, fileheader_extended.cbCFFolder, SEEK_CUR);
  }
  printf("  --FILES--\n");
  fseek(cabfile, filesOffset, SEEK_SET);
  if(outfile)
    fseek(outfile, sizeof(struct CFHEADER)+(sizeof(struct CFFOLDER)*fileheader.cFolders), SEEK_SET);
  for(n=0; n<fileheader.cFiles; n++){
    struct CFFILE thisfile;
    unsigned char name[257];
    name[256]=0;
    fread2(&thisfile, sizeof(struct CFFILE), 1, cabfile);
    int m;
    for(m=0;m<256;m++){
      fread2(&name[m], 1, 1, cabfile);
      if(name[m]==0)
        m=257;
    }
    printf("  Size: %08u  Folder: %u  Name: '%s'\n", thisfile.cbFile, thisfile.iFolder, name);
    if(outfile){
       fwrite(&thisfile, sizeof(struct CFFILE), 1, outfile);
       fwrite(name, strlen(name)+1, 1, outfile); //The +1 is for the null terminator.
    }
  }
  printf("  --FOLDERS--\n");
  for(n=0; n<fileheader.cFolders; n++){
    printf("  Folder: %04u   Offset: %08u   Blocks: %04u   Compression: ", n, folders[n].coffCabStart, folders[n].cCFDATA);
    if(folders[n].typeCompress==0)
      printf("None\n");
    else if(folders[n].typeCompress==1)
      printf("MSZIP\n");
    else if(folders[n].typeCompress==2)
      printf("Quantum\n");
    else if(folders[n].typeCompress==3)
      printf("LZX\n");
    else
      printf("Unrecognised (Type 0x%04X).\n", folders[n].typeCompress); //There are some not-part-of-the-spec compression methods that appear to be in use but poorly documented. 0x1503, 0x1003, 0x0F03.
    if(outfile){
      fseek(cabfile, folders[n].coffCabStart, SEEK_SET);
      fseek(outfile, 0, SEEK_END);
      folders[n].coffCabStart=ftell(outfile);
      copy_CFDATA(cabfile, outfile, folders[n].cCFDATA, folders[n].typeCompress, fileheader_extended.cbCFData);
    }
  }
 if(outfile){
   fileheader.cbCabinet=ftell(outfile);
   fseek(outfile, 0, SEEK_SET);
   fileheader.flags=fileheader.flags & 0xFFFB;
   fileheader.coffFiles=sizeof(struct CFHEADER)+(sizeof(struct CFFOLDER)*fileheader.cFolders);
   fwrite(&fileheader, sizeof(struct CFHEADER), 1, outfile);
   fwrite(folders, sizeof(struct CFFOLDER)*fileheader.cFolders, 1, outfile); 
 }
}

int isnulls(uint8_t *data, uint16_t count){
  while(count--)
    if(data[count])
      return(0);
  return(1);
}

void copy_CFDATA(FILE *infile, FILE *outfile, uint16_t cCFData, uint16_t compression, uint16_t skip){
  //This is the most complicated part of the program, and one of the reasons the program exists.
  //Before calling, the two files must be fseek-ed to the appropriate positions.
  //'infile' to the start of the chain of CFDATA structures (As referenced in the corresponding CFFOLDER).
  //'outfile' to a suitable place (ie, the end) to place the data in.
  struct CFDATA datablock;
  uint8_t buffer[65535];
  int n;
  for(n=0;n<cCFData;n++){
    fread2(&datablock, sizeof(struct CFDATA), 1, infile);
    fread2(buffer, datablock.cbData, 1, infile);
//    printf("  Block: %u  C.size: %05u  U.size: %05u \n", n, datablock.cbData, datablock.cbUncomp);
    fwrite(&datablock, sizeof(struct CFDATA), 1, outfile);
    fwrite(buffer, datablock.cbData, 1, outfile);
    if(skip)
      fseek(infile, skip, SEEK_CUR);
  }
}

size_t fread2(void * ptr, size_t size, size_t count, FILE * stream ){
  //It's fread, but with error handling.
  size_t ret=fread(ptr,size,count,stream );
  if(ret == count)
    return(ret);
  fprintf(stderr, "  analyze_cab: Error reading input file. Aborting.\n");
  if(outfile){
    fclose(outfile);
    remove(outfilename);
  }
  exit(1);
}

uint8_t is_little_endian(){
  uint32_t a=0x44434241;
  return(!memcmp(&a, "ABCD", 4));
}