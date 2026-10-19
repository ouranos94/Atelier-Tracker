#!/bin/zsh
# Rebuild the self-contained ARM64 decoder from the official, checksum-pinned source.
set -euo pipefail
cd "$(dirname "$0")/.."
TRACKER_ROOT="$PWD"
TRACKER_MPT_VERSION='0.8.9+release.autotools'
TRACKER_MPT_SHA='d7ce84fd05d686c4bcf66af40eae857afa371442db60eeda3f874bd6cf6fc318'
TRACKER_MPT_CACHE="$TRACKER_ROOT/.build/openmpt-src"
mkdir -p "$TRACKER_MPT_CACHE" "$TRACKER_ROOT/Vendor/OpenMPT/lib" "$TRACKER_ROOT/Vendor/OpenMPT/include" "$TRACKER_ROOT/Vendor/OpenMPT/licenses"
if [[ ! -f "$TRACKER_MPT_CACHE/source.tar.gz" ]]; then
    curl --fail --location "https://lib.openmpt.org/files/libopenmpt/src/libopenmpt-$TRACKER_MPT_VERSION.tar.gz" -o "$TRACKER_MPT_CACHE/source.tar.gz"
fi
printf '%s  %s\n' "$TRACKER_MPT_SHA" "$TRACKER_MPT_CACHE/source.tar.gz" | shasum -a 256 -c -
if [[ ! -d "$TRACKER_MPT_CACHE/libopenmpt-$TRACKER_MPT_VERSION" ]]; then
    tar -xzf "$TRACKER_MPT_CACHE/source.tar.gz" -C "$TRACKER_MPT_CACHE"
fi
cd "$TRACKER_MPT_CACHE/libopenmpt-$TRACKER_MPT_VERSION"
./configure --disable-shared --enable-static --disable-openmpt123 --disable-examples --disable-tests --disable-doxygen-doc --without-zlib --without-mpg123 --without-ogg --without-vorbis --without-vorbisfile --without-portaudio --without-portaudiocpp --without-sndfile --without-flac CFLAGS='-O2 -arch arm64 -mmacosx-version-min=14.0' CXXFLAGS='-O2 -arch arm64 -mmacosx-version-min=14.0'
make -j8
cp .libs/libopenmpt.a "$TRACKER_ROOT/Vendor/OpenMPT/lib/"
cp libopenmpt/libopenmpt{,_config,_version,_ext}.h "$TRACKER_ROOT/Vendor/OpenMPT/include/"
cp LICENSE "$TRACKER_ROOT/Vendor/OpenMPT/LICENSE"
cp src/mpt/LICENSE.*.txt "$TRACKER_ROOT/Vendor/OpenMPT/licenses/"
