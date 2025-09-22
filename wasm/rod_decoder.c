// ROD TY6 Decoder - WebAssembly C implementation
// Based on the authoritative Python implementation from dxtbx/format/FormatROD.py

#include <stdint.h>
#include <string.h>

// Constants from Python implementation
#define BLOCKSIZE 8
#define SHORT_OVERFLOW 254
#define LONG_OVERFLOW 255
#define SHORT_OVERFLOW_SIGNED (SHORT_OVERFLOW - 127)  // 127
#define LONG_OVERFLOW_SIGNED (LONG_OVERFLOW - 127)    // 128

// Helper function to read little-endian 16-bit signed integer
int16_t read_int16_le(const uint8_t* data, int offset) {
    return (int16_t)(data[offset] | (data[offset + 1] << 8));
}

// Helper function to read little-endian 32-bit signed integer
int32_t read_int32_le(const uint8_t* data, int offset) {
    return (int32_t)(data[offset] | (data[offset + 1] << 8) | 
                     (data[offset + 2] << 16) | (data[offset + 3] << 24));
}

// Main TY6 decompression function - exact port of Python decode_TY6_oneline
// linedata: compressed line data
// width: number of pixels in the line
// output: output array (must be allocated by caller)
// Returns: number of pixels decoded
int decode_ty6_oneline(const uint8_t* linedata, int linedata_len, int width, int32_t* output) {
    int ipos = 0;
    int opos = 0;
    
    // Clear output array
    memset(output, 0, width * sizeof(int32_t));
    
    int nblock = (width - 1) / (BLOCKSIZE * 2);
    int nrest = (width - 1) % (BLOCKSIZE * 2);
    
    // Process first pixel (absolute value)
    if (ipos >= linedata_len) return 0;
    
    uint8_t firstpx = linedata[ipos++];
    if (firstpx < SHORT_OVERFLOW) {
        output[opos] = firstpx - 127;
    } else if (firstpx == LONG_OVERFLOW) {
        if (ipos + 3 < linedata_len) {
            output[opos] = read_int32_le(linedata, ipos);
            ipos += 4;
        }
    } else {
        if (ipos + 1 < linedata_len) {
            output[opos] = read_int16_le(linedata, ipos);
            ipos += 2;
        }
    }
    opos += 1;
    
    // Process blocks
    for (int k = 0; k < nblock; k++) {
        if (ipos >= linedata_len) break;
        
        uint8_t bittype = linedata[ipos++];
        int nbits[2] = {bittype & 15, (bittype >> 4) & 15};
        
        for (int i = 0; i < 2; i++) {
            int nbit = nbits[i];
            
            // Calculate zero point
            int zero_at = 0;
            if (nbit > 1) {
                zero_at = (1 << (nbit - 1)) - 1;
            }
            
            // Read packed bits
            uint64_t v = 0;
            for (int j = 0; j < nbit; j++) {
                if (ipos >= linedata_len) break;
                v |= ((uint64_t)linedata[ipos++]) << (8 * j);
            }
            
            // Unpack pixels
            uint64_t mask = (1ULL << nbit) - 1;
            for (int j = 0; j < BLOCKSIZE; j++) {
                if (opos >= width) break;
                output[opos] = ((v >> (nbit * j)) & mask) - zero_at;
                opos += 1;
            }
        }
        
        // Apply differential encoding to the block just processed
        // Python: for i in range(opos - BLOCKSIZE * 2, opos):
        for (int i = opos - BLOCKSIZE * 2; i < opos; i++) {
            int32_t offset = output[i];
            
            // Handle overflow values
            if (offset >= SHORT_OVERFLOW_SIGNED) {
                if (offset >= LONG_OVERFLOW_SIGNED) {
                    if (ipos + 3 < linedata_len) {
                        offset = read_int32_le(linedata, ipos);
                        ipos += 4;
                    }
                } else {
                    if (ipos + 1 < linedata_len) {
                        offset = read_int16_le(linedata, ipos);
                        ipos += 2;
                    }
                }
            }
            
            // Apply differential encoding: output[i] = offset + output[i - 1]
            output[i] = offset + output[i - 1];
        }
    }
    
    // Process remaining pixels
    for (int i = 0; i < nrest; i++) {
        if (ipos >= linedata_len || opos >= width) break;
        
        uint8_t px = linedata[ipos++];
        if (px < SHORT_OVERFLOW) {
            output[opos] = output[opos - 1] + px - 127;
        } else if (px == LONG_OVERFLOW) {
            if (ipos + 3 < linedata_len) {
                output[opos] = output[opos - 1] + read_int32_le(linedata, ipos);
                ipos += 4;
            }
        } else {
            if (ipos + 1 < linedata_len) {
                output[opos] = output[opos - 1] + read_int16_le(linedata, ipos);
                ipos += 2;
            }
        }
        opos += 1;
    }
    
    return opos;
}

// WebAssembly exports
__attribute__((export_name("decode_line")))
int decode_line(const uint8_t* linedata, int linedata_len, int width, int32_t* output) {
    return decode_ty6_oneline(linedata, linedata_len, width, output);
}

__attribute__((export_name("get_memory")))
uint8_t* get_memory() {
    return 0; // WebAssembly linear memory starts at 0
}