# minuimus.pl

- [minuimus.pl](#minuimuspl)
    - [Supported file types](#supported-file-types)
      - [Transparent optimization](#transparent-optimization)
      - [Non-transparent conversion](#non-transparent-conversion)
      - [Description of processing](#description-of-processing)
    - [Command Line Options](#command-line-options)
    - [Dependencies](#dependencies)
      - [Optional Dependencies](#optional-dependencies)

Minuimus is a file optimizer utility script: Point it at a file, and it transparently reduces filesize. It is dependent upon many other utilities for this, as well as some more specialised methods developed especially for it. Minuimus automates the process of calling upon all of these utilities—including the process of recursively processing container files and ensuring proper reassembly, detecting and handling the various errors that may occur, and running integrity checks on the optimized files to prevent damage.

Minuimus's optimizations are, by default, completely transparent: Not a single pixel of an image will be changed in value, no audio or video will fall in quality. Even metadata is preserved unaltered. It also supports a number of forms of lossy optimization, which must be explicitly enabled via command line option.

As Minuimus is entirely automated, simply install the prerequsites and run a single command to point Minuimus at the files to be optimized. It will optimize those files it can, and skip over those it cannot.

Minuimus consists of a perl script and three optional supporting binaries which are used for the processing of PDF, WOFF and SWF files. These are written for use on Ubuntu Linux, but should be adaptable to other Linux distributions with little if any alteration. Running on Windows would require substantial modification and testing. These utilities are released under the GPL v3 license, as is Minuimus itself.

When faced with files which are zip containers - such as zip, epub, or docx - it will extract these files, recursively process all of the files contained within them, and put them back together. In this manner it can make e-books and office documents substantially smaller.

The exact space saving achieved by Minuimus is highly dependent upon the file being optimized. As is expected for any file optimizer, even after extensive testing, the results are too inconsistent to easily quantify. A collection of PDF files sampled from the-eye.eu was reduced in size to 90% of the input, while a half-terabyte sample taken from the archive.org 'computermagazine' collection was reduced with greater success to 78% of the input size. A collection of epub files from Project Gutenberg was reduced to a mere 95%, as these files are light on images, and ZIP files with no files inside which can be recursively optimized are reduced only very slightly, typically to around 97%.


### Supported file types

#### Transparent optimization

```
Images: JPEG TIFF PNG APNG GIF
Documents: DOCX PPTX XLSX ODT ODS ODP EPUB PDF CBZ XPS
Archives: ZIP 7Z GZ TGZ CAB
Other: JAR WOFF FLAC SWF STL MP3
```

#### Non-transparent conversion

```
CBR -> CBZ
RAR -> ZIP
RAR -> 7z
7z -> zpaq
GIF -> PNG
PNG -> WebP
Legacy video -> WebM
MP3 >=256kbps -> Opus
```

#### Description of processing

```
JPEG files are initially processed by jpegoptim. For most JPEG files, this is as much as is possible. In some rare cases Minuimus may find a color JPEG which contains only grayscale values, in which case the empty color channels will be removed for a further reduction in size.
PNG files are processed by optipng, followed by advpng - unless they are animated pngs, as advpng is not animation-safe. Those get advdef instead. Optionally pngout will be called if installed on non-animated PNGs, which sometimes saves another percent or so.
GIF files are processed by gifsicle. If the file is less than 100KiB and flexigif is installed, it is then processed by flexigif.
TIFF files are re-compressed on highest setting supported by imagemagick.
JAR files are processed by advzip, as these files are too delicate to be safely manipulated beyond this. In particular, altering the files within would invalidate any signing.
PDF files are processed by using qpdf to remove unused object and object versions, ensure a consisten format and correct any minor errors. Following this pre-processing, all JPEG objects within the PDF are located and processed using jpegoptim. All objects compressed using DEFLATE are also identified and processed using a C helper binary, minuimus_def_helper - if this in not installed, DEFLATE processing is skipped. Certain unimportant metadata objects are deleted, but the main document metadata is not touched unless --discard-meta is specified. The processed PDF is then relinearised using qpdf. As a fail-safe against anything going wrong in this process, both original and compressed PDFs are rendered into bitmap format and compared - the original will only be overwritten if the optimized file rendered identically. This combination of qpdf, jpeg and DEFLATE processing makes Minuimus one of the most effective lossless PDF optimisation utilities available. Finally, if pdfsizeopt is installed, it will be called - as it includes some optimisations that minuimus lacks, and vice versa, the two tools together can outperform either alone.
ZIP, DOCX, XLSX, ODT, ODS, ODP, EPUB and CBZ, the zip-derived archive formats, are processed by extracting to a temporary folder, processing all (non-archive) files within as independent files, then re-compressing into a ZIP file and compressing that with advzip. The 'mimetype' file is correctly placed as the first in the completed file using store-only compression in accordance with the EPUB OCF. Additionally a number of 'junk' files such as Thumb.db and .ds_store are deleted from ZIP files.
For CBZ files, any GIF, BMP, PCX or TIFF files within are converted to PNG (In an animation-safe manner) in addition to the standard ZIP processing. The capability to convert PNGs into WebP is present, but default disabled due to limited viewer support for WebP.
GZ and TGZ files just get processed by advdef.
7Z archives are extracted and constituent files processed, then recompression attempted using both LZMA and PPMd compression algorithms on highest practical settings. Whichever of these produces the smallest file is kept, unless the original file is smaller. Solid compression is not used.
WOFF files (web fonts) are processed using a Zopfli-based recompresser.
FLAC files are re-encoded using the highest possible profile-complient settings - slightly better than the regular -9. Metadata is preserved. FLAC files are also examined to determine if they contain a mono audio track encoded as stereo. Such files are converted to true mono, which achieves a substantial space saving.
CAB - the MS CAB, not Installshield CAB - will be repackaged if possible, but the savings from this are very small. Signed cabs are ignored.
HTML, CSS and SVG files are also searched for any base64-encoded JPG, PNG or WOFF resources, and these resources optimized appropriately.
SWF files will have their internal JPEG and PNG objects recompressed, and the outer DEFLATE wrapper run through Zopfli. However, as most SWF generation software is already focused on producing small files, savings are generally small.
STL models in ASCII form will be converted to binary form. This makes them a lot smaller - but most STLs are already binary now.
MP3 files will be repacked if that makes them smaller. Usually it doesn't - but some very old MP3s are poorly packed and might get a tiny bit smaller.
```

If the utility [Leanify](https://github.com/JayXon/Leanify) is installed, it will also be used to augment Minuimus where possible. As both programs can support a few tricks that the other cannot, they work better in conjunction than either alone on certain files. Most significently, JPEG and formats containing JPEG.

Some further capabilities are disabled by default because they are not fully transparent, but can be enabled by command-line option:

```
Conversion of PNG within CBZ files into WebP. The resulting files are more compact, but not supported by all CBZ-viewing software. All conversions animation-safe.
Conversion of all GIFs to PNG, or of PNGs to WebP, or of legacy image formats (bmp, pcx, tiff) to PNG. These do chain: GIF-to-PNG plus PNG-to-WebP results in GIF-to-WebP.
Conversion of CBR to CBZ and RAR to ZIP. This doesn't compact files directly, but does enable the use of the optimisations appropriate for the converted file type.
Conversion of RAR or ZIP files into 7Z, if doing so would result in smaller overall size (Which it usually does), using the same optimisations used for 7Z files.
Conversion of 7z to ZPAQ likewise. ZPAQ is perhaps the highest-ratio compression container currently available for general usage.
```

Lossy multimedia operations

Additionally, minuimus has the option (disabled by default) of converting certain legacy multimedia files into modern codecs - reducing their size greatly in the process. This is, however, an inherently lossy operation. The compression will be abandoned if it results in an output file of larger size than the input.

```
If video processing is enabled, video files using dated codecs such as DivX, XviD or MPEG1/2 will be converted to WebM using AV1 and Opus. The files will be compared in duration after encoding as a precaution against truncation due to damaged input files.
If audio processing is enabled, MP3 files with a bitrate of 256kbps or above will be converted to 128kbps Opus. Both these bitrates are chosen as they are generally considered transparent for their respective codecs. The bitrate can be reduced with --audio-agg if processing speech only.
Both of these also detect mono audio stored as stereo, and convert it to mono format for more efficient compression.
```

### Command Line Options

These options enable file format conversion and other non-transparent features, which will alter the format of your files in order further reduce filesize.
| Option | Description |
| --- | --- |
| `--gif-png` | Converts .gif files to .png, including animated gif to animated PNG. This will almost always result in a smaller file. |
| `--png-webp` | Converts .png (Or, with above option, .gif) to .webp. Ignores animated PNG files. Aborts if the conversion would result in a larger file than the post-optimisation PNG. |
| `--rar-zip` | Converts .rar to .zip. This will almost always make the file larger, but it does allow for the processing of files within the rar. Converting to 7z may be a better choice. |
| `--cbr-cbz` | Converts .cbr to .cbz. This may make the file larger, but - as it allows for the use of the image-specific optimisations - usually makes them smaller. Also I just dislike RAR. |
| `--zip-7z` | Converts zip to 7z, including recursive optimisations, but only if this results in a smaller file than the original. |
| `--rar-7z` | Converts rar to 7z, including recursive optimisations, but only if this results in a smaller file than the original.<br/> .rar and .7z typically use different compression algorithms (Generally PPMd vs LZMA), but they are both sophisticated and neither is clearly superior for all data.<br/> Fortunately 7z supports both! So Minuimus will compress twice, once with LZMA and once with PPMd, and pick whichever performs best. So it'll almost always be smaller than RAR. |
| `--7z-7paq` | Convert 7z to zpaq, only if this makes a smaller file. Still tries to optimize the 7z first. Zpaq is pretty much the highest-ratio archive-compresser that exists. |
| `--webp-in-cbz` | Convert PNG files within CBZ to WebP. The resulting files will be very substantially smaller, but exhibit poor compatibility: Many CBZ viewers wont open them. Maybe one day. |
| `--jpg-webp` | Convert JPG to WebP. Uses the knusperli jpeg decoder. This process is lossy, but only very slightly, as it uses WebP quality 90.<br/> If the space saving is less than 10% of the file size - which will be true for all but the highest-quality-setting JPEGs - then the conversion is rejected and original kept. |
| `--jpg-webp-cbz` | Enables the above option when processing CBZ files. The space saving can be considerable, justifying the very slight loss of quality. |
| `--misc-png` | Converts BMP and PCX files to PNG. |
| `--keep-mod` | Preserve the modification time of files, even if they are altered. |
| `--omni-<ext>` | nables the 'omnicompressor' function for the specified file extension: Compress it with gzip, bzip2, lz, rz, 7z on PPMd and zpaq on max, and keep whichever is smallest.<br/> This is a somewhat extreme option, for desperate people who have a need to save every last byte, no matter how long it takes. It's intended for archival use.<br/> It's troublesome to extract, as whoever ends up with the files will probably need to install some software to do so. It's also unbelievably, ridiculously slow. |
| `--iszip-<ext>` | Forces a specified extension to be processed as a ZIP file. |
| `--video` | Enables lossy video recompression of legacy formats into WebM. For exactly why you might want to do this, see the note in the source file. |
| `--audio` | Enables compression of high-quality MP3 (>=256kbps) to Opus 128kbps. This will also apply within archive files, for converting albums. |
| `--audio-agg` | With `--audio`, converts MP3 to very low-bitrate Opus. Sound quality suffers. Intended for voice, never music. Also reencodes .m4b files. All metadata preserved. |
| `--discard-meta` | Discards metadata from image and PDF files. On PDF files can produce a considerable space saving! It only deletes the XML-based metadata, so the title remains. |
| `--fix-ext` | Detects some common file types with the wrong extension, and corrects. |

### Dependencies

- `advancecomp`

- `gif2apng`

- `gifsicle`

- `imagemagick-6.q16`

- `jpegotim`

- `libjpeg-progs`

- `optipng`

- `p7zip-full`

- `poppler-utils`

- `qpdf`

- `unrar`

- `webp`

- `zip`

#### Optional Dependencies

- `ffmpeg` - required for MP3, FLAC and video processing

- `flexigif` - additional for GIF processing

- `jbig2`- 

- `jbig2dec` - 

- `leanify` - additional JPEG, SWF, ICO and FB2 processing

- `pdfsizeopt` - additional PDF processing
  
  - `png22pnm`
  
  - `sam2p`

- `pngout` - additional PNG processing

