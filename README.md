# Demo
<img src="https://github.com/user-attachments/assets/355475f0-dd7f-453e-8520-c34c78fcccfc" width="600">

### Manual tag editing
<img width="600" alt="tag_edit_demo" src="https://github.com/user-attachments/assets/a85b30e5-12d5-40d1-a1f5-3868180f4ee8" />

# Installation

### Windows

- Install [WinFSP](https://winfsp.dev/rel/)
- Restart your machine
- Download the latest [release](https://github.com/Dry-Leaf/kaimen/releases/tag/latest)

### Setup
Gelbooru requires api credentials to be provided to pull metadata from it. After making an account and logging in, your credentials can be found at the bottom of [this page](https://gelbooru.com/index.php?page=account&s=options).

<img src="https://github.com/user-attachments/assets/60744096-5e80-4714-a7b6-6a261d3e2d61" width="900">

# Advantages over Hydrus Network
- Minimal setup
- Familiar UI
- Works with file managers
- Does not require its own copy of files

# Building

## Requirments
- git lfs
- go
- Flutter
- gcc
- taskfile
- patchelf

### Linux
- libfuse-dev
- cmake
- ninja
- ayatana-appindicator3-0.1

### Windows
- WinFsp

### Windows compilation

```powershell
mkdir releases
task build
```
