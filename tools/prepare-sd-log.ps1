param(
	[Parameter(Mandatory = $true)]
	[ValidatePattern('^[A-Za-z]:?$')]
	[string]$Drive
)

$ErrorActionPreference = 'Stop'
$driveLetter = $Drive.TrimEnd(':').ToUpperInvariant()
$volume = Get-Volume -DriveLetter $driveLetter
if ($volume.FileSystem -ne 'FAT32' -or $volume.FileSystemLabel -notin @('SCORPION', 'SCORPION_BOOT')) {
	throw "Expected the SCORPION FAT32 volume; found label '$($volume.FileSystemLabel)' / filesystem '$($volume.FileSystem)'."
}

$logPath = "${driveLetter}:\XNU.LOG"
$requiredBytes = 4198400 # 4 KiB header plus 4 MiB circular log
if (Test-Path -LiteralPath $logPath) {
	$existing = Get-Item -LiteralPath $logPath
	if ($existing.Length -ne $requiredBytes) {
		throw "Refusing to resize existing $logPath ($($existing.Length) bytes). Move it aside and rerun this script."
	}
	Write-Host "$logPath already has the required $requiredBytes-byte allocation."
	exit 0
}

$stream = [System.IO.File]::Open($logPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
try {
	$stream.SetLength($requiredBytes)
	$zeroChunk = New-Object byte[] (64 * 1024)
	$remaining = $requiredBytes
	while ($remaining -gt 0) {
		$writeSize = [Math]::Min($zeroChunk.Length, $remaining)
		$stream.Write($zeroChunk, 0, $writeSize)
		$remaining -= $writeSize
	}
	$stream.Flush($true)
}
finally {
	$stream.Dispose()
}
Write-Host "Created $logPath ($requiredBytes bytes). Keep this file on the FAT volume for XNU logging."
