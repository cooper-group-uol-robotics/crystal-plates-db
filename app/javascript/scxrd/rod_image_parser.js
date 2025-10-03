// ROD Image Parser - WebAssembly implementation
// Uses C implementation compiled to WebAssembly for pixel-perfect accuracy

// Global WebAssembly module cache to avoid reloading
let globalWasmModule = null;
let globalWasmModulePromise = null;

class RodImageParser {
  constructor(base64Data) {
    console.log('ROD Parser: Initializing with base64 data (WebAssembly)');

    // Convert base64 to ArrayBuffer
    const binaryString = atob(base64Data);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }

    this.data = bytes;
    this.dataView = new DataView(bytes.buffer);
    this.textHeader = {};
    this.binaryHeader = {};
    this.wasmModule = null;

    console.log(`ROD Parser: Initialized with ${bytes.length} bytes`);
  }

  async loadWasmModule() {
    // Use global cache to avoid reloading the module for each instance
    if (globalWasmModule) {
      this.wasmModule = globalWasmModule;
      return this.wasmModule;
    }

    // Ensure we only load the module once globally, even with concurrent calls
    if (globalWasmModulePromise) {
      this.wasmModule = await globalWasmModulePromise;
      return this.wasmModule;
    }

    globalWasmModulePromise = this._loadWasmModuleInternal();
    globalWasmModule = await globalWasmModulePromise;
    this.wasmModule = globalWasmModule;
    return this.wasmModule;
  }

  async _loadWasmModuleInternal() {
    try {
      console.log('ROD Parser: Loading WebAssembly module (global cache)...');

      // Dynamically import the WebAssembly module
      const { default: RodDecoderModule } = await import('wasm/rod_decoder');
      
      // Provide custom locateFile function to find WASM file in assets
      const wasmModule = await RodDecoderModule({
        locateFile: (path, prefix) => {
          if (path.endsWith('.wasm')) {
            // Use the asset path provided by Rails views
            return window.ROD_WASM_PATH || '/assets/' + path;
          }
          return prefix + path;
        }
      });
      
      console.log('ROD Parser: WebAssembly module loaded successfully (cached for future use)');
      return wasmModule;
    } catch (error) {
      console.error('ROD Parser: Failed to load WebAssembly module:', error);
      throw new Error(`WebAssembly module loading failed: ${error.message}`);
    }
  }

  async parse() {
    try {
      console.log('ROD Parser: Starting parse process');

      // Load WebAssembly module
      await this.loadWasmModule();

      // Parse headers
      this.parseTextHeader();
      this.parseBinaryHeader();

      // Parse image data using WebAssembly
      const imageData = await this.parseImageData();

      return {
        success: true,
        image_data: imageData,
        dimensions: [this.textHeader.NX, this.textHeader.NY],
        metadata: {
          compression: this.textHeader.COMPRESSION,
          version: this.textHeader.version
        }
      };
    } catch (error) {
      console.error('ROD Parser: Parse failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  parseTextHeader() {
    // Read first 256 bytes as ASCII text
    const headerBytes = this.data.slice(0, 256);
    const headerText = String.fromCharCode(...headerBytes).replace(/\0/g, '');
    const lines = headerText.split('\n');

    if (lines.length < 2) {
      throw new Error('Invalid text header: insufficient lines');
    }

    // Parse version line
    const versionParts = lines[0].split(/\s+/);
    if (versionParts.length < 3 || versionParts[0] !== 'OD' || versionParts[1] !== 'SAPPHIRE') {
      throw new Error('Invalid text header: wrong format identifier');
    }
    this.textHeader.version = parseFloat(versionParts[2]);

    // Parse compression line
    const compressionParts = lines[1].split('=');
    if (compressionParts[0] !== 'COMPRESSION') {
      throw new Error('Invalid text header: missing compression info');
    }
    this.textHeader.COMPRESSION = compressionParts[1];

    // Parse dimension definitions
    const defnRegex = /([A-Z]+=\s*\d+)/g;
    for (let i = 2; i <= 4 && i < lines.length; i++) {
      const matches = lines[i].match(defnRegex);
      if (matches) {
        matches.forEach(match => {
          const [key, value] = match.split('=');
          this.textHeader[key.trim()] = parseInt(value.trim());
        });
      }
    }
  }

  parseBinaryHeader() {
    const offset = 256;

    // Read binning
    this.binaryHeader.bin_x = this.dataView.getInt16(offset, true);
    this.binaryHeader.bin_y = this.dataView.getInt16(offset + 2, true);

    // Read image dimensions
    this.binaryHeader.chip_npx_x = this.dataView.getInt16(offset + 22, true);
    this.binaryHeader.chip_npx_y = this.dataView.getInt16(offset + 24, true);
    this.binaryHeader.im_npx_x = this.dataView.getInt16(offset + 26, true);
    this.binaryHeader.im_npx_y = this.dataView.getInt16(offset + 28, true);

    // Validate dimensions
    if (this.binaryHeader.im_npx_x === 0 || this.binaryHeader.im_npx_y === 0 ||
      this.binaryHeader.im_npx_x > 10000 || this.binaryHeader.im_npx_y > 10000) {
      this.binaryHeader.im_npx_x = this.textHeader.NX;
      this.binaryHeader.im_npx_y = this.textHeader.NY;
    }
  }

  async parseImageData() {
    const nx = this.textHeader.NX;
    const ny = this.textHeader.NY;
    const compression = this.textHeader.COMPRESSION?.trim();

    if (!compression || !compression.startsWith('TY6')) {
      throw new Error(`Unsupported compression: ${compression}`);
    }

    // Image data starts after header
    const offset = this.textHeader.NHEADER || 5120;

    // Read compressed field size
    const compressedFieldSize = this.dataView.getInt32(offset, true);

    // Read compressed line data
    const lineDataStart = offset + 4;
    const lineData = this.data.slice(lineDataStart, lineDataStart + compressedFieldSize);

    // Read line offsets
    const offsetsStart = lineDataStart + compressedFieldSize;
    const offsets = [];
    for (let i = 0; i < ny; i++) {
      const offsetValue = this.dataView.getUint32(offsetsStart + i * 4, true);
      offsets.push(offsetValue);
    }

    // Decompress each line using WebAssembly
    const image = [];
    for (let iy = 0; iy < ny; iy++) {
      if (offsets[iy] >= lineData.length) {
        image.push(new Array(nx).fill(0));
        continue;
      }

      const lineStart = lineData.slice(offsets[iy]);
      const decodedLine = await this.decodeTY6OneLineWasm(lineStart, nx);
      image.push(decodedLine);
    }

    return image.flat();
  }

  async decodeTY6OneLineWasm(lineData, width) {
    if (!this.wasmModule) {
      throw new Error('WebAssembly module not loaded');
    }

    // Allocate memory in WebAssembly
    const lineDataPtr = this.wasmModule._malloc(lineData.length);
    const outputPtr = this.wasmModule._malloc(width * 4); // 4 bytes per int32

    try {
      // Copy line data to WebAssembly memory
      this.wasmModule.HEAP8.set(lineData, lineDataPtr);

      // Call the WebAssembly decoder function
      const pixelsDecoded = this.wasmModule.ccall(
        'decode_line',
        'number',
        ['number', 'number', 'number', 'number'],
        [lineDataPtr, lineData.length, width, outputPtr]
      );

      // Read the result from WebAssembly memory
      const result = new Array(width);
      const outputView = new Int32Array(this.wasmModule.HEAP32.buffer, outputPtr, width);
      for (let i = 0; i < width; i++) {
        result[i] = outputView[i];
      }

      return result;
    } finally {
      // Free allocated memory
      this.wasmModule._free(lineDataPtr);
      this.wasmModule._free(outputPtr);
    }
  }
}

// Export to global scope for backward compatibility
window.RodImageParser = RodImageParser;

// Export as ES6 module
export default RodImageParser;

console.log('RodImageParser: WebAssembly implementation loaded');
