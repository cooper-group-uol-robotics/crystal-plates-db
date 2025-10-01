import { Controller } from "@hotwired/stimulus";

// Simple TAR format implementation for maximum speed
class SimpleTAR {
  constructor() {
    this.chunks = [];
  }
  
  // Create TAR header (512 bytes)
  createHeader(filename, size) {
    if (!filename || size === undefined || size === null) {
      throw new Error(`Invalid TAR header parameters: filename="${filename}", size=${size}`);
    }
    
    const header = new Uint8Array(512);
    
    // Filename (100 bytes max)
    const nameBytes = new TextEncoder().encode(filename.slice(0, 99));
    header.set(nameBytes, 0);
    
    // File mode (8 bytes) - "0000644\0"
    header.set(new TextEncoder().encode('0000644\0'), 100);
    
    // Owner ID (8 bytes) - "0000000\0"
    header.set(new TextEncoder().encode('0000000\0'), 108);
    
    // Group ID (8 bytes) - "0000000\0"
    header.set(new TextEncoder().encode('0000000\0'), 116);
    
    // File size (12 bytes) - octal format
    const fileSize = parseInt(size) || 0;
    const sizeOctal = fileSize.toString(8).padStart(11, '0') + '\0';
    header.set(new TextEncoder().encode(sizeOctal), 124);
    
    // Modification time (12 bytes) - current time in octal
    const mtime = Math.floor(Date.now() / 1000).toString(8).padStart(11, '0') + '\0';
    header.set(new TextEncoder().encode(mtime), 136);
    
    // Type flag (1 byte) - '0' for regular file
    header[156] = 48; // '0'
    
    // Calculate checksum
    let checksum = 0;
    // Initialize checksum field with spaces
    for (let i = 148; i < 156; i++) header[i] = 32; // spaces
    
    // Calculate checksum
    for (let i = 0; i < 512; i++) checksum += header[i];
    
    // Write checksum in octal
    const checksumOctal = checksum.toString(8).padStart(6, '0') + '\0 ';
    header.set(new TextEncoder().encode(checksumOctal), 148);
    
    return header;
  }
  
  addFile(filename, data) {
    // Ensure data is a Uint8Array and get proper size
    let fileData;
    let fileSize;
    
    if (data instanceof ArrayBuffer) {
      fileData = new Uint8Array(data);
      fileSize = data.byteLength;
    } else if (data instanceof Uint8Array) {
      fileData = data;
      fileSize = data.length;
    } else {
      throw new Error(`Unsupported data type for TAR: ${typeof data}`);
    }
        
    // Add header
    const header = this.createHeader(filename, fileSize);
    this.chunks.push(header);
    
    // Add file data
    this.chunks.push(fileData);
    
    // Pad to 512-byte boundary
    const padding = 512 - (fileSize % 512);
    if (padding < 512) {
      this.chunks.push(new Uint8Array(padding));
    }
  }
  
  finalize() {
    // Add two 512-byte zero blocks to end the archive
    this.chunks.push(new Uint8Array(512));
    this.chunks.push(new Uint8Array(512));
    
    return new Blob(this.chunks, { type: 'application/x-tar' });
  }
}

// Connects to data-controller="scxrd-dataset-uploader"
export default class extends Controller {
  static targets = [
    "form", "submitBtn", "folderInput", "zipFileInput", "compressedInput", 
    "experimentNameField", "uploadFolderRadio", "uploadZipRadio", 
    "folderUploadSection", "zipUploadSection", "folderInfo", "folderName", 
    "fileCount", "compressionProgress", "compressionStatus", "compressionPercent",
    "progressBar", "zipInfo", "zipName", "zipSize", "statusText"
  ];

  connect() {
    console.log('SCXRD: Dataset uploader controller connected');
    this.selectedFiles = null;
    this.uploadType = 'folder';
    this.isDatasetPersisted = this.formTarget.dataset.persisted === 'true';
    
    this.setupEventListeners();
    this.toggleUploadType();
  }

  disconnect() {
    console.log('SCXRD: Dataset uploader controller disconnected');
  }

  setupEventListeners() {
    this.uploadFolderRadioTarget.addEventListener('change', () => this.toggleUploadType());
    this.uploadZipRadioTarget.addEventListener('change', () => this.toggleUploadType());
    this.folderInputTarget.addEventListener('change', (e) => this.handleFolderSelection(e));
    this.zipFileInputTarget.addEventListener('change', (e) => this.handleZipFileSelection(e));
    this.formTarget.addEventListener('submit', (e) => this.handleFormSubmission(e));
  }

  toggleUploadType() {
    if (this.uploadFolderRadioTarget.checked) {
      this.uploadType = 'folder';
      this.folderUploadSectionTarget.style.display = 'block';
      this.zipUploadSectionTarget.style.display = 'none';
      this.folderInputTarget.required = !this.isDatasetPersisted;
      this.zipFileInputTarget.required = false;
      this.statusTextTarget.textContent = 'Select a folder first to enable upload';
    } else {
      this.uploadType = 'zip';
      this.folderUploadSectionTarget.style.display = 'none';
      this.zipUploadSectionTarget.style.display = 'block';
      this.folderInputTarget.required = false;
      this.zipFileInputTarget.required = !this.isDatasetPersisted;
      this.statusTextTarget.textContent = 'Select an archive file first to enable upload';
    }
    
    this.resetFormState();
  }

  resetFormState() {
    this.selectedFiles = null;
    this.folderInfoTarget.style.display = 'none';
    this.zipInfoTarget.style.display = 'none';
    this.compressionProgressTarget.style.display = 'none';
    this.submitBtnTarget.disabled = true;
    
    // Clear file inputs
    this.folderInputTarget.value = '';
    this.zipFileInputTarget.value = '';
    
    // Clear experiment name if not persisted
    if (!this.isDatasetPersisted && this.experimentNameFieldTarget) {
      this.experimentNameFieldTarget.value = '';
    }
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  handleFolderSelection(e) {
    this.selectedFiles = Array.from(e.target.files);
    
    if (this.selectedFiles.length > 0) {
      // Get folder name from the first file's path
      const fullPath = this.selectedFiles[0].webkitRelativePath;
      const folderNameStr = fullPath.split('/')[0];
      
      // Auto-fill experiment name with folder name
      if (this.experimentNameFieldTarget && !this.experimentNameFieldTarget.value) {
        this.experimentNameFieldTarget.value = folderNameStr;
      }
      
      this.folderNameTarget.textContent = folderNameStr;
      this.fileCountTarget.textContent = this.selectedFiles.length;
      this.folderInfoTarget.style.display = 'block';
      
      // Enable submit button
      this.submitBtnTarget.disabled = false;
      this.statusTextTarget.textContent = 'Ready to upload';
    } else {
      this.folderInfoTarget.style.display = 'none';
      this.submitBtnTarget.disabled = true;
      this.statusTextTarget.textContent = 'Select a folder first to enable upload';
    }
  }

  handleZipFileSelection(e) {
    const file = e.target.files[0];
    
    if (file) {
      // Auto-fill experiment name with ZIP filename (without extension)
      if (this.experimentNameFieldTarget && !this.experimentNameFieldTarget.value) {
        const nameWithoutExt = file.name.replace(/\.[^/.]+$/, "");
        this.experimentNameFieldTarget.value = nameWithoutExt;
      }
      
      this.zipNameTarget.textContent = file.name;
      this.zipSizeTarget.textContent = this.formatFileSize(file.size);
      this.zipInfoTarget.style.display = 'block';
      
      // Set the ZIP file directly to the compressed input
      const dt = new DataTransfer();
      dt.items.add(file);
      this.compressedInputTarget.files = dt.files;
      
      // Enable submit button
      this.submitBtnTarget.disabled = false;
      this.statusTextTarget.textContent = 'Ready to upload';
    } else {
      this.zipInfoTarget.style.display = 'none';
      this.submitBtnTarget.disabled = true;
      this.statusTextTarget.textContent = 'Select an archive file first to enable upload';
    }
  }

  async handleFormSubmission(e) {
    if (this.uploadType === 'folder') {
      await this.handleFolderUpload(e);
    } else {
      this.handleZipUpload(e);
    }
  }

  async handleFolderUpload(e) {
    if (!this.selectedFiles || this.selectedFiles.length === 0) return;
    
    e.preventDefault();
    
    // Show compression progress
    this.compressionProgressTarget.style.display = 'block';
    this.submitBtnTarget.disabled = true;
    this.submitBtnTarget.textContent = 'Packaging...';
    
    try {
      const tar = new SimpleTAR();
      let processedFiles = 0;
      let totalOriginalSize = 0;
      
      // Filter out temporary files first
      const filteredFiles = this.selectedFiles.filter(file => {
        const path = file.webkitRelativePath.toLowerCase();
        return !path.includes('tmp');
      });
      
      const totalFiles = this.selectedFiles.length;
      const totalFilesToProcess = filteredFiles.length;
      const skippedFiles = totalFiles - totalFilesToProcess;
      
      console.log(`SCXRD: Starting TAR packaging of ${totalFilesToProcess} files (${skippedFiles} temporary files excluded)...`);
      
      if (skippedFiles > 0) {
        console.log(`SCXRD: Excluding ${skippedFiles} temporary files from archive`);
        this.compressionStatusTarget.textContent = `Excluding ${skippedFiles} temporary files...`;
        await new Promise(resolve => setTimeout(resolve, 500)); // Brief pause to show the message
      }
      
      // Process files directly with TAR (much faster than ZIP)
      console.log('SCXRD: Processing files with TAR format...');
      const tarStartTime = Date.now();
      
      for (const file of filteredFiles) {
        try {
          this.compressionStatusTarget.textContent = `Adding ${file.name} (${processedFiles + 1}/${totalFilesToProcess})`;
          const progressPercent = Math.round((processedFiles / totalFilesToProcess) * 100);
          this.compressionPercentTarget.textContent = `${progressPercent}%`;
          this.progressBarTarget.style.width = `${progressPercent}%`;
          this.progressBarTarget.setAttribute('aria-valuenow', progressPercent);
          
          // Validate file properties
          if (!file.webkitRelativePath || file.size === undefined) {
            console.warn(`Skipping invalid file: ${file.name}, path: ${file.webkitRelativePath}, size: ${file.size}`);
            continue;
          }
                    
          // Read file content as ArrayBuffer
          const fileData = await file.arrayBuffer();
          
          // Validate the read data
          if (!fileData || fileData.byteLength !== file.size) {
            console.warn(`File read mismatch: ${file.name}, expected: ${file.size}, got: ${fileData?.byteLength}`);
          }
          
          totalOriginalSize += file.size;
          
          // Add to TAR archive (much faster than ZIP)
          tar.addFile(file.webkitRelativePath, fileData);
          processedFiles++;
          
        } catch (fileError) {
          console.error(`Error processing file ${file.name}:`, fileError);
          // Continue with other files instead of failing completely
          continue;
        }
        
        // Yield control every 25 files for UI responsiveness  
        if (processedFiles % 25 === 0) {
          await new Promise(resolve => setTimeout(resolve, 0));
        }
      }
      
      // Finalize TAR archive (very fast)
      this.compressionStatusTarget.textContent = 'Finalizing TAR archive...';
      const tarBlob = tar.finalize();
      
      const tarTime = Date.now() - tarStartTime;
      console.log(`SCXRD: TAR generation completed in ${tarTime}ms (${(tarTime/totalFilesToProcess).toFixed(1)}ms per file)`);
      
      const archivedSizeMB = (tarBlob.size / 1024 / 1024).toFixed(2);
      const originalSizeMB = (totalOriginalSize / 1024 / 1024).toFixed(2);
      const overhead = ((tarBlob.size / totalOriginalSize - 1) * 100).toFixed(1);
      
      console.log(`SCXRD: TAR packaging complete. Original: ${originalSizeMB} MB, Archived: ${archivedSizeMB} MB (+${overhead}% overhead)`);
      
      // Show final packaging stats
      this.compressionStatusTarget.textContent = `Complete! ${totalFilesToProcess} files archived (${archivedSizeMB} MB)`;
      this.compressionPercentTarget.textContent = '100%';
      this.progressBarTarget.style.width = '100%';
      this.progressBarTarget.setAttribute('aria-valuenow', 100);
      this.progressBarTarget.classList.remove('progress-bar-animated'); // Stop animation when complete
      
      // Create a File object from the TAR blob
      const tarFile = new File([tarBlob], `${this.experimentNameFieldTarget.value || 'scxrd_dataset'}.tar`, {
        type: 'application/x-tar'
      });
      
      // Create a new FileList-like object for the TAR file
      const dt = new DataTransfer();
      dt.items.add(tarFile);
      this.compressedInputTarget.files = dt.files;
      
      // Brief pause to show final stats
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Update UI for upload
      this.compressionProgressTarget.style.display = 'none';
      this.submitBtnTarget.textContent = 'Uploading...';
      this.submitBtnTarget.setAttribute('data-disable-with', 'Uploading TAR archive...');
      
      // Submit the form with the compressed file
      this.formTarget.submit();
      
    } catch (error) {
      console.error('SCXRD: TAR packaging failed:', error);
      alert(`TAR packaging failed: ${error.message}`);
      
      // Reset UI
      this.compressionProgressTarget.style.display = 'none';
      this.submitBtnTarget.disabled = false;
      this.submitBtnTarget.textContent = this.isDatasetPersisted ? "Update SCXRD Dataset" : "Upload SCXRD Dataset";
    }
  }

  handleZipUpload(e) {
    // Handle ZIP file upload - just submit normally as file is already set
    if (!this.compressedInputTarget.files || this.compressedInputTarget.files.length === 0) {
      e.preventDefault();
      alert('Please select an archive file first.');
      return;
    }
    
    this.submitBtnTarget.disabled = true;
    this.submitBtnTarget.textContent = 'Uploading...';
    this.submitBtnTarget.setAttribute('data-disable-with', 'Uploading archive file...');
  }
}