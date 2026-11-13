param(
    [Parameter(Mandatory)]
    [string]$Source
)

$ErrorActionPreference = 'Stop'
$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$artPath = Join-Path $sourcePath 'art'
$map = Join-Path $sourcePath 'data/AMER2.MP'
if (!(Test-Path -LiteralPath (Join-Path $artPath 'terrain.png')) -or !(Test-Path -LiteralPath $map)) {
    throw 'Choose the folder containing the existing local v020 build, including its art and data folders.'
}
$localArt = Join-Path $PSScriptRoot 'game/art'
$localData = Join-Path $PSScriptRoot 'game/data'
New-Item -ItemType Directory -Force $localArt,$localData | Out-Null
Get-ChildItem -LiteralPath $artPath -File -Filter '*.png' | Copy-Item -Destination $localArt
Copy-Item -LiteralPath $map -Destination $localData
