# 
# Aktuális Fájl: Killer.ps1
# Bloatware Killer - Végrehajtó / Eltávolító modul
# Gyártóspecifikus bloatware elemek automatizált keresése, naplózása, kezelése, és törlése.
# Verzió v0.1.11
#

Function Write-Log {
    Param([string]$Message, [string]$Type = "INFO")
    $LogLine = "[$([System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$Type] $Message"
    Write-Host $LogLine
    [System.IO.File]::AppendAllText($LogFile, $LogLine + [System.Environment]::NewLine)
}

Write-Log "Killer modul v0.1.11 elinditva."
Write-Host "-> Takaritas megkezdodott..." -ForegroundColor Cyan

foreach ($App in $ToKill) {
    if ($App.RegistryName -eq "HPSmart" -or $App.RegistryName -eq "HPJumpstart" -or $App.RegistryName -or "DellSmartByte" -or $App.RegistryName -eq "LenovoNow") {
        Write-Log "UWP eltavolitas: $($App.Name)"
        Write-Host "[-] UWP eltavolitas: $($App.Name)" -ForegroundColor Yellow
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$($App.RegistryName)*" } | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$($App.RegistryName)*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
}

$CurrentInstalledItems = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue

foreach ($App in $ToKill) {
    $ServiceKeywords = @("HP", "Wolf", "SureClick", "Analytics", "Dell", "SupportAssist", "Lenovo", "Vantage", "ImController")
    foreach ($Keyword in $ServiceKeywords) {
        if ($App.Name -like "*$Keyword*" -or $App.RegistryName -like "*$Keyword*") {
            $Services = Get-Service | Where-Object { $_.DisplayName -like "*$Keyword*" -or $_.Name -like "*$Keyword*" }
            foreach ($Service in $Services) {
                if ($Service.Status -eq "Running") {
                    Write-Log "Szolgaltatas leallitas: $($Service.Name)"
                    Stop-Service -Name $Service.Name -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $Service.Name -StartupType Disabled -ErrorAction SilentlyContinue
                }
            }
        }
    }

    $Match = $CurrentInstalledItems | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }
    if ($Match) {
        foreach ($Item in $Match) {
            $Unstring = $Item.UninstallString
            if ($Unstring) {
                Write-Log "Win32 eltavolitas inditasa: $($App.Name)"
                Write-Host "[-] Win32 eltavolitas folyamatban: $($App.Name)..." -ForegroundColor Yellow
                
                # JAVÍTVA: Az msiexec argumentum-összefűzés tiszta és hibátlan lett
                if ($Unstring -like "msiexec*") {
                    $CleanArgs = $Unstring -replace "msiexec.exe", "" -replace "/I", "/X"
                    $Args = "$($CleanArgs.Trim()) /qn /norestart"
                    try {
                        $Proc = [System.Diagnostics.Process]::Start("msiexec.exe", $Args)
                        # BIZTOSÍTVA: Kötelezően megvárjuk a háttérfolyamat végét!
                        $Proc.WaitForExit()
                    } catch { Write-Log "MSI Hiba: $($App.Name)" "WARN" }
                } else {
                    $CleanUnstring = $Unstring -replace '"', ''
                    if ($CleanUnstring -like "*.exe*") {
                        $ExePath = $CleanUnstring.Substring(0, $CleanUnstring.IndexOf(".exe") + 4)
                        $Args = "/S /silent /verysilent /qn /norestart"
                        try {
                            $Proc = [System.Diagnostics.Process]::Start($ExePath, $Args)
                            # BIZTOSÍTVA: Kötelezően megvárjuk az EXE uninstaller lefutását!
                            $Proc.WaitForExit()
                        } catch { Write-Log "EXE Hiba: $($App.Name)" "WARN" }
                    }
                }
            }
        }
    }

    if ($App.RegistryBlock) {
        Write-Log "IFEO tiltas beallitasa: $($App.Name)"
        Write-Host "[*] Vedelem (IFEO) aktivalasa: $($App.Name)" -ForegroundColor Blue
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

# JAVÍTVA: Adunk a rendszernek 3 másodpercet, hogy a lemezműveletek és a registry frissüljenek
Write-Log "Varakozas a registry frissulesere a kiertekeles elott..."
[System.Threading.Thread]::Sleep(3000)

# --- SUMMARY (ÖSSZEGZÉS) VALÓS IDEJŰ LEKÉRDEZÉSSEL ---
Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          TAKARITAS VEGEREDMENYE (SUMMARY)         " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$SuccessCount = 0
$FailCount = 0
# Valódi, friss lekérdezés a lemezről a lefutás után
$FinalCheck = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue

foreach ($App in $ToKill) {
    $CheckInstalled = $FinalCheck | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }
    if (-not $CheckInstalled) {
        Write-Host " [SIKERES]   $($App.Name) eltavolitva." -ForegroundColor Green
        Write-Log "Sikeresen eltavolitva: $($App.Name)"
        $SuccessCount++
    } else {
        Write-Host " [SIKERTELEN] $($App.Name) a rendszerben maradt." -ForegroundColor Red
        Write-Log "Sikertelen tavolitas: $($App.Name)" "WARN"
        $FailCount++
    }
}

if ($Error.Count -gt 0) {
    Write-Log "A futas soran keletkezett rendszerhibak mentese..." "WARN"
    foreach ($Err in $Error) {
        if ($Err.Exception -and $Err.InvocationInfo) {
            Write-Log "Konzol Hiba: $($Err.Exception.Message) | Hely: $($Err.InvocationInfo.ScriptLineNumber). sor" "ERROR"
        }
    }
}

Write-Host "--------------------------------------------------"
Write-Log "Takaritasi statisztika -> Siker: $SuccessCount, Hiba: $FailCount"
