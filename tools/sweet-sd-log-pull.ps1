param(
	[Parameter(Mandatory = $true)]
	[ValidatePattern('^[A-Za-z]:?$')]
	[string]$Drive,
	[string]$OutFile = '.\logs\x670-boot.txt'
)

$ErrorActionPreference = 'Stop'
$driveLetter = $Drive.TrimEnd(':').ToUpperInvariant()
$volume = Get-Volume -DriveLetter $driveLetter
if ($volume.FileSystem -ne 'FAT32' -or $volume.FileSystemLabel -notin @('SCORPION', 'SCORPION_BOOT')) {
	throw "Expected the SCORPION FAT32 volume; found label '$($volume.FileSystemLabel)' / filesystem '$($volume.FileSystem)'."
}

$logPath = "${driveLetter}:\XNU.LOG"
if (-not (Test-Path -LiteralPath $logPath)) {
	throw "Log file not found: $logPath"
}
$outDir = Split-Path -Parent $OutFile
if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$python = Get-Command python -ErrorAction Stop
& $python.Source (Join-Path $PSScriptRoot 'sweet-log.py') $logPath $OutFile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Decoded $logPath to $OutFile"
