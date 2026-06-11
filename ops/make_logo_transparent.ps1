# Makes the in-app logo transparent + tightly cropped.
#
# `assets/branding/app_logo.png` was exported with a baked dark background, which
# renders as an ugly box wherever the logo sits on the app's gradient. A logo
# should composite cleanly, so we key the dark bg out to alpha (per-pixel, from
# how far above the dark floor each pixel is) — preserving the neon/amber glow as
# a soft fade — then square-crop to the logo's content so it fills its frame.
#
# Idempotent-ish (re-running on an already-transparent logo keeps it transparent).
# Run: powershell -File ops/make_logo_transparent.ps1

Add-Type -AssemblyName System.Drawing

$path = (Resolve-Path "assets/branding/app_logo.png").Path

# Load via a memory stream so the source file isn't locked while we save back.
$bytesIn = [System.IO.File]::ReadAllBytes($path)
$ms = New-Object System.IO.MemoryStream (, $bytesIn)
$src = [System.Drawing.Bitmap]::new($ms)
$w = $src.Width
$h = $src.Height

# Work on a guaranteed 32bpp ARGB copy.
$bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($src, 0, 0, $w, $h)
$g.Dispose()
$src.Dispose()
$ms.Dispose()

$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stride = $data.Stride
$len = $stride * $h
$buf = New-Object byte[] $len
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $len)

# Alpha key: dark bg (max channel <= floor) -> 0; bright logo -> 1; glow ramps.
$floor = 44.0
$span = 92.0
$minX = $w; $minY = $h; $maxX = -1; $maxY = -1

for ($y = 0; $y -lt $h; $y++) {
  $row = $y * $stride
  for ($x = 0; $x -lt $w; $x++) {
    $i = $row + $x * 4   # BGRA
    $b = $buf[$i]; $gr = $buf[$i + 1]; $r = $buf[$i + 2]
    $maxc = [Math]::Max($r, [Math]::Max($gr, $b))
    $a = ($maxc - $floor) / $span
    if ($a -lt 0) { $a = 0 } elseif ($a -gt 1) { $a = 1 }
    $buf[$i + 3] = [byte][Math]::Round($a * 255)
    if ($a -gt 0.12) {
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}

[System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $data.Scan0, $len)
$bmp.UnlockBits($data)

if ($maxX -lt 0) { Write-Error "No content found"; exit 1 }

# Square crop centered on the content bbox, with ~12% padding.
$cx = ($minX + $maxX) / 2.0
$cy = ($minY + $maxY) / 2.0
$side = [Math]::Max($maxX - $minX, $maxY - $minY)
$side = [int][Math]::Round($side * 1.12)
$left = [int][Math]::Round($cx - $side / 2.0)
$top = [int][Math]::Round($cy - $side / 2.0)
if ($left -lt 0) { $left = 0 }
if ($top -lt 0) { $top = 0 }
if (($left + $side) -gt $w) { $side = $w - $left }
if (($top + $side) -gt $h) { $side = $h - $top }

$cropRect = New-Object System.Drawing.Rectangle $left, $top, $side, $side
$cropped = $bmp.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bmp.Dispose()

$cropped.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$cropped.Dispose()

Write-Output "Wrote transparent + cropped logo: ${side}x${side} -> $path"
