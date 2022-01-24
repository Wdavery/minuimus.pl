#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "zlib.h"
#include "zopfli/zlib_container.h"

typedef struct {
uint32_t	signature;
uint32_t	flavor;
uint32_t	length;
uint16_t	numTables;
uint16_t	reserved;
uint32_t	totalSfntSize;
uint16_t	majorVersion;
uint16_t	minorVersion;
uint32_t	metaOffset;
uint32_t	metaLength;
uint32_t	metaOrigLength;
uint32_t	privOffset;
uint32_t	privLength;
} WOFFHeader;

typedef struct {
uint32_t	tag;
uint32_t	offset;
uint32_t	compLength;
uint32_t	origLength;
uint32_t	origChecksum;
} TableDirectoryEntry;

void processtableentry(TableDirectoryEntry *table, void *data);
void littleEndianize(void *buffer);
void bigEndianize(void *buffer);
static uint32_t endflip32(uint32_t value);
static uint16_t endflip16(uint16_t value);

int main(int argc, char *argv[]){

  if(argc!=2){
    printf("  Usage: minuimus_woff_helper <file.woff>\n  The WOFF file will be recompressed using Zopfli and reduced in size if possible. If no size reduction is achieved, the file will be untouched.\n");
    printf("  The space savings are not impressive, generally in the range of 2-4%%. If compatibility permits, converting the WOFF to WOFF2 will probably result in a much greater saving.\n");
    printf("  Internally, this program works by decompressing the individual font tables within the WOFF (plus metadata XML) and recompressing them using Zopfli. It's like an advzip for fonts.\n");
    return(0);
  }
//  printf("Compacting %s\n", argv[1]);
  FILE *input_file=fopen(argv[1],"rb");
  if(!input_file){
    printf("  minuimus_woff_helper: Unable to open input file.\n");
    return(1);
  }
  fseek(input_file, 0,SEEK_END);
  off_t filesize=ftello(input_file);

  fseek(input_file, 0, SEEK_SET);
  void *loadedfile=malloc(filesize);
  if(!loadedfile){
    fprintf(stderr, "minuimus_woff_helper: Failed to allocate memory when reading file.\n");
    return(1);
  }
  size_t ret=fread(loadedfile, 1, filesize, input_file);
  if(ret!=filesize){
    fprintf(stderr, "minuimus_woff_helper: Failed to read file into memory.\n");
    return(1);
  }
  fclose(input_file);
  WOFFHeader *fileheader=loadedfile;
  int iAmLittleEndian=0;
  if(fileheader->signature == endflip32(0x774F4646)){
    littleEndianize(loadedfile);
    iAmLittleEndian=1;
  }
  if(fileheader->signature != 0x774F4646){
    fprintf(stderr, "File missing WOFF signature. Probably not a WOFF file.\n");
    return(1);
  }

  if(filesize!=fileheader->length){
    fprintf(stderr, "minuimus_woff_helper: File size does not match file size in header. Actual size %lu, header claims size %u (%s).\n", filesize, fileheader->length, argv[1]);
    return(1);
  }
//  printf("Processing %u entries.\n", fileheader->numTables);
  uint32_t n;
  uint32_t totalSizeBefore=0;
  uint32_t totalSizeAfter=0;
  for(n=0;n<fileheader->numTables;n++){
    TableDirectoryEntry *table=loadedfile+sizeof(WOFFHeader)+(sizeof(TableDirectoryEntry)*n);
//    printf("  %03u  %06u %06u\n", n, table->origLength, table->compLength);
    totalSizeBefore+=table->compLength;
    processtableentry(table, loadedfile+table->offset);
    totalSizeAfter+=table->compLength;
//    printf("       %06u %06u\n", table->origLength, table->compLength);
  }
  if(0&fileheader->metaLength){
    TableDirectoryEntry dummy; //This is just a dummy object used to repurpose processtableentry to handle the metadata XML.
    dummy.compLength=fileheader->metaLength;
    dummy.origLength=fileheader->metaOrigLength;
    processtableentry(&dummy,loadedfile+fileheader->metaOffset);
    totalSizeBefore+=fileheader->metaLength;
    fileheader->metaLength=dummy.compLength;
    totalSizeAfter+=fileheader->metaLength;
  }
  if(totalSizeBefore==totalSizeAfter){
    printf("  minuimus_woff_helper: No space saving achieved processing WOFF file.\n");
    return(0);
  }
  printf("Compressed WOFF internal structures from %u to %u (%f).\n", totalSizeBefore, totalSizeAfter, (float)totalSizeAfter/totalSizeBefore);

  //All recompressed! Now to write it back out again.
  void *newFile=malloc(filesize+3); //filesize is an upper limit. We won't need it all.
  memset(newFile, 0, filesize);
  uint32_t bytesWritten=+sizeof(WOFFHeader)+(sizeof(TableDirectoryEntry)*fileheader->numTables);
  memcpy(newFile, loadedfile, bytesWritten);
  for(n=0;n<fileheader->numTables;n++){
    TableDirectoryEntry *table=newFile+sizeof(WOFFHeader)+(sizeof(TableDirectoryEntry)*n);
    memcpy(newFile+bytesWritten, loadedfile+table->offset, table->compLength); 
    table->offset=bytesWritten;
    bytesWritten+=table->compLength;
    if(bytesWritten&0x00000003){bytesWritten++;}if(bytesWritten&0x00000003){bytesWritten++;}if(bytesWritten&0x00000003){bytesWritten++;}
  }
  if(fileheader->metaLength){
    if(bytesWritten&0x00000003){bytesWritten++;}if(bytesWritten&0x00000003){bytesWritten++;}if(bytesWritten&0x00000003){bytesWritten++;}
    memcpy(newFile+bytesWritten, loadedfile+fileheader->metaOffset, fileheader->metaLength);
    fileheader->metaOffset=bytesWritten;
    bytesWritten+=fileheader->metaLength;
  }
  if(fileheader->privLength){
    if(bytesWritten&0x00000003){bytesWritten++;}if(bytesWritten&0x00000003){bytesWritten++;}if(bytesWritten&0x00000003){bytesWritten++;}
    memcpy(newFile+bytesWritten, loadedfile+fileheader->privOffset, fileheader->privLength);
    fileheader->privOffset=bytesWritten;
    bytesWritten+=fileheader->privLength;
  }

  fileheader->length=bytesWritten;
  memcpy(newFile, loadedfile, sizeof(WOFFHeader));
  free(loadedfile);
  if(iAmLittleEndian)
    bigEndianize(newFile);


  FILE *outfile=fopen(argv[1], "wb");
  if(!outfile){
    printf("  minuimus_woff_helper: Unable to open output file.\n");
    return(1);
  }
  fwrite(newFile, 1, bytesWritten, outfile);
  fclose(outfile);
  free(newFile);
}

void processtableentry(TableDirectoryEntry *table, void *data){
    void *decompressed=malloc(table->origLength);
    uLongf destLen=table->origLength;
    if(destLen==0)
      return;
    if(table->origLength == table->compLength)
      memcpy(decompressed, data, table->compLength);
    else{
      int err=uncompress(decompressed, &destLen, data, table->compLength);
      if(err){
        if(err==Z_BUF_ERROR)
          fprintf(stderr,"DEFLATE stream too long for allocated memory.\n");
        if(err==Z_DATA_ERROR)
          fprintf(stderr,"DEFLATE stream appears corrupt. Possible damaged WOFF.\n");
        if(err==Z_MEM_ERROR)
          fprintf(stderr,"Insufficient memory.\n");
        free(decompressed);
        return;
      }
    }

  ZopfliOptions options;
  ZopfliInitOptions(&options);
//  options.Numterations=15;
  uint8_t *zopfli_output=0;
  size_t zopfli_size=0;
  destLen=table->origLength;
  void *recompressed;
  size_t newLen=0;
  ZopfliZlibCompress(&options, decompressed, table->origLength, (unsigned char**)&recompressed, &newLen);
//  printf("New len %lu\n", newLen);
  if(newLen>=table->compLength){
    free(decompressed);
    free(recompressed);
    return;
  }
  memcpy(data, recompressed, newLen);
  table->compLength=newLen;

}

void littleEndianize(void *buffer){
  WOFFHeader *fileheader=buffer;
  fileheader->signature=endflip32(fileheader->signature);
  fileheader->length=endflip32(fileheader->length);
  fileheader->numTables=endflip16(fileheader->numTables);
  fileheader->metaLength=endflip32(fileheader->metaLength);
  fileheader->metaOrigLength=endflip32(fileheader->metaOrigLength);
  fileheader->metaOffset=endflip32(fileheader->metaOffset);
  fileheader->privOffset=endflip32(fileheader->privOffset);
  fileheader->privLength=endflip32(fileheader->privLength);
  uint32_t n;
  for(n=0;n<fileheader->numTables;n++){
    TableDirectoryEntry *table=buffer+sizeof(WOFFHeader)+(sizeof(TableDirectoryEntry)*n);
    table->offset=endflip32(table->offset);
    table->compLength=endflip32(table->compLength);
    table->origLength=endflip32(table->origLength);
  }

}

void bigEndianize(void *buffer){
  WOFFHeader *fileheader=buffer;
  uint32_t n;
  for(n=0;n<fileheader->numTables;n++){
    TableDirectoryEntry *table=buffer+sizeof(WOFFHeader)+(sizeof(TableDirectoryEntry)*n);
    table->offset=endflip32(table->offset);
    table->compLength=endflip32(table->compLength);
    table->origLength=endflip32(table->origLength);
  }
  fileheader->signature=endflip32(fileheader->signature);
  fileheader->length=endflip32(fileheader->length);
  fileheader->numTables=endflip16(fileheader->numTables);
  fileheader->metaLength=endflip32(fileheader->metaLength);
  fileheader->metaOrigLength=endflip32(fileheader->metaOrigLength);
  fileheader->metaOffset=endflip32(fileheader->metaOffset);
  fileheader->privOffset=endflip32(fileheader->privOffset);
  fileheader->privLength=endflip32(fileheader->privLength);
}


static uint32_t endflip32(uint32_t value)
{
    uint32_t result = 0; //Code shamelessly copied from Wikipedia;
    result |= (value & 0x000000FF) << 24;
    result |= (value & 0x0000FF00) << 8;
    result |= (value & 0x00FF0000) >> 8;
    result |= (value & 0xFF000000) >> 24;
    return result;
}

static uint16_t endflip16(uint16_t value)
{
    uint16_t result = 0;
    result |= (value & 0x00FF) << 8;
    result |= (value & 0xFF00) >> 8;
    return result;
}
