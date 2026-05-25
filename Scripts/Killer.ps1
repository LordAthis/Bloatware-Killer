# 
# Aktuális Fájl: Killer.ps1
# Bloatware Killer - Végrehajtó / Eltávolító modul
# Gyártóspecifikus bloatware elemek automatizált keresése, naplózása, kezelése, és törlése.
# Verzió v0.1.12
#

Function Write-Log {
    Param([string]$Message, [string]$Type = "INFO")
    $LogLine = "[$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Type] $Message"
    Write-Host $LogLine
    [System.IO.File]::AppendAllText($LogFile, $LogLine + [System.Environment]::NewLine)
}

Write-Log "Killer modul v0.1.12 elinditva."
Write-Host "-> Erőszakos háttértakarítás megkezdődött..." -ForegroundColor Cyan

# --- 1. HP SPECIFIKUS CÉLZOTT TÖRLESEK (ÁTUGORVA A GYÁRI HIBÁS STRINGEKET) ---
foreach ($App in $ToKill) {
    if ($App.Name -eq "HP Documentation") {
        $DocCmd = "C:\Program Files\HP\Documentation\Doc_uninstall.cmd"
        if (Test-Path $DocCmd) {
            Write-Log "HP Documentation torlese a gyari CMD scripttel..."
            $Proc = Start-Process -FilePath $DocCmd -ArgumentList "/s" -WindowStyle Hidden -PassThru
            $Proc.WaitForExit()
        }
        # Ha a CMD ott hagyná a registry-t, manuálisan is kisöpörjük
        Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HP Documentation" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\HP Documentation" -Force -ErrorAction SilentlyContinue
    }

    if ($App.Name -eq "HP Connection Optimizer") {
        Write-Log "HP Connection Optimizer erőszakos leállítása és eltávolítása..."
        # Leállítjuk a szolgáltatását direkt parancssorból
        sc.exe stop "HPConnectionOptimizerService" | Out-Null
        sc.exe delete "HPConnectionOptimizerService" | Out-Null
        
        # InstallShield csendesített kényszerítése GUID alapján
        $Proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/X{6468C4A5-E47E-405F-B675-A70A70983EA6} /qn /norestart" -PassThru -ErrorAction SilentlyContinue
        if ($Proc) { $Proc.WaitForExit() }
    }
}

# --- 2. ÁLTALÁNOS WIN32 SZOFTVEREK ELTÁVOLÍTÁSA ---
$CurrentInstalledItems = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue

foreach ($App in $ToKill) {
    # Ha a fentiek már elintézték, ezt az általános kört átugorjuk
    if ($App.Name -eq "HP Documentation" -or $App.Name -eq "HP Connection Optimizer") { continue }

    $Match = $CurrentInstalledItems | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }
    if ($Match) {
        foreach ($Item in $Match) {
            $Unstring = $Item.UninstallString
            if ($Unstring) {
                Write-Log "Altalanos Win32 eltavolitasa: $($App.Name)"
                if ($Unstring -like "msiexec*") {
                    $CleanArgs = $Unstring -replace "msiexec.exe", "" -replace "/I", "/X"
                    $Args = "$($CleanArgs.Trim()) /qn /norestart"
                    try {
                        $Proc = [System.Diagnostics.Process]::Start("msiexec.exe", $Args)
                        $Proc.WaitForExit()
                    } catch { Write-Log "MSI Hiba: $($App.Name)" "WARN" }
                } else {
                    $CleanUnstring = $Unstring -replace '"', ''
                    if ($CleanUnstring -like "*.exe*") {
                        $ExePath = $CleanUnstring.Substring(0, $CleanUnstring.IndexOf(".exe") + 4)
                        try {
                            $Proc = [System.Diagnostics.Process]::Start($ExePath, "/S /silent /verysilent /qn /norestart")
                            $Proc.WaitForExit()
                        } catch { Write-Log "EXE Hiba: $($App.Name)" "WARN" }
                    }
                }
            }
        }
    }

    # IFEO tiltás (hogy ha a Windows Update visszatolná, se tudjon elindulni)
    if ($App.RegistryBlock) {
        $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($App.RegistryName).exe"
        if (-not (Test-Path $IfeoPath)) { New-Item -Path $IfeoPath -Force | Out-Null }
        Set-ItemProperty -Path $IfeoPath -Name "Debugger" -Value "cmd.exe /c exit" -Force
    }
}

# --- 3. VALÓDI REGISTRY ELLENŐRZÉS ÉS SUMMARY ---
Write-Log "Kényszerített várakozás a Registry frissülésére..."
[System.Threading.Thread]::Sleep(3000)

Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          TAKARITAS VEGEREDMENYE (SUMMARY)         " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$SuccessCount = 0
$FailCount = 0
# Újra lekérjük a nyers listát a lemezről ellenőrzésre!
$FinalCheck = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue

foreach ($App in $ToKill) {
    $CheckInstalled = $FinalCheck | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }
    
    if (-not $CheckInstalled) {
        Write-Host " [SIKERES]   $($App.Name) eltavolitva a gépből." -ForegroundColor Green
        Write-Log "Valoban sikeresen eltavolitva: $($App.Name)"
        $SuccessCount++
    } else {
        Write-Host " [SIKERTELEN] $($App.Name) meg mindig a registry-ben van!" -ForegroundColor Red
        Write-Log "Sikertelen erőszakos eltávolítás: $($App.Name)" "WARN"
        $FailCount++
    }
}

if ($Error.Count -gt 0) {
    foreach ($Err in $Error) {
        if ($Err.Exception -and $Err.InvocationInfo) {
            Write-Log "Rendszer Hiba: $($Err.Exception.Message) | Sor: $($Err.InvocationInfo.ScriptLineNumber)" "ERROR"
        }
    }
}

Write-Host "--------------------------------------------------"
Write-Log "Takaritasi statisztika -> Siker: $SuccessCount, Hiba: $FailCount"
