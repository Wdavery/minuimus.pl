all: minuimus_def_helper minuimus_woff_helper cab_analyze minuimus_swf_helper

minuimus_def_helper: minuimus_def_helper.c
	gcc minuimus_def_helper.c -o minuimus_def_helper -O3 -lz zopfli/deflate.c zopfli/lz77.c zopfli/hash.c zopfli/tree.c zopfli/squeeze.c zopfli/blocksplitter.c  zopfli/cache.c zopfli/katajainen.c zopfli/util.c zopfli/zlib_container.c -lm

minuimus_woff_helper: minuimus_woff_helper.c
	gcc minuimus_woff_helper.c -o minuimus_woff_helper  -lz zopfli/deflate.c zopfli/lz77.c zopfli/hash.c zopfli/tree.c zopfli/squeeze.c zopfli/blocksplitter.c  zopfli/cache.c zopfli/katajainen.c zopfli/util.c zopfli/zlib_container.c -lm

minuimus_swf_helper: minuimus_swf_helper.c
	gcc minuimus_swf_helper.c -o minuimus_swf_helper -O3 -lz zopfli/deflate.c zopfli/lz77.c zopfli/hash.c zopfli/tree.c zopfli/squeeze.c zopfli/blocksplitter.c  zopfli/cache.c zopfli/katajainen.c zopfli/util.c zopfli/zlib_container.c -lm

cab_analyze: cab_analyze.c
	gcc cab_analyze.c -o cab_analyze -O3

windows: cab_analyze.c minuimus_swf_helper.c minuimus_woff_helper.c minuimus_def_helper.c
	i686-w64-mingw32-gcc minuimus_def_helper.c -o minuimus_def_helper.exe -O3 -lz zopfli/deflate.c zopfli/lz77.c zopfli/hash.c zopfli/tree.c zopfli/squeeze.c zopfli/blocksplitter.c zopfli/cache.c zopfli/katajainen.c zopfli/util.c zopfli/zlib_container.c -lm
	i686-w64-mingw32-gcc minuimus_woff_helper.c -o minuimus_woff_helper.exe  -O3 -lz zopfli/deflate.c zopfli/lz77.c zopfli/hash.c zopfli/tree.c zopfli/squeeze.c zopfli/blocksplitter.c zopfli/cache.c zopfli/katajainen.c zopfli/util.c zopfli/zlib_container.c -lm
	i686-w64-mingw32-gcc cab_analyze.c -o cab_analyze.exe -O3

install: all
	cp minuimus_def_helper /usr/bin/minuimus_def_helper
	cp minuimus_woff_helper /usr/bin/minuimus_woff_helper
	cp cab_analyze /usr/bin/cab_analyze
	cp minuimus.pl /usr/bin/minuimus.pl
	cp minuimus_swf_helper /usr/bin/minuimus_swf_helper

deps:
	apt-get install qpdf jpegoptim optipng advancecomp gif2apng webp unrar zip gifsicle p7zip-full poppler-utils libjpeg-progs imagemagick-6.q16 mupdf-tools brotli

zip:	minuimus.pl minuimus_def_helper.c makefile README.TXT READ_WIN.TXT  minuimus_woff_helper.c cab_analyze.c minuimus_swf_helper.c CHANGELOG
	zip -r9XD minuimus.zip minuimus.pl minuimus_def_helper.c makefile README.TXT READ_WIN.TXT zopfli minuimus_woff_helper.c cab_analyze.c minuimus_swf_helper.c CHANGELOG
	advzip -z4 minuimus.zip
