# 
# Aktuális Fájl: Killer.ps1
# Bloatware Killer - Végrehajtó / Eltávolító modul
# Gyártóspecifikus bloatware elemek automatizált keresése, naplózása, kezelése, és törlése.
# Verzió v0.1.13
#

Function Write-Log {
    Param([string]$Message, [string]$Type = "INFO")
    $LogLine = "[$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Type] $Message"
    Write-Host $LogLine
    [System.IO.File]::AppendAllText($LogFile, $LogLine + [System.Environment]::NewLine)
}

Write-Log "Killer modul v0.1.13 elinditva."
Write-Host "-> Erőszakos háttértakarítás megkezdődött..." -ForegroundColor Cyan

# --- 1. HP SPECIFIKUS "NUKLEÁRIS" TÖRLÉSEK ---
foreach ($App in $ToKill) {
    
    # HP Documentation (Ez már bizonyítottan működik, de benne hagyjuk)
    if ($App.Name -eq "HP Documentation") {
        $DocCmd = "C:\Program Files\HP\Documentation\Doc_uninstall.cmd"
        if (Test-Path $DocCmd) {
            Write-Log "HP Documentation torlese a gyari CMD scripttel..."
            try {
                $Proc = Start-Process -FilePath $DocCmd -ArgumentList "/s" -WindowStyle Hidden -PassThru
                $Proc.WaitForExit()
            } catch { Write-Log "CMD Hiba: HP Documentation" "WARN" }
        }
        # Registry takarítás biztos, ami biztos
        Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\HP Documentation" -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\HP Documentation" -Force -Recurse -ErrorAction SilentlyContinue
    }

    # HP Connection Optimizer - A PROBLÉMÁS ELEM
    if ($App.Name -eq "HP Connection Optimizer") {
        Write-Log "HP Connection Optimizer: Többlépcsős, erőszakos eltávolítás indítása..."
        
        # Lépés 1: Szolgáltatás likvidálása
        Write-Host " [1/4] Szolgáltatás leállítása..." -ForegroundColor Yellow
        sc.exe stop "HPConnectionOptimizerService" | Out-Null
        sc.exe delete "HPConnectionOptimizerService" | Out-Null
        
        # Lépés 2: WMIC alapú eltávolítás (Ez néha okosabb, mint az msiexec)
        Write-Host " [2/4] WMIC uninstall kísérlet..." -ForegroundColor Yellow
        try {
            $WmicProc = Start-Process -FilePath "wmic.exe" -ArgumentList "product where ""name like 'HP Connection Optimizer'"" call uninstall /nointeractive" -PassThru -WindowStyle Hidden
            $WmicProc.WaitForExit()
        } catch { Write-Log "WMIC hiba, lépés tovább..." "WARN" }

        # Lépés 3: Registry kulcs "kitépése" (Hogy ne látszódjon telepítettnek)
        Write-Host " [3/4] Registry kulcsok kényszerített törlése..." -ForegroundColor Yellow
        # GUID alapú kulcs
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{6468C4A5-E47E-405F-B675-A70A70983EA6}" -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{6468C4A5-E47E-405F-B675-A70A70983EA6}" -Force -Recurse -ErrorAction SilentlyContinue
        # Név alapú keresés és törlés (ha más GUID-on lenne)
        Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.GetValue("DisplayName") -like "*HP Connection Optimizer*" } | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        # Lépés 4: Fizikai fájlok törlése a lemezről
        Write-Host " [4/4] Programkönyvtárak törlése..." -ForegroundColor Yellow
        $PathsToDelete = @(
            "C:\Program Files (x86)\HP\HP Connection Optimizer",
            "C:\Program Files\HP\HP Connection Optimizer",
            "C:\ProgramData\HP\HP Connection Optimizer"
        )
        foreach ($P in $PathsToDelete) {
            if (Test-Path $P) {
                Remove-Item -Path $P -Force -Recurse -ErrorAction SilentlyContinue
                Write-Log "Mappa törölve: $P"
            }
        }
        Write-Log "HP Connection Optimizer tisztítás kész."
    }
}

# --- 2. ÁLTALÁNOS WIN32 SZOFTVEREK ELTÁVOLÍTÁSA ---
$CurrentInstalledItems = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue

foreach ($App in $ToKill) {
    # A HP specifikusokat már elintéztük fent, átugorjuk őket
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
                    # EXE kezelés
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

    # IFEO tiltás
    if ($App.RegistryBlock) {
        $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($App.RegistryName).exe"
        if (-not (Test-Path $IfeoPath)) { New-Item -Path $IfeoPath -Force | Out-Null }
        Set-ItemProperty -Path $IfeoPath -Name "Debugger" -Value "cmd.exe /c exit" -Force
    }
}

$GarbagePaths = @(
    "C:\ProgramData\HP\TCO", "C:\Online Services", "C:\Users\Public\Desktop\TCO Certified.lnk",
    "C:\ProgramFiles\Dell\DigitalDelivery", "C:\ProgramData\Dell\SARemediation"
)
foreach ($Path in $GarbagePaths) {
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue
        Write-Log "Szemet mappa pucolva: $Path"
    }
}

# --- VÁRAKOZÁS ÉS ELLENŐRZÉS ---
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
        Write-Log "Sikeresen eltavolitva: $($App.Name)"
        $SuccessCount++
    } else {
        Write-Host " [SIKERTELEN] $($App.Name) meg mindig a registry-ben van!" -ForegroundColor Red
        Write-Log "Még mindig detektálható: $($App.Name)" "WARN"
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
