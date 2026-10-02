# One-shot setup: rename the Chinese-named cursors to English and convert the
# three we need (pointer / move / cross) to PNG, because .cur is NOT a texture
# format Godot can import.
#
# All ASCII on purpose -- Windows PowerShell 5.1 would read a BOM-less UTF-8
# script as ANSI and mangle the Chinese literals, so the name table lives in
# _cursor_names.txt and is decoded explicitly as UTF-8.
#
# Usage:  & 'D:\WorkSpace\mine-sweeper\_cursors_setup.ps1'
# Idempotent: already-renamed files are reported as MISS and skipped.

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$root     = 'D:\WorkSpace\mine-sweeper'
$src      = Join-Path $root 'Asset\Lightech Editor Cursor'
$out      = Join-Path $root 'Asset\cursors'
$listPath = Join-Path $root '_cursor_names.txt'
New-Item -ItemType Directory -Force -Path $out | Out-Null

# ---- name table (explicit UTF-8) ----
$pairs = @()
$lines = [System.IO.File]::ReadAllLines($listPath, [System.Text.Encoding]::UTF8)
foreach ($ln in $lines) {
	$t = $ln.Trim()
	if ($t -eq '' -or $t.StartsWith('#')) { continue }
	$i = $t.IndexOf('=')
	if ($i -lt 1) { continue }
	$pairs += , @($t.Substring(0, $i), $t.Substring($i + 1))
}

Write-Output '=== 1) rename to English ==='
$missing = 0
foreach ($p in $pairs) {
	$from = Join-Path $src $p[0]
	if (Test-Path -LiteralPath $from) {
		Rename-Item -LiteralPath $from -NewName $p[1]
		Write-Output ('  OK   ' + $p[1])
	} else {
		$missing++
		Write-Output ('  MISS ' + $p[1])
	}
}
if ($missing -gt 0) {
	Write-Output '  --- actual folder content ---'
	Get-ChildItem -LiteralPath $src -File | ForEach-Object {
		Write-Output ('    {0}   {1} bytes' -f $_.Name, $_.Length)
	}
}

Write-Output ''
Write-Output '=== 2) sizes + hotspots inside each .cur ==='
function Show-CurEntries([string]$file) {
	$path = Join-Path $src $file
	if (-not (Test-Path -LiteralPath $path)) { Write-Output ('  MISS ' + $file); return }
	$bytes = [System.IO.File]::ReadAllBytes($path)
	$count = [BitConverter]::ToUInt16($bytes, 4)
	Write-Output ('  {0}  ({1} images)' -f $file, $count)
	for ($i = 0; $i -lt $count; $i++) {
		$o = 6 + $i * 16
		$w = [int]$bytes[$o]
		$h = [int]$bytes[$o + 1]
		if ($w -eq 0) { $w = 256 }
		if ($h -eq 0) { $h = 256 }
		$hx = [BitConverter]::ToUInt16($bytes, $o + 4)
		$hy = [BitConverter]::ToUInt16($bytes, $o + 6)
		Write-Output ('      {0}x{1}  hotspot=({2},{3})' -f $w, $h, $hx, $hy)
	}
}
foreach ($f in @('pointer.cur', 'move.cur', 'cross.cur')) { Show-CurEntries $f }

Write-Output ''
Write-Output '=== 3) convert to PNG ==='
function Convert-Cur([string]$file, [string]$pngName) {
	$curPath = Join-Path $src $file
	if (-not (Test-Path -LiteralPath $curPath)) { Write-Output ('  MISS ' + $file); return }
	# System.Drawing.Icon refuses .cur: its header check only accepts type==1 (ICO),
	# while a cursor is type==2 (CUR) -- hence
	# "Argument 'picture' must be a picture that can be used as a Icon."
	# The pixel payload is identical, so patch the type field in memory only.
	$bytes = [System.IO.File]::ReadAllBytes($curPath)
	$bytes[2] = [byte]1
	$ms = New-Object System.IO.MemoryStream(, $bytes)
	$icon = New-Object System.Drawing.Icon($ms)
	$bmp  = $icon.ToBitmap()
	$pngPath = Join-Path $out $pngName
	$bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
	Write-Output ('  {0} -> {1}   {2}x{3}' -f $file, $pngName, $bmp.Width, $bmp.Height)
	$bmp.Dispose()
	$icon.Dispose()
	$ms.Dispose()
}
Convert-Cur 'pointer.cur' 'pointer.png'
Convert-Cur 'move.cur'    'move.png'
Convert-Cur 'cross.cur'   'cross.png'

Write-Output ''
Write-Output '=== done ==='
Get-ChildItem -LiteralPath $out -File | ForEach-Object {
	Write-Output ('  {0}   {1} bytes' -f $_.FullName, $_.Length)
}
