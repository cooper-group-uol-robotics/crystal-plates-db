#!/bin/bash

# ROD TY6 WebAssembly Build Script
# This script compiles the C implementation to WebAssembly

set -e

echo "Building ROD TY6 WebAssembly decoder..."

# Check if Emscripten is available
if ! command -v emcc &> /dev/null; then
    echo "Error: Emscripten not found. Please install Emscripten SDK:"
    echo "  git clone https://github.com/emscripten-core/emsdk.git"
    echo "  cd emsdk"
    echo "  ./emsdk install latest"
    echo "  ./emsdk activate latest"
    echo "  source ./emsdk_env.sh"
    exit 1
fi

# Create output directory
mkdir -p ../app/assets/javascripts/wasm

# Compile C to WebAssembly
emcc rod_decoder.c \
    -O3 \
    -s WASM=1 \
    -s EXPORTED_FUNCTIONS='["_decode_line", "_malloc", "_free"]' \
    -s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap", "HEAP8", "HEAP32"]' \
    -s ALLOW_MEMORY_GROWTH=1 \
    -s MODULARIZE=1 \
    -s EXPORT_NAME='RodDecoderModule' \
    -o ../app/assets/javascripts/wasm/rod_decoder.js

echo "WebAssembly build complete!"
echo "Generated files:"
echo "  - app/assets/javascripts/wasm/rod_decoder.js"
echo "  - app/assets/javascripts/wasm/rod_decoder.wasm"