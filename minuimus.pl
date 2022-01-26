#!/usr/bin/perl


#Minuimus is released under the GPL v3, including the supporting programs written in C.
#It is written by Codebird, AKA CorvusRidiculissimus on Reddit.

#Changes:
# 1.1: Added WebP converson, fixed a bug in the .zip processing that caused deletion of thumbs.db and .ds_store to fail.
#      Would like to convert all GIFs and PNGs in CBZ files to WebP, but support for that format is not widespread in CBZ viewers, so I will not. Same reason I don't use arithmetic JPEG.
# 1.2: Improved performance on zip-family files: Will no longer reassemble the .zip file if none of the constituent files were altered.
#      Fixed a minor typo in instruction text.
#      Fixed a bug that caused deletion of empty directories in cbz files to fail.
# 1.3: Added the ability (disabled by default) to convert rar to zip and cbr to cbz, in order to enable further processing. Also because I dislike RAR.
#      Added minuimus_pdf_helper.
# 1.31:Fixed a resource leak in minuimus_pdf_helper.
# 1.4: Added a new PDF comparison routine using pdf2djvu which allows for the safe use of qpdf's recovery of malformed PDFs. Now even slightly-iffy PDFs can be optimised.
#      Fixed a bug which was causing zip files to be skipped - I must have inadvertently removed them from the list of zip formats while changing something earlier.
#      Licensed Minuimus and the minuimus_pdf_helper under the GPL v3.
#      Added support for .gz and .tgz files via advdef.
#      Replaced the many dependency checking routines with one testcommand() function.
# 1.5: Added RAR-to-7z capability.
#      Fixed a few minor mistakes in comments.
#      Will no longer go wrong when given a passworded rar.
#      Command-line option interpreter added: No need to edit the file before running it now.
#      Attempted to fix a bug where minuimus_pdf_helper sometimes hangs while processing certain PDFs. Fix has not been throughly tested. Might be fixed, might not.
#      Added option to preserve file modification times.
#      There's much in common between zip, rar and 7z parts - so now they are all handled by the same routine.
#      Added minuimus_woff_helper. Not as good as converting to woff2, but that wouldn't be transparent - this is. And WOFF fonts are used in EPUB files sometimes. Nice.
# 1.6  Clarified PDF error messages.
#      Rewrote zip_compare: Previous version was inefficient and choked on ZIPs containing files with accented characters in the filename.
# 1.7  Substantial improvements to minuimus_pdf_helper. This release focuses on extreme levels of PDF optimisation.
#      After further study of the PDF specification, determining that progressive JPEG is permitted (From PDF1.2 onwards), I altered minuimus_pdf_helper to use it.
#      Added more helpful output to minuimus_pdf_helper, counting objects recompresed.
#      Added the conversion of greyscale RGB images in PDF into true-greyscale.
#      Added some tidying of stream dictionaries to better handle unusual quirks, which were previously not recognised as potentially recompressible objects.
#      As a result of all of the above, PDF compression has been significently improved.
#      Additionally added a new trick for JPEG: Identifying greyscale images encoded as RGB, and turning them into true greyscale. Saves about 2KB per file thus optimised.
#      Added a little more error-handling code.
# 1.8  Extended agif2apng to include a workaround for a bug in the gif2apng external program. Silly program interprets absolute paths as command line arguments!
#      Added the 'omnicompressor' - an utterly ridiculous method that tries compressing with lots of utilities, and picks whichever works best.
#      Added 7z-zpaq.
#      Removed solid achive creation for 7z. Too much risk for too little gain.
#      Retained and reused the PDF file hash from first validation, if performed, for second validation. This just means that processing of slightly-damaged PDF files will be faster.
#      Added a check for free space *before* attempting a file, so it (probably) won't run out during processing. Probably. Still succeptable to zip-bombs.
#      Added JPG to WebP functionality (Slightly lossy, so only enabled by command line option - mostly intended for shrinking .cbz files.)
#      keep-mod now enabled for recursively processed containers. It's still not fully deterministic, as files may be re-ordered arbitarily, but it's a step closer.
#      Fixed a version compatibility issue with imagemagick.
# 1.9  Now deletes error-recovery and error-checking files from within CBZ. The recompression process renders them all worthless anyway.
#      JPEG to WebP conversion now uses -pass 10. Very, very slightly more efficient.
#      Improved PNG optimisation by using imagemagick to re-encode files using the adaptive encoder prior to the previous methods of optimisation.
#      Discovered that the improved ZIP comparison from 1.6 introduces new issues. So put the first one back in as a fallback.
# 2.0  Added FLAC support. Though in my testing, the space saving was pretty small, never more than two percent.
#      Now displays saving as a decimal, not just absolute byte counts.
#      Improved omnicompresser to detect rare-but-possible compression errors that might otherwise lead to corruption.
#      Fixed a bug causing .7z to become .7z. - with an extra dot.
# 2.1  HTML lower-case-er-izer. This is ridiculous - the space saving will be a fraction of a fraction of a percent. Still going to do it though.
#      Fixed two minor bugs in CBZ handling. Nothing major, they just caused less-then-optimal performance.
#      Added CAB file support. I'd hoped to be able to recompress, but CAB's compression is weird and obscure. MSZIP is almost DEFLATE, but differs just enough that I can't Zopfli it.
# 2.2  Added support for embedded base64 encoded objects within HTML, CSS and SVG files.
#      Fixed small omission in makefile.
#      Fixed potentially serious issue in minuimus_pdf_helper that could cause crashing or failed recompression.
#      Thanks to eed00 on Reddit for pointing that one out to me.
# 2.3  Added --iszip-<ext> option.
#      Added --misc-png option, and made it default within CBZ files.
# 2.4  Randomised $counter on startup. This relates to my testing-cluster, which currently has a shared /tmp/ while I convert it to root-on-NFS-with-local-tmp configuration.
#      Added SWF support. Though in testing, this has proven to be a bit disapointing. It does work, but the space saving is maybe 1% on average.
#      Added video reencoding support.
#      Added --fix-ext
#      Added MP3-to-Opus support.
#      Added generic_image_recode() - and with it, TIFF support.
#      Fixed a line in minuimus_woff_helper that wouldn't compile with some versions of Zopfli.
#      Added TIFF to the list of 'legacy' formats that can be converted to PNG/WebP if enabled.
# 2.5 Changed pdf2djvu for pdftoppm. This makes PDF testing much, much faster.
#      Complete rewrite of the PDF optimiser. New one is slower, but more capable (ie, smaller files) and much less succeptable to errors.
#      minuimus_pdf_helper is gone, replaced by minuimus_def_helper
#      Also has scope for further improvements, though it's at diminishing returns now.
#      Fixed a bug that could potentially corrupt HTML files if multiple instances of minuimus run at once, but only in very rare circumstances.
#      Made the temporary folder a configurable option, not just hard-coded /tmp/
# 2.6  Added audio mono-isation code.
#      Subtitle detection now looks for .SRT as well as .srt
#      Now uses ffmpeg's default bitrate for opus, as it automatically sets based on number of channels.
# 2.7  Improved capabilities of JPEG handling. Also recognises .jfif extensions as JPEG files.
#      Added automatic chaining with leanify, if present.
#      Now discards metadata on images contained within CBR/CBZ or PDF containers.
#      Added indio5 to list of obsolete codecs.
#      Fixed incorrect function reference to pdf_compare created in 2.5.
# 2.71 Tidied up audio bitrate determination and added the audio-agg option.
#      Added PAR2 to the list of extensions to discard from CBZ files (As they will be invalidated anyway)
#      Added del-zip-junk option.
# 2.8  Revised obsolete codec list. Also tries FLV now.
#      fix_ext now does rar/cbr mislabeled cbz/zip
#      Stereo detection now allows for a tiny amount of inter-channel difference, due to rounding errors in lossy compression.
#      Various changes in verbosity.
#      The 'most critical error' will now exit 255, causing xargs to terminate too.
#      Processing PDF files no longer requires jpegtran. Also very slightly improved PDF compression, but it won't save much.
#      Increased minuimus_def_helper memory minimum to 25MB. Tested is on a pi as well, seems to work fine on ARM.
#      Added STL file support. It doesn't actually work on most STL files, but those few it does work on, it works very well.
#      Added MP3 optimiser: It also doesn't actually work on most files. I found that some MP3 files - mostly very old ones - use an inefficient packing. Repacking saves maybe 1-4%.
# 2.9  No longer uses generic recode on PNGs: Anything it could do, later utility did better.
#      Added ability to strip metadata from PDF files. This can produce a considerable saving, as some PDF files are seriously bloated with useless metadata. Mostly for all the images within.
#      If that function isn't enabled, it still strips useless metadata from some internal objects where it isn't going to be of any use to anyone, giving a smaller saving.
#      qpdf version detection now automatic.
#      Minor adjustment to deciding which streams are candidates for reencoding.
# 3.0  Deletes '__MACOSX/*' from ZIPs.
#      Video now uses variable frame rate where appropriate. Most video processing toolchains support that now. It'll save space and processing time.
#      Added a WebM repacker - I found too many dodgy WebMs in circulation with invalid timecodes, I think there must be a program out there that makes them.
#      Removed --jpeg-keep-all from leanify call due to compatibility issues - it seems some versions of leanify don't recognise it.
# 3.1  Fixed a stupid, stupid bug in PDF verification. A single-character typo that meant corruption could be potentially missed!
#      Added the ability to convert RGB24 in PDF images to Y8 - the 'fake grey' where the pixels are 24-bit, but all of them are grey.
# 3.2  Chained pdfsizeopt into the PDF chain. It's a complicated program to install, but it suppliments minuimus nicely.
#      Added pngout into the png chain, but only if it's installed - it's not in the apt-get repository, so it's optional. It sometimes (though not usually) improves PNG compression further.
#      Doesn't do animated PNG though.
# 3.2.1  Minor compatibility improvements. Mostly moving from checking /usr/bin to using the 'which' command.
#      This is to improve compatibility between distros, as not all put their utilities in the same place.
#      Fixed typo in an error message.
#      Leanify now processes SVG and PNG when discard-meta enabled.
#      Fixed a bug in video reencode handling files with multiple audio - ffmpeg was dropping all but one track by default!
# 3.3  Re-fixed the bug with multiple audio: It wasn't fixed after all. Now it is.
#      advdef z4k changed to z4
#      Fixed a number of not-at-all-serious warnings visible with 'use warnings.'

use File::Spec;
use File::Copy;
use File::stat;
use Digest::SHA  qw(sha1 sha1_hex);
use MIME::Base64;
use Fcntl qw< LOCK_EX SEEK_SET >;

use strict;

use Cwd;
my %empty;
my $counter=int(rand(10000));
my $tmpfolder='/tmp'; #Temp folder. No trailing /.
my $qpdfvers=0;
my $pdfsizeopt;
my $pdfsizeoptpath='/var/opt/pdfsizeopt/pdfsizeopt';

if (!@ARGV) {
  print("  minuimus.pl: condēnstor optimum tardissimum.\n\n  The best, slowest, compresser.\n", #Condēnsō with -tor suffix. New Latin, I can make up words if I want to.
        "  Minuimus makes files smaller, while leaving them functionally equivilent. It does this in a completely transparent manner - the smaller file is functionally equivilent to the original, and may be substituted for it without issue.\n",
        "  It does this by calling upon a number of compression utilities: The AdvanceCOMP suite, optipng, jpegoptim, gifsicle, flexigif, qpdf, and several others.\n",
        "  While you could just call these directly, minuimus can go one level better: It not only selects the right utility for each file, it will also extract the contents of zip and zip-like files such as epub or docx, and apply those utilities to all the files within as well. It even checks for animated PNG files and ensure only animation-safe utilities (ie, not advpng) are used.\n\n  It validates files after processing, comparing and looking for potential errors and unusual cases, automating the process from start to end. You need only point it to your files, wait, and watch them shrink.\n\n");
  print("    minuimus.pl <file> [file] [file] ... [file]\n");
  print("  For processing large numbers of files, use find:\n   find <target> -type f -print0|xargs -0 -P <threads> -n 8 minuimus.pl\n  or\n   find <target> -type f -print0|parallel -0 -n 4 minuimus.pl\n\n",
        "  Supported types:\n  png jpg/jpeg gif tiff\n  zip epub docx xlsx jar cbz xps\n  pdf woff\n  gz tgz\n  flac swf\n",
        "  Unsupported extensions will be ignored.\n\n",
        "  minuimus.pl requires a number of supporting binaries, and will exit if a required component is missing. Most of these should be obtainable via your distribution's package managment. It also has supporting binary files (supplied as C code) which are not required to run minuimus, but will increase its capabilities. For full installation instructions, see the README file.\n",
        "  For a full description of miniumus's operation and how each file type is optimised, see https://birds-are-nice.me/software/minuimus.html\n",
        "  For ubuntu, 'make deps', 'sudo make install', then fetch flexigif from https://create.stephan-brumme.com/flexigif-lossless-gif-lzw-optimization/\n\n",
        "  Minuimus is also capable of automating the conversion of many file types to more compact equivilents, but this ability is not transparent and so is not enabled by default. View 'minuimus.pl --help' to see the options for enabling these type conversions. \n\n");
  exit(0);
}

my %options={};



my %testedcommands={};

#my $input_file = File::Spec->rel2abs($ARGV[0]) ;

for (@ARGV) {
  if(substr($_, 0, 2) eq '--'){
    $options{substr($_, 2)}=1;
  }
}
my @files = map { File::Spec->rel2abs($_) } @ARGV;
$options{'recur-depth'}=1;

if($options{'help'}){
  print("Minuimus, by default, performs only transparent conversions: It will never convert one type of file unless you explicitly enable this function.\n",
        "          These options enable file format conversion and other non-transparent features, which will alter the format of your files in order to make them more compact:\n\n",
        "  --gif-png      Converts .gif files to .png, including animated gif to animated PNG. This will almost always result in a smaller file.\n",
        "  --png-webp     Converts .png (Or, with above option, .gif) to .webp. Ignores animated PNG files. Aborts if the conversion would result in a larger file than the post-optimisation PNG.\n",
        "  --rar-zip      Converts .rar to .zip. This will almost always make the file larger, but it does allow for the processing of files within the rar. Converting to 7z may be a better choice.\n",
        "  --cbr-cbz      Converts .cbr to .cbz. This may make the file larger, but - as it allows for the use of the image-specific optimisations - usually makes them smaller. Also I just dislike RAR.\n",
        "  --zip-7z       Converts zip to 7z, including recursive optimisations, but only if this results in a smaller file than the original.\n",
        "  --rar-7z       Converts rar to 7z, including recursive optimisations, but only if this results in a smaller file than the original.\n",
        "                 .rar and .7z typically use different compression algorithms (Generally PPMd vs LZMA), but they are both sophisticated and neither is clearly superior for all data.\n",
        "                 Fortunately 7z supports both! So Minuimus will compress twice, once with LZMA and once with PPMd, and pick whichever performs best. So it'll almost always be smaller than RAR.\n",
        "  --7z-7paq      Convert 7z to zpaq, only if this makes a smaller file. Still tries to optimise the 7z first. Zpaq is pretty much the highest-ratio archive-compresser that exists.\n",
        "  --webp-in-cbz  Convert PNG files within CBZ to WebP. The resulting files will be very substantially smaller, but exhibit poor compatibility: Many CBZ viewers wont open them. Maybe one day.\n",
        "  --jpg-webp     Convert JPG to WebP. Uses the knusperli jpeg decoder. This process is lossy, but only very slightly, as it uses WebP quality 90.\n",
        "                 If the space saving is less than 10% of the file size - which will be true for all but the highest-quality-setting JPEGs - then the conversion is rejected and original kept.\n",
        "  --jpg-webp-cbz Enables the above option when processing CBZ files. The space saving can be considerable, justifying the very slight loss of quality.\n",
        "  --misc-png     Converts BMP and PCX files to PNG.\n",
        "  --keep-mod     Preserve the modification time of files, even if they are altered.\n",
        "  --omni-<ext>   Enables the 'omnicompressor' function for the specified file extension: Compress it with gzip, bzip2, lz, rz, 7z on PPMd and zpaq on max, and keep whichever is smallest.\n",
        "                 This is a somewhat extreme option, for desperate people who have a need to save every last byte, no matter how long it takes. It's intended for archival use.\n",
        "                 It's troublesome to extract, as whoever ends up with the files will probably need to install some software to do so. It's also unbelievably, ridiculously slow.\n",
        "  --iszip-<ext>  Forces a specified extension to be processed as a ZIP file.\n",
        "  --video        Enables lossy video recompression of legacy formats into WebM. For exactly why you might want to do this, see the note in the source file.\n",
        "  --audio        Enables compression of high-quality MP3 (>=256kbps) to Opus 128kbps. This will also apply within archive files, for converting albums.\n",
        "  --audio-agg    With --audio, converts MP3 to very low-bitrate Opus. Sound quality suffers. Intended for voice, never music. Also reencodes .m4b files. All metadata preserved.\n",
        "  --discard-meta Discards metadata from image and PDF files. On PDF files can produce a considerable space saving! It only deletes the XML-based metadata, so the title remains.\n",
        "  --fix-ext      Detects some common file types with the wrong extension, and corrects.\n\n");
  exit(0);
}
#If you're looking for the note on why these's a video mode: Error detection, in short. All it does really is run ffmpeg, but use this script and you get the benefit of some fancier integrity checking.
#It'll compare the length in seconds of video before and after, so there's no chance of losing material because of a corrupted input file causing the encoder to crash.
#Added bonus: If it finds an SRT file with the same name, it'll automatically include that too! Can't set the language tag though.
#Be warned that it will delete the input file if encoding is successful.
#This is really intended to rid the world of the really old legacy formats: DivX, WMV, MPEG1, etc. Ancient tech. With AV1 and the settings this uses, the loss of quality from reencode is not significent.
#Mostly because any video in those formats will look terrible anyway. But it will make them much smaller, which is very nice.
#Something to watch out for though: The ffmpeg in distro repositories tends to be /seriously/ out of date regarding libaom-av1, and you *need* a recent version. v1.0.0 sucks. Unusably slow.
#At time of writing, ubuntu 20.04's apt-get only gives you libaom-av1 1.0.0 - the latest has passed 2.0.0 now! So you're probably going to have to compile ffmpeg yourself.

#Imagemagick commands differ by distro. This should pick them up.
my $im_identify='identify-im6';
my $im_convert='convert-im6';
`which $im_identify`;
if($?){$im_identify='identify'};
`which $im_convert`;
if($?){$im_convert='convert'};

`which leanify`;
if($?){
  print("leanify not found. This is not a serious problem: Minuimus does not require leanify, but if present, it will be used to augment minuimus's own methods. Minuimus together with Leanify can achieve better compression than either could achieve alone.\n");
}

for (@files) {
  if(-f $_){
    compressfile($_, \%options);
  }
}

sub compressfile($%) {
  my $file=$_[0];
  my %options = %{$_[1]};
  my $saving=0;
  if ($file =~ m/[";`\n]/){
    print("Skipping $file due to potential attempted exploit in filename.\n");
    return;
  }

  # Used to determine if any improvement was actually achieved.
  my $initialsize = -s $file;
  if(!$initialsize){
    print("Input file '$file' does not exist or has zero size.\n");
    return;
  }
  if($options{'fix-ext'}){
    $file=fix_proper_ext($file);
  }
  my $freespace=getfreespace();
  if($freespace < $initialsize/256){
    print("Possible insufficient free space on $tmpfolder - aborting. Will not attempt to process a file without 2x file size free. File $initialsize, free $freespace.\n");
    return;
  }
  my $oldtime;
  if($options{'keep-mod'}){
     $oldtime=stat($file)->mtime;
  }else{
    $oldtime=time;
  }
  print("Attempting: $file:$initialsize\n");
  my $ext=lc($file);
  $ext=~s/^.*\.//;
  if ($ext eq 'epub') {
    # Every time you so much as open an epub in Calibre, it creates this.
    system('zip', '-d',$file, 'META-INF/calibre_bookmarks.txt');
  }
  if($ext eq 'woff'){
    process_woff($file);
  }
  if($options{'audio'}){
    if($ext eq 'mp3'){
      $file=recode_audio($file);
    }
    if($options{'audio-agg'} &&
      ($ext eq 'm4b')){
      $file=recode_audio($file);
    }
    $ext=lc($file);
    $ext=~s/^.*\.//;
  }
  if($ext eq 'mp3'){
    process_mp3($file);
  }
  if($ext eq 'tiff' || #This is the only handler for TIFF.
     $ext eq 'gif'){  #It also applies the first effort on optimising GIF, but better tools follow further down.{
    generic_image_recode($file);
  }
  if ($ext eq 'gif') {
    if( $options{'gif-png'} ) {
      $file=agif2apng($file); #If successful, returns new name. Otherwise returns old name.
      $ext=lc($file);
      $ext=~s/^.*\.//;
    }else{
      compress_gif($file);
    }
  }

  if (($ext eq 'pcx' ||
      $ext eq 'bmp' ||
      $ext eq 'tiff')
      && $options{'misc-png'}){
    $file=img2png($file);
    $ext=lc($file);
    $ext=~s/^.*\.//;

  }
  if ($ext eq 'png') {
    compress_png($file);
    $options{'discard-meta'} && leanify($file);
    if( $options{'png-webp'} ) {
      $file=png2webp($file); #If successful, returns new name. Otherwise returns old name.
      $ext=lc($file);
      $ext=~s/^.*\.//;
    }
  }
 
  if ($ext eq 'jpg' || $ext eq 'jpeg' || $ext eq 'jfif') {
    process_jpeg($file, $options{'discard-meta'});
    leanify($file, $options{'discard-meta'});
    if($options{'jpg-webp'}){
      $file=jpeg2webp($file);
      $ext=lc($file);
      $ext=~s/^.*\.//;
    }
  }
  
  if ($ext eq 'ico' ||
      $ext eq 'fb2') {
    leanify($file);
  }
  if ($ext eq 'stl') {
    process_stl($file);
  }
  if ($ext eq 'pdf') {
    compress_pdf($file, $options{'discard-meta'});
    pdfsizeopt($file);

  }
  if ($ext eq 'flac') {
    compress_flac($file);
  }
  if ($ext eq 'cab') {
    compress_cab($file);
  }
  if ($ext eq 'html' ||
      $ext eq 'htm') {
    process_html($file);
    optimise_base64_file($file);
  }
  if ($ext eq 'svg' ||
      $ext eq 'css'){
    optimise_base64_file($file);
    $options{'discard-meta'} && leanify($file);
  }
  if ($ext eq 'jar') { #Not going to take these apart, too much risk of breaking things.
    testcommand('advzip');
    system('advzip', '-z4', '-q', $file);
  }
  if($ext eq 'gz' ||
     $ext eq 'tgz' ){
    testcommand('advdef');
    system('advdef', '-z4', $file);
  }
  if($ext eq 'swf'){
    `which minuimus_swf_helper `;
    if( ! $?){
      testcommand('jpegoptim');
      system('minuimus_swf_helper', 'z', $file, $file);
    }else{
      print("Optional helper minuimus_swf_helper not found - skipping SWF file.\n");
    }
    leanify($file);
  }
  if ($ext eq 'webm'){
    repack_webm($file);
  }
  if($options{'video'} &&(
    $ext eq 'avi' ||
    $ext eq 'mpg' ||
    $ext eq 'mpeg' ||
    $ext eq 'ogm' ||
    $ext eq 'mov' ||
    $ext eq 'flv' ||
    $ext eq 'ts' ||
    ($ext eq 'mp4' && $options{'video-agg'})
    )){
    $file=processvideo($file);
    $ext=lc($file);
    $ext=~s/^.*\.//;
  }

  if ($ext eq 'docx' ||
     $ext eq 'pptx' ||
     $ext eq 'xlsx' ||
     $ext eq 'zip' ||
     $ext eq 'cbz' || #Comic book archive
     $ext eq 'odt' || #OpenDocument
     $ext eq 'ods' || #OpenDocument
     $ext eq 'odp' || #OpenDocument
     $ext eq 'epub'||
     $ext eq 'xps' ||
     $ext eq '7z' ||
     ($ext eq 'cbr' && $options{'cbr-cbz'}) ||
     ($ext eq 'rar' && $options{'rar-zip'}) ||
     $options{"iszip-$ext"}){
    $options{'recur-depth'} || return(0);
    my $outtype='zip';
    if($ext eq 'zip' && $options{'zip-7z'}){$outtype='7z'}
    if($ext eq '7z' ){$outtype='7z'}
    
    my $ret=compress_zip($file,$outtype);
    if($ret){
      if($ret ne $file){
        print("  New filename $ret\n");
        $file=$ret;
        $ext=lc($file);
        $ext=~s/^.*\.//;
      }
    }else{
      print("Archive processing failed.\n");
    }
  }

  if($ext eq '7z' && $options{'7z-zpaq'}){
    my $ret=compress_zip($file,'zpaq');
    if($ret){
      if($ret ne $file){
        print("  New filename $ret\n");
        $file=$ret;
        $ext=lc($file);
        $ext=~s/^.*\.//;
      }
    }else{
      print("7z-zpaq conversion failed.\n");
    }
  }

  if($ext eq 'rar' && $options{'rar-7z'}){
    $options{'recur-depth'} || return(0);
    my $ret=compress_zip($file,'7z');
    if($ret){
      if($ret ne $file){
        print("  New filename $ret\n");
        $file=$ret;
        $ext=lc($file);
        $ext=~s/^.*\.//;
      }
    }else{
      print("Archive processing failed.\n");
    }
  }



  if( $options{"omni-$ext"}){
    my $ret=omnicompress($file);
    if($ret){
      if($ret ne $file){
        print("  New filename $ret\n");
        $file=$ret;
        $ext=lc($file);
        $ext=~s/^.*\.//;
      }
    }
  }


  my $finalsize= -s $file;
  if(!$finalsize){
    print("Minuimus most critical error encountered - data loss has resulted - aborting)! File was $file\n");
    exit(255);
  }
  if ($initialsize ne $finalsize) {
      my $rate=$finalsize/$initialsize;
      print("  Success! $initialsize to $finalsize ($rate)\n");
      utime($oldtime, $oldtime, $file);
      $saving=1;
  } else {
    print("  No space saving achieved ($initialsize->$finalsize).\n");
  }
  return($saving);
}

sub process_jpeg($$$){
  my $file=$_[0];
  my $copytype='all';
  if($_[1]){ #A flag indicating that the file metadata may be discarded. Use when compressing a JPEG inside of another format.
    $copytype='none';
  }
  my $ignoregrey=$_[2]; #Disables the greyscale image detection.
  testcommand('jpegoptim');
  $ignoregrey || testcommand('jpegtran');
  $ignoregrey || testcommand($im_identify);
  $ignoregrey || testcommand($im_convert);
  my $ret=system('jpegoptim', '-T1', '--all-progressive', '-p', '-q', $file);
  if($ret){
    print "  Aborting processing of JPEG file. May be a damaged file or incorrect extension?\n";
    return($file);
  }


  my $tempfile="$tmpfolder/greyconv-$$-$counter.jpg";
  $counter++;
  my $grey='';

  if(!$ignoregrey && fileisgrey($file)){
      print "  JPEG is greyscale but encoded as color. Converting to true greyscale if this reduces usage.\n";
      $grey='-grayscale';
  }
  `which jpegtran`;
  if($?){
    `jpegtran -optimize -progressive -copy $copytype $grey "$file" > $tempfile`;
    my $before = -s $file;
    my $after = -s $tempfile;
    if($? || !$after ||$after >= $before){
      unlink($tempfile);
      return($file);
    }
    move($tempfile, $file);
    unlink($tempfile);
  }
  leanify($file);
  return($file);
}

sub fileisgrey(){
  my $file=$_[0];
  my $desc=`$im_identify "$file"`;
  if(!($desc =~ m/ 8-bit sRGB /)){
    return(0);
  }
  my $pipe;
  my $pid=open($pipe, '-|',"$im_convert \"$file\" rgb:-");
  if(!$pid){
    return(0);
  }
  binmode($pipe);
  while(!eof($pipe)){
    my $a;my $b;my $c;
    my $check=read($pipe, $a, 1);
    $check+=read($pipe, $b, 1);
    $check+=read($pipe, $c, 1);
    if(($check!=3) || ($a ne $b) || ($b ne $c)){
      close($pipe);
      return(0);
    }
  }
  close($pipe);
  return(1);
}

sub jpeg2webp(){
  #This function is lossy, and so will only be used if the appropriate command-line option is given. It's not very lossy though. Tiny degredation.
  my $input_file=$_[0];
  my $tempfile="$tmpfolder/$$-$counter.png";
  $counter++;
  my $output_file=$input_file;
  $output_file =~ s/\.jpg$/\.webp/i;
  $output_file =~ s/\.jpeg$/\.webp/i;
  if(($input_file eq $output_file) || -e $output_file){
    return($input_file);
  }
  printq("  Attempting JPEG to WebP.\n");
  testcommand('knusperli');
  testcommand('cwebp');
  my $ret=system('knusperli', $input_file, $tempfile);
  if($ret || !(-f $tempfile)){
    print("Error in knusperli.\n");
    unlink($tempfile);
    return($input_file);
  }
  $ret=system('cwebp', '-sharp_yuv', '-m', '6', '-q', '90', '-quiet', '-pass', '10', $tempfile, '-o', $output_file);
  unlink($tempfile);
  if($ret || !(-f $output_file)){
    print("Error in cwebp.\n");
    unlink($output_file);
    return($input_file);
  }
  if((-s $output_file) > (-s $input_file)*0.9){
    printq("    Not worth the quality loss.\n");
    unlink($output_file);
    return($input_file);
  }
  unlink($input_file);
  return($output_file);
}

sub getsha256($){
  my $makesha256 = Digest::SHA->new("sha256");
  my $fh;
  open($fh, '<', $_[0]);
  $makesha256->addfile($fh);
  close($fh);
  return(lc($makesha256->hexdigest));
}

sub png2webp(){
  my $file=$_[0];
  testcommand('cwebp');
  my $anim=is_animated_png($file);
  my $output_file=$file;
  $output_file=~ s/\.png$/\.webp/i;

  if ($anim != 0){
    # Either animated, or not a PNG.
    return($file);
  }
  print "Attempting png->webp conversion.\n";
  if(-e $output_file){
    print("  WEBP file exists already.\n");
    return($file);
  }
  my $tempfile="$tmpfolder/$$-$counter.webp";
  $counter++;
  system('cwebp', $file, '-lossless', '-quiet', '-z', '9', '-metadata', 'all', '-o', $tempfile);
  if($? || (! -f $tempfile)){
    print("  cwebp failed.\n");
    unlink($tempfile);
    return($file);
  }
  my $before= -s $file;
  my $after= -s $tempfile;
  if($after >= $before){
    printq("  No space saving from webp conversion. Unusual.\n");
    unlink($tempfile);
    return($file);
  }

  move($tempfile, $output_file);
  if(-f $output_file){
    print("Converted '$file' to '$output_file'\n");
    unlink($file);
    return($output_file);
  }
  return($file);
}

sub img2png(){
  #Converts most images to PNG.
  #But not GIFs. Well, it would do GIFs, but it wouldn't preserve their animation.
  my $input_file=$_[0];
  my $not_ext=substr($input_file, 0,rindex($input_file, '.')+1);
  my $tempfile="$tmpfolder/$$-$counter.png";
  $counter++;
  my $newname=$not_ext.'png';
  if(-e $newname){
    print "  Cannot convert file: Output '$newname' exists.\n";
    return($input_file);
  }
  testcommand($im_convert);
  my $ret=system($im_convert, $input_file, $tempfile);
  if($ret){
    unlink($tempfile);
    return($input_file);
  }
  $newname=$not_ext.'png';
  print "  Converted '$input_file' to '$newname'\n";
  move($tempfile, $newname);
  if(! -f $newname){
    print("  Conversion failed.\n");
    unlink($tempfile);
    return($input_file);
  }
  unlink($input_file);
  return($newname);
}

sub agif2apng($) {
  my $input_file=$_[0];
  my $initialcwd;
  if (substr($input_file, 0, 1) eq '/'){
    $initialcwd=getcwd();
    chdir('/');
    $input_file=substr($input_file, 1);
#    print("Patch: $input_file\n");
  }
  my $output_file=$input_file;
  $output_file=~ s/\.gif$/\.png/i;
  print("Converting $input_file to $output_file\n");
  if(-e $output_file){
    print("  Conversion failed: $output_file exists.\n");
    return($input_file);
  }
  testcommand('gif2apng');
  system('gif2apng', $input_file, $output_file);
  if($initialcwd){
    chdir($initialcwd);
    $input_file='/'.$input_file;
    $output_file='/'.$output_file;
  }
  if( $? && -f $output_file ){ unlink($output_file); }

  if( -f $output_file ){
    print("Gif $input_file converted.\n");
    unlink($input_file);
  }else{
    print("Conversion failed.\n");
    return($input_file);
  }
  compress_png($output_file);
  return($output_file);
}

sub compress_cab(){
  my $input_file=$_[0];
  if(!-e '/usr/bin/cab_analyze'){
    printf("/usr/bin/cab_analyse not found. Installing this helper might permit a small - very small - space reduction of CAB files. Maybe a few K at most.\n");
    return;
  }
  testcommand('cabextract');
  my $tempfile="$tmpfolder/$$-$counter";
  $counter++;
  my $ret=system('/usr/bin/cab_analyze', $input_file, $tempfile);
  if($ret && -f $tempfile){unlink($tempfile)};
  if(-s $input_file <= -s $tempfile){unlink($tempfile)};
  if(!-f $tempfile){return;}
  my $a = `cabextract "$input_file" -p | sha256sum`;
  my $b = `cabextract "$tempfile" -p | sha256sum`;
  if($a ne $b){
    unlink($tempfile);
    printf("CAB file reduction failed in verification.\n");
  }
  if(-f $tempfile){
    printf("Cab file reduction successful.\n");
    move($tempfile, $input_file);
  }
}

sub compress_zip() {
  #Not just ZIP! This also handles zip-container-based formats.
  #It may also be used for archive conversion, so it returns 0 on fail, or the new filename on success.
  my $input_file=$_[0];
  my $outtype=$_[1]; # 'zip' 'cbz' or '7z'
  my $intype='zip';
  my $output_file=substr($input_file, 0, rindex($input_file, '.'));
  my $ext=substr($input_file, rindex($input_file, '.'));

  if(!$outtype){$outtype='zip'}
  if($outtype eq 'zip'){
    $output_file = $output_file.$ext;
    $output_file=~ s/\.cbr$/\.cbz/i;
    $output_file=~ s/\.rar$/\.zip/i;
  }
  if($outtype eq '7z'){
    $output_file = $output_file.'.7z';
    testcommand('7z');
  }
  if($outtype eq 'zpaq'){
    $output_file = $output_file.'.zpaq';
    testcommand('zpaq');
  }

  my %suboptions;
  $suboptions{'recur-depth'}=0;
  $suboptions{'keep-mod'}=1;
  testcommand('zip');
  testcommand('advzip');
  my $initialcwd=getcwd();
  if($ext eq '.rar' ||
     $ext eq '.cbr' ){
    testcommand('unrar');
    $intype='rar';
  }
  if($ext eq '.7z' ||
     $ext eq '.cb7'){
    $intype='7z';
  }
  if($ext eq '.epub' ||
     $ext eq '.docx' ||
     $ext eq '.pptx' ||
     $ext eq '.xlsx' ){
    $suboptions{'discard-meta'}=1;
  }

  if($ext eq '.cbz' ||
     $ext eq '.cbr' ||
     $ext eq '.cb7'){
    $suboptions{'fix-ext'}=1;
    $suboptions{'discard-meta'}=1;
    $suboptions{'gif-png'}=1;
    $suboptions{'misc-png'}=1;
    print("  Converting obsolete image formats to CBZ-friendly formats.\n");
    $suboptions{'png-webp'}=$options{'webp-in-cbz'};
    $suboptions{'png-webp'} && print("  Using PNG-to-WEBP conversion.\n");
    $suboptions{'jpg-webp'}=$options{'jpg-webp-cbz'};
    $suboptions{'jpg-webp'} && print("  Using JPG-to-WEBP conversion.\n");
  }
  $suboptions{'jpg-webp'}=$suboptions{'jpg-webp'} || $options{'jpg-webp-archive'};
  
  if($ext eq '.zip' ||
    $ext eq '.rar' ||
    $ext eq '.7z' ||
    $ext eq '.zpaq'){
    #Additional handling for 'pure' archive formats.
    $suboptions{'audio'}=$options{'audio'};
    $suboptions{'gif-png'}=$options{'zip-images'};
    $suboptions{'misc-png'}=$options{'zip-images'};
    $suboptions{'png-webp'}=$options{'zip-images'};
  }
  
  my $zipclear=0;
  if($ext eq '.cbz' || ($ext eq '.zip' && $options{'del-zip-junk'})){
    system('zip', '-qd',$input_file, '*/', #Looks weird, but actually here to delete empty directories.
           '*.PAR2', '*.PAR', '*.P01', '*.P02', '*.P03', '*.P04', '*.P05', '*.P06',#And all this error correction
           '*.SFV', '*.MD5', '*.csv', '*.sfv', '*.md5',                 #Which we are about to invalidate.
           'WS_FTP.LOG', '*/SUPERJPG.TNC', 'PPThumbs.ptn', #And that is just sloppy!
           '*/PPThumbs.ptn', '*/WS_FTP.LOG','*/.DS_Store','.DS_Store','*/Thumbs.db','Thumbs.db',
           '__MACOSX/*');
     $zipclear=1;
  }


  if(!$zipclear && ($intype eq 'zip' )){
    system('zip', '-qd',$input_file, '*/.DS_Store','.DS_Store','*/Thumbs.db','Thumbs.db', 'SUPERJPG.TNC', '*/SUPERJPG.TNC'); #Dirt. There's nothing of value in these.
    system('advzip', '-z4', '-q', $input_file);
  }

  my $id="$$-$counter";
  $counter++;
  my $tempfolder="$tmpfolder/zipshrink$id";
  if (-e $tempfolder) {
    die "Fatal error in archive extraction: Temporary directory already exists. Try clearing old folders from $tmpfolder.";
  } 

  mkdir($tempfolder);
  chdir($tempfolder);
  print("  Decompressing  container.\n");
  if (  extract_archive($input_file) ) {
    print "Archive error 1: Decompress failed on $input_file\n";
    chdir("$tmpfolder/");
   `rm -rf $tempfolder`;
   chdir($initialcwd);
   return(0);
  }


  #Keep it to the simple files only.
  my @filelist=sort split(
    /\0/,
    `find . -type f -print0`
  );
  my $numfiles=@filelist;

  my $savedfiles=0;
  for (@filelist){
    $savedfiles+=compressfile($_, \%suboptions);
  };
#$savedfiles=1;
  if(!$savedfiles &&
      $intype eq 'zip' &&
      $outtype eq 'zip'){
    print("  No sub-files were compressed, not attempting reassembly.\n");
    chdir($tmpfolder);
    `rm -rf $tempfolder`;
    chdir($initialcwd);
    return($output_file);
  }
  print(" Compressed $savedfiles sub-files.\n");
  my $tempfile="$tmpfolder/ziptmp$id.zip";
  if(lc(substr($input_file, -4)) eq '.cbz' ||
     lc(substr($input_file, -4)) eq '.cbr' ){
    $tempfile="$tmpfolder/ziptmp$id.cbz";
  }
  if($outtype eq '7z'){
    $tempfile="$tmpfolder/ziptmp$id.7z";
  }
  if($outtype eq 'zpaq'){
    $tempfile="$tmpfolder/ziptmp$id.zpaq";
  }
  print("  Reassembling into container.\n");
  my $ret;
  if($outtype eq '7z'){
    $ret=make_7z($tempfile);
  }elsif ($outtype eq 'zpaq'){
    $ret=make_zpaq($tempfile);
  }else{
    $ret=make_zip($tempfile);
  }
  chdir($tmpfolder);
  `rm -rf "$tempfolder"`;
  if($ret || (! -f $tempfile)){
    print("  Archive creation failed.\n");
    unlink($tempfile);
    chdir($initialcwd);
    return(0);
  }

  if((lc(substr($input_file, -4)) eq '.zip' ||
     lc(substr($input_file, -4)) eq '.cbz' ) &&
     (lc(substr($output_file, -4)) eq '.zip' ||
     lc(substr($output_file, -4)) eq '.cbz' )){
    if (!zip_compare($input_file, $tempfile)) {
      print("  Zip error 3: Although the process appeared to complete successfully, the output file differs in number of contained files from the input.\n  Something must have gone wrong. Aborting.\n");
      unlink($tempfile);
      chdir($initialcwd);
      return(0);
    }
  }


  my $insize = -s $input_file;
  my $outsize = -s $tempfile;
  if(!$outsize){
    print("Archive creation failed.\n");
    return(0);
  }
  my $ignoresize=0;
  if(lc(substr($input_file, -4)) eq '.cbr'){$ignoresize=1};
  if (($outsize >= $insize) && !$ignoresize) {
    print("  Failed to achieve significant space savings ($input_file, $insize->$outsize).\n");
    unlink($tempfile);
    chdir($initialcwd);
    return($input_file);
  }
  unlink($input_file);
  move($tempfile, $output_file);
  chdir($initialcwd);
  return($output_file);
}



sub zip_compare(){
  #Call with two filenames for ZIP files.
  #Returns:
    #0: The files have different numbers of entries within.
    #1: The files have the same number of entries within.
    #2: Unable to compare files. Most likely because on of them contains a zip comment.
  my ($namea, $nameb) = @_;
  print "Comparing $namea and $nameb.\n";

  open(my $filea, '<:raw', $namea) || return(2);
  binmode($filea);
  seek($filea, -22, 2);
  my $dataa='';
  read($filea, $dataa, 4);
  if(unpack('H*',$dataa) ne '504b0506'){ close($filea); return(2);}
  seek($filea, -12, 2);
  read($filea, $dataa, 2);
  close($filea);

  open(my $fileb, '<:raw', $nameb) || return(2);
  binmode($fileb);
  seek($fileb, -22, 2);
  my $datab='';
  read($fileb, $datab, 4);
  if(unpack('H*',$datab) ne '504b0506'){ close($fileb); return(2);}
  seek($fileb, -12, 2);
  read($fileb, $datab, 2);
  close($fileb);

  if($dataa eq $datab) {return(1);}

  #Either the zips don't match, or there's something throwing off the first comparison. Like empty folders.
  #Or a zip comment. Fall back to the alternate comparison method.
  my $a=`advzip -l \"$namea\" |grep -iv \"/\$\"|wc -l`;
  my $b=`advzip -l \"$namea\" |grep -iv \"/\$\"|wc -l`;

  if($a == $b) {return(1);}

  #No, these zips don't match.
  return(0);
}

sub process_woff(){
  my $file=$_[0];
  if(! -e '/usr/bin/minuimus_woff_helper'){
    print("/usr/bin/minuimus_woff_helper not found. Installing this will allow a small (very small) reduction in the size of WOFF fonts, including those in EPUB files. Around 2% smaller.\n");
    return;
  }
  system('minuimus_woff_helper', $file);
}

sub compress_png() {
  my $file=$_[0];
#  $tested_png || test_png();
  testcommand('optipng');
  testcommand('advdef');
  testcommand('advpng');

  my $anim=is_animated_png($file);

  if ($anim == -1){
    # Maybe not a valid PNG file?
    return;
  }

  print "Compressing $file $anim ...\n";

  system('optipng', '-quiet','-o6', '-nc', '-nb', $file);

  if ($anim) {
    system('advdef', '-z4', '-q', $file);
  } else {
    system('advpng', '-z4', '-q', $file);
    `which pngout`;
    $? || system('pngout', $file);
  }
}

sub generic_image_recode($){
  #Uses imagemagick to convert an image file to its own type, while at the highest compression settings.
  #There are better tools for PNG and JPEG. But not for TIFF. Still going to run this on PNGs, but only as a first-effort.
  #It also works on GIF, though again, only as a first-effort before trying some other tools.
  testcommand($im_convert);
  my $file=$_[0];
  my $ext=lc($file);
  $ext=~s/^.*\.//;
  my $quality;
  if($ext eq 'tiff'){
    $quality='90';
  }elsif($ext eq 'png'){
    $quality='95';
    is_animated_png($file) && return(0);#Convert does not support animated PNG.
  }elsif($ext eq 'gif'){
  }else{
    return(0);
  }
  my $tempfile="$tmpfolder/image-$$-$counter.$ext";
  $counter++;
  if($ext eq 'gif'){
    system($im_convert, $file, $tempfile);
  }else{
    system($im_convert, $file, '-quality', $quality, $tempfile);
  }
  if($? || (-s $tempfile == 0)){unlink($tempfile);}
  if(! -f $tempfile){
    return(1);
  }
  if((-s $tempfile) < (-s $file)){
    print("  generic_image_recode succeeded.\n");
    unlink($file);
    move($tempfile, $file);
  }else{
    unlink($tempfile);
  }
  return(0);
}

# Determine if the specified PNG file is animated. Return 1 if yes, 0 if no, or -1 if it appears to not be a valid PNG at all.
sub is_animated_png() {
  my $file=$_[0];
  if (! -f $file) {
    return(-1);
  }
  testcommand('advpng');
  my @chunks=`advpng -l "$file"`;

  if ($?) {
    return(-1);
  }

  for (@chunks) {
    if (substr($_, 0, 4) eq 'acTL') {
      return(1);
    }
  }

  return(0);
}

sub compress_gif(){
  my $file=$_[0];
  testcommand('gifsicle');
  my $tempfile="$tmpfolder/$$-$counter";
  $counter++;
  if (-e $tempfile) {
    print "Gif compressor error 1\n";
    return;
  }
  system('gifsicle', '-O3', $file, '-o', $tempfile);

  if (! -f $tempfile) {
    print "Gif compressor error 2\n";
    return;
  }

  my $befores = -s $file;
  my $afters = -s $tempfile;

  if (! $afters) {
    print "Gif compressor error 3\n";
    return;
  }

  if ($afters < $befores) {
    move($tempfile, $file);
  }

  if (-f $tempfile) {
    unlink($tempfile);
  }

  $befores = -s $file;

  `which flexiGIF`;
  if ($? || $befores>102400) {
    # FlexiGIF is a optional thing, mostly because it's not in the ubuntu
    # apt-get repository.
    return;
  }

  # It's also incredibly slow - so painfully slow that it's best skipped for
  # large files, otherwise it could take all day - and that's not hyperbole.
  system('flexiGIF', '-p', $file, $tempfile);

  $afters = -s $tempfile;

  if (! $afters) {
    print "Gif compressor error 3b\n";
    return;
  }

  if ($afters < $befores) {
    move($tempfile, $file);
  }

  if (-f $tempfile) {
    unlink($tempfile);
  }
}

sub compress_flac(){
  my $file=$_[0];
  testcommand('flac');
  #Reencode a FLAC file. There are two reasons for this:
  # 1. Turning the compression settings up to eleven. Or at least as high possible without the compatibility issues that --lax would allow.
  # 2. Some FLAC files will have been compressed using earlier, less-efficient versions of the encoder. So recompressing with a new version will make them smaller.
  # 3. Occasionally (rarely) a mono file will be incorrectly and wastefully encoded as stereo.
  my $tempfile="$tmpfolder/$$-$counter.flac";
  $counter++;
  my $isnotmono= !isnotmonoable($file);#Yes, double negative.
  if($isnotmono){
    testcommand('ffmpeg');
    my $ret = system('ffmpeg', '-i', $file, '-ac', '1', $tempfile);
    $ret && unlink($tempfile);
    if(-f $tempfile){
      if((-s $tempfile != 0) && (-s $tempfile < -s $file)){
        print(" FLAC file converted to mono.\n");
        move($tempfile, $file);
      }
      unlink($tempfile);
    }
    $tempfile="$tmpfolder/$$-$counter.flac";
    $counter++;
  }
  system('flac', '-8', '-e', '-p', '-r', '0,8', '--totally-silent', $file, '-o', $tempfile); #The flac encoder is very helpful in this: Not only will it encode FLAC to FLAC, it also preserves all metadata while doing so!
  if($? or !(-f $tempfile)){
    unlink($tempfile);
    print(" FLAC re-encode error: Possible corrupted file '$file'\n");
    return;
  }
  if((-s $tempfile) >= (-s $file)){
    unlink($tempfile);
    print(" FLAC re-encode successful, but the file did not get smaller. Keeping original.\n");
    return;
  }
  unlink($file);
  move($tempfile, $file);
  print(" FLAC re-encode successful.\n");
}

sub compress_pdf() {
  my $file=$_[0];
  my $discard_meta=$_[1];
  testcommand('qpdf');
  testcommand('pdftoppm');
  testcommand('jpegoptim');
  my $tempfile="$tmpfolder/$$-$counter.pdf";
  $counter++;
  my $tempfile2="$tmpfolder/$$-$counter.pdf";
  $counter++;
  
  print("  adv_pdf($file) using tempfile $tempfile\n");
  if(! testcommand_nonessential('minuimus_def_helper')){
    print("    The utility minuimus_def_helper was not found.\n    This program is not required to optimise PDF files, but substantially higher compression will be achieved if it is present.\n");
  }
#  my $ret=system('qpdf', $file, '--stream-data=compress', '--object-streams=generate', '--decode-level=specialized', '--compression-level=9', '--linearize',$tempfile);
  my $ret;
  if($discard_meta){
    $ret=system('qpdf', $file, '--stream-data=compress', '--object-streams=disable', '--decode-level=specialized', '--linearize',$tempfile);
  }else{
    $ret=system('qpdf', $file, '--stream-data=compress', '--object-streams=generate', '--decode-level=specialized', '--linearize',$tempfile);
  }
  my $pdfhash;
  if(-f $tempfile && $ret){
    print("    qpdf exited non-zero. Checking output integrity.\n");
    $pdfhash=pdfcompare($file, $tempfile);
    if(!$pdfhash){
      print("    Failed comparison. Input PDF file may be malformed or invalid.\n");
      unlink($tempfile);
    }else{
      print("    Comparison successful. Any errors in the PDF successfully repaired.\n");
    }
  }
  if(! -f $tempfile){
    print("  Failed to pre-process PDF.\n");
    return;
  }
  my @objects2;
  for(`qpdf --show-xref "$tempfile"`){
    if(index($_, 'offset = ')!=-1){
      s/\n//;
      push(@objects2, $_);
    }
  }
  if($?){
    print("    Failure reading xref in compress_pdf\n");
    return;
  }
  my $fh;
  open($fh, '+<:raw', $tempfile);
  binmode($fh);
  my @candidate_streams;
  my $count=0;  
  for my $object (@objects2){
    $count++;
    my $offset=$object;
    $offset=~s/.*offset = //;
    my $dict='';
    sysseek($fh, $offset, SEEK_SET);
    sysread($fh, $dict, 512);
    next if(index($dict, '/Crypt ') != -1); #Not touching this.
    if(index($dict, 'stream')>0){
      $dict=substr($dict, 0, index($dict, 'stream')+6);
    }
    if(($discard_meta ||($count>5)) && index($dict, '/Metadata ')!=-1){ #Due to how qpdf lays out linearised files, the main metadata will always be in the first few objects.
      my $t=$dict;
      if($t =~ m/(\/Metadata \d+ 0 R)/){;
        $dict=substring_replace($dict, $1, ' ');
        sysseek($fh, $offset, SEEK_SET); #Goodbye, metadata
        syswrite($fh, $dict, length($dict));
      }
    }

    if(index($dict, 'endobj')==-1 && index($dict, 'stream')>0){ #Not guaranteed to be a stream, but almost certain.
      if(index($dict, ' /Filter ') != -1 && index($dict, ' /Length ')!=-1){ #We have a candidate!
        #There is still a tiny possibility this isn't really a stream, but just something that happens to have the same field names in it.
        #Not likely, unless this PDF is actually a book about PDF files.
        #But in that unlikely case, the verification step later will catch the error.
        my $origdict=$dict;
        #Going to clean up a few common 'pointless' dict entries first. Null operators, really - they don't do anything.
        #Note the importance of maintaining $dict's length exactly;
        $dict=substring_replace($dict, '/DecodeParms [ null ] ', ' ');
        $dict=substring_replace($dict, '/DecodeParms << [ null ] >> ', ' ');
        $dict=substring_replace($dict, '/DecodeParms << null >> ', ' ');
        $dict=substring_replace($dict, '/DecodeParms [ << >> ] ', ' ');
        $dict=substring_replace($dict, '/Filter [ /DCTDecode ] ', '/Filter /DCTDecode ');
        $dict=substring_replace($dict, '/Filter [ /JPXDecode ] ', '/Filter /JPXDecode ');
        $dict=substring_replace($dict, '/Filter [ /FlateDecode ] ', '/Filter /FlateDecode ');
        $dict=substring_replace($dict, '/Filter [ /ASCIIHexDecode ] ', '/Filter /ASCIIHexDecode ');
        $dict=substring_replace($dict, '/Filter [ /ASCII85Decode ] ', '/Filter /ASCII85Decode ');
        $dict=substring_replace($dict, '/Filter [ /LZWDecode ] ', '/Filter /LZWDecode ');
        $dict=substring_replace($dict, '/Filter [ /JBIG2Decode ] ', '/Filter /JBIG2Decode ');
        if($dict && ($dict ne $origdict)){ 
          sysseek($fh, $offset, SEEK_SET); #And write the patched dictionary in - for the benefit of later processing.
          syswrite($fh, $dict, length($dict));
        }
        advpdf_obj($fh, $object, $offset, $dict);
      }
    }
  }
  close($fh);
  my $object_stream_mode='--object-streams=preserve';
  if($discard_meta){
    $object_stream_mode='--object-streams=generate';
  }
  
  if(!$qpdfvers){
    my $vers=`qpdf --version`;
    $vers=~ m/version (\d+)/i;
    $qpdfvers=$1;
    print("  Detected qpdf version >=$qpdfvers\n");
  }

  if($qpdfvers>=9){ #Automatic version detection pending.
    system('qpdf', $tempfile, '--stream-data=preserve', $object_stream_mode, '--decode-level=none', '--compression-level=9', '--linearize',  $tempfile2);
  }else{
    system('qpdf', $tempfile, '--stream-data=preserve', $object_stream_mode, '--decode-level=none', '--linearize',  $tempfile2);
  }
  unlink($tempfile);
  my $was= -s $file;
  my $done= -s $tempfile2;
  if(! -f $tempfile2){
    print("    Optimisation failed: Unable to re-assemble optimised PDF.\n");
    return;
  }
  if($done>=$was){
    print("    Optimisation failed: No space saving achieved.\n");
    unlink($tempfile2);
    return;
  }
  printq("    Compression done. Checking compressed PDF integrity.\n");
  my $test=pdfcompare($file, $tempfile2, $pdfhash);
  if($test){
    print("  Advanced PDF processing done: Was $was, finished $done.\n");
    move($tempfile2, $file)
  }else{
    unlink($tempfile2);
    print("      Comparison failed after advanced PDF processing! Something went wrong that appears to have corrupted the PDF, so the original has not been overwritten.\n");
  }
}


my %smallobjcache; #PDF object cache - performance improving feature.
sub advpdf_obj(){
  my $fh=$_[0];
  my $object=$_[1];
  my $offset=$_[2];
  my $dict=$_[3];
  my $tempname="$tmpfolder/tempex-$$-$counter";
  $counter++;
  my $filtertype;
  my $isimage=0;
  if(index($dict, '/Filter /FlateDecode ')>0){
    $filtertype=1;
    $tempname=$tempname.'.def';
    if(! -f '/usr/bin/minuimus_def_helper'){return;}
    if((index($dict, '/Subtype /Image ')>0) &&
       (index($dict, '/BitsPerComponent 8 ')>0) &&
       (index($dict, '/DecodeParms') == -1) && #Probably as optimised as it's getting.
       ((index($dict, '/ColorSpace /DeviceGray ')>0) || (index($dict, '/ColorSpace /DeviceRGB ')>0)) &&
       (index($dict, '/Width ')>0)){
      $isimage=1; #There are potential further optimisations to apply later on. But only for 8-bit gray or 24-bit RGB images.
    }
  }elsif(index($dict, '/Filter /DCTDecode ')>0){
    $filtertype=2;
    $tempname=$tempname.'.jpg';
  }elsif((index($dict, '/Filter /JBIG2Decode ')>0) && (index($dict, 'JBIG2Globals') == -1)){
    if(! (testcommand_nonessential('jbig2dec') && testcommand_nonessential('jbig2'))){
      return; #jbig2dec you can get off of the repository, but jbig2 is a complicated compile from source.
                 #And in any case, almost all PDFs with JBIG2 already use the same or better encoder, so it's not likely to improve at all.
                 #Use it if it's around, maybe it'll give another percentage point saving at most. But if not, don't even prompt for it to be installed.
    }
    $filtertype=3;
    $tempname=$tempname.'.jbig2';
  }else{
    return; #Unsupported filter type.
  }
  my $streamlen=substr($dict, index($dict, ' /Length ')+9);
  $streamlen=substr($streamlen, 0, index($streamlen, ' '));
  if($streamlen<=5){return;}
#  print("Processing object:\n$object\n");
  my $contentsoffset=$offset+length($dict)+1;
  my $contents;
  sysseek($fh, $contentsoffset, SEEK_SET);
  sysread($fh, $contents, $streamlen);
  my $hash; #It's common for PDFs to contain small objects repeated many times, for some reason. So let's cache a few things.
  if($streamlen<=10240 && !$isimage){ #But only small things.
    my $sha = Digest::SHA->new('sha1');
    $sha->add($contents);
    $sha->add($filtertype);
    $hash=$sha->hexdigest;
#    print(" Trying cache: $hash\n");
  }
  my $newlen;
  if($smallobjcache{$hash}){
    $contents=$smallobjcache{$hash};
    $newlen=length($contents);
    #print("  Cache succeeded.\n");
  }else{
    my $tempfh;
    open($tempfh, '>:raw', $tempname)||die;
    syswrite($tempfh, $contents, $streamlen);
    close($tempfh);
    if($filtertype==3){
      my $temp1="$tmpfolder/tempex-$$-$counter.pbm";
      $counter++;
      system('jbig2dec', '-e', '-t', 'pbm', '-o', $temp1 ,$tempname);
      `jbig2 -p -v "$temp1" 2>/dev/null > "$tempname"`;
      my $newsize= -s $tempname;
      if(($newsize == 0 ) || ($newsize >= $streamlen)){
        unlink($tempname);unlink($temp1);return;
      }
    }
    if($filtertype==2){
      process_jpeg($tempname, 1, 1);
    }
    if($filtertype==1){ #DEFLATE
      if($isimage && (index($dict, '/ColorSpace /DeviceRGB ')>0) && (index($dict, '/SMask ') == -1) ){ #A DEFLATed image in RGB. Testing if it can be made gray.
        my $defret=system('minuimus_def_helper', $tempname, 1)>>8;
        if($defret == 2){
          $dict=substring_replace($dict, '/ColorSpace /DeviceRGB ', '/ColorSpace /DeviceGray'); #qpdf always allows us a generous extra space we can fill up.
          print("  Converted an RGB24 image to Y8.\n");
        }
      }else{
        system('minuimus_def_helper', $tempname); #Simple DEFLATE, not an image.
      }
    }
    $newlen = -s $tempname;
    if(!$newlen || ($newlen >= $streamlen)){
      unlink($tempname);
      return;
    }
    open($tempfh, '<:raw', $tempname)||die;
    sysread($tempfh, $contents, $newlen);
    close($tempfh);
    unlink($tempname);
    if($hash){
      $smallobjcache{$hash}=$contents;
    }
  }
  
  if($newlen >= $streamlen){
    return;
  }     
  sysseek($fh, $contentsoffset, SEEK_SET);
  syswrite($fh, $contents, $newlen) || die "write failed";
  syswrite($fh, "endstream\nendobj\n", 17);
  
  #Now for the fun part: Updating the length field in the dictionary. If PDF were a simple text based format, this would be trivial.
  #But due to the possibility of encountering PDF's weird character encoding, going to have to do this working on raw bytes.
  #This is going to hurt. Unless you are a C programmer.
  my $startoflength=index($dict, ' /Length ')+9;
  my $pos=$startoflength;
  do{
    vec($dict, $pos++, 8)=ord(' ');
  }while(vec($dict, $pos, 8)!=ord(' '));
  for($pos=0;$pos<length($newlen);$pos++){
    vec($dict, $startoflength+$pos, 8)=ord(substr($newlen, $pos, 1));
  }
  sysseek($fh, $offset, SEEK_SET);
  syswrite($fh, $dict, length($dict));
}

sub substring_replace(){
  #Takes a string, and a substring, and a replacement string. Replaces the substring in string with the replacement string.
  #Pads with spaces in the process! $c must be shorter than or equal to $b in length. Notable this is, unlike regexs, guaranteed binary-safe.
  #It's part of the PDF processing.
  my $a=$_[0];
  my $b=$_[1];
  my $c=$_[2];
  my $offset=index($a, $b);
  if($offset == -1){return($a);}
  my $oldlen=length($b);
  substr($a, $offset, $oldlen)=" " x $oldlen;
  substr($a, $offset, length($c))=$c;
  return($a);
}

sub pdfsizeopt(){
  #Runs pdfsizeopt, if it's available.
  my $in_file=$_[0];
  is_pdfsizeopt_installed() || return;
#  my $initialcwd=getcwd();
  my $tempfile="$tmpfolder/minu-sizeopt-$$-$counter.pdf";
  $counter++;
  my $optimisers='--use-image-optimizer=optipng,advpng';
  `which pngout`;
  if(! $?) {$optimisers = $optimisers.",pngout";}
  `which jbig2`;
  if(! $?) {$optimisers = $optimisers.",jbig2";}
  print("  Invoking pdfsizeopt ($optimisers)\n");
  system($pdfsizeoptpath, '--quiet', $optimisers, $in_file, $tempfile);
  if((-s $tempfile) == 0){
    print("    pdfsizeopt failed.\n");
    unlink($tempfile);
    return;
  }
  if((-s $tempfile) >= (-s $in_file)){
    print("    pdfsizeopt was unable to achieve any space saving.\n");
    unlink($tempfile);
    return;
  }
  if(pdfcompare($in_file, $tempfile)){
    print("    pdfsizeopt successful. Size optimised from ".(-s $in_file)." to ".(-s $tempfile).".\n");
    move($tempfile, $in_file);
  }else{
    print("    pdfsizeopt failed: Optimised PDF validation shows it does not match original.\n");
  }
  unlink($tempfile);
}

sub is_pdfsizeopt_installed(){
  if($pdfsizeopt==1){return(0);}
  if($pdfsizeopt==2){return(1);}
  testcommand('optipng');
  testcommand('advpng');
  if((-e $pdfsizeoptpath) &&
     testcommand_nonessential('png22pnm') &&
     testcommand_nonessential('sam2p')){
    $pdfsizeopt=2;
    return(1);
  }
  $pdfsizeopt=1;
  print("  pdfsizeopt or supporting programs (png22pnm and sam2p) not installed. It's a fiddly program to set up - you will need to install png22pnm as well, and none of this is apt-getable.\n");
  print("  If it were installed, some additional size reduction may be possible.\n");
  return(0);
}

sub extract_archive(){
  #Extracts an archive into CWD.
  #Returns non-zero upon any sort of failure.
  my $input_file=$_[0];
  my $ext=lc($input_file);
  $ext=~s/^.*\.//;
  my $err=1;

  if($ext eq 'rar' ||
     $ext eq 'cbr'){
    testcommand('unrar');
     $err=system('unrar', 'x', '-ai', '-c-', '-p-', $input_file);
  }elsif($ext eq '7z' ||
         $ext eq 'cb7'){
    testcommand('7z');
    $err=system('7z', 'x', $input_file);
  }else{
    testcommand('unzip');
    $err=system('unzip', '-q', $input_file);
  }
  # Because some epubs, for some odd reason, seem to like putting a unix
  # permission extension in that 000's mimetype. Better do this just to be safe.
  if($err || $?){return(1);}
  system('chmod', 'u+rwX', '.', '-R');
  return(0);
}

sub make_zip(){
  #Makes a zip file from the CWD. Returns 1 upon failure.
  my $dest=$_[0];
  if(-e $dest){
    print("File $dest already exists.\n");
    return(1);
  }

 if (-f 'mimetype') {
    # Special treatment for this file: The epub specification requires it be:
    #1. First in the file and 2. Uncompressed.
    if (system('zip', '-X0m', $dest, 'mimetype')) {
      print("  ZIP: Error 2: Reassembly failed (1), aborting.\n");
      return(1);
    }
  }
  my $zipoptions='-Xr9m';

  if(lc(substr($dest, -4)) eq '.cbz'){
    $zipoptions='-Xr9Dm';
  }

  my $failed=system('zip', $zipoptions, $dest, '.');
  if(! -f $dest){
    $failed=1;
  }
  if($failed){return(1);}
  system('advzip', '-z4', '-i 40', '-q', $dest);
  print("Zip created.\n");
  return(0);
}


sub make_7z(){
  #This makes a 7z file. It is responsible for choosing the best compression.
  #Returns 1 if fail.
  my $output_file=$_[0];
  if(-e $output_file){print("Output 7z already exists\n");return(1);}
  testcommand('7z');
  system('7z', 'a', '-t7z', '-m0=lzma', '-mx=9', '-mfb=64', '-md=128m', '-mmt=off', '-bd', '-bb0', "$output_file-A", '.');
  if($?){print "  7z error. Aborting.\n";unlink("$output_file-A");return(1)};
  system('7z', 'a', '-t7z', '-m0=PPMd', '-mmem=128m', '-mmt=off', '-mo=15', '-bd', '-bb0', "$output_file-B", '.');
  if($?){print "  7z error. Aborting.\n";unlink("$output_file-A");unlink("$output_file-B");return(1)};
  print "LZMA size: ".(-s "$output_file-A")."\n";
  print "PPMd size: ".(-s "$output_file-B")."\n";
  if((-s "$output_file-A" ) > (-s "$output_file-B")){
    unlink("$output_file-A");move("$output_file-B", $output_file);
  }else{
    unlink("$output_file-B");move("$output_file-A", $output_file);
  }

  my @filelist=split(
    /\0/,
    `find . -type f -print0`
  );
  my $numfiles=@filelist;
  if($numfiles==1){
    print("Best size: ".(-s $output_file)."\n");
    return(0);
  }

  print("Best size: ".(-s $output_file)."\n");
  return(0);
}

sub make_zpaq(){
  my $output_file=$_[0];
  testcommand('zpaq');
  print("  Creating zpaq archive $output_file.\n");
  if( -e $output_file){
    print("  Error creating zpaq file: File already exists.\n");
    return(1);
  }
  my @filelist=sort split(/\0/,`find . -type f -print0`);
  my $zconf='/usr/share/doc/zpaq/examples/max.cfg';
  -f $zconf || ($zconf='');
  system('zpaq', "pqc$zconf", $output_file, @filelist); #p is required. q for quiet operation.
  my $size = -s $output_file;
  $size || unlink($output_file);
  if($? || (! -f $output_file)){
    print("  zpaq error.\n");
    unlink($output_file);
    return(1);
  }
#  print("  zpaq size $size.");
  return(0);
}

sub pdfcompare(){
  #Returns 0 upon fail (Either a PDF is damaged, or they don't match.)
  #If they do match, returns the hash.
  #Optional third parameter is the known hash of $filea, to save the need to recompute it, as doing so takes a very long time.
  testcommand('pdftoppm');
  my $filea=$_[0];
  my $fileb=$_[1];
  if(!(-f $filea) || !(-f $fileb) || $filea =~ m/[";]/i ||$fileb =~ m/[";]/i ){return(0)}
  my $hasha=$_[2];
  if(!$hasha){
    $hasha=`pdftoppm "$filea" -q | sha256sum`;
  }
  my $hashb=`pdftoppm "$fileb" -q | sha256sum`;
  if($hasha ne $hashb){return(0)}
  return($hasha);
}

sub omnicompress(){
  #Runs the file through a few different compression programs, and applies the smallest.
  #This includes the notoriously slow zpaq. On maximum settings.
  #The sheer slowness of this cannot be overstated.
  #https://www.nongnu.org/lzip/xz_inadequate.html
  my $input_file=File::Spec->rel2abs($_[0]);
  -f $input_file || return($input_file);
  my $input_filename=$input_file;
  my $tempfolder="$tmpfolder/omni-$$-$counter";$counter++;
  -e $tempfolder && return($input_file);
  mkdir($tempfolder);
  $input_filename =~ s/.*\///;
  my $tempfile="$tempfolder/$input_filename";
  -e $tempfile && return($input_file);
  testcommand('gzip');
  testcommand('bzip2');
  testcommand('lzip');
  testcommand('rzip');
  testcommand('brotli');
  testcommand('7z');
  testcommand('zpaq');
  my $zconf='/usr/share/doc/zpaq/examples/max.cfg';
  -f $zconf || ($zconf='');
  copy($input_file, $tempfile);
  if(-s $input_file != -s $tempfile){
    unlink($tempfile);
    return($input_file);
  }
  print("  OmniCom: $input_file (via $tempfile).\n");
  system('gzip', $tempfile, '-k9');
  if(!$? && (-s $tempfile.'.gz' < 4294967296)){
    system('advdef', '-z4', '-q', $tempfile.'.gz');
    $?=0;
  }
  my $best=$tempfile.'.gz';
  system('bzip2', $tempfile, '-k9');
  $best=omni_whichisbigger($tempfile.'.bz2', $best);
  system('lzip', $tempfile, '-k9', '-s', '27');
  $best=omni_whichisbigger($tempfile.'.lz', $best);
  system('rzip', $tempfile, '-k9');
  $best=omni_whichisbigger($tempfile.'.rz', $best);
  system('brotli', '-knZ', $tempfile);
  $best=omni_whichisbigger($tempfile.'.br', $best);
  system('7z', 'a', '-t7z', '-m0=PPMd', '-mmem=128m', '-mmt=off', '-mo=15', '-bd', '-bb0', $tempfile.'.7z', $tempfile);
  $best=omni_whichisbigger($tempfile.'.7z', $best);
  system('zpaq', "pqc$zconf", $tempfile.'.zpaq', $tempfile);
  $best=omni_whichisbigger($tempfile.'.zpaq', $best);
  unlink($tempfile);
  if(-s $best >= -s $input_file){
    print("  OmniCom: Unsuccessful. None of the attempted compression utilities achieved any saving.");
    unlink($best);
    rmdir($tempfolder);
    return($input_file);
  }
  my $bestex=$best;
  $bestex =~ s/.*\.//;
  my $output_file=$input_file.'.'.$bestex;
  print("  OmniCom: Best file is $best/$bestex.\n");
  if(-e $output_file){
    print("  OmniCom: Output file $output_file exists.\n");
    unlink($best);
    rmdir($tempfolder);
    return($input_file);
  }
  print("  OmniCom: Saving to $output_file.\n");
  my $check = -s $best;
  move($best, $output_file);
  if($check != -s $output_file){
    unlink($output_file);
  }
  if(! -f $output_file){
    print("  OmniCom: Move failed.\n");
    unlink($best);
    rmdir($tempfolder);
    return($input_file);
  }
  rmdir($tempfolder);
  unlink($input_file);
  return($output_file);
}

sub testcommand($){
  my $totest=$_[0];
  if($testedcommands{$totest}){return;}
  `which $totest`;
   if(! $?){
    $testedcommands{$totest}=1;
    return;
  }
  print("Minuimus requires $totest. Install dependency or 'make deps' and retry.\n");
  exit(1);
}

sub testcommand_nonessential($){
  my $totest=$_[0];
  `which $totest`;
  return(! $?);
}


sub omni_whichisbigger(){
  my $alpha=$_[0];
  my $beta=$_[1];
  my $alphasize = -s $alpha;
  $alphasize || unlink($alpha);
  $? && unlink($alpha); #This function is called right after running a compression program - a non-zero return thus indicates Something Went Wrong. Discard alpha, as it may be damaged.
  my $betasize = -s $beta;
  if(! -f $alpha){
    return($beta);
  }
  if($betasize == 0){ #The *only* time this is possible is if the very first program tried, gzip, fails. But this is a possibility.
    return($alpha);
  }
  #print("$alpha/$alphasize : $beta/$betasize\n");
  if($alphasize < $betasize){
    print("  New best: $alpha:$alphasize\n");
    unlink($beta);
    return($alpha);
  }
    unlink($alpha);
    return($beta);
}

sub getfreespace(){
  my @ret=`df -Pk "$tmpfolder/"`;

  my @columns=split(' ', $ret[1]);
  return($columns[3]);
}

sub process_html(){
  #Convert upper-case characters in HTML tags to lower-case. This saves us zero bytes. But it does render the HTML slightly more compressible.
  #So it's an indirect space saving. And if it can knock another hundred-odd bytes off an epub, I'm doing it.
  #This is not a full HTML parser(See html_line_lc for reasons) so it'll just abort if it sees a script.
  my $input_filename=$_[0];
  my $tempfilename="$tmpfolder/$$-$counter.html";
  $counter++;
  if(-f $tempfilename){print("  Temp file already exists. This should never happen.\n");return(0);}

  open(input_file, "<:encoding(UTF-8)", $input_filename);
  open(output_file, ">:encoding(UTF-8)", $tempfilename);
  my $changed=0;
  while (<input_file>){
    my $rest=$_;
    my $initial=$rest;
    my $out='';
    while($rest){
      (my $fixed, $rest, my $abort)=html_line_lc($rest);
      if($abort){
        print("  HTML file processing skipped as a precaution\n  ($fixed).\n");
        close(input_file);
        close(output_file);
        unlink($tempfilename);
        return(0);
      }
      $out=$out.$fixed;
    }
    print output_file $out;
    if($out ne $initial){
      $changed++;
    }
    if(lc($out) ne lc($initial)){
      print("  Something went horribly wrong. Aborting HTML processing. Possibly invalid character encoding encountered?\n");
      close(input_file);
      close(output_file);
      unlink($tempfilename);
      return(0);
    }
  }
  close(input_file);
  close(output_file);
  if(!($changed)){
    print("  HTML is already correctly lower-case. Nothing changed.\n");
    unlink($tempfilename);
    return(0);
  }
  print("  Modified $changed line(s).\n");
  move($tempfilename, $input_filename);
  return($changed);
}

sub html_line_lc(){
  #Why am I using this heap of string manipulation rather than an HTML parser?
  #Because people write awful HTML, and I don't trust any parsing library not to go horribly wrong when it encounters malformed tags.
  #What if someone forgets to close a tag, or a quote?
  #This is safer, because it can just do in-place replacement of the 'easy bits' and avoid venturing into dangerous territory.
  my $in=$_[0];
  my $ind=index($in, '<');
  if($ind == -1){return($in)}
  my $head=substr($in, 0, $ind);
  my $tail=substr($in, $ind);
  my $ind2=index($tail, '>');
  if($ind2 == -1){return($in)}
  my $mid=substr($tail,0, $ind2);
  $tail=substr($tail, $ind2);
  #$mid now contains an HTML tag. From < to just before the >.
  if(substr($mid, 0, 2) eq '<!'){return($head.$mid,$tail)} #Don't decapital comments. Or DOCTYPE.
  if($mid =~ m/< *script.*/i){ #Scripts may contain characters that look like HTML. Best not touch pages with scripts in.
    if(!($mid =~ m/< *script.*src=".*/i)){ #External scripts are OK though.
      return($mid,0,1);
    }
  }
  my $ind3=index($mid, '=');
  #Not venturing past the first =. Who knows what horrors lurk? Someone, somewhere, has proably used curly-quotes in HTML.
  #And when <tag attrib="contents:'parameter<string fakeattrib=hello'"> is technically valid syntax... no, better to just give up.
  if($ind3==-1){$mid=lc($mid)}else
  {
    my $a=substr($mid, 0, $ind3);
    my $b=substr($mid, $ind3);
    $mid=lc($a).$b;
  }
  return($head.$mid,$tail);
}

sub optimise_base64_file(){
  #Optimises a file with embedded base64-encoded objects. These objects may be found within HTML, CSS and SVG.
  my $file=$_[0];
  my $ext=lc($file);
  $ext=~s/^.*\.//;
  my $tempfile="$tmpfolder/minu-base64file-$$-$counter.".$ext;
  $counter++;
  my $input = readwholefile($file);
  my $len=length($input);
  my $output='';
  for (split(/(")/, $input)){
    if( m/^data:.+\/.+;.*base64,[a-zA-Z0-9+\/\r\n]*=*$/s){
      $_=optimise_base64_object($_);
    }
    $output.=$_;
  }
  if(length($output) == $len){
    print("  No space savings achieved processing base64 in $file.\n");
    return;
  }
  writewholefile($tempfile, $output); 
  if(do_comparison_hash($file, $tempfile)){
    print("  COMPARISON FAIL AFTER BASE64 OPTIMISATION. SKIPPING FILE.\n");
    unlink($tempfile);
    return;
  }
  move($tempfile, $file);

}

sub optimise_base64_object(){
  my $index=index($_, ';base64,')+8;
  my $description=substr($_, 0, $index);
  my $data=substr($_, $index);
  my $tempfile='';
  if(substr($description, 0, 26) eq 'data:application/font-woff'){
    $tempfile="$tmpfolder/base64opt-$$-$counter.woff";
  }
  if(substr($description, 0, 15) eq 'data:image/jpeg'){
    $tempfile="$tmpfolder/base64opt-$$-$counter.jpg";
  }
  if(substr($description, 0, 14) eq 'data:image/png'){
    $tempfile="$tmpfolder/base64opt-$$-$counter.png";
  }

  if($tempfile){
    $counter++;
    #print("  Processing base64 data ($description).\n");
    my $rawdata=decode_base64($data);
    $rawdata || return($_);
    writewholefile($tempfile, $rawdata);
    my %empty;
    compressfile($tempfile, \%empty);
    $data=encode_base64(readwholefile($tempfile));
    unlink($tempfile);
    $data =~ s/[\r\n]//g;
    $_=$description.$data;
  }
  return($_);  
}

sub readwholefile(){
  open my $fh, '<:raw', $_[0] or return;
  my $input = do { local $/; <$fh> };
  close($fh);
  return($input);
}
sub writewholefile(){
  open(my $fh, '>:raw', $_[0]);
  binmode($fh);
  print $fh $_[1];
  close($fh);
}

sub do_comparison_hash(){
  #Used for before-after tests on image files.
  my $ext=lc($_[0]);
  $ext=~s/^.*\.//;
  if($ext eq 'svg'){
    my $tempfile="$tmpfolder/minuimus-comptemp-$$-$counter.bmp";
    $counter++;
    system($im_convert, $_[0], $tempfile);
    my $hasha=`sha256sum $tempfile`;
    unlink($tempfile);
    system($im_convert, $_[1], $tempfile);
    my $hashb=`sha256sum $tempfile`;
    unlink($tempfile);
    return($hasha ne $hashb);
  }else{return(0);}
}

sub repack_webm(){ #Certain particually poor video encoding programs produce bad WebM files - corrupt timecodes, so seeking is impossible. This fixes them.
  my $file=$_[0];
  testcommand('ffmpeg');
  my $tempfile="$tmpfolder/minu-repackwebm-$$-$counter.webm";
  $counter++;
  my $ret=system('ffmpeg', '-i', $file, '-map', '0', '-c', 'copy', $tempfile);
  if($ret || (! -s $tempfile)){unlink($tempfile);}
  if(-s $tempfile >= -s $file){unlink($tempfile);}
  if(! -f $tempfile) {return;}
  move($tempfile, $file);  
}


sub processvideo(){
  print "Processing video: $_\n";
  m/\"/ && return($_);
  my $oldname=$_;
  if(($oldname =~ m/\.CD\d\./i)||
     ($oldname =~ m/\.PART\d\./i)){
    print("  Name suggests this is a multi-part file - ignoring. You may want to join these together.\n");
    return($oldname);
  };
 testcommand('ffprobe');
 testcommand('ffmpeg');
  my $ret=`ffprobe "$oldname" 2>&1`;
  if(!$ret || $?){
    print("  Unable to get streams - not a supported file?\n");
    return($oldname);
  }
  my @streams;
  for (split(/\n/, $ret)){
    if(substr($_, 0, 14) eq "    Stream #0:"){
      push(@streams, substr($_, 14));
    }
  }
  my $keepaudio=0;
  for (@streams){
    my $streamret=isstreamok($_);
    if($streamret==0){
      print "  Bad stream: $_\n";
      return($oldname);
    }
    if($streamret==2){
      $keepaudio=1;
    }
  }
  print "  No troublesome streams found: Should be convertable.\n";
  my $newname=substr($oldname, 0, rindex($oldname, '.')).'.webm';
  $newname =~ s/[.-]divx[.-]/\./i; #Going to remove a load of tags marking codec in the filename, as they are wrong now.
  $newname =~ s/\(divx\)/\./i;
  $newname =~ s/[.-]divx5[.-]/\./i;
  $newname =~ s/\(divx5\)/\./i;
  $newname =~ s/[.-]AC3[.-]/\./;
  $newname =~ s/\(AC3\)/\./;
  $newname =~ s/[.-]AAC[.-]/\./;
  $newname =~ s/\(AAC\)/\./;
  $newname =~ s/[.-]MP3[.-]/\./;
  $newname =~ s/\(MP3\)/\./;
  $newname =~ s/[.-]xvid[.-]/\./i;
  $newname =~ s/\(xvid\)/\./i;
  $newname =~ s/-+/-/g; #And that lot probably left an ugly filename, so let's tidy it up a little.
  $newname =~ s/ +/ /g;
  $newname =~ s/\.+/\./g;
  $newname =~ s/\(\)//g;
  $newname =~ s/\[\]//g;
  $newname =~ s/- \./-\./g;
  $newname =~ s/\. -/\.-/g;
  $newname =~ s/ *\.- */\.-/g;
  $newname =~ s/ *-\. */-\./g;
  print "  New name: $newname\n";

  if(-f $newname){
    print "  File exists. Aborting.\n";return($oldname);
  }
  my $tempfile="$tmpfolder/video$$-$counter.webm";
  $counter++;
  my @args=('ffmpeg', '-i', $oldname, '-map', '0');  
  my $subname=substr($oldname, 0, rindex($oldname, '.')).'.srt';
  #  push(@args, '-strict', '-2');

  if(-f $subname){
    print "  SRT subtitles found.\n";
    push(@args, '-i', $subname);
  }
  if($keepaudio){
    print("  Keeping existing audio without reencode.\n");
    push(@args, '-c:a', 'copy');
  }else{
    my $isnotmono=isnotmonoable($oldname); #See function for return values, as there are a lot of them.
    if($isnotmono){
      push(@args, '-codec:a', 'libopus', '-frame_duration', '60');
    }else{
      push(@args, '-ac', '1','-codec:a', 'libopus', '-frame_duration', '60');
    }
  }
  push(@args, '-c:v', 'av1', '-lag-in-frames', '19', '-b:v', '0', '-tiles', '2x2');
  my $crf=28;
  if($options{'video-agg'}){$crf=34;}

  push(@args,  '-crf', $crf); #Default is 32, but going for a bit higher quality here.
                              #Remember the aim is to recompress ancient DivX/XVID/MPEG1/MPEG2.
                              #Even on a high quality setting, AV1 will hit a lower bitrate than those.
  push(@args, '-vf', 'hqdn3d=0:0:2:2,nlmeans=s=1,mpdecimate=max=6'); #A mild denoiser, followed by duplicate frame removal (Saves space and encoding time, mostly good on animation)
                              #Denoising used very sparingly to take out some of the artifacts.
                              #Otherwise the old compression artifacts would interfere with AV1.
                              #Leading to reduced compression efficiency.
                              #These settings are very low though, anything more would be risky.
                              #Proper manual adjustment would do much better than this script.
                              #But this is automatic, so err on the side of too-weak.
#  push(@args, '-cpu-used', '0'); #Nothing less than perfection!
#  push(@args, '-cpu-used', '8'); #For testing purposes only.
  my $oldname_shortened=$oldname;
  $oldname_shortened=~s/.*\///;
  push(@args, '-metadata', 'encoded_from_name='.$oldname_shortened);
  push(@args, '-metadata', 'encoded_from_sha256='.getsha256($oldname));

  my $in_len=get_media_len($oldname);
  if(!$in_len){
    print("  Could not get media length. Skipping.\n");
    return($oldname);
  }
  push(@args, $tempfile);
  $ret=system(@args);
  if($ret){
    print("  Encode failed (Returned $ret).\n");
    unlink($tempfile);
  }
  if(! -f $tempfile){
    print("  Encode failed.\n");
    return($oldname);
  }
  if(-s $tempfile >= -s $oldname){
    print "  File got bigger. That was a waste of time. Deleting re-encoded video.\n";
    unlink($tempfile);
    return($oldname);
  }
  my $out_len=get_media_len($tempfile);
  if(abs($in_len - $out_len) > 5){ #Allow five second difference. Because different containers.
    print "  File re-encoded, but output length different from input. Corruption likely. Aborting.\n";
    print "  ($out_len vs $in_len)\n";
    unlink($tempfile);
    return($oldname);
  }
  move($tempfile, $newname);
  if(! -f $tempfile){
    unlink($oldname);
  }
  return($newname);
}

sub recode_audio($){
  my $file=$_;
  my $ext=lc($file);
  $ext=~s/^.*\.//;


  my $timelen=get_media_len($file);
  $timelen || return($file);
  my $sizelen= -s $file;
  my $rate= int(($sizelen) / ($timelen*128)); #Rate in kbps. Why this roundabout way of calculating? Because VBR, and because I don't trust the metadata.
  if($rate<4) {$rate=64}; #Bitrate detection seems to fail in a few low-bitrate files.
  print("  Approx bitrate: $rate\n");
  if(!$options{'audio-agg'} && $rate < 255){
    print("  File bitrate is too low to justify a re-encode: Go find a clean source.\n");
    return($file);
  }
  if($rate < 34){
    print("  File bitrate is too low to justify a re-encode even with audio-agg: Go find a clean source.\n");
    return($file);
  }
  my $output_file=substr($file, 0, rindex($file, '.')).'.opus';
  if(-e $output_file){
    print("  Output file exists. Skipping reencode.\n");
    return($file);
  }
  my $oldname_shortened=$file;
  $oldname_shortened=~s/.*\///;

  #Informal consensus is that anything over 256kbps in MP3 can be considered transparent - it used to be 320, but that was with very old encoders.
  #Which means any MP3 over 256kbps is just wasteful... and also absolutely free of perceptible audible artifacts. Ripe for recompression!
  #And Opus is good. Really good. Arguably the best audio compression codec yet developed, at any bitrate.
  #A discussion on HydrogenAudio reaches a rough consensus: Most users find Opus transparent at a mere 96kbps.
  #Even the most demanding of ears claims he couldn't hear any degredation until 128bps... except on one exceptionally demanding sample.
  #A harpsichord. Harpsichords have a bit of a reputation as being hard to compress. Weird. That sample needed 140kbps.
  #My conclusion: Opus should be transparent to even the most discerning, sensitive listener at 128kbps.
  #Note that opus's default setting is VBR though, so specifying 128kbps is more of a guideline.
  my $isnotmono=isnotmonoable($file); #See function for return values, as there are a lot of them. 7 means already mono. 0 means turn mono.
  my @args=('ffmpeg', '-i', $file);
  $rate=128; #For stereo
  if($isnotmono == 7 || $isnotmono==0) {$rate = 64} #For mono
  if($options{'audio-agg'}){$rate = 24} #Aggressive mode: Intended for voice, where a little artifacting is forgivable. Anything under 24 means sacrificing bandwidth though.
  if($isnotmono == 0){
    push(@args, '-ac', '1');
  }
  print("Target bitrate $rate kbps\n");
  push(@args, '-codec:a', 'libopus', '-b:a', $rate.'k', '-frame_duration', '60');
  push(@args, '-metadata', 'encoded_from_name='.$oldname_shortened);
  push(@args, '-metadata', 'encoded_from_sha256='.getsha256($file));
  push(@args, $output_file);
  my $ret=system(@args);
  if(! -f $output_file){
    $ret=1;
  }
  if(-s $output_file > -s $file){
    print("  File somehow got larger?\n");
    $ret=1;
  }
  if($ret){
    unlink($output_file);
    print("  OPUS encode failed.\n");
    return($file);
  }
  #Why ffmpeg, rather than opusenc?
  # 1: ffmpeg reads MP3 directly, opusenc doesn't.
  # 2: ffmpeg automatically reads the ID3 info (Of all ID3 versions) and turns it into tag pairs for Opus.
  # 3: Because ffmpeg is already a dependency for FLAC and video, so I can avoid creating yet another.
  unlink($file);
  return($output_file);
}

sub process_mp3($){
  my $file=$_[0];
  my $tempfile="$tmpfolder/$$-$counter.mp3";
  $counter++;
  testcommand('ffmpeg');
  my $ret=system('ffmpeg', '-loglevel', 'quiet', '-i', $file, '-c', 'copy', $tempfile);
  if($ret){
    print("  Possible error in MP3, will attempt to process anyway: $file\n");
  }
  if(! -f $tempfile || (-s $tempfile < 1000)){
    print("  Decode failed. File is likely to be corrupt: $file\n");
    unlink($tempfile);
    return;
  }
  my $oldsize = -s $file;
  my $newsize = -s $tempfile;
  if(($newsize / $oldsize) >0.99){ #Not worth it.
    unlink($tempfile);
    return;
  }
  my $in_len=get_media_len($file);
  my $out_len=get_media_len($tempfile);
  if(abs($in_len - $out_len) > 1){
  print("  Length differs after transcode, possible damaged or malformed file: $file\n");
    unlink($tempfile);
    return;
  }
  move($tempfile, $file);
  unlink($tempfile);
}

sub get_media_len(){
  my $fn=$_[0];
  testcommand('ffmpeg');
  my $len=`ffmpeg -i "$fn" 2>&1 | grep "  Duration: "`;
  $len =~ /(\d\d):(\d\d):(\d\d)\.(\d\d)/;
#  $len =~ s/,.*//;
#  $len =~ s/.* //;
#  $len =~ m/()@/; 
  return($3+(60*$2)+(60*60*$1));
}

sub isnotmonoable($){
  #Returns 0 if the file is a stereo file which contains mono audio.
  #Returns a non-zero value otherwise which indicates why the file is not a stereo file containing mono audio.
  my $file=$_[0];
  testcommand('ffprobe');
  testcommand('ffmpeg');
  my @ret=`ffprobe "$file"  2>&1`;
  if($?){
    print("  Unable to ffprobe file.\n");
    return(4); #Error in file decoding.
  }
  my $audioline;
  for (@ret){
    if($_ =~ m/    Stream #[0123456789]+.*: Audio: (.*)/){
      $audioline && return(1); #File contains multiple audio streams.
      $audioline=$1;
    }
  }
  $audioline || return(2); #File contains no audio streams.
  if(index($audioline,', mono,') != -1){;
    return(7); #This is already mono. The calling routine will interpret a return of 7 as an indicator to lower the bitrate a bit.
  }
  if(index($audioline,'stereo,') == -1){;
    return(3); #The audio is not stereo (ie, multichannel)
  }

  my $pipe;
  my $pid=open($pipe, '-|','ffmpeg -v warning -nostats -hide_banner -i "'.$file.'" -f u8 -ac 2  - 2>/dev/null');
  if(!$pid){
    return(4); #Error in file decoding.
  }
  binmode($pipe);
  my $differences=0; #Tolerate a small number of differences.
  while(!eof($pipe)){
    my $a;my $b;
    my $check=read($pipe, $a, 1);
    $check+=read($pipe, $b, 1);
    if($check!=2){
      close($pipe);
      return(5); #Bad file?
    }
    if(abs(ord($a)-ord($b)) > 5){$differences++} #You have to allow a little for rounding errors in earlier processing.
    if($differences>100){
      close($pipe);
      kill(9, $pid);
      return(6); #This is actually the most common: It's just a stereo file.
    }
  }
  close($pipe);
  print("  File contains a stereo track, but with mono audio. Downmixing to a single channel.\n");
  return(0); #Mono audio in a stereo file. Inefficiency identified! This can be optimised.
}


sub isstreamok(){ #These are the streams we are OK to mess with.
#This is a list of old, obsolete video codecs, those which I consider worthy of retirement.
#Some were historic in their day. I have fond memories of downloading movies in DivX when I was in school.
#But now they are old, and modern software often does not support them. Their day is past.
#Additionally, due to the intentionally limited codec support of WebM (For good reason that I shall not go into here),
#most audio tracks will need re-encoding to Opus and substitles to webvtt.
#If any codec is detected that is not on this list, re-encode will not be attempted.
#So it won't try to reencode a modern codec such as h264, and will not try to convert subtitles that cannot be converted to webvtt by ffmpeg.
  m/: Audio: aac / && return(1);
  m/: Audio: sipr / && return(1); #Ancient RealVideo format.
  m/: Video: rv20 / && return(1); #Ancient RealVideo format.
  m/: Video: mpeg4 / && return(1); #MPEG4 is a pretty broad family. Includes DivX and XviD.
  m/: Audio: mp3[ ,][ (]/ && return(1); #Die you obsolete piece of junk!
  m/: Audio: mp2[ ,]/ && return(1); #Unintuitively, not actually a predecessor to MP3: They were developed simutainously. Internal MPEG politics were involved.
  m/: Video: mpeg1video[ ,]/ && return(1);
  m/: Video: mpeg2video / && return(1);
  m/: Video: indeo5 / && return(1);
  m/: Video: mjpeg / && return(1);
  m/: Audio: ac3 / && return(1);
  m/: Video: msmpeg4v3 / && return(1); #Is this the old WMV?
  m/: Audio: qdm2 / && return(1); #An audio codec used in old quicktime files.
  m/: Video: svq3 / && return(1); #A video codec used in old quicktime files. Tends to be found alongside the above.
  m/: Audio: vorbis,/ && return(2); #The 2 says to set audio to copy, not re-encode.
  m/: Video: vp6f[ ,]/ && return(1); #Old codec from 2003, sometimes found in old FLV files.
  m/: Video: flv1[ ,]/ && return(1); #Another codec from old FLV files.
  m/: Subtitle: text/ && return(1); #ffmpeg can convert this into webvtt, the one format WebM allows.
  return(0);
}

sub fix_proper_ext($){
  my $oldname=$_[0];
  testcommand('file');
  my $oldext=lc($oldname);
  $oldext=~s/^.*\.//;
  my $fileret=`file -b "$oldname"`;
  my $newext;
  # All these data times have something important in common: They are things that file never gets wrong.
  # I have yet to encounter a false positive for any of them.
  if(index($fileret, 'JPEG image data') == 0){
    $newext='jpg';
  } elsif(index($fileret, 'PNG image data,') == 0){
    $newext='png';
  } elsif(index($fileret, 'GIF image data,') == 0){
    $newext='gif';
  } elsif(index($fileret, 'PDF document, ') == 0){
    $newext='pdf';
  } elsif(index($fileret, 'TIFF image data') == 0){
    $newext='tiff';
  } elsif(index($fileret, 'WebM') != -1){
    $newext='webm';
  } elsif(index($fileret, 'RIFF (little-endian) data, Web/P image') == 0){
    $newext='webp';
  } elsif(index($fileret, 'Zip archive data') == 0){
    if(lc($oldext) eq 'rar'){$newext = 'zip'}
    if(lc($oldext) eq 'cbr'){$newext = 'cbz'}
  } elsif((index($fileret, 'Composite Document File V2 Document,') == 0) &&
          (index($fileret, ' Name of Creating Application: Microsoft Office Word,') != -1)){
    $newext='doc';
  }else{return($oldname)}
  if(!$newext || (lc($oldext) eq $newext)){
    return($oldname);
  }
  my $newname=substr($oldname, 0, length($oldname)-length($oldext)).$newext;
  if(-e $newname){
    print("  File has incorrect extension, but cannot be renamed as another file with the target name already exists.\n ($oldname, $newext)\n");
    return($oldname);
  }
  move($oldname, $newname);
  if(-f $newname){
    print("  Ext-fix: $oldname, $newext\n");
    return($newname);
  }
  print("  File has incorrect extension, but rename attempt failed for unclear reason.\n");
  return($oldname);
}

sub leanify($){
  my $file=$_[0];
  my $discard_meta=$_[1];
  `which leanify`;
  $? && return; #Leanify is not installed.
  #Leanify is powerful, but a bit more intrusive than minuimus's defaults.
  #There's a reason minuimus's more aggressive features all need to be enabled by command line option.
  #So leanify is to be invoked upon certain formats only.
  #Specifically, not upon APK or JAR (for it screws with signing), upon HTML (Because what it does, minuimus does already),
  #Upon SVG (it removes metadata), upon archive files (Duplicates minuimus's own functions) or upon XML (deletes comments).
  #Or PNG (Deletes metadata. Plus the things it does, optipng and advpng already did.)
  #But it does work well at optimising JPEGs - and I really can't figure out what magic it's using, other than that it outdoes minuimus alone.
  #(But doesn't do the grey conversion: That's a minuimus-specific trick, no-one else thought of that!)
  #So basically: JPEG, SWF, ICO, FB2.
  my $tempfile="$tmpfolder/$$-$counter.tmp";
  $counter++;
  copy($file, $tempfile);
  if(! -f $tempfile){
    die("  Failed when copying to $tmpfolder - possible permissions or free space issue. Terminating.");
  }
  my @leanify_parms = ('leanify', '-q', '--keep-icc');
  $discard_meta && push(@leanify_parms, '--keep-exif');
  push(@leanify_parms, $file);
  my $ret=system(@leanify_parms);
  my $presize = -s $tempfile;
  my $postsize = -s $file;
  if($ret || ($postsize > $presize) || (-s $file == 0)){
    print("  Leanify appears to have gone wrong, restoring original file.\n  Return was $ret.");
    unlink($file);
    copy($tempfile, $file);
  }
  unlink($tempfile);
  if($presize>$postsize){
    printq("  Leanify achieved an additional saving ($presize->$postsize)\n");
  }
}

sub process_stl($){
  my $file=$_[0];
  my $fh;
  open($fh, "<", "$file") || return;
  local $_ = <$fh>;
  s/[\r\n]//;

  if(! m/^solid .*\n/){
    close($fh);
    return;
  }
  my ($name) = /^solid (.*?)$/msg;
  print "Converting STL. Name: $name\n";
  my $numtris=0;
  my @triangle;
  my @output_file;
  #push(@output_file, "                                                                                ");
  while(<$fh>){
    s/ +/ /g;
    s/^ *//g;
    s/ *$//g;
    s/\r//;
    s/\n//;
    push(@triangle, $_);
    if( $_ eq 'endfacet' ){
      if(@triangle != 7 ||
         $triangle[1] ne 'outer loop' ||
         $triangle[5] ne 'endloop' ||
         $triangle[6] ne 'endfacet') {close($fh);return(0);}
      $triangle[0] =~ s/[^0-9e -.]//g;
      $triangle[0] =~ s/^[ e]*//g;
      $triangle[2] =~ s/[^0-9e -.]//g;
      $triangle[2] =~ s/^[ e]*//g;
      $triangle[3] =~ s/[^0-9e -.]//g;
      $triangle[3] =~ s/^[ e]*//g;
      $triangle[4] =~ s/[^0-9e -.]//g;
      $triangle[4] =~ s/^[ e]*//g;
      push(@output_file, pack("f<f<f<", split(/ /,$triangle[0])));
      push(@output_file, pack("f<f<f<", split(/ /,$triangle[2])));
      push(@output_file, pack("f<f<f<", split(/ /,$triangle[3])));
      push(@output_file, pack("f<f<f<", split(/ /,$triangle[4])));
      push(@output_file, chr(0).chr(0));
      @triangle=();
      $numtris++;
    }
  }
  close($fh);
  if( substr($triangle[0], 0, 8) ne 'endsolid'){
    print("  Expected STL termination not found. Corrupted input or not STL file?\n");
    return;
  }
  print("  File read. Triangles: $numtris\n");
  my $tempfile="$tmpfolder/$$-$counter.stl";
  $counter++;
  print("  Writing output via $tempfile\n");
  my $header=substr('STL:'.$name.'                                                                                ', 0, 80);
  unshift(@output_file, $header, pack("L<", $numtris));
  open(FH, ">", "$tempfile") || return;
  print FH @output_file;
  close(FH);
  if(-s $tempfile ne (($numtris * 50) + 84)){
    unlink($tempfile);
    print("  Error writing output. Permissions issue or out of space?");
    return;
  }
  print("  STL file written.\n");
  move($tempfile, $file);
  unlink($tempfile);
}

sub printq(){
  if($options{'verbose'}){
    print($_);
  }
}

# Abandoned ideas:
# - Arithmetic coded JPEG. Great idea in principle, but hardly anything reads them! This is a great shame, and a prime example of how software patents can harm everyone.
# - Use of LZW or bzip2 in ZIP files. Same problem again: The ZIP standard supports them, but in practice almost every ZIP-reading program and library doesn't.
# - defluff. Optimises deflate even better than Zopfli, though it's very close. But it appears to be abandoned by the developer. No source code. Same for DeflOpt, kzip.
