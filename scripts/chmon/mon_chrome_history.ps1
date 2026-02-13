# mon_chrome_history.ps1

$basePath = "C:\local\scripts\chmon"
$logPath = Join-Path $basePath "chrome_history.log"
$archivePath = Join-Path $basePath "archive"

# Ensure archive directory exists
if (-not (Test-Path $archivePath)) {
    New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
}

function ConvertTo-Hashtable {
    param([object]$obj)
    $hash = @{}
    foreach ($property in $obj.PSObject.Properties) {
        if ($property.Value -is [System.Management.Automation.PSCustomObject]) {
            $hash[$property.Name] = ConvertTo-Hashtable $property.Value
        } else {
            $hash[$property.Name] = $property.Value
        }
    }
    return $hash
}

# Load previous state
$stateFile = Join-Path $basePath "chmon_state.json"
if (Test-Path $stateFile) {
    $rawJson = Get-Content $stateFile -Raw | ConvertFrom-Json
    $lastStates = ConvertTo-Hashtable $rawJson
} else {
    $lastStates = @{}
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$historyFiles = Get-ChildItem -Path "$env:LOCALAPPDATA\Google\Chrome\User Data" -Recurse -Filter "History" -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch "\\Snapshots\\" -and
        $_.DirectoryName -notmatch "\\Snapshots(-|\\)\d{4}"
    }

foreach ($file in $historyFiles) {
    $profileName = Split-Path (Split-Path $file.FullName -Parent) -Leaf
    $lastWrite = $file.LastWriteTimeUtc.Ticks
    $fileKey = $file.FullName.Replace("\\", "/")
    $currentSize = $file.Length

    $hasChanged = $false
    if (-not $lastStates.ContainsKey($fileKey)) {
        $hasChanged = $true
    } elseif ($lastStates[$fileKey].lastWrite -ne $lastWrite) {
        $hasChanged = $true
    }

    if ($hasChanged) {
        # Update log
        $logEntry = "$timestamp`tCHANGED`t$($file.FullName)"
        Add-Content -Path $logPath -Value $logEntry

        # Archive decision
        $now = Get-Date
        $yearMonth = $now.ToString("yyyy-MM")
        $yearMonthDayHM = $now.ToString("yyyy-MM-dd-HHmm")

        $prevSize = if ($lastStates.ContainsKey($fileKey)) { $lastStates[$fileKey].size } else { 0 }
        $ext = ".sqlite"  # standard extension for SQLite

        $monthlyFile = Join-Path $archivePath "$profileName-History-$yearMonth$ext"

        if ($currentSize -lt $prevSize -and (Test-Path $monthlyFile)) {
            $preserveFile = Join-Path $archivePath "$profileName-History-$yearMonthDayHM$ext"
            Copy-Item -Path $monthlyFile -Destination $preserveFile -Force
        }

        Copy-Item -Path $file.FullName -Destination $monthlyFile -Force

        # Update state
        $lastStates[$fileKey] = @{ lastWrite = $lastWrite; size = $currentSize }
    }
}

# Save state
$lastStates | ConvertTo-Json | Set-Content -Path $stateFile -Force