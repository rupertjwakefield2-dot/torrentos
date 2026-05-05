#!/usr/bin/env pwsh
#
# TorrentOS — Flash latest ISO to USB (PhysicalDrive1 / Samsung 256GB)
#
# Usage:
#   .\scripts\flash-usb.ps1              # Flash latest ISO in .\out\
#   .\scripts\flash-usb.ps1 -IsoPath <path>   # Flash a specific ISO
#   .\scripts\flash-usb.ps1 -Watch       # Wait for a new ISO then flash
#
param(
    [string]$IsoPath   = "",
    [int]   $DiskNum   = 1,
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
        "{0} — {1:N1} GB — {2}" -f $d.FriendlyName, ($d.Size/1GB), $d.PartitionStyle
    } else {
        "(disk $n not found)"
    }
}

# ── Watch mode: poll until a new ISO appears ──────────────────────────────────
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

# ── Resolve ISO path ──────────────────────────────────────────────────────────
if (-not $IsoPath) {
    $iso = Get-LatestIso
    if (-not $iso) { Write-Error "No ISO found in $OutDir"; exit 1 }
    $IsoPath = $iso.FullName
}

if (-not (Test-Path $IsoPath)) { Write-Error "ISO not found: $IsoPath"; exit 1 }

$isoSize = (Get-Item $IsoPath).Length
$isoName = Split-Path $IsoPath -Leaf

# ── Confirm ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ISO  : $isoName" -ForegroundColor Yellow
Write-Host "  Size : $("{0:N2}" -f ($isoSize/1GB)) GB"
Write-Host "  Disk : $DiskNum — $(Show-Disk $DiskNum)" -ForegroundColor Red
Write-Host ""
Write-Host "  *** ALL DATA ON DISK $DiskNum WILL BE ERASED ***" -ForegroundColor Red
Write-Host ""
$ans = Read-Host "  Type YES to confirm"
if ($ans -ne "YES") { Write-Host "Aborted."; exit 0 }

# ── Flash ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[flash] Opening disk $DiskNum for writing..." -ForegroundColor Cyan

try {
    $src  = [System.IO.File]::OpenRead($IsoPath)
    $dst  = [System.IO.File]::OpenWrite("\\.\PhysicalDrive$DiskNum")
    $buf  = New-Object byte[] $BufSize
    $written = 0
    $sw   = [System.Diagnostics.Stopwatch]::StartNew()

    while (($read = $src.Read($buf, 0, $buf.Length)) -gt 0) {
        $dst.Write($buf, 0, $read)
        $written += $read
        $pct  = [int](($written / $isoSize) * 100)
        $mbps = [int](($written / 1MB) / ($sw.Elapsed.TotalSeconds + 0.001))
        Write-Progress -Activity "Flashing $isoName" `
                       -Status "$pct% — $("{0:N0}" -f ($written/1MB)) / $("{0:N0}" -f ($isoSize/1MB)) MB  ($mbps MB/s)" `
                       -PercentComplete $pct
    }

    $dst.Flush()
    Write-Progress -Activity "Flashing" -Completed
    $elapsed = $sw.Elapsed.ToString("mm\:ss")
    Write-Host ""
    Write-Host "[flash] Done in $elapsed. $("{0:N2}" -f ($isoSize/1GB)) GB written to Disk $DiskNum." -ForegroundColor Green
    Write-Host "        Boot your PC from the USB to run TorrentOS!" -ForegroundColor Cyan
}
catch {
    Write-Error "Flash failed: $_"
    exit 1
}
finally {
    if ($src) { $src.Close() }
    if ($dst) { $dst.Close() }
}
