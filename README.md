```
            _                _                                   _ 
           (_)              (_)                                 | |
 _ __ ___   _  _ __   _   _  _  _ __ ___   _   _  ___     _ __  | |
| '_ ` _ \ | || '_ \ | | | || || '_ ` _ \ | | | |/ __|   | '_ \ | |
| | | | | || || | | || |_| || || | | | | || |_| |\__ \ _ | |_) || |
|_| |_| |_||_||_| |_| \__,_||_||_| |_| |_| \__,_||___/(_)| .__/ |_|
                                                         | |       
                                             by Codebird |_|       
```
**Note:** This is not the official repository. The original creator is known as Codebird and hosts Minuimus [here](https://birds-are-nice.me/software/minuimus.html).  
This repository was created to improve the documentation of dependencies and command line options, primarily to help create a reproducible dockerfile. Additionally, to serve as installation instructions for other users who may find the documentation at the source lacking, especially for a full installation with the numerous optional dependencies.

Two branches exist:
- `codebird-mirror`, containing the contents of [minuimus.zip provided by Codebird](https://birds-are-nice.me/software/minuimus.zip) (starting at v3.2.1)
- `main`, containing my dockerfile, documentation, and changes to the code

For a list of my changes see [below](#changes)

# minuimus.pl
- [minuimus.pl](#minuimuspl)
    - [Supported File Types](#supported-file-types)
    - [Command Line Options](#command-line-options)
    - [Dependencies](#dependencies)
    - [Changes](#changes)

Minuimus is a file optimizer utility script written in Perl. By default, it can be pointed to a file and it will transparently reduce the file size, leaving all pixels/text/audio/metadata intact. Using command line options, it can also run lossy optimizations and conversions.

As well as using it's own methods and four optional supporting binaries, Minuimus is dependent on many established utilities. 
It automates the process of calling all of these utilities—including recursively processing and reassembling container files (such as `ZIP`, `EPUB` and `DOCX`), detecting and handling any errors, and running integrity checks on the optimized files to prevent data loss. 
Based on which dependencies are installed, Minuimus will process files the best it can, and skip those that have no compatible tool installed.

As is the case for any optimizer, the size reduction achieved by Minuimus is highly dependent upon the input data. Even after extensive testing, the results are too inconsistent to easily quantify. Despite that, here are some examples:
- A collection of PDF files sampled from the-eye.eu was reduced by 10%
- A 500GB sample from the archive.org 'computermagazine' collection was reduced by 22%
- A collection of ePub files from Project Gutenberg was reduced by 5%, as these files are light on images, and ZIP files with no optimizable files inside are reduced only slightly, by about 3%

### Supported File Types
All processing is only saved to disk if the processed file is smaller and changes are transparent.
- `7Z` archives are extracted and files within processed, then recompressed using both LZMA and PPMd algorithms on highest practical settings. Whichever file is smallest is kept, unless the original file is smaller. Solid compression is not used
- `CAB` (Microsoft CAB) files are processed by `cab_analyze`—repackaged if possible. Signed `CAB` is ignored
- `CBZ` files are processed additionally beyond standard `ZIP` compression by converting `GIF`, `BMP`, `PCX` and `TIFF` files within to (animation-safe) `PNG`. Conversion from `PNG` to `WebP` is possible via command-line option
- `EPUB` files are processed additionally beyond standard `ZIP` compression by placing the `mimetype` file first using store-only compression in accordance with the EPUB OCF
- `FLAC` files are re-encoded using the highest possible profile-compliant settings (slightly better than the regular -9). Metadata is preserved. Mono audio tracks encoded as stereo are converted to true mono
- `GIF` files are processed by `gifsicle`, then if  <100KiB, `flexigif`
- `GZ` and `TGZ` files are processed by `advdef`
- `HTML`, `CSS` and `SVG` files are searched for any base64-encoded `JPG`, `PNG` or `WOFF` resources, which are optimized individually
- `JAR` files are only processed by `advzip`–altering the files within would invalidate any signing
- `JPEG` files are processed by `jpegoptim`. If a colour `JPEG` contains only grayscale values, empty color channels will be removed
- `MP3` files will be repacked
- `PDF` files are processed by `qpdf` to remove unused objects and versions, ensure consistent format and correct errors. `JPEG` objects are processed individually. DEFLATE compressed objects are processed by `minuimus_def_helper`. Unimportant metadata objects are deleted. Then the `PDF` is relinearised using `qpdf`. Then processed by `pdfsizeopt`
- `PNG` files are processed by `optipng`, then `advpng`, then `pngout`. Animated `PNG` processed by `optipng`, then `advdef`
- `STL` models in ASCII form will be converted to binary
- `SWF` files are processed by `minuimus_swf_helper`—internal `JPEG` and `PNG` objects are recompressed, and the outer DEFLATE wrapper run through `zopfli`
- `TIFF` files are re-compressed on highest setting supported by `imagemagick`
- `WOFF` files are processed by `minuimus_woff_helper`, a `zopfli`-based recompressor
- `ZIP` (and ZIP-derived formats:`CBZ`, `DOCX`, `EPUB`, `ODP`, `ODS`, `ODT`, and `XLSX`) are extracted and (non-archive) files within are processed individually, junk files such as Thumb.db and .ds_store are deleted, then recompressed into `ZIP` by `advzip`

### Command Line Options
| Option           | Description                                                                                          |
| ---------------- | ---------------------------------------------------------------------------------------------------- |
| `--check-deps`   | Checks for all core and optional dependencies (Actually checks for each called command individually) |
| `--help`         | Displays this help page                                                                              |
| `--version`      | Displays current version, release date and credits                                                   |

The following options enable file format conversion and other non-transparent features, which will alter the format of your files in order further reduce filesize.
Note that these can chain together—eg. `--gif-png --png-to-webp` results in .gif being converted to .webp
| Option           | Description                                                                                                                                                                                                                                   |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--7z-zpaq`      | Convert `7z` to `ZPAQ`. Aborts if larger than original. Tries to optimize the `7z` first                                                                                                                                                      |
| `--audio-agg`    | With `--audio`, converts `MP3` to very low-bitrate `OPUS`. Sound quality suffers. Intended for voice, never music. Also re-encodes .m4b files. All metadata preserved                                                                         |
| `--audio`        | Enables compression of high-quality `MP3` (>=256kbps) to `OPUS` 128kbps. This will also apply within archive files, for converting albums                                                                                                     |
| `--cbr-cbz`      | Converts `CBR` to `CBZ`. Likely creates a larger file, but allows image optimizations—resulting in ultimately smaller file                                                                                                                    |
| `--discard-meta` | Discards metadata from image and `PDF` files. Can produce considerable savings for `PDF`. It only deletes the XML-based metadata, so the title remains                                                                                        |
| `--fix-ext`      | Detects some common file types with the wrong extension, and corrects                                                                                                                                                                         |
| `--gif-png`      | Converts `GIF` files to `PNG`, including animated `GIF` to animated `PNG`. Likely results in a smaller file                                                                                                                                   |
| `--iszip-<ext>`  | Forces a specified extension to be processed as a `ZIP` file                                                                                                                                                                                  |
| `--jpg-webp-cbz` | Enables `--jpg-webp` when processing `CBZ` files. The space saving can be considerable, justifying the very slight quality loss                                                                                                               |
| `--jpg-webp`     | Convert `JPG` to `WebP` using the knusperli decoder. This process is slightly lossy, using WebP quality: 90. If the size reduction is <10%, conversion is rejected                                                                            |
| `--keep-mod`     | Preserve the modification time of files, even if they are altered                                                                                                                                                                             |
| `--misc-png`     | Converts `BMP` and `PCX` files to `PNG`                                                                                                                                                                                                       |
| `--omni-<ext>`   | Enables the 'omnicompressor' function for maximum size reduction for the specified file extension. Compresses with `gzip`, `bzip2`, `lz`, `rz`, `7z` on PPMd and `zpaq` on max, keeps the smallest. Extremely slow. Intended for archival use |
| `--png-webp`     | Converts `PNG` to `WEBP`. Ignores animated `PNG`. Aborts if the conversion results in a larger file than the optimized `PNG`                                                                                                                  |
| `--rar-7z`       | Converts `RAR` to `7z`. Allows recursive optimizations. Aborts if larger than original. Compressed with PPMd and LZMA separately, smallest is kept                                                                                            |
| `--rar-zip`      | Converts `RAR` to `ZIP`. Likely results in larger file, but allows processing of files within the `RAR`. Converting to `7z` likely superior                                                                                                   |
| `--srr`          | Enables 'Selective Resolution Reduction.' Scales images down, if doing so is lossless (or near lossless). That means pictures of flat colors, gradients, and sometimes pixel art
| `--video`        | Enables lossy video recompression of legacy formats into `WEBM`. For why you might want to do this, see the note in the source file                                                                                                           |
| `--webp-in-cbz`  | Convert `PNG` files within `CBZ` to `WEBP`. Results in substantial savings, but poor compatibility—many viewers wont open them                                                                                                                |
| `--zip-7z`       | Converts `ZIP` to `7z`. Aborts if larger than the original                                                                                                                                                                                    |

### Dependencies
Minuimus and it's supporting binaries are written on Ubuntu, but should be adaptable to other Linux distributions with little to no alteration. Running on Windows would require substantial modification and testing.

#### Build Dependencies 🟣
These are only required to build and install the `minuimus_***_helper` and `cab_analyze` binaries. As a perl script, `minuimus.pl` requires no compiliation and can be installed and run anywhere as is.
- `gcc`
- `libz-dev` - required for `minuimus_***_helper` binaries 
- `make`

#### Hard Dependency 🔴
- `perl` - required for running minuimus.pl 

#### Core Dependencies 🟠
Nearly all dependencies of Minuimus are optional, depending on what file types will be processed.  
Missing core dependencies will cause Minuimus to exit if processing a relevant file type is attempted.  
Running `minuimus.pl --check-deps` will output a list of all called commands, indicating if each is found or missing.  

- `advancecomp` - required for GZ, PNG, TGZ, and ZIP-derived format processing
- `cabextract` - required for CAB processing
- `ffmpeg` - required for MP3, FLAC, WEBM and video processing
- `gifsicle` - required for GIF processing
- `imagemagick-6.q16` - required for GIF, JPEG, TIFF
- `jpegotim` - required for JPEG processing
- `libjpeg-progs` - required for JPEG processing
- `optipng` - required for PNG processing
- `p7zip-full` - required for 7z processing
- `poppler-utils` - required for PDF processing
- `qpdf` - required for PDF processing
- `zip` - required for ZIP-derived format processing
- `zpaq` - required for ZPAQ processing

##### Additional `--options` Core Dependencies 🟡
If an option requires a dependency from [Core Dependencies](#core-dependencies-) it is omitted here
- `brotli` - required for `--omni-<ext>`
- `bzip2` - required for `--omni-<ext>`
- `file` - required for `--fix-ext` and `cbr-cbz`
- `gif2apng` - required for `--gif-png` 
- `gzip` - required for `--omni-<ext>`
- `knusperli` - required for `--jpg-webp` 
- `lzip` - required for `--omni-<ext>`
- `rzip` - required for `--omni-<ext>`
- `unrar` - required for `--rar-7z` and `--rar-zip`
- `webp` - required for `--jpeg-webp` and `--png-webp`

#### Optional Dependencies 🔵
Optional dependencies will be used if installed, and skipped if not
- `cab_analyze` - additional CAB processing (Optional part of Minuimus install)
- `flexigif` - additional GIF processing ([Source](https://create.stephan-brumme.com/flexigif-lossless-gif-lzw-optimization/))
- `jbig2`- additional PDF processing ([Source](https://github.com/agl/jbig2enc), also available as part of pdfsizeopt install)
- `jbig2dec` - additional PDF processing
- `leanify` - additional JPEG and SWF processing, required for ICO and FB2 processing ([Source](https://github.com/JayXon/Leanify))
- `minuimus_def_helper` - additional PDF processing (Optional part of Minuimus install)
- `minuimus_swf_helper` - additional SWF processing (Optional part of Minuimus install)
- `minuimus_woff_helper` - additional WOFF processing (Optional part of Minuimus install)
- `mupdf-tools` - additional PDF processing ([Source](https://mupdf.com/releases/index.html))
- `pdfsizeopt` - additional PDF processing ([Source](https://github.com/pts/pdfsizeopt)) With deps:
    - `imgdataopt` - addtional PDF processing ([Source](https://github.com/pts/imgdataopt))
    - `png22pnm` - required for `pdfsizeopt` ([Source](https://github.com/pts/tif22pnm))
    - `sam2p` - required for `pdfsizeopt` ([Source](https://github.com/pts/sam2p))
- `pngout` - additional PNG processing ([Source](https://jonof.id.au/kenutils.html), also available as part of pdfsizeopt install)

### Changes
List of changes this repo makes—excluding the dockerfile, which was created from scratch.
#### README
- Edits the summary for readability
- Merges basic list of supported file types with descriptions of processing, edits for readability, adds more formats
- Adds command line options documentation
- Adds list of dependencies, and how they are used
#### minuimus.pl
From top to bottom:
- Adds release dates to version history (starting at v3.2.1)
- Removes cruft from message when running minuimus.pl with no arguments
- ~~Alphabetizes and adds command line options available via `--help`~~ [merged]
- ~~Edits options text for clarity and brevity~~ [merged]
- ~~Adds `--version` option to display version/date/credits~~ [merged]
- ~~Adds `check-deps` option to check availablity of all required and optional dependencies~~ [merged]
- Moves check for `leanify` to subroutine to eliminate the warning message appearing when irrelevant
- ~~Adds subroutine `depcheck` utilized by `--check-deps` option~~ [merged]
