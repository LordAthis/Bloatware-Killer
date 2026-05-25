# 
# Aktuális Fájl: Killer.ps1
# Bloatware Killer - Végrehajtó / Eltávolító modul
# Gyártóspecifikus bloatware elemek automatizált keresése, naplózása, kezelése, és törlése.
# Verzió v0.1.16
#

Function Write-Log {
    Param([string]$Message, [string]$Type = "INFO")
    $LogLine = "[$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Type] $Message"
    Write-Host $LogLine
    [System.IO.File]::AppendAllText($LogFile, $LogLine + [System.Environment]::NewLine)
}

# Explicit módon naplózzuk a fájl saját verzióját
Write-Log "Killer modul v0.1.16 elinditva."
Write-Host "-> Ellenorzott hattertakaritas megkezdodott..." -ForegroundColor Cyan

# --- 1. HP SPECIFIKUS ELLENŐRZÖTT ÉS CÉLZOTT TÖRLESEK ---
foreach ($App in $ToKill) {
    
    # --- HP Documentation törlése ---
    if ($App.Name -eq "HP Documentation") {
        $DocCmd = "C:\Program Files\HP\Documentation\Doc_uninstall.cmd"
        
        if (Test-Path $DocCmd) {
            Write-Log "HP Documentation: Gyari CMD script detektalva. Inditas..."
            try {
                $Proc = Start-Process -FilePath $DocCmd -ArgumentList "/s" -WindowStyle Hidden -PassThru
                $Proc.WaitForExit()
                Write-Log "HP Documentation: Gyari CMD script sikeresen lefutott."
            } catch { Write-Log "HP Documentation: Hiba a CMD futtatasa kozben!" "WARN" }
        }

        $RegDoc1 = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HP Documentation"
        $RegDoc2 = "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\HP Documentation"
        
        if (Test-Path $RegDoc1) { 
            Write-Log "HP Documentation: Registry kulcs detektalva ($RegDoc1). Torles..."
            Remove-Item -Path $RegDoc1 -Force -Recurse -ErrorAction SilentlyContinue 
        }
        if (Test-Path $RegDoc2) { 
            Write-Log "HP Documentation: Registry kulcs detektalva ($RegDoc2). Torles..."
            Remove-Item -Path $RegDoc2 -Force -Recurse -ErrorAction SilentlyContinue 
        }
    }

    # --- HP Connection Optimizer törlése ---
    if ($App.Name -eq "HP Connection Optimizer") {
        Write-Log "HP Connection Optimizer: Ellenorzott eltavolitas inditasa..."
        
        $ServiceCheck = Get-Service -Name "HPConnectionOptimizerService" -ErrorAction SilentlyContinue
        if ($ServiceCheck) {
            Write-Log "HP Connection Optimizer: Szolgaltatas detektalva. Leallitas es torles..."
            sc.exe stop "HPConnectionOptimizerService" | Out-Null
            sc.exe delete "HPConnectionOptimizerService" | Out-Null
        }
        
        $WmicCheck = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_Product -Filter "Name = 'HP Connection Optimizer'" -ErrorAction SilentlyContinue
        if ($WmicCheck) {
            Write-Log "HP Connection Optimizer: WMI termek detektalva. WMIC uninstall inditasa..."
            try {
                $WmicProc = Start-Process -FilePath "wmic.exe" -ArgumentList "product where ""name like 'HP Connection Optimizer'"" call uninstall /nointeractive" -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
                if ($WmicProc) { $WmicProc.WaitForExit() }
                Write-Log "HP Connection Optimizer: WMIC uninstall lefutott."
            } catch { Write-Log "HP Connection Optimizer: WMIC hiba!" "WARN" }
        }

        $RegOpt1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{6468C4A5-E47E-405F-B675-A70A70983EA6}"
        $RegOpt2 = "HKLM:\SOFTWARE\Wow6432Node\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{6468C4A5-E47E-405F-B675-A70A70983EA6}"
        
        if (Test-Path $RegOpt1) { 
            Write-Log "HP Connection Optimizer: GUID Registry kulcs detektalva ($RegOpt1). Torles..."
            Remove-Item -Path $RegOpt1 -Force -Recurse -ErrorAction SilentlyContinue 
        }
        if (Test-Path $RegOpt2) { 
            Write-Log "HP Connection Optimizer: GUID Registry kulcs detektalva ($RegOpt2). Torles..."
            Remove-Item -Path $RegOpt2 -Force -Recurse -ErrorAction SilentlyContinue 
        }
        
        $LegacyKeys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -Recurse -ErrorAction SilentlyContinue | 
                      Where-Object { $_.GetValue("DisplayName") -like "*HP Connection Optimizer*" }
        if ($LegacyKeys) {
            Write-Log "HP Connection Optimizer: Maradvany nev alapu kulcsok torlese..."
            $LegacyKeys | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }

        $PathsToDelete = @(
            "C:\Program Files (x86)\HP\HP Connection Optimizer",
            "C:\Program Files\HP\HP Connection Optimizer",
            "C:\ProgramData\HP\HP Connection Optimizer"
        )
        foreach ($P in $PathsToDelete) {
            if (Test-Path $P) {
                Write-Log "HP Connection Optimizer: Fizikai mappa detektalva ($P). Torles..."
                Remove-Item -Path $P -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        Write-Log "HP Connection Optimizer ellenorzott tisztitasa befejezodott."
    }
}

# --- 2. ÁLTALÁNOS WIN32 SZOFTVEREK ELLENŐRZÖTT ELTÁVOLÍTÁSA ---
$CurrentInstalledItems = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue

foreach ($App in $ToKill) {
    if ($App.Name -eq "HP Documentation" -or $App.Name -eq "HP Connection Optimizer") { continue }

    $Match = $CurrentInstalledItems | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }
    if ($Match) {
        foreach ($Item in $Match) {
            $Unstring = $Item.UninstallString
            if ($Unstring) {
                Write-Log "Win32 Szoftver detektalva: $($App.Name). Eltavolitas inditasa..."
                
                if ($Unstring -like "msiexec*") {
                    $CleanArgs = $Unstring -replace "msiexec.exe", "" -replace "/I", "/X"
                    $Args = "$($CleanArgs.Trim()) /qn /norestart"
                    try {
                        $Proc = [System.Diagnostics.Process]::Start("msiexec.exe", $Args)
                        $Proc.WaitForExit()
                        Write-Log "MSI alapu szoftver eltavolitasa kesz: $($App.Name)"
                    } catch { Write-Log "MSI Hiba történt ennel: $($App.Name)" "WARN" }
                } else {
                    $CleanUnstring = $Unstring -replace '"', ''
                    if ($CleanUnstring -like "*.exe*") {
                        $ExePath = $CleanUnstring.Substring(0, $CleanUnstring.IndexOf(".exe") + 4)
                        try {
                            $Proc = [System.Diagnostics.Process]::Start($ExePath, "/S /silent /verysilent /qn /norestart")
                            $Proc.WaitForExit()
                            Write-Log "EXE alapu szoftver eltavolitasa kesz: $($App.Name)"
                        } catch { Write-Log "EXE Hiba történt ennel: $($App.Name)" "WARN" }
                    }
                }
            }
        }
    }

    if ($App.RegistryBlock) {
        $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($App.RegistryName).exe"
        if (-not (Test-Path $IfeoPath)) { 
            Write-Log "IFEO Vedelem: Tiltas alkalmazasa a szoftverhez: $($App.Name)"
            New-Item -Path $IfeoPath -Force | Out-Null 
            Set-ItemProperty -Path $IfeoPath -Name "Debugger" -Value "cmd.exe /c exit" -Force
        }
    }
}

# --- 3. PROMO / REKLÁMMAPPÁK ELLENŐRZÖTT TÖRLÉSE ---
$GarbagePaths = @(
    "C:\ProgramData\HP\TCO", "C:\Online Services", "C:\Users\Public\Desktop\TCO Certified.lnk",
    "C:\ProgramFiles\Dell\DigitalDelivery", "C:\ProgramData\Dell\SARemediation"
)
foreach ($Path in $GarbagePaths) {
    if (Test-Path $Path) {
        Write-Log "Reklam/Szemét maradvany detektalva ($Path). Pucolas..."
        Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# --- VÁRAKOZÁS ÉS MEGERŐSÍTETT ELLENŐRZÉS ---
Write-Log "Varakozas a registry frissulesere..."
[System.Threading.Thread]::Sleep(3000)

Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          TAKARITAS VEGEREDMENYE (SUMMARY)         " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$SuccessCount = 0
$FailCount = 0
$FinalCheck = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue

foreach ($App in $ToKill) {
    $CheckInstalled = $FinalCheck | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }
    
    if (-not $CheckInstalled) {
        Write-Host " [SIKERES]   $($App.Name) eltavolitva." -ForegroundColor Green
        Write-Log "Vegleges ellenorzes -> SIKERES: $($App.Name) mar nincs a gepen."
        $SuccessCount++
    } else {
        Write-Host " [SIKERTELEN] $($App.Name) meg mindig a registry-ben van!" -ForegroundColor Red
        Write-Log "Vegleges ellenorzes -> SIKERTELEN: $($App.Name) a rendszerben maradt!" "WARN"
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
