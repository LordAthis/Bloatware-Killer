#
# Bloatware Killer - Vegrehajto / Eltavolito modul (.NET alapon)
# Verzio 0.1.2
#


Write-Log "Killer modul elinditva. Takaritas megkezdodott..."
Clear-Host
Write-Host "-> Takaritas megkezdodott..." -ForegroundColor Cyan

foreach ($App in $ToKill) {
    if ($App.RegistryName -eq "HPSmart" -or $App.RegistryName -eq "HPJumpstart" -or $App.RegistryName -eq "DellSmartByte" -or $App.RegistryName -eq "LenovoNow") {
        Write-Log "UWP Alkalmazas eltavolitasa: $($App.Name)"
        Write-Host "[-] UWP alkalmazas eltavolitasa: $($App.Name)" -ForegroundColor Yellow
        Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*$($App.RegistryName)*" } | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$($App.RegistryName)*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
}

$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$InstalledItems = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue

foreach ($App in $ToKill) {
    $ServiceKeywords = @("HP", "Wolf", "SureClick", "Analytics", "Dell", "SupportAssist", "Lenovo", "Vantage", "ImController")
    foreach ($Keyword in $ServiceKeywords) {
        if ($App.Name -like "*$Keyword*" -or $App.RegistryName -like "*$Keyword*") {
            $Services = Get-Service | Where-Object { $_.DisplayName -like "*$Keyword*" -or $_.Name -like "*$Keyword*" }
            foreach ($Service in $Services) {
                if ($Service.Status -eq "Running") {
                    Write-Log "Szolgaltatas leallitasa: $($Service.Name)"
                    Stop-Service -Name $Service.Name -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $Service.Name -StartupType Disabled -ErrorAction SilentlyContinue
                }
            }
        }
    }

    $Match = $InstalledItems | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }
    
    if ($Match) {
        foreach ($Item in $Match) {
            $Unstring = $Item.UninstallString
            if ($Unstring) {
                Write-Log "Szoftver eltavolitasa folyamatban: $($App.Name)"
                Write-Host "[-] Win32 szoftver eltavolitasa: $($App.Name)" -ForegroundColor Yellow
                
                if ($Unstring -like "msiexec*") {
                    $Args = $Unstring -replace "msiexec.exe", "" -replace "/I", "/X"
                    $Args += " /qn /norestart"
                    try {
                        $Proc = [System.Diagnostics.Process]::Start("msiexec.exe", $Args.Trim())
                        $Proc.WaitForExit()
                    } catch {
                        Write-Log "MSI Uninstaller hiba ennel: $($App.Name)" "WARN"
                    }
                } else {
                    $CleanUnstring = $Unstring -replace '"', ''
                    if ($CleanUnstring -like "*.exe*") {
                        $ExePath = $CleanUnstring.Substring(0, $CleanUnstring.IndexOf(".exe") + 4)
                        $Args = "/S /silent /verysilent /qn /norestart"
                        try {
                            $Proc = [System.Diagnostics.Process]::Start($ExePath, $Args)
                            $Proc.WaitForExit()
                        } catch {
                            Write-Log "EXE Uninstaller hiba, direktben futtatas..." "WARN"
                        }
                    }
                }
            }
        }
    }

    if ($App.RegistryBlock) {
        Write-Log "Registry tiltas alkalmazasa a kovetkezohoz: $($App.Name)"
        Write-Host "[*] Ujratelepites elleni vedelem (IFEO) beallitasa: $($App.Name)" -ForegroundColor Blue
        
        $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($App.RegistryName).exe"
        if (-not (Test-Path $IfeoPath)) {
            New-Item -Path $IfeoPath -Force | Out-Null
        }
        Set-ItemProperty -Path $IfeoPath -Name "Debugger" -Value "cmd.exe /c exit" -Force
    }
}

$GarbagePaths = @(
    "C:\ProgramData\HP\TCO",
    "C:\Online Services",
    "C:\Users\Public\Desktop\TCO Certified.lnk",
    "C:\ProgramFiles\Dell\DigitalDelivery",
    "C:\ProgramData\Dell\SARemediation"
)
foreach ($Path in $GarbagePaths) {
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue
        Write-Log "Szemet mappa/parancsikon torolve: $Path"
    }
}

# --- INTERAKTÍV ÖSSZEGZÉS ÉS MEGÁLLÍTÁS JAVÍTÁSA ---
Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          TAKARITAS VEGEREDMENYE (SUMMARY)         " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$SuccessCount = 0
$FailCount = 0

# Frissítjük az uninstall listát a törlés utáni ellenőrzéshez
$PostInstalledItems = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue

foreach ($App in $ToKill) {
    $CheckInstalled = $PostInstalledItems | Where-Object { $_.DisplayName -like "*$($App.Name)*" -or $_.DisplayName -like "*$($App.RegistryName)*" }
    
    if (-not $CheckInstalled) {
        Write-Host " [SIKERES]   $($App.Name) eltavolitva." -ForegroundColor Green
        Write-Log "Sikeresen eltavolitva: $($App.Name)"
        $SuccessCount++
    } else {
        Write-Host " [SIKERTELEN] $($App.Name) eltavolitasa nem sikerult." -ForegroundColor Red
        Write-Log "Sikertelen eltavolitas: $($App.Name)" "WARN"
        $FailCount++
    }
}

Write-Host "--------------------------------------------------"
Write-Host "Sikeresen tisztitott elemek szama: $SuccessCount" -ForegroundColor Green
if ($FailCount -gt 0) {
    Write-Host "Megmaradt / hibat jelento elemek szama: $FailCount" -ForegroundColor Red
}

Write-Host "`nA reszletes naplot itt talalod: $LogFile" -ForegroundColor Gray
Write-Log "Takaritasi statisztika: Siker: $SuccessCount, Hiba: $FailCount"

Write-Host "`nNyomj meg egy gombot a bezarashoz es a kilepeshez..." -ForegroundColor Cyan
Write-Log "Szkript megallitva, varakozas a gombnyomasra..."
[System.Console]::ReadKey($true) | Out-Null

