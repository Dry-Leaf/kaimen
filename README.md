# Installation

### Windows

- Install [WinFSP](https://winfsp.dev/rel/)
- Restart your machine
- Download the latest [release](https://github.com/Dry-Leaf/kaimen/releases/tag/latest)

### Setup
Gelbooru requires api credentials to be provided to pull metadata from it. Your credentials can be found at the bottom of [this page](https://gelbooru.com/index.php?page=account&s=options).

![Gelbooru Setup](https://github.com/user-attachments/assets/60744096-5e80-4714-a7b6-6a261d3e2d61)

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
