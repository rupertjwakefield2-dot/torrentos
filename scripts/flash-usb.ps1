#Requires -RunAsAdministrator
#
# TorrentOS - Flash latest ISO to USB
#
# Usage:
#   .\scripts\flash-usb.ps1              # Flash latest ISO in .\out\
#   .\scripts\flash-usb.ps1 -IsoPath <path>   # Flash a specific ISO
#   .\scripts\flash-usb.ps1 -Watch       # Wait for a new ISO then flash
#
param(
    [string]$IsoPath = "",
    [int]   $DiskNum = 1,
    [switch]$Watch
)

$OutDir  = "$PSScriptRoot\..\out"
$BufSize = 4MB

function Get-LatestIso {
    Get-ChildItem "$OutDir\torrentos-*.iso" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Show-Disk($n) {
    $d = Get-Disk -Number $n -ErrorAction SilentlyContinue
    if ($d) {
        "$($d.FriendlyName) - $([math]::Round($d.Size/1GB,1)) GB - $($d.PartitionStyle)"
    } else {
        "(disk $n not found)"
    }
}

# -- Watch mode: poll until a new ISO appears ---------------------------------
if ($Watch) {
    $before = Get-LatestIso
    Write-Host "[watch] Waiting for a new ISO in $OutDir ..." -ForegroundColor Cyan
    while ($true) {
        Start-Sleep -Seconds 15
        $after = Get-LatestIso
        if ($after -and $after.FullName -ne $before.FullName) {
            Write-Host "[watch] New ISO detected: $($after.Name)" -ForegroundColor Green
            $IsoPath = $after.FullName
            break
        }
    }
}

# -- Resolve ISO path ---------------------------------------------------------
if (-not $IsoPath) {
    $iso = Get-LatestIso
    if (-not $iso) { Write-Error "No ISO found in $OutDir"; exit 1 }
    $IsoPath = $iso.FullName
}

if (-not (Test-Path $IsoPath)) { Write-Error "ISO not found: $IsoPath"; exit 1 }

$isoSize = (Get-Item $IsoPath).Length
$isoName = Split-Path $IsoPath -Leaf

# -- Confirm ------------------------------------------------------------------
Write-Host ""
Write-Host "  ISO  : $isoName" -ForegroundColor Yellow
Write-Host "  Size : $([math]::Round($isoSize/1GB,2)) GB"
Write-Host "  Disk : $DiskNum - $(Show-Disk $DiskNum)" -ForegroundColor Red
Write-Host ""
Write-Host "  *** ALL DATA ON DISK $DiskNum WILL BE ERASED ***" -ForegroundColor Red
Write-Host ""
$ans = Read-Host "  Type YES to confirm"
if ($ans -ne "YES") { Write-Host "Aborted."; exit 0 }

# -- Lock and dismount every volume on the disk via Win32 DeviceIoControl -----
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public class DiskUtil {
    const uint GENERIC_READ        = 0x80000000;
    const uint GENERIC_WRITE       = 0x40000000;
    const uint FILE_SHARE_RW       = 0x00000003;
    const uint OPEN_EXISTING       = 3;
    const uint FILE_FLAG_NO_BUF    = 0x20000000;
    const uint FSCTL_LOCK_VOLUME   = 0x00090018;
    const uint FSCTL_DISMOUNT_VOL  = 0x00090020;

    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    static extern SafeFileHandle CreateFile(string path, uint access, uint share,
        IntPtr sec, uint disp, uint flags, IntPtr tmpl);

    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool DeviceIoControl(SafeFileHandle h, uint code,
        IntPtr inBuf, uint inSz, IntPtr outBuf, uint outSz,
        out uint bytes, IntPtr ov);

    public static string LockAndDismount(string volumePath) {
        var h = CreateFile(volumePath, GENERIC_READ|GENERIC_WRITE,
                           FILE_SHARE_RW, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if (h.IsInvalid) return "open failed: " + Marshal.GetLastWin32Error();
        uint b;
        DeviceIoControl(h, FSCTL_LOCK_VOLUME,   IntPtr.Zero, 0, IntPtr.Zero, 0, out b, IntPtr.Zero);
        DeviceIoControl(h, FSCTL_DISMOUNT_VOL,  IntPtr.Zero, 0, IntPtr.Zero, 0, out b, IntPtr.Zero);
        h.Close();
        return "ok";
    }

    public static SafeFileHandle OpenDisk(string diskPath) {
        return CreateFile(diskPath, GENERIC_READ|GENERIC_WRITE,
                          FILE_SHARE_RW, IntPtr.Zero, OPEN_EXISTING,
                          FILE_FLAG_NO_BUF, IntPtr.Zero);
    }
}
'@ -ErrorAction Stop

Write-Host "[flash] Locking volumes on Disk $DiskNum..." -ForegroundColor Cyan
Get-Partition -DiskNumber $DiskNum -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.DriveLetter) {
        $path = "\\.\$($_.DriveLetter):"
        $r = [DiskUtil]::LockAndDismount($path)
        Write-Host "  $path -> $r"
    }
}

# -- Flash --------------------------------------------------------------------
Write-Host ""
Write-Host "[flash] Opening disk $DiskNum for writing..." -ForegroundColor Cyan

try {
    $src     = [System.IO.File]::OpenRead($IsoPath)
    $handle  = [DiskUtil]::OpenDisk("\\.\PhysicalDrive$DiskNum")
    if ($handle.IsInvalid) { throw "Cannot open PhysicalDrive$DiskNum (error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))" }
    $dst     = New-Object System.IO.FileStream($handle, [System.IO.FileAccess]::Write)
    $buf     = New-Object byte[] $BufSize
    $written = 0
    $sw      = [System.Diagnostics.Stopwatch]::StartNew()

    while (($read = $src.Read($buf, 0, $buf.Length)) -gt 0) {
        $dst.Write($buf, 0, $read)
        $written += $read
        $pct  = [int](($written / $isoSize) * 100)
        $mbps = [int](($written / 1MB) / ($sw.Elapsed.TotalSeconds + 0.001))
        Write-Progress -Activity "Flashing $isoName" `
                       -Status "$pct% - $([math]::Round($written/1GB,2)) / $([math]::Round($isoSize/1GB,2)) GB  ($mbps MB/s)" `
                       -PercentComplete $pct
    }

    $dst.Flush()
    Write-Progress -Activity "Flashing" -Completed
    $elapsed = $sw.Elapsed.ToString("mm\:ss")
    Write-Host ""
    Write-Host "[flash] Done in $elapsed. $([math]::Round($isoSize/1GB,2)) GB written to Disk $DiskNum." -ForegroundColor Green
    # Bring disk back online so Windows can read it
    "select disk $DiskNum`nonline disk`n" | diskpart | Out-Null
    Write-Host "        Eject the USB and boot your PC from it to run TorrentOS!" -ForegroundColor Cyan
}
catch {
    Write-Error "Flash failed: $_"
    exit 1
}
finally {
    if ($src) { $src.Close() }
    if ($dst) { $dst.Close() }
}
