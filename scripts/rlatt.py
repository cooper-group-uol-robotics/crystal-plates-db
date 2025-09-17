import struct
import numpy as np

def read_binary_file(filename):
    """
    Read binary file with the following structure:
    - First 8 bytes: long long (number of chunks)
    - 312 padding bytes
    - Repeating 168-byte chunks
    - Each chunk contains 5 doubles (x, y, z, r, i) at the beginning
    - End of file may contain junk data
    """
    with open(filename, 'rb') as f:
        # Read the number of chunks from first 8 bytes
        num_chunks_bytes = f.read(8)
        if len(num_chunks_bytes) < 8:
            raise ValueError("File too short to contain chunk count")
        
        num_chunks = struct.unpack('<Q', num_chunks_bytes)[0]  # Q = unsigned long long
        print(f"Number of chunks specified in file header: {num_chunks}")
        
        # Skip the 312 padding bytes including the initial 8 bytes
        f.seek(312)  # 312 padding bytes
        
        data_points = []
        chunk_size = 168
        double_size = 8
        doubles_per_chunk = 5
        
        # Read exactly the number of chunks specified in the header
        for i in range(num_chunks):
            chunk = f.read(chunk_size)
            if len(chunk) < chunk_size:
                print(f"Warning: Chunk {i+1} is incomplete ({len(chunk)} bytes instead of {chunk_size})")
                break
            
            # Extract the 5 doubles from the beginning of the chunk
            # struct format: 'd' = double (8 bytes), '<' = little-endian
            doubles = struct.unpack('<4dq', chunk[:doubles_per_chunk * double_size])
            x, y, z, r, i = doubles
            
            data_points.append({
                'x': x,
                'y': y,
                'z': z,
                'r': r,
                'i': i
            })
        
        print(f"Successfully read {len(data_points)} chunks")
        return data_points

def convert_to_arrays(data_points):
    """Convert list of dictionaries to numpy arrays for easier processing"""
    if not data_points:
        return None
    
    return {
        'x': np.array([point['x'] for point in data_points]),
        'y': np.array([point['y'] for point in data_points]),
        'z': np.array([point['z'] for point in data_points]),
        'r': np.array([point['r'] for point in data_points]),
        'i': np.array([point['i'] for point in data_points])
    }

def analyze_binary_file(filename):
    """Analyze the binary file structure and provide statistics"""
    import os
    
    file_size = os.path.getsize(filename)
    print(f"File size: {file_size} bytes")
    
    # Calculate expected number of chunks
    data_size = file_size - 312  # Subtract padding
    num_chunks = data_size // 168
    remaining_bytes = data_size % 168
    
    print(f"Padding bytes: 312")
    print(f"Data size: {data_size} bytes")
    print(f"Expected number of chunks: {num_chunks}")
    if remaining_bytes > 0:
        print(f"Remaining bytes (incomplete chunk): {remaining_bytes}")
    
    return num_chunks

def plot_data_points(arrays, title="Data Points"):
    """Plot the x, y, z coordinates in 3D space"""
    import matplotlib.pyplot as plt
    from mpl_toolkits.mplot3d import Axes3D
    
    if arrays is None:
        print("No data to plot")
        return
    
    fig = plt.figure(figsize=(12, 8))
    
    # 3D scatter plot
    ax1 = fig.add_subplot(221, projection='3d')
    scatter = ax1.scatter(arrays['x'], arrays['y'], arrays['z'], 
                         c=arrays['r'], cmap='viridis', alpha=0.6)
    ax1.set_xlabel('X')
    ax1.set_ylabel('Y')
    ax1.set_zlabel('Z')
    ax1.set_title(f'{title} - 3D (colored by r)')
    plt.colorbar(scatter, ax=ax1, shrink=0.5)
    
    # XY projection
    ax2 = fig.add_subplot(222)
    ax2.scatter(arrays['x'], arrays['y'], c=arrays['r'], cmap='viridis', alpha=0.6)
    ax2.set_xlabel('X')
    ax2.set_ylabel('Y')
    ax2.set_title('XY Projection')
    
    # r vs i plot
    ax3 = fig.add_subplot(223)
    ax3.scatter(arrays['r'], arrays['i'], alpha=0.6)
    ax3.set_xlabel('r')
    ax3.set_ylabel('i')
    ax3.set_title('r vs i')
    
    # Value distributions
    ax4 = fig.add_subplot(224)
    ax4.hist([arrays['x'], arrays['y'], arrays['z'], arrays['r'], arrays['i']], 
             bins=20, alpha=0.7, label=['x', 'y', 'z', 'r', 'i'])
    ax4.set_xlabel('Value')
    ax4.set_ylabel('Frequency')
    ax4.set_title('Value Distributions')
    ax4.legend()
    
    plt.tight_layout()
    plt.show()

# Example of complete workflow:
def process_binary_file(filename, plot=False):
    """Complete processing workflow for the binary file"""
    print("Analyzing file structure...")
    num_chunks = analyze_binary_file(filename)
    
    print("\nReading data...")
    data = read_binary_file(filename)
    arrays = convert_to_arrays(data)
    
    if arrays:
        print(f"Successfully read {len(data)} data points")
        print("\nData statistics:")
        for key in ['x', 'y', 'z', 'r', 'i']:
            arr = arrays[key]
            print(f"{key}: min={arr.min():.6f}, max={arr.max():.6f}, mean={arr.mean():.6f}, std={arr.std():.6f}")
        
        if plot:
            print("\nPlotting data...")
            plot_data_points(arrays, f"Binary File Data ({len(data)} points)")
    
    return data, arrays