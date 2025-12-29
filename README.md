# Advantages over Hydrus Network
- Minimal setup
- Familiar UI
- Works with file managers
- Does not require its own copy of files

# Demo
![kaimen_demo](https://github.com/user-attachments/assets/355475f0-dd7f-453e-8520-c34c78fcccfc)

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
