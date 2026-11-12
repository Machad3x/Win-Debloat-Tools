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
