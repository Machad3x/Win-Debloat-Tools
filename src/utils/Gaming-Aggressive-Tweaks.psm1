Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\Get-HardwareInfo.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\Title-Templates.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\debloat-helper\Remove-ItemPropertyVerified.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\debloat-helper\Set-ItemPropertyVerified.psm1"

# Optional aggressive gaming tweaks (individual, selectable in GUI)

function Enable-MemoryIntegrityOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling Memory Integrity (HVCI)..."
    $HvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    If (!(Test-Path "$HvciPath")) { New-Item -Path "$HvciPath" -Force | Out-Null }
    Set-ItemPropertyVerified -Path "$HvciPath" -Name "Enabled" -Type DWord -Value 0
    Set-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0
}
function Disable-MemoryIntegrityOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling Memory Integrity (HVCI)..."
    $HvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    If (!(Test-Path "$HvciPath")) { New-Item -Path "$HvciPath" -Force | Out-Null }
    Set-ItemPropertyVerified -Path "$HvciPath" -Name "Enabled" -Type DWord -Value 1
    Set-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
}

function Enable-VirtualizationPlatformOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling Virtual Machine Platform / Hyper-V..."
    Try { Disable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue | Out-Null } Catch {}
    Try { Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue | Out-Null } Catch {}
}
function Disable-VirtualizationPlatformOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling Virtual Machine Platform / Hyper-V..."
    Try { Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue | Out-Null } Catch {}
    Try { Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue | Out-Null } Catch {}
}

function Enable-CpuMitigationsOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling CPU security mitigations..."
    $MmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemPropertyVerified -Path "$MmPath" -Name "FeatureSettingsOverride" -Type DWord -Value 3
    Set-ItemPropertyVerified -Path "$MmPath" -Name "FeatureSettingsOverrideMask" -Type DWord -Value 3
}
function Disable-CpuMitigationsOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring CPU security mitigations..."
    Remove-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverride"
    Remove-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverrideMask"
}

function Enable-MpoOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling MPO..."
    Set-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -Type DWord -Value 5
}
function Disable-MpoOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling MPO..."
    Remove-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"
}

function Enable-GpuPreemptionOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling GPU preemption..."
    $SchedPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler"
    If (!(Test-Path "$SchedPath")) { New-Item -Path "$SchedPath" -Force | Out-Null }
    Set-ItemPropertyVerified -Path "$SchedPath" -Name "DisablePreemption" -Type DWord -Value 1
}
function Disable-GpuPreemptionOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling GPU preemption..."
    Remove-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler" -Name "DisablePreemption"
}

function Enable-GpuPowerSavingOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling GPU clock gating / power saving..."
    $GpuClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    If (Test-Path "$GpuClass") {
        Get-ChildItem -Path "$GpuClass" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            $Desc = (Get-ItemProperty -Path $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            If ($Desc -match 'NVIDIA') {
                Set-ItemPropertyVerified -Path $_.PSPath -Name "DisableDynamicPstate" -Type DWord -Value 1
            } ElseIf ($Desc -match 'AMD|Radeon') {
                Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps" -Type DWord -Value 0
                Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps_NA" -Type DWord -Value 0
                Set-ItemPropertyVerified -Path $_.PSPath -Name "PP_DisableULPS" -Type DWord -Value 1
                Set-ItemPropertyVerified -Path $_.PSPath -Name "DisableAllClockGating" -Type DWord -Value 1
            }
        }
    }
}
function Disable-GpuPowerSavingOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring GPU power saving..."
    $GpuClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    If (Test-Path "$GpuClass") {
        Get-ChildItem -Path "$GpuClass" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            $Desc = (Get-ItemProperty -Path $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            If ($Desc -match 'NVIDIA') {
                Remove-ItemPropertyVerified -Path $_.PSPath -Name "DisableDynamicPstate"
            } ElseIf ($Desc -match 'AMD|Radeon') {
                Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps" -Type DWord -Value 1
                Remove-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps_NA"
                Remove-ItemPropertyVerified -Path $_.PSPath -Name "PP_DisableULPS"
                Remove-ItemPropertyVerified -Path $_.PSPath -Name "DisableAllClockGating"
            }
        }
    }
}

function Enable-NvidiaPstateOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Locking NVIDIA P-State 0..."
    $GpuClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    If (Test-Path "$GpuClass") {
        Get-ChildItem -Path "$GpuClass" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            $Desc = (Get-ItemProperty -Path $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            If ($Desc -match 'NVIDIA') {
                Set-ItemPropertyVerified -Path $_.PSPath -Name "DisableDynamicPstate" -Type DWord -Value 1
            }
        }
    }
}
function Disable-NvidiaPstateOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring NVIDIA P-State..."
    $GpuClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    If (Test-Path "$GpuClass") {
        Get-ChildItem -Path "$GpuClass" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            $Desc = (Get-ItemProperty -Path $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            If ($Desc -match 'NVIDIA') {
                Remove-ItemPropertyVerified -Path $_.PSPath -Name "DisableDynamicPstate"
            }
        }
    }
}

function Enable-UlpsOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling ULPS (all AMD)..."
    $GpuClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    If (Test-Path "$GpuClass") {
        Get-ChildItem -Path "$GpuClass" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            $Desc = (Get-ItemProperty -Path $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            If ($Desc -match 'AMD|Radeon') {
                Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps" -Type DWord -Value 0
                Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps_NA" -Type DWord -Value 0
                Set-ItemPropertyVerified -Path $_.PSPath -Name "PP_DisableULPS" -Type DWord -Value 1
            }
        }
    }
}
function Disable-UlpsOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling ULPS (all AMD)..."
    $GpuClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    If (Test-Path "$GpuClass") {
        Get-ChildItem -Path "$GpuClass" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            $Desc = (Get-ItemProperty -Path $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            If ($Desc -match 'AMD|Radeon') {
                Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps" -Type DWord -Value 1
                Remove-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps_NA"
                Remove-ItemPropertyVerified -Path $_.PSPath -Name "PP_DisableULPS"
            }
        }
    }
}

function Enable-UnlockAllCoresOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Unlocking all CPU cores..."
    $CorePath = "HKLM:\SYSTEM\ControlSet001\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    If (!(Test-Path "$CorePath")) { New-Item -Path "$CorePath" -Force | Out-Null }
    Set-ItemPropertyVerified -Path "$CorePath" -Name "ValueMax" -Type DWord -Value 0
    Set-ItemPropertyVerified -Path "$CorePath" -Name "ValueMin" -Type DWord -Value 0
}
function Disable-UnlockAllCoresOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring CPU core parking..."
    $CorePath = "HKLM:\SYSTEM\ControlSet001\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    Remove-ItemPropertyVerified -Path "$CorePath" -Name "ValueMax"
    Remove-ItemPropertyVerified -Path "$CorePath" -Name "ValueMin"
}

function Enable-DefenderRealtimeOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling Defender real-time monitoring..."
    Try { Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue } Catch {}
}
function Disable-DefenderRealtimeOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling Defender real-time monitoring..."
    Try { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue } Catch {}
}

function Enable-UsbSelectiveSuspendOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling USB selective suspend..."
    powercfg -setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
    powercfg -setdcvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
}
function Disable-UsbSelectiveSuspendOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling USB selective suspend..."
    powercfg -setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 | Out-Null
    powercfg -setdcvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 | Out-Null
}

function Enable-AudioEnhancementsOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling audio enhancements (best-effort)..."
    Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render" -ErrorAction SilentlyContinue | ForEach-Object {
        $FxPath = Join-Path $_.PSPath "FxProperties"
        If (Test-Path "$FxPath") {
            Set-ItemPropertyVerified -Path "$FxPath" -Name "{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},5" -Type DWord -Value 0 -ErrorAction SilentlyContinue
        }
    }
}
function Disable-AudioEnhancementsOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling audio enhancements (best-effort)..."
    Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render" -ErrorAction SilentlyContinue | ForEach-Object {
        $FxPath = Join-Path $_.PSPath "FxProperties"
        If (Test-Path "$FxPath") {
            Set-ItemPropertyVerified -Path "$FxPath" -Name "{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},5" -Type DWord -Value 1 -ErrorAction SilentlyContinue
        }
    }
}

function Enable-GameBarCompleteOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling Game Bar completely..."
    Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Type DWord -Value 0
    Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Type DWord -Value 0
    Set-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Type DWord -Value 0
}
function Disable-GameBarCompleteOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling Game Bar..."
    Remove-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled"
    Remove-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled"
    Remove-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR"
}

function Enable-WindowsSearchOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling Windows Search service..."
    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
}
function Disable-WindowsSearchOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling Windows Search service..."
    Set-Service -Name "WSearch" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
}

function Enable-SysMainOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling SysMain service..."
    Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
}
function Disable-SysMainOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling SysMain service..."
    Set-Service -Name "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "SysMain" -ErrorAction SilentlyContinue
}

function Enable-AnimationsTransparencyOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling animations and transparency..."
    Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Type Binary -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00))
    Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 0
}
function Disable-AnimationsTransparencyOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling animations and transparency..."
    Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Type Binary -Value ([byte[]](0x9e,0x1e,0x07,0x80,0x12,0x00,0x00,0x00))
    Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 1
}

function Enable-RecallCopilotWidgetsOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling Recall, Copilot and Widgets..."
    $CopilotPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    If (!(Test-Path "$CopilotPath")) { New-Item -Path "$CopilotPath" -Force | Out-Null }
    Set-ItemPropertyVerified -Path "$CopilotPath" -Name "TurnOffWindowsCopilot" -Type DWord -Value 1
    Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Type DWord -Value 0
    $RecallPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
    If (!(Test-Path "$RecallPath")) { New-Item -Path "$RecallPath" -Force | Out-Null }
    Set-ItemPropertyVerified -Path "$RecallPath" -Name "DisableAIDataAnalysis" -Type DWord -Value 1
}
function Disable-RecallCopilotWidgetsOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling Recall, Copilot and Widgets..."
    Remove-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot"
    Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Type DWord -Value 1
    Remove-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis"
}


function Enable-MpoMinFpsOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling MPO minimum FPS requirement..."
    Set-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayMinFPS" -Type DWord -Value 0
}
function Disable-MpoMinFpsOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring MPO minimum FPS requirement..."
    Remove-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayMinFPS"
}

function Enable-DisableAllOverlaysOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling hardware overlays..."
    Set-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "DisableOverlays" -Type DWord -Value 1
}
function Disable-DisableAllOverlaysOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling hardware overlays..."
    Remove-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "DisableOverlays"
}

function Enable-NagleAlgorithmOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling Nagle's algorithm (per interface)..."
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemPropertyVerified -Path $_.PSPath -Name "TcpAckFrequency" -Type DWord -Value 1 -ErrorAction SilentlyContinue
        Set-ItemPropertyVerified -Path $_.PSPath -Name "TCPNoDelay" -Type DWord -Value 1 -ErrorAction SilentlyContinue
    }
}
function Disable-NagleAlgorithmOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring Nagle's algorithm..."
    Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-ItemPropertyVerified -Path $_.PSPath -Name "TcpAckFrequency"
        Remove-ItemPropertyVerified -Path $_.PSPath -Name "TCPNoDelay"
    }
}

function Enable-VrrOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Enabling VRR optimizations..."
    $p = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
    If (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    $cur = (Get-ItemProperty -Path $p -Name "DirectXUserGlobalSettings" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    If ([string]::IsNullOrWhiteSpace($cur)) { $cur = "" }
    If ($cur -notmatch "VRROptimizeEnable") {
        if ([string]::IsNullOrWhiteSpace($cur)) { $cur = "VRROptimizeEnable=1;" } else { $cur = ($cur.TrimEnd(";") + ";VRROptimizeEnable=1;") }
    } else { $cur = $cur -replace "VRROptimizeEnable=\d", "VRROptimizeEnable=1" }
    Set-ItemPropertyVerified -Path $p -Name "DirectXUserGlobalSettings" -Type String -Value $cur
}
function Disable-VrrOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring VRR optimizations..."
    $p = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
    $cur = (Get-ItemProperty -Path $p -Name "DirectXUserGlobalSettings" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    If ($cur) { $cur = $cur -replace "VRROptimizeEnable=\d", "VRROptimizeEnable=0"; Set-ItemPropertyVerified -Path $p -Name "DirectXUserGlobalSettings" -Type String -Value $cur }
}

function Enable-AutoHdrOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Enabling Auto HDR..."
    $p = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
    If (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    $cur = (Get-ItemProperty -Path $p -Name "DirectXUserGlobalSettings" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    If ([string]::IsNullOrWhiteSpace($cur)) { $cur = "" }
    If ($cur -notmatch "AutoHDREnable") {
        if ([string]::IsNullOrWhiteSpace($cur)) { $cur = "AutoHDREnable=1;" } else { $cur = ($cur.TrimEnd(";") + ";AutoHDREnable=1;") }
    } else { $cur = $cur -replace "AutoHDREnable=\d", "AutoHDREnable=1" }
    Set-ItemPropertyVerified -Path $p -Name "DirectXUserGlobalSettings" -Type String -Value $cur
}
function Disable-AutoHdrOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring Auto HDR..."
    $p = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
    $cur = (Get-ItemProperty -Path $p -Name "DirectXUserGlobalSettings" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    If ($cur) { $cur = $cur -replace "AutoHDREnable=\d", "AutoHDREnable=0"; Set-ItemPropertyVerified -Path $p -Name "DirectXUserGlobalSettings" -Type String -Value $cur }
}

function Enable-NvidiaSharpeningOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling legacy NVIDIA sharpening..."
    Set-ItemPropertyVerified -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" -Name "EnableGR535" -Type DWord -Value 0
}
function Disable-NvidiaSharpeningOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring legacy NVIDIA sharpening..."
    Set-ItemPropertyVerified -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" -Name "EnableGR535" -Type DWord -Value 1
}

function Enable-AutoColorManagementOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Disabling auto color management..."
    $p = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\MonitorDataStore"
    If (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemPropertyVerified -Path $p -Name "AutoColorManagementEnabled" -Type DWord -Value 0
}
function Disable-AutoColorManagementOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Re-enabling auto color management..."
    Set-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\MonitorDataStore" -Name "AutoColorManagementEnabled" -Type DWord -Value 1
}

function Enable-AutostartDelayOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Enabling startup app delay (10s)..."
    $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
    If (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemPropertyVerified -Path $p -Name "StartupDelayInMSec" -Type DWord -Value 10000
}
function Disable-AutostartDelayOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Disabling startup app delay..."
    Set-ItemPropertyVerified -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -Name "StartupDelayInMSec" -Type DWord -Value 0
}

function Enable-BackgroundAppsOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Forcing deny background apps..."
    foreach ($root in @("HKCU:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy","HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy")) {
        If (!(Test-Path $root)) { New-Item -Path $root -Force | Out-Null }
        Set-ItemPropertyVerified -Path $root -Name "LetAppsRunInBackground" -Type DWord -Value 2
    }
}
function Disable-BackgroundAppsOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring background apps control..."
    foreach ($root in @("HKCU:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy","HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy")) {
        Remove-ItemPropertyVerified -Path $root -Name "LetAppsRunInBackground"
    }
}

function Enable-MouseHoverTimeOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Setting mouse hover time to 1ms..."
    Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Mouse" -Name "MouseHoverTime" -Type String -Value "1"
}
function Disable-MouseHoverTimeOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring mouse hover time (400ms)..."
    Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Mouse" -Name "MouseHoverTime" -Type String -Value "400"
}

function Enable-MenuShowDelayOptimization() {
    Write-Status -Types "-", "GamingAgg" -Status "Setting menu show delay to 0..."
    Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Type String -Value "0"
}
function Disable-MenuShowDelayOptimization() {
    Write-Status -Types "+", "GamingAgg" -Status "Restoring menu show delay (400)..."
    Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Type String -Value "400"
}
