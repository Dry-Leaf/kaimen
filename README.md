# Advantages over Hydrus Network
- Minimal setup
- Familiar UI
- Works with file managers
- Does not require its own copy of files

# Building

## Requirments 
- go
- Flutter
- gcc

### Linux
- libfuse-dev

### Windows
- WinFsp

### Windows compilation

$env:CGO_CFLAGS = "\`"-IC:\Program Files (x86)\WinFsp\inc\fuse\`""
> adjust according to installation location of WinFSP
