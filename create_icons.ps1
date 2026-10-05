Add-Type -AssemblyName System.Drawing

function Generate-AppIcon {
    param(
        [int]$width = 1024,
        [int]$height = 1024,
        [string]$outputPath = "assets/icon/app_icon_1024.png"
    )

    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $cx = [float]($width / 2.0)
    $cy = [float]($height / 2.0)
    $scale = [float]($width / 1024.0)

    # 1. Background Solid Dark Theme
    $rect = New-Object System.Drawing.RectangleF(0, 0, $width, $height)
    $cTop = [System.Drawing.Color]::FromArgb(255, 15, 23, 42)    # #0F172A
    $bgBrush = New-Object System.Drawing.SolidBrush($cTop)
    $g.FillRectangle($bgBrush, $rect)
    $bgBrush.Dispose()

    # Inner Background Radial Glow Circle
    $bgCircleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 30, 27, 75))
    $bgCircleR = [float](480.0 * $scale)
    $g.FillEllipse($bgCircleBrush, ($cx - $bgCircleR), ($cy - $bgCircleR), ($bgCircleR * 2), ($bgCircleR * 2))
    $bgCircleBrush.Dispose()

    # Outer decorative orbit ring
    $orbitR = [float](330.0 * $scale)
    $orbitPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(90, 56, 189, 248), [float](4.0 * $scale))
    $orbitPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
    $g.DrawEllipse($orbitPen, ($cx - $orbitR), ($cy - $orbitR), ($orbitR * 2), ($orbitR * 2))
    $orbitPen.Dispose()

    # 2. Camera Angles: 270 deg (Top), 30 deg (Bottom Right), 150 deg (Bottom Left)
    $angles = @(270.0, 30.0, 150.0)

    # Draw Laser Sightlines intersecting at center
    foreach ($a in $angles) {
        $rad = $a * [Math]::PI / 180.0
        $camX = [float]($cx + $orbitR * [Math]::Cos($rad))
        $camY = [float]($cy + $orbitR * [Math]::Sin($rad))

        # Outer Laser Glow
        $glowPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140, 14, 165, 233), [float](12.0 * $scale))
        $g.DrawLine($glowPen, $camX, $camY, $cx, $cy)
        $glowPen.Dispose()

        # Core Laser Beam
        $laserPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 56, 189, 248), [float](4.0 * $scale))
        $g.DrawLine($laserPen, $camX, $camY, $cx, $cy)
        $laserPen.Dispose()
    }

    # 3. Irregular Polygon at Center (Scaled DOWN so cameras do NOT overlap)
    $p1 = [System.Drawing.PointF]::new([float]($cx - 22.0 * $scale), [float]($cy - 30.0 * $scale))
    $p2 = [System.Drawing.PointF]::new([float]($cx + 18.0 * $scale), [float]($cy - 34.0 * $scale))
    $p3 = [System.Drawing.PointF]::new([float]($cx + 34.0 * $scale), [float]($cy - 6.0 * $scale))
    $p4 = [System.Drawing.PointF]::new([float]($cx + 26.0 * $scale), [float]($cy + 26.0 * $scale))
    $p5 = [System.Drawing.PointF]::new([float]($cx - 6.0 * $scale), [float]($cy + 36.0 * $scale))
    $p6 = [System.Drawing.PointF]::new([float]($cx - 30.0 * $scale), [float]($cy + 18.0 * $scale))
    $p7 = [System.Drawing.PointF]::new([float]($cx - 34.0 * $scale), [float]($cy - 8.0 * $scale))

    [System.Drawing.PointF[]]$polyPoints = @($p1, $p2, $p3, $p4, $p5, $p6, $p7)

    # Fill polygon with Cyan Solid Brush
    $polyBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 14, 165, 233))
    $g.FillPolygon($polyBrush, $polyPoints)
    $polyBrush.Dispose()

    # Draw facet wireframe lines inside polygon for 3D effect
    $wirePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 255, 255, 255), [float](2.5 * $scale))
    $g.DrawPolygon($wirePen, $polyPoints)
    foreach ($pt in $polyPoints) {
        $g.DrawLine($wirePen, $cx, $cy, $pt.X, $pt.Y)
    }
    $wirePen.Dispose()

    # Draw glowing nodes at polygon vertices
    $nodeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
    $nodeR = [float](4.5 * $scale)
    foreach ($pt in $polyPoints) {
        $g.FillEllipse($nodeBrush, [float]($pt.X - $nodeR), [float]($pt.Y - $nodeR), [float]($nodeR * 2), [float]($nodeR * 2))
    }
    # Center node
    $g.FillEllipse($nodeBrush, [float]($cx - $nodeR*1.2), [float]($cy - $nodeR*1.2), [float]($nodeR * 2.4), [float]($nodeR * 2.4))
    $nodeBrush.Dispose()

    # 4. Draw 3 MAGNIFIED Cameras (3x Larger) Pointing to Center
    foreach ($a in $angles) {
        $rad = $a * [Math]::PI / 180.0
        $camX = [float]($cx + $orbitR * [Math]::Cos($rad))
        $camY = [float]($cy + $orbitR * [Math]::Sin($rad))

        $state = $g.Save()
        $g.TranslateTransform($camX, $camY)
        $angleToCenter = [float]($a + 180.0)
        $g.RotateTransform($angleToCenter)

        # Magnified Camera Body (3x larger)
        $cw = [float](190.0 * $scale)
        $ch = [float](125.0 * $scale)

        $camBodyRect = New-Object System.Drawing.RectangleF([float](-$cw/2), [float](-$ch/2), $cw, $ch)
        $camBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 30, 41, 59))
        $g.FillRectangle($camBrush, $camBodyRect)
        $camBrush.Dispose()

        # Camera Outline
        $camPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 148, 163, 184), [float](5.0 * $scale))
        $g.DrawRectangle($camPen, $camBodyRect.X, $camBodyRect.Y, $camBodyRect.Width, $camBodyRect.Height)
        $camPen.Dispose()

        # Camera Lens Barrel
        $lensW = [float](55.0 * $scale)
        $lensH = [float](85.0 * $scale)
        $lensRect = New-Object System.Drawing.RectangleF([float]($cw/2), [float](-$lensH/2), $lensW, $lensH)
        $lensBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 15, 23, 42))
        $g.FillRectangle($lensBrush, $lensRect)
        $lensBrush.Dispose()

        # Lens Front Element (Cyan Glass Ring)
        $glassBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 56, 189, 248))
        $g.FillEllipse($glassBrush, [float]($cw/2 + $lensW - 14*$scale), [float](-$lensH/2 + 5*$scale), [float](22*$scale), [float]($lensH - 10*$scale))
        $glassBrush.Dispose()

        # Inner Lens Glass Aperture Circle
        $apertureBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 224, 242, 254))
        $g.FillEllipse($apertureBrush, [float]($cw/2 + $lensW - 8*$scale), [float](-12*$scale), [float](14*$scale), [float](24*$scale))
        $apertureBrush.Dispose()

        # Recording LED (Red Dot - Magnified)
        $ledBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 239, 68, 68))
        $ledSize = [float](22.0 * $scale)
        $g.FillEllipse($ledBrush, [float](-$cw/2 + 18*$scale), [float](-$ch/2 + 18*$scale), $ledSize, $ledSize)
        $ledBrush.Dispose()

        $g.Restore($state)
    }

    $g.Dispose()

    $dir = [System.IO.Path]::GetDirectoryName($outputPath)
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Generated icon: $outputPath ($width x $height)"
}

# Function to wrap PNG bytes into a valid Win32 ICO (3.00 format)
function Save-ValidWin32Ico {
    param(
        [string]$tempPngPath,
        [string]$icoOutputPath
    )

    $pngBytes = [System.IO.File]::ReadAllBytes($tempPngPath)
    $pngLength = $pngBytes.Length

    # 6 bytes ICONDIR + 16 bytes ICONDIRENTRY = 22 bytes header
    $icoHeader = [byte[]](
        0, 0,           # idReserved
        1, 0,           # idType (1 = ICO)
        1, 0,           # idCount (1 image)
        0,              # bWidth (0 = 256px)
        0,              # bHeight (0 = 256px)
        0,              # bColorCount
        0,              # bReserved
        1, 0,           # wPlanes
        32, 0,          # wBitCount (32 bpp)
        [byte]($pngLength -band 0xFF),
        [byte](($pngLength -shr 8) -band 0xFF),
        [byte](($pngLength -shr 16) -band 0xFF),
        [byte](($pngLength -shr 24) -band 0xFF), # dwBytesInRes
        22, 0, 0, 0     # dwImageOffset (22)
    )

    $dir = [System.IO.Path]::GetDirectoryName($icoOutputPath)
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $icoStream = New-Object System.IO.FileStream($icoOutputPath, [System.IO.FileMode]::Create)
    $icoStream.Write($icoHeader, 0, $icoHeader.Length)
    $icoStream.Write($pngBytes, 0, $pngBytes.Length)
    $icoStream.Close()
    Write-Host "Generated valid Win32 3.00 ICO icon: $icoOutputPath"
}

# Generate Primary App Store & Google Play Icons
Generate-AppIcon -width 1024 -height 1024 -outputPath "assets/icon/app_icon_1024.png"
Generate-AppIcon -width 512  -height 512  -outputPath "assets/icon/app_icon_512.png"

# Generate Android Mipmap Icons
$androidMipmaps = @{
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"    = 48
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"    = 72
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"   = 96
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"  = 144
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" = 192
}

foreach ($path in $androidMipmaps.Keys) {
    $size = $androidMipmaps[$path]
    Generate-AppIcon -width $size -height $size -outputPath $path
}

# Generate iOS AppIcons
$iosIcons = @{
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png"   = 20
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png"   = 40
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png"   = 60
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png"   = 29
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png"   = 58
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png"   = 87
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png"   = 40
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png"   = 80
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png"   = 120
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png"   = 120
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"   = 180
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png"   = 76
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png"   = 152
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png" = 167
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" = 1024
}

foreach ($path in $iosIcons.Keys) {
    $size = $iosIcons[$path]
    Generate-AppIcon -width $size -height $size -outputPath $path
}

# Generate Windows Launcher Icon (Valid Win32 3.00 ICO Format)
$tempWinPng = "assets/icon/temp_win_256.png"
Generate-AppIcon -width 256 -height 256 -outputPath $tempWinPng
Save-ValidWin32Ico -tempPngPath $tempWinPng -icoOutputPath "windows/runner/resources/app_icon.ico"
Remove-Item $tempWinPng -ErrorAction SilentlyContinue

Write-Host "All icons generated with valid Win32 3.00 ICO format successfully!"
