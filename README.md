_Note about this repository:_ This is not the official repository. The original creator is known as CodeBird and can be found here: https://birds-are-nice.me/software/minuimus.html  
This repository was created primarily for personal use, as documentation of dependancies and command line options were limited at the original source.
As well, this will serve as a location for a docker image (based on Debian:slim) for Minuimus that contains all dependancies. This is currently undergoing testing and will be added here for public use in the future. Ideally a working image based on Alpine will be created as well.

# minuimus.pl

- [minuimus.pl](#minuimuspl)
    - [Supported file types](#supported-file-types)
      - [Transparent optimization](#transparent-optimization)
      - [Non-transparent conversion](#non-transparent-conversion)
      - [Description of processing](#description-of-processing)
    - [Command Line Options](#command-line-options)
    - [Dependencies](#dependencies)
      - [Optional Dependencies](#optional-dependencies)

Minuimus is a file optimizer utility script. By default, it can be pointed to a file and it will transparently reduce the file size, leaving all pixels/text/audio/metadata intact. Using command line options, it can also run lossy optimizations and conversions. 

Minuimus is primarily a Perl script, but three optional supporting binaries are available which are used for processing of PDF, WOFF and SWF files. These are written on Ubuntu, but should be adaptable to other Linux distributions with little to no alteration. Running on Windows would require substantial modification and testing.

As well as using it's own methods, Minuimus is dependent on many established utilities. Minuimus automates the process of calling all of these utilities—including recursively processing and reassembling container files (such as `zip`, `7z`, `ePub` and `docx`), detecting and handling any errors, and running integrity checks on the optimized files to prevent data loss. Based on which dependencies are installed, Minuimus will process all possible files, and skip those that have no compatible tool installed.

As is the case for any optimizer, the size reduction achieved by Minuimus is highly dependent upon the input data. Even after extensive testing, the results are too inconsistent to easily quantify. Despite that, here are some examples:
- A collection of PDF files sampled from the-eye.eu was reduced by 10%
- A 500GB sample from the archive.org 'computermagazine' collection was reduced by 22%
- A collection of ePub files from Project Gutenberg was reduced by 5%, as these files are light on images, and ZIP files with no optimizable files inside are reduced only slightly, by about 3%

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

### Command Line Options

These options enable file format conversion and other non-transparent features, which will alter the format of your files in order further reduce filesize.
Note that these options chain together—eg. `--gif-png --png-to-webp` results in .gif converted to .webp
| Option | Description |
| --- | --- |
| `--gif-png` | Converts .gif files to .png, including animated gif to animated PNG. Likely results in a smaller file. |
| `--png-webp` | Converts .png to .webp. Ignores animated PNGs. Aborts if the conversion results in a larger file than the optimized PNG. |
| `--rar-zip` | Converts .rar to .zip. Likely results in larger file, but allows processing of files within the rar. Converting to 7z likely superior. |
| `--cbr-cbz` | Converts .cbr to .cbz. Likely creates a larger file, but allows image optimizations—resulting in ultimately smaller file. |
| `--zip-7z` | Converts zip to 7z. Aborts if larger than the original. |
| `--rar-7z` | Converts rar to 7z. Allows recursive optimizations. Aborts if larger than the original. <br/> .rar and .7z typically use different compression algorithms (Generally PPMd vs LZMA), but neither is superior for all data.<br/> 7z supports both, so Minuimus will compress with PPMd and LZMA separately, and pick the smallest file. |
| `--7z-7paq` | Convert 7z to zpaq. Aborts if larger than original. Still tries to optimize the 7z first. Zpaq is pretty much the highest-ratio archive-compressor that exists. |
| `--webp-in-cbz` | Convert PNG files within CBZ to WebP. Resulting in substantially smaller files, but poor compatibility—many CBZ viewers wont open them. Maybe one day. |
| `--jpg-webp` | Convert JPG to WebP. Uses the knusperli jpeg decoder. This process is lossy, but only very slightly, as it uses WebP quality 90.<br/> If the space saving is <10%, the conversion is rejected. |
| `--jpg-webp-cbz` | Enables the above option when processing CBZ files. The space saving can be considerable, justifying the very slight loss of quality. |
| `--misc-png` | Converts BMP and PCX files to PNG. |
| `--keep-mod` | Preserve the modification time of files, even if they are altered. |
| `--omni-<ext>` | Enables the 'omnicompressor' function for the specified file extension: Compress it with gzip, bzip2, lz, rz, 7z on PPMd and zpaq on max, and keep whichever is smallest.<br/> This is an extreme option for minimum file size, no matter how long it takes. Intended for archival use.|
| `--iszip-<ext>` | Forces a specified extension to be processed as a ZIP file. |
| `--video` | Enables lossy video recompression of legacy formats into WebM. For why you might want to do this, see the note in the source file. |
| `--audio` | Enables compression of high-quality MP3 (>=256kbps) to Opus 128kbps. This will also apply within archive files, for converting albums. |
| `--audio-agg` | With `--audio`, converts MP3 to very low-bitrate Opus. Sound quality suffers. Intended for voice, never music. Also re-encodes .m4b files. All metadata preserved. |
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
- `flexigif` - required for GIF processing ([Source](https://create.stephan-brumme.com/flexigif-lossless-gif-lzw-optimization/))
- `jbig2`- required for JBIG2 processing ([Source](https://github.com/agl/jbig2enc))
- `jbig2dec` - required for JBIG2 processing
- `leanify` - additional JPEG, SWF, ICO and FB2 processing ([Source](https://github.com/JayXon/Leanify))
- `pdfsizeopt` - additional PDF processing ([Source](https://github.com/pts/pdfsizeopt)) (Installed to `/var/opt/pdfsizeopt/pdfsizeopt`–configurable in minuimus.pl)
- `pngout` - additional PNG processing ([Source](https://jonof.id.au/kenutils.html), also available as part of pdfsizeopt install)
