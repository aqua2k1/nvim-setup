# Windows IME helper

`ime.cpp` is a small Win32 helper for switching the active IME mode. It uses
`WM_IME_CONTROL` and does not switch the input-method profile.

The output is intentionally kept in this directory and is ignored by Git:

```text
scripts/ime/ime.exe
```

## Build in WSL

Install MinGW-w64 if necessary:

```bash
sudo apt install g++-mingw-w64-x86-64
```

Build the Windows executable from this directory:

```bash
cd ~/.config/nvim/scripts/ime
x86_64-w64-mingw32-g++ -std=c++17 -O2 -s \
  -static -static-libgcc -static-libstdc++ \
  ime.cpp -luser32 -limm32 -o ime.exe
```

## Build on Windows

From a Visual Studio Developer Command Prompt, build in the `scripts/ime`
directory under Neovim's config directory (check it with `:echo stdpath('config')`):

```powershell
cd $env:LOCALAPPDATA\nvim\scripts\ime
cl /nologo /std:c++17 /O2 /EHsc /MT ime.cpp user32.lib imm32.lib /Fe:ime.exe
```

## Test

Run while the target Windows application is in the foreground.

In WSL:

```bash
./ime.exe status
./ime.exe en
./ime.exe zh
```

In PowerShell:

```powershell
.\ime.exe status
.\ime.exe en
.\ime.exe zh
```

## Server mode

For low-latency WSL use, `ime.exe --server` stays alive and accepts one command
per line. Neovim starts this mode in the background when it starts, so the WSL
Windows-process startup cost is paid only once.

```bash
printf 'status\nen\nstatus\n' | ./ime.exe --server
```

The Neovim configuration calls `ime.exe --server` automatically on startup and
sends commands on `InsertLeave` and `InsertEnter` for Windows and WSL.
