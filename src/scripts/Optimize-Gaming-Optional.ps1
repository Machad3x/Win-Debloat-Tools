Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\Get-HardwareInfo.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\Title-Templates.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\debloat-helper\Remove-ItemPropertyVerified.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\debloat-helper\Set-ItemPropertyVerified.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\debloat-helper\Set-OptionalFeatureState.psm1"
Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\debloat-helper\Set-ServiceStartup.psm1"

# Aggressive/optional gaming tweaks. Use at your own risk.

function Optimize-Gaming-Optional() {
    [CmdletBinding()]
    param(
        [Switch] $Revert
    )
    $TweakType = "GamingOptional"

    Write-Title "Optional Aggressive Gaming Tweaks"

    Write-Status -Types "@", $TweakType -Status "These tweaks are aggressive and may reduce security/stability. Revert anytime via Undo." -Warning

    # 1. Disable VBS/HVCI (Memory Integrity)
    Write-Section "VBS / Memory Integrity"
    $HvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling Memory Integrity (HVCI)..."
        If (!(Test-Path "$HvciPath")) { New-Item -Path "$HvciPath" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$HvciPath" -Name "Enabled" -Type DWord -Value 0
        Set-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0
    } Else {
        Set-ItemPropertyVerified -Path "$HvciPath" -Name "Enabled" -Type DWord -Value 1
        Set-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 1
    }

    # 2. Disable Virtual Machine Platform / Hyper-V
    Write-Section "Virtualization Platform"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling Virtual Machine Platform and Hyper-V..."
        Try { Disable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue | Out-Null } Catch {}
        Try { Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue | Out-Null } Catch {}
    } Else {
        Try { Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue | Out-Null } Catch {}
        Try { Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue | Out-Null } Catch {}
    }

    # 3/11/20. Disable CPU mitigations (Spectre/Meltdown/KPTI/Retpoline)
    Write-Section "CPU Mitigations"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling CPU security mitigations (Spectre/Meltdown)..."
        $MmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        Set-ItemPropertyVerified -Path "$MmPath" -Name "FeatureSettingsOverride" -Type DWord -Value 3
        Set-ItemPropertyVerified -Path "$MmPath" -Name "FeatureSettingsOverrideMask" -Type DWord -Value 3
    } Else {
        Remove-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverride"
        Remove-ItemPropertyVerified -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverrideMask"
    }

    # 4. Disable MPO
    Write-Section "Multiplane Overlay (MPO)"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling MPO..."
        Set-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -Type DWord -Value 5
    } Else {
        Remove-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"
    }

    # 5. Disable GPU preemption
    Write-Section "GPU Preemption"
    $SchedPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling GPU task preemption..."
        If (!(Test-Path "$SchedPath")) { New-Item -Path "$SchedPath" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$SchedPath" -Name "DisablePreemption" -Type DWord -Value 1
    } Else {
        Remove-ItemPropertyVerified -Path "$SchedPath" -Name "DisablePreemption"
    }

    # 6/7. GPU clock gating / power saving + P-State 0 (NVIDIA)
    Write-Section "GPU Power Saving (Aggressive)"
    $GpuClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    If (Test-Path "$GpuClass") {
        Get-ChildItem -Path "$GpuClass" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            $Desc = (Get-ItemProperty -Path $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            If ($Desc -match 'NVIDIA') {
                If (!$Revert) {
                    Write-Status -Types "-", $TweakType -Status "NVIDIA: disabling dynamic P-state and power saving..."
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "DisableDynamicPstate" -Type DWord -Value 1
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "DisableDynamicPstate" -Type DWord -Value 1
                } Else {
                    Remove-ItemPropertyVerified -Path $_.PSPath -Name "DisableDynamicPstate"
                }
            } ElseIf ($Desc -match 'AMD|Radeon') {
                If (!$Revert) {
                    Write-Status -Types "-", $TweakType -Status "AMD: disabling ULPS and clock gating..."
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps" -Type DWord -Value 0
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps_NA" -Type DWord -Value 0
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "PP_DisableULPS" -Type DWord -Value 1
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "DisableAllClockGating" -Type DWord -Value 1
                } Else {
                    Set-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps" -Type DWord -Value 1
                    Remove-ItemPropertyVerified -Path $_.PSPath -Name "EnableUlps_NA"
                    Remove-ItemPropertyVerified -Path $_.PSPath -Name "PP_DisableULPS"
                    Remove-ItemPropertyVerified -Path $_.PSPath -Name "DisableAllClockGating"
                }
            }
        }
    }

    # 8. ULPS all AMD (already above)

    # 9. Unlock All Cores (hellzerg)
    Write-Section "Unlock All Cores"
    $CorePath = "HKLM:\SYSTEM\ControlSet001\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Unlocking all CPU cores..."
        If (!(Test-Path "$CorePath")) { New-Item -Path "$CorePath" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$CorePath" -Name "ValueMax" -Type DWord -Value 0
        Set-ItemPropertyVerified -Path "$CorePath" -Name "ValueMin" -Type DWord -Value 0
    } Else {
        Remove-ItemPropertyVerified -Path "$CorePath" -Name "ValueMax"
        Remove-ItemPropertyVerified -Path "$CorePath" -Name "ValueMin"
    }

    # 10. Disable Windows Defender real-time
    Write-Section "Windows Defender (Aggressive)"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling Defender real-time monitoring..."
        Try { Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue } Catch {}
    } Else {
        Try { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue } Catch {}
    }

    # 12. USB selective suspend
    Write-Section "USB Selective Suspend"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling USB selective suspend..."
        powercfg -setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
        powercfg -setdcvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
    } Else {
        powercfg -setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 | Out-Null
        powercfg -setdcvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 | Out-Null
    }

    # 13. Audio enhancements (best-effort)
    Write-Section "Audio Enhancements"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling audio enhancements (best-effort)..."
        Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render" -ErrorAction SilentlyContinue | ForEach-Object {
            $FxPath = Join-Path $_.PSPath "FxProperties"
            If (Test-Path "$FxPath") {
                Set-ItemPropertyVerified -Path "$FxPath" -Name "{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},5" -Type DWord -Value 0 -ErrorAction SilentlyContinue
            }
        }
    }

    # 15. Disable Game Bar completely
    Write-Section "Game Bar (Complete)"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling Game Bar completely..."
        Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Type DWord -Value 0
        Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Type DWord -Value 0
        Set-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Type DWord -Value 0
    } Else {
        Remove-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled"
        Remove-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled"
        Remove-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR"
    }

    # 16. Disable Windows Search
    Write-Section "Windows Search Service"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling Windows Search service..."
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
    } Else {
        Set-Service -Name "WSearch" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    }

    # 17. Disable SysMain
    Write-Section "SysMain (Superfetch)"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling SysMain service..."
        Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
    } Else {
        Set-Service -Name "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "SysMain" -ErrorAction SilentlyContinue
    }

    # 18. Disable animations/transparency
    Write-Section "Animations & Transparency"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling animations and transparency..."
        Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Type Binary -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00))
        Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 0
    } Else {
        Set-ItemPropertyVerified -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Type Binary -Value ([byte[]](0x9e,0x1e,0x07,0x80,0x12,0x00,0x00,0x00))
        Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 1
    }

    # 19. Disable Recall/Copilot/Widgets
    Write-Section "Recall / Copilot / Widgets"
    If (!$Revert) {
        Write-Status -Types "-", $TweakType -Status "Disabling Recall, Copilot and Widgets..."
        $CopilotPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
        If (!(Test-Path "$CopilotPath")) { New-Item -Path "$CopilotPath" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$CopilotPath" -Name "TurnOffWindowsCopilot" -Type DWord -Value 1
        Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Type DWord -Value 0
        $RecallPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        If (!(Test-Path "$RecallPath")) { New-Item -Path "$RecallPath" -Force | Out-Null }
        Set-ItemPropertyVerified -Path "$RecallPath" -Name "DisableAIDataAnalysis" -Type DWord -Value 1
    } Else {
        Remove-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot"
        Set-ItemPropertyVerified -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Type DWord -Value 1
        Remove-ItemPropertyVerified -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis"
    }

    Write-Status -Types "@", $TweakType -Status "Optional aggressive tweaks done. Reboot recommended." -Warning
}

If (!$Revert) {
    Optimize-Gaming-Optional
} Else {
    Optimize-Gaming-Optional -Revert
}
