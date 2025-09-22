# ROD TY6 WebAssembly Setup Instructions

## Option 1: WebAssembly Implementation (Recommended for pixel-perfect accuracy)

### Install Emscripten SDK

```bash
# Install Emscripten
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh

# Add to your shell profile (e.g., ~/.bashrc or ~/.zshrc)
echo 'source /path/to/emsdk/emsdk_env.sh' >> ~/.bashrc
```

### Build WebAssembly Module

```bash
cd /home/thomas/crystal-plates-db/wasm
./build.sh
```

### Update JavaScript to use WebAssembly

Replace the current `rod_image_parser.js` with `rod_image_parser_wasm.js`:

```bash
mv app/assets/javascripts/rod_image_parser.js app/assets/javascripts/rod_image_parser_js.js
mv app/assets/javascripts/rod_image_parser_wasm.js app/assets/javascripts/rod_image_parser.js
```

## Option 2: Web Worker Implementation (Alternative approach)

If WebAssembly setup is complex, you can try the Web Worker approach which isolates the JavaScript implementation and may resolve browser optimization issues.

## Option 3: Server-side Processing (Fallback)

Keep using the Ruby implementation on the server side, which is known to work correctly.

## Testing

After implementing either option, test with the diffraction image viewer to verify that horizontal streaks are eliminated.

## Why WebAssembly?

- **Pixel-perfect accuracy**: Compiled from the same C/C++ code base as the Python implementation
- **Performance**: Faster execution than JavaScript
- **Deterministic**: Avoids JavaScript engine optimizations that might cause subtle differences
- **Memory management**: Direct control over memory layout matching the C implementation