# Recolor the empty/low VIT heart icons so they read against the dark UI.
#
# Problem: the dark "unfilled" hearts use a #4A4A66 steel outline + #1C1C2A fill,
# which measure 1.95:1 / 1.01:1 against the card background (kCard #1C1C34) — below
# the WCAG 1.4.11 3:1 non-text floor, so they read as noise beside the bright value.
#
# Fix (idempotent): for every dark-outlined heart, remap the steel outline -> the
# app's muted token kMutedText #9494B8 and ramp the dark interior to transparent,
# preserving the red meter fill (partials), the anti-aliasing, and the dimensions.
# The all-red full heart and the lck-streak icons are untouched.
#
# Run from the repo root:  powershell -File ops\recolor_vitality_hearts.ps1

Add-Type -AssemblyName System.Drawing

# Target steel: kMutedText #9494B8.
$TR = 0x94; $TG = 0x94; $TB = 0xB8

function Lum([double]$r, [double]$g, [double]$b) {
  $f = {
    param($c)
    $c = $c / 255.0
    if ($c -le 0.03928) { $c / 12.92 } else { [math]::Pow(($c + 0.055) / 1.055, 2.4) }
  }
  0.2126 * (& $f $r) + 0.7152 * (& $f $g) + 0.0722 * (& $f $b)
}

# Luminance anchors from the source art: fill #1C1C2A -> transparent, outline #4A4A66 -> opaque steel.
$Lfill = Lum 0x1C 0x1C 0x2A
$Lout = Lum 0x4A 0x4A 0x66
$span = $Lout - $Lfill

$files = @(
  'vitality-heart-empty',
  'vitality-heart-20',
  'vitality-heart-40',
  'vitality-heart-60',
  'vitality-heart-80'
)

foreach ($name in $files) {
  $path = (Resolve-Path "assets\icons\radar\$name.png").Path
  $bmp = New-Object System.Drawing.Bitmap($path)
  $w = $bmp.Width; $h = $bmp.Height
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $stride = $data.Stride
  $bytes = New-Object byte[] ($stride * $h)
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)

  $changed = 0
  for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $stride
    for ($x = 0; $x -lt $w; $x++) {
      $i = $row + $x * 4            # BGRA order in Format32bppArgb
      $b = $bytes[$i]; $g = $bytes[$i + 1]; $r = $bytes[$i + 2]; $a = $bytes[$i + 3]
      if ($a -le 0) { continue }
      # Red meter fill / glow — leave untouched.
      if ($r -gt $b + 24) { continue }
      # Steel outline + dark fill (+ AA): ramp to transparent..opaque steel by luminance.
      $t = (Lum $r $g $b) - $Lfill
      $t = $t / $span
      if ($t -lt 0) { $t = 0 } elseif ($t -gt 1) { $t = 1 }
      $bytes[$i] = $TB
      $bytes[$i + 1] = $TG
      $bytes[$i + 2] = $TR
      $bytes[$i + 3] = [byte][math]::Round($a * $t)
      $changed++
    }
  }

  [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
  $bmp.UnlockBits($data)
  # Save to a temp file (GDI+ can't overwrite the file the Bitmap still holds open),
  # then dispose and move it over the original.
  $tmp = "$path.tmp"
  $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Move-Item -Force -LiteralPath $tmp -Destination $path
  "recolored $name ($w x $h, $changed px remapped)"
}
