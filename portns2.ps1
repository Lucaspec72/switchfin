# Switchfin Switch 2 build wrapper.
#
# Builds Switchfin.nro for Switch 2 (libounce + OunceVK) inside the official
# devkitpro/devkita64 Docker image, overlaying the local ounce-devkit drop
# (libounce + portlibs/switch2) and installing the Switch 1 prebuilt portlibs
# (mpv/ffmpeg/curl/...) that upstream's Switch build links against.
#
# Usage (from the repo root):
#   .\portns2.ps1              configure + build build_ns2/Switchfin.nro
#   .\portns2.ps1 build        same
#   .\portns2.ps1 clean        delete the build dir
#   .\portns2.ps1 shell        interactive bash in the container
#   .\portns2.ps1 run <bash>   arbitrary command with switch2vars.sh sourced
#
# Requires: Docker Desktop running, and the Switch 2 devkit drop
# (ounce-devkit-<date>, containing libounce/ and portlibs/switch2/) in this
# folder or any parent - or set $env:SWITCH2_DEVKIT to its path.
param(
    [Parameter(Position = 0)] [string] $Action = "build",
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)] [string[]] $Rest
)
$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
$Image = "devkitpro/devkita64"
$Repo = "/work/switchfin"
$Cache = Join-Path $Root "ns2\cache"
$BuildDir = "build_ns2"

# --- locate the devkit drop -------------------------------------------------
$Devkit = $env:SWITCH2_DEVKIT
if (-not $Devkit) {
    $dir = $Root
    while ($dir) {
        $hit = Get-ChildItem $dir -Directory -Filter "ounce-devkit-*" -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "switch2vars.sh") } |
            Select-Object -First 1
        if ($hit) { $Devkit = $hit.FullName; break }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
}
if (-not $Devkit -or -not (Test-Path (Join-Path $Devkit "switch2vars.sh"))) {
    Write-Error "Switch 2 devkit drop not found: put ounce-devkit-<date> in this folder or a parent, or set `$env:SWITCH2_DEVKIT."
}
$Vars = "/devkit/switch2vars.sh"
$WinDevkit = $Devkit -replace '\\', '/'
$WinRoot = $Root -replace '\\', '/'

# --- Switch 1 prebuilt portlibs (upstream's switch-portlibs release) --------
$Portlibs = @(
    "mbedtls-3.6.7-1", "libssh2-1.11.1-1", "dav1d-1.5.4-1",
    "curl-8.23.0-3", "ffmpeg-7.1.5-5", "libmpv-0.36.0-5"
)
$PortlibsBase = "https://github.com/dragonflylee/switchfin/releases/download/switch-portlibs"
New-Item -ItemType Directory -Force $Cache | Out-Null
foreach ($p in $Portlibs) {
    $n = "switch-$p-any.pkg.tar.zst"
    if (-not (Test-Path (Join-Path $Cache $n))) {
        Write-Host "downloading $n ..."
        Invoke-WebRequest "$PortlibsBase/$n" -OutFile (Join-Path $Cache $n)
    }
}

# --- bind mounts ------------------------------------------------------------
$mounts = @(
    "-v", "${WinRoot}:/work/switchfin",
    "-v", "${WinRoot}/ns2/cache:/pkgs",
    "-v", "${WinDevkit}:/devkit:ro",
    "-v", "${WinDevkit}/libounce:/opt/devkitpro/libounce:ro",
    "-v", "${WinDevkit}/portlibs/switch2:/opt/devkitpro/portlibs/switch2:ro"
)

function Invoke-Docker([string] $Workdir, [string] $Command) {
    docker run --rm @mounts -w $Workdir $Image bash -lc $Command
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# Installer step: overlay the Switch 1 portlibs onto the image's
# portlibs/switch (runs in seconds; packages are cached in ns2/cache).
$InstallPortlibs = '/opt/devkitpro/pacman/bin/pacman -U --noconfirm /pkgs/*.pkg.tar.zst >/dev/null'

switch ($Action) {
    "build" {
        $extra = if ($Rest) { $Rest -join ' ' } else { "" }
        Invoke-Docker $Repo ("$InstallPortlibs && source $Vars && " +
            "aarch64-none-elf-cmake -S . -B $BuildDir -G Ninja " +
            "-DPLATFORM_SWITCH2=ON -DCMAKE_BUILD_TYPE=Release " +
            "-DUSE_LIBUSBHSFS=OFF -DUSE_MUPDF=OFF -DBUILTIN_NSP=OFF " +
            "-DVERSION_BUILD=0 $extra " +
            "&& cmake --build $BuildDir --target Switchfin.nro")
    }
    "clean" {
        Remove-Item -Recurse -Force (Join-Path $Root $BuildDir) -ErrorAction SilentlyContinue
        "cleaned $BuildDir"
    }
    "shell" {
        docker run --rm -it @mounts -w $Repo $Image bash -lc $InstallPortlibs
        docker run --rm -it @mounts -w $Repo $Image bash -lc "source $Vars && exec bash"
    }
    "run" {
        $cmd = $Rest -join " "
        Invoke-Docker $Repo "$InstallPortlibs && source $Vars && $cmd"
    }
    default {
        Write-Host "Unknown action '$Action'. See header comment in portns2.ps1."
        exit 1
    }
}
