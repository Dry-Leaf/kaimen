Linux, requires libfuse-dev
Windows requires WinFsp

Windows compilation

$env:CGO_CFLAGS = "\`"-IC:\Program Files (x86)\WinFsp\inc\fuse\`""
> adjust according to installation location of WinFSP
