# Demo
<img src="https://github.com/user-attachments/assets/355475f0-dd7f-453e-8520-c34c78fcccfc" width="600">

### Manual tag editing
<img width="600" alt="tag_edit_demo" src="https://github.com/user-attachments/assets/a85b30e5-12d5-40d1-a1f5-3868180f4ee8" />

# How does it work?

A Fuse mount is created, and virtual files populate a directory within it whenever a query is made. No on-disk file copying occurs. 

# Installation

### Linux

- Download the AppImage from from the latest [release](https://github.com/Dry-Leaf/kaimen/releases/tag/2.4)

### Windows

- Install [WinFSP](https://winfsp.dev/rel/)
- Restart your machine
- Download the latest [release](https://github.com/Dry-Leaf/kaimen/releases/tag/2.4)

### Setup
Gelbooru requires api credentials to be provided to pull metadata from it. After making an account and logging in, your credentials can be found at the bottom of [this page](https://gelbooru.com/index.php?page=account&s=options).

<img src="https://github.com/user-attachments/assets/60744096-5e80-4714-a7b6-6a261d3e2d61" width="900">

### Hydrus Integration

`For those who wish to use Kaimen as a Hydrus front-end`

`Note: Kaimen comes with many pre-defined tags, however tags in Hydrus, but not Kaimen, will not appear in autosuggestions. You will need to add those tags to Kaimen manually to allow their autosuggestion.`

Set up the Hydrus client api service and insert its URL and api access key into Kaimen's setting.

<img width="2142" height="738" alt="hydrus_setting_demo" src="https://github.com/user-attachments/assets/87bfed48-8790-4673-a1be-f24fdc3b87f5" />

# Advantages over Hydrus Network
`Note: Kaimen can also be used as a front-end for Hydrus`

- Minimal setup
- Familiar UI
- Built in [tag inference](https://huggingface.co/Camais03/camie-tagger-v2)
- Works with file managers
- Does not require its own copy of files

# Building

## Requirements
- git lfs
- go
- Flutter
- gcc
- taskfile

### Linux
- libfuse-dev
- cmake
- ninja
- ayatana-appindicator3-0.1 development
- libnotify-dev
- patchelf

### Windows
- WinFsp

### Windows compilation

```powershell
task build
```

### Linux compilation

```bash
task build-linux
```
