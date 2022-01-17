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

Minuimus is a file optimizer utility script written in Perl. By default, it can be pointed to a file and it will transparently reduce the file size, leaving all pixels/text/audio/metadata intact. Using command line options, it can also run lossy optimizations and conversions.

As well as using it's own methods and three optional supporting binaries (for PDF, WOFF and SWF files), Minuimus is dependent on many established utilities. It automates the process of calling all of these utilities—including recursively processing and reassembling container files (such as `zip`, `ePub` and `docx`), detecting and handling any errors, and running integrity checks on the optimized files to prevent data loss. Based on which dependencies are installed, Minuimus will process files the best it can, and skip those that have no compatible tool installed.

As is the case for any optimizer, the size reduction achieved by Minuimus is highly dependent upon the input data. Even after extensive testing, the results are too inconsistent to easily quantify. Despite that, here are some examples:
- A collection of PDF files sampled from the-eye.eu was reduced by 10%
- A 500GB sample from the archive.org 'computermagazine' collection was reduced by 22%
- A collection of ePub files from Project Gutenberg was reduced by 5%, as these files are light on images, and ZIP files with no optimizable files inside are reduced only slightly, by about 3%

### Supported file types
#### Transparent optimization
```
Images: JPEG TIFF PNG GIF
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
All processing is only saved to disk if the processed file is smaller and changes are transparent.
- `JPEG` files are processed by `jpegoptim`. If a color JPEG contains only grayscale values, empty color channels will be removed
- `PNG` files are processed by `optipng`, then `advpng`, then `pngout`. Animated PNGs are processed by `optipng`, then `advdef`
- `GIF` files are processed by `gifsicle`, then if  <100KiB, `flexigif`
- `TIFF` files are re-compressed on highest setting supported by `imagemagick`
- `JAR` files are only processed by `advzip`–altering the files within would invalidate any signing
- `PDF` files are processed by `qpdf` to remove unused objects and versions, ensure a consistent format and correct minor errors. `JPEG` objects are processed by `jpegoptim`. DEFLATE compressed objects are processed by `minuimus_def_helper`. Unimportant metadata objects are deleted, main document metadata is retained unless `--discard-meta` is specified. Then the PDF is relinearised using `qpdf`. Original and optimized PDFs are rendered into bitmap and compared. Then processed by `pdfsizeopt`
- `ZIP`, `DOCX`, `XLSX`, `ODT`, `ODS`, `ODP`, `EPUB` and `CBZ`–the ZIP-derived archive formats–are extracted and (non-archive) files within are processed individually, junk files such as Thumb.db and .ds_store are deleted, then recompressed into ZIP by `advzip`. The `mimetype` file is placed first using store-only compression in accordance with the EPUB OCF
- `CBZ` files are processed additionally after standard ZIP compression by converting GIF, BMP, PCX and TIFF files within to (animation-safe) PNGs. Conversion from PNG to WebP is possible via command-line option (disabled by default  due to limited viewer support for WebP)
- `GZ` and `TGZ` files are processed by `advdef`
- `7Z` archives are extracted and files within processed, then recompressed using both LZMA and PPMd algorithms on highest practical settings. Whichever file is smallest is kept, unless the original file is smaller. Solid compression is not used
- `WOFF` files are processed by a `Zopfli`-based recompressor.
- `FLAC` files are re-encoded using the highest possible profile-compliant settings (slightly better than the regular -9). Metadata is preserved. Mono audio tracks encoded as stereo are converted to true mono
- `CAB` - (Microsoft CAB) files will be repackaged if possible, but the savings are very small. Signed cabs are ignored
- `HTML`, `CSS` and `SVG` files are searched for any base64-encoded `JPG`, `PNG` or `WOFF` resources, which are optimized individually
- `SWF` files will have internal `JPEG` and `PNG` objects recompressed, and the outer DEFLATE wrapper run through `zopfli`
- `STL` models in ASCII form will be converted to binary form
- `MP3` files will be repacked

### Command Line Options
These options enable file format conversion and other non-transparent features, which will alter the format of your files in order further reduce filesize.
Note that these options chain together—eg. `--gif-png --png-to-webp` results in .gif converted to .webp
| Option           | Description                                                                                                                                                                                                                                   |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--gif-png`      | Converts .gif files to .png, including animated gif to animated PNG. Likely results in a smaller file                                                                                                                                         |
| `--png-webp`     | Converts .png to .webp. Ignores animated PNGs. Aborts if the conversion results in a larger file than the optimized PNG                                                                                                                       |
| `--rar-zip`      | Converts .rar to .zip. Likely results in larger file, but allows processing of files within the rar. Converting to 7z likely superior                                                                                                         |
| `--cbr-cbz`      | Converts .cbr to .cbz. Likely creates a larger file, but allows image optimizations—resulting in ultimately smaller file                                                                                                                      |
| `--zip-7z`       | Converts zip to 7z. Aborts if larger than the original.                                                                                                                                                                                       |
| `--rar-7z`       | Converts rar to 7z. Allows recursive optimizations. Aborts if larger than original. Compressed with PPMd and LZMA separately, smallest is kept                                                                                                |
| `--7z-7paq`      | Convert 7z to zpaq. Aborts if larger than original. Still tries to optimize the 7z first. Zpaq is pretty much the highest-ratio archive-compressor that exists                                                                                |
| `--webp-in-cbz`  | Convert PNG files within CBZ to WebP. Resulting in substantially smaller files, but poor compatibility—many CBZ viewers wont open them                                                                                                        |
| `--jpg-webp`     | Convert JPG to WebP using the knusperli decoder. This process is slightly lossy, using WebP quality: 90. If the size reduction is <10%, conversion is rejected                                                                                |
| `--jpg-webp-cbz` | Enables the above option when processing CBZ files. The space saving can be considerable, justifying the very slight quality loss                                                                                                             |
| `--misc-png`     | Converts BMP and PCX files to PNG.                                                                                                                                                                                                            |
| `--keep-mod`     | Preserve the modification time of files, even if they are altered.                                                                                                                                                                            |
| `--omni-<ext>`   | Enables the 'omnicompressor' function for maximum size reduction for the specified file extension. Compresses with `gzip`, `bzip2`, `lz`, `rz`, `7z` on PPMd and `zpaq` on max, keeps the smallest. Extremely slow. Intended for archival use |
| `--iszip-<ext>`  | Forces a specified extension to be processed as a ZIP file.                                                                                                                                                                                   |
| `--video`        | Enables lossy video recompression of legacy formats into WebM. For why you might want to do this, see the note in the source file.                                                                                                            |
| `--audio`        | Enables compression of high-quality MP3 (>=256kbps) to Opus 128kbps. This will also apply within archive files, for converting albums.                                                                                                        |
| `--audio-agg`    | With `--audio`, converts MP3 to very low-bitrate Opus. Sound quality suffers. Intended for voice, never music. Also re-encodes .m4b files. All metadata preserved.                                                                            |
| `--discard-meta` | Discards metadata from image and PDF files. On PDF files can produce a considerable space saving! It only deletes the XML-based metadata, so the title remains.                                                                               |
| `--fix-ext`      | Detects some common file types with the wrong extension, and corrects.   

### Dependencies
Minuimus and it's supporting binaries are written on Ubuntu, but should be adaptable to other Linux distributions with little to no alteration. Running on Windows would require substantial modification and testing.
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
- `jbig2`- required for JBIG2 processing within PDFs ([Source](https://github.com/agl/jbig2enc), also available as part of pdfsizeopt install)
- `jbig2dec` - required for JBIG2 processing within PDFs
- `leanify` - additional JPEG, SWF, ICO and FB2 processing ([Source](https://github.com/JayXon/Leanify))
- `pdfsizeopt` - additional PDF processing ([Source](https://github.com/pts/pdfsizeopt)) (Installed to `/var/opt/pdfsizeopt/pdfsizeopt`–configurable in minuimus.pl)
- `pngout` - additional PNG processing ([Source](https://jonof.id.au/kenutils.html), also available as part of pdfsizeopt install)


