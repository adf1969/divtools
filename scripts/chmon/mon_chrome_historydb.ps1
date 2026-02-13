# mon_chrome_historydb.ps1

param(
    [string]$p,
    [switch]$q,                      # Quiet mode: suppress debug output
    [int]$days = 14,                # Number of days to look back
    [string]$PushoverToken = "aim9smm4sq7gi3oogf41srxoi8bgie",  # Pushover application token
    [string]$PushoverUser  = "u6fbgr6p6nzp467d9orteuiohoqanm"   # Pushover user key
)

# Quiet flag
$Quiet = $q.IsPresent

# Logging function
function Log {
    param([string]$Message)
    if (-not $Quiet) { Write-Host $Message }
}

# Pushover notification function
function Send-PushoverNotification {
    param([string]$Message)
    if ([string]::IsNullOrWhiteSpace($PushoverToken) -or [string]::IsNullOrWhiteSpace($PushoverUser)) { return }
    $body = @{ token = $PushoverToken; user = $PushoverUser; message = $Message; title = "Chrome History Monitor" }
    try { Invoke-RestMethod -Uri "https://api.pushover.net/1/messages.json" -Method Post -Body $body }
    catch { Log "Failed to send Pushover notification: $_" }
}

# Paths
$basePath        = "C:\local\scripts\chmon"
$sqlitePath      = "C:\PORTABLE\sqlite\sqlite3.exe"
$archiveDbPath   = Join-Path $basePath "archivedb"
$archiveFilePath = Join-Path $basePath "archive"

# Ensure directories exist
foreach ($path in @($archiveDbPath, $archiveFilePath)) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

# Profile normalization
function Get-NormalizedProfileName {
    param([string]$profileName)
    if ([string]::IsNullOrWhiteSpace($profileName)) { return "" }
    $n = $profileName.Trim().ToLower()
    if ($n -eq "default") { return "Default" }
    elseif ($n -match '^[1-9][0-9]*$') { return "Profile $n" }
    return $profileName.Trim()
}

# Load previous state (for monthly archive)
$stateFile  = Join-Path $basePath "chmon_state.json"
$lastStates = @{}
if (Test-Path $stateFile) {
    try { $lastStates = ConvertFrom-Json (Get-Content $stateFile -Raw) } catch { $lastStates = @{} }
}

# Determine profile filtering
$filterAll = [string]::IsNullOrWhiteSpace($p)
if ($filterAll) { Log "Processing all Chrome profiles" } else { $profileFilter = Get-NormalizedProfileName -profileName $p; Log "Filtering for profile: $profileFilter" }

# Locate Chrome History files
$historyFiles = Get-ChildItem -Path "$env:LOCALAPPDATA\Google\Chrome\User Data" -Recurse -Filter History -File -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -notmatch '\\Snapshots' }

foreach ($file in $historyFiles) {
    $leaf        = Split-Path $file.DirectoryName -Leaf
    $profileName = Get-NormalizedProfileName -profileName $leaf
    if (-not $filterAll -and $profileName -ne $profileFilter) { continue }

    Log "`n--- Processing profile: $profileName ---"
    # Prepare paths
    $historyWrite = $file.LastWriteTimeUtc
    $now          = Get-Date
    $yearMonth    = $now.ToString('yyyy-MM')
    $timeTag      = $now.ToString('yyyy-MM-dd-HHmmss')
    $monthlyFile  = Join-Path $archiveFilePath "$profileName-History-$yearMonth.sqlite"
    $preserve     = Join-Path $archiveFilePath "$profileName-History-$timeTag.sqlite"
    $jsonFile     = Join-Path $archiveDbPath   "$profileName-HistoryDb.json"
    $csvReport    = Join-Path $archiveDbPath   "$profileName-HistoryDb-Deleted.csv"

    # Skip if JSON up-to-date
    if (Test-Path $jsonFile) {
        $jsonTime = (Get-Item $jsonFile).LastWriteTimeUtc
        if ($jsonTime -ge $historyWrite) {
            Log "JSON archive is current (modified $jsonTime), skipping."
            if (-not (Test-Path $monthlyFile)) { Log "Monthly archive missing, copying."; Copy-Item $file.FullName $monthlyFile -Force }
            continue
        }
    }

    # Compute WebKit threshold for -days
    $cutoff    = [datetime]::UtcNow.AddDays(-$days)
    $epoch     = [datetime]'1601-01-01T00:00:00Z'
    $threshold = [math]::Floor(($cutoff - $epoch).TotalSeconds * 1000000)
    Log "Filtering visits newer than $cutoff (webkit > $threshold)"

    # Extract visits within window
    $copyDb  = [IO.Path]::GetTempFileName() + '.sqlite'
    Copy-Item $file.FullName $copyDb -Force
    $tempCsv = [IO.Path]::GetTempFileName()
    & $sqlitePath $copyDb ".mode csv" ".headers on" "SELECT v.id AS visit_id, u.url, u.title, u.visit_count, u.last_visit_time, v.visit_time, v.visit_duration FROM urls u LEFT JOIN visits v ON u.id=v.url WHERE v.visit_time > $threshold;" > $tempCsv
    $currentData = Import-Csv $tempCsv
    Remove-Item $copyDb, $tempCsv -Force

    # Build current visits map
    $currentVisits = @{}
    foreach ($r in $currentData) {
        $vid = [int]$r.visit_id
        if ($vid -and -not $currentVisits.ContainsKey($vid)) {
            $currentVisits[$vid] = [PSCustomObject]@{
                visit_id       = $vid; url = $r.url; title = $r.title;
                visit_count    = [int]$r.visit_count; last_visit_time = $r.last_visit_time;
                visit_time     = $r.visit_time; visit_duration = $r.visit_duration; deleted = $false
            }
        }
    }

    # Load or init archive JSON
    $archiveVisits = @{}
    $jsonMiss     = -not (Test-Path $jsonFile)
    if ($jsonMiss) { Log "Initializing new visit archive" } else {
        $old = ConvertFrom-Json (Get-Content $jsonFile -Raw)
        Log "Loaded archive with $($old.Count) visits"
        foreach ($e in $old) { $archiveVisits[[int]$e.visit_id] = $e }
    }

        # Detect deletions for visits within the time window
    $deletedList = @()
    foreach ($vid in $archiveVisits.Keys) {
        $ent = $archiveVisits[$vid]
        # Only consider visits newer than threshold
        if ([int64]$ent.visit_time -le $threshold) { continue }
        if (-not $currentVisits.ContainsKey($vid) -and -not $ent.deleted) {
            $ent.deleted = $true
            Log "Visit removed: v.id=$vid url=$($ent.url)"
            $deletedList += [PSCustomObject]@{
                visit_id       = $vid
                url            = $ent.url
                title          = $ent.title
                visit_time     = $ent.visit_time
                visit_duration = $ent.visit_duration
            }
        }
    }

    # Merge new visits
    foreach ($vid in $currentVisits.Keys) {
        if (-not $archiveVisits.ContainsKey($vid)) { $archiveVisits[$vid] = $currentVisits[$vid] }
    }

    # Export deletion report
    if ($deletedList.Count -gt 0) {
        Log "Appending $($deletedList.Count) deletions to CSV"
        if (-not (Test-Path $csvReport)) {
            $deletedList | Export-Csv $csvReport -NoTypeInformation -Force
        } else {
            $exist = Import-Csv $csvReport; $toApp = @()
            foreach ($d in $deletedList) { if (-not ($exist | Where-Object { $_.visit_id -eq $d.visit_id })) { $toApp += $d } }
            if ($toApp.Count -gt 0) { $toApp | Export-Csv $csvReport -NoTypeInformation -Append }
        }
        # Build Pushover notification
        $pref  = Join-Path $file.DirectoryName 'Preferences'; $email = ''
        if (Test-Path $pref) {
            try { $pr = Get-Content $pref -Raw | ConvertFrom-Json } catch {}
            if ($pr.account_info -and $pr.account_info.Count -gt 0) { $email = $pr.account_info[0].email }
        }
        $urls = ($deletedList | Select-Object -First 5 | ForEach-Object { $_.url }) -join ', '
        if ($deletedList.Count -gt 5) { $urls += ", ...and $($deletedList.Count - 5) more" }
        $msg = "Profile '$profileName'"
        if ($email) { $msg += " ($email)" }
        $msg += " had $($deletedList.Count) deletions: $urls"
        Send-PushoverNotification $msg
    } else { Log "No visit deletions detected" }

    # Save archive JSON
    Log "Saving visit archive to $jsonFile"
    $archiveVisits.Values | ConvertTo-Json -Depth 5 | Set-Content $jsonFile -Force

    # Monthly SQLite archive logic
    if ($jsonMiss -or $deletedList.Count -eq 0) {
        Log "Updating monthly archive"
        Copy-Item $file.FullName $monthlyFile -Force
    } else {
        if (Test-Path $monthlyFile) { Log "Preserving monthly archive to $preserve"; Copy-Item $monthlyFile $preserve -Force }
        Log "Overwriting monthly after deletions"
        Copy-Item $file.FullName $monthlyFile -Force
    }

    Log "Archive updated."
}

# Persist state file
if ($lastStates.Keys.Count -gt 0) {
    Log "Saving state to $stateFile"
    $lastStates | ConvertTo-Json | Set-Content $stateFile -Force
    Log "Done."
}
