FROM debian:stable-slim

RUN \
echo "************************************************************" && \
echo "****  update and install build packages ****" && \
apt-get update -qy && \
apt-get install -qy \
 curl \
 g++ \
 gcc \
 zlib1g-dev \
 make \
 wget && \
echo "************************************************************" && \
echo "**** install required and optional packages ****" && \
 apt-get install -qy \
 advancecomp \ 
 cabextract \
 ffmpeg \
 file \
 gif2apng \
 gifsicle \
 imagemagick-6.q16 \
 jbig2dec \
 jpegoptim \
 libjpeg-progs \
 optipng \
 p7zip-full \
 perl \
 poppler-utils \
 qpdf \
 unrar-free \
 webp \
 zip && \
echo "************************************************************" && \
echo "**** compile minuimus and extras ****" && \
mkdir -p /tmp/minuimus-src && \
wget -O /tmp/minuimus-src/minuimus.pl-main.zip https://github.com/Wdavery/minuimus.pl/archive/refs/heads/main.zip && \
cd /tmp/minuimus-src && \
unzip /tmp/minuimus-src/minuimus.pl-main && \
cd /tmp/minuimus-src/minuimus.pl-main && \
make install && \
rm -r /tmp/minuimus-src && \
echo "************************************************************" && \
echo "**** install flexiGIF ****" && \
mkdir -p /tmp/flexigif-src && \
cd /tmp/flexigif-src && \
wget -O /tmp/flexigif-src/flexigif https://create.stephan-brumme.com/flexigif-lossless-gif-lzw-optimization/flexiGIF.2018.11a && \
mv flexigif /usr/bin/flexigif && \
chmod +x /usr/bin/flexigif && \
rm -r /tmp/flexigif-src && \
echo "************************************************************" && \
echo "**** install pdfsizeopt, pngout, jbig2 and dependencies ****" && \
mkdir /var/opt/pdfsizeopt && \
cd /var/opt/pdfsizeopt  && \
wget -O pdfsizeopt_libexec_linux.tar.gz https://github.com/pts/pdfsizeopt/releases/download/2017-01-24/pdfsizeopt_libexec_linux-v3.tar.gz && \
tar xzvf pdfsizeopt_libexec_linux.tar.gz && \
rm -f pdfsizeopt_libexec_linux.tar.gz && \
ln pdfsizeopt_libexec/pngout /usr/bin/pngout && \
ln pdfsizeopt_libexec/jbig2 /usr/bin/jbig2 && \
ln pdfsizeopt_libexec/png22pnm /usr/bin/png22pnm && \
ln pdfsizeopt_libexec/sam2p /usr/bin/sam2p && \
wget -O pdfsizeopt.single https://raw.githubusercontent.com/pts/pdfsizeopt/master/pdfsizeopt.single && \
chmod +x pdfsizeopt.single && \
ln -s pdfsizeopt.single pdfsizeopt && \
echo "************************************************************" && \
echo "**** compile leanify ****" && \
mkdir -p /tmp/leanify-src && \
cd /tmp/leanify-src && \
wget -O leanify.zip https://github.com/JayXon/Leanify/archive/refs/heads/master.zip && \
unzip leanify.zip && \
rm leanify.zip && \
cd Leanify-master && \
make && \
mv leanify /usr/bin/leanify && \
rm -r /tmp/leanify-src && \
echo "************************************************************" && \
echo "**** Cleanup ****" && \
apt-get purge -qy \
 curl \
 gcc \
 g++ \
 zlib1g-dev \
 make \
 wget && \
apt-get autoremove -qy && \
rm -rf /var/lib/apt/lists/* && \
cat

VOLUME /data