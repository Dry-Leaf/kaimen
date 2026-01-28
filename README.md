# Installation

### Windows

- Install [WinFSP](https://winfsp.dev/rel/)
- Restart your machine
- Download the latest [release](https://github.com/Dry-Leaf/kaimen/releases/tag/latest)

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

```powershell
# adjust according to installation location of WinFSP
$env:CGO_CFLAGS = "\`"-IC:\Program Files (x86)\WinFsp\inc\fuse\`""

cd backend

go build -ldflags="-s -w -H=windowsgui" -o kaimen.exe

cd ../frontend

flutter build windows --release

mv ../backend/kaimen.exe build/windows/x64/runner/Release
```
