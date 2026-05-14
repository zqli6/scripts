@echo off
chcp 65001 >nul
title Windows 更新暂停时长设置工具
color 0A

:: 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 请右键以管理员身份运行本脚本。
    pause
    exit /b
)

:: 定义注册表路径和数值名称
set "RegKey=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
set "ValueName=FlightSettingsMaxPauseDays"
set "BackupFile=%USERPROFILE%\Desktop\WindowsUpdate_UX_Settings_backup.reg"

:menu
cls
echo ==========================================
echo    Windows 更新暂停时长设置工具
echo ==========================================
echo 1. 设置暂停更新的天数（默认 100 年）
echo 2. 恢复默认（允许更新）
echo 3. 退出
echo ==========================================
set /p choice=请输入选项数字 (1/2/3)：

if "%choice%"=="1" goto setDays
if "%choice%"=="2" goto restoreDefault
if "%choice%"=="3" goto end
echo 输入无效，请重新选择。
pause
goto menu

:setDays
cls
echo 当前默认天数为 36500 天（约 100 年）。
set /p days=请输入要暂停更新的天数（直接回车使用 100 年）：
if "%days%"=="" set days=36500

:: 校验输入是否为纯数字
echo %days%|findstr /r "^[1-9][0-9]*$" >nul
if %errorlevel% neq 0 (
    echo 输入无效，请输入正整数。
    echo 脚本即将退出...
    timeout /t 3 >nul
    goto end
)

echo.
echo 正在备份当前注册表项...
reg export "%RegKey%" "%BackupFile%" /y >nul 2>&1
if %errorlevel% equ 0 (
    echo 备份成功：%BackupFile%
) else (
    echo 备份可能失败，但仍将继续修改...
)

echo.
echo 正在修改注册表...
reg add "%RegKey%" /v %ValueName% /t REG_DWORD /d %days% /f >nul
if %errorlevel% equ 0 (
    echo 修改成功！已将最长暂停更新天数设为 %days% 天。
    echo.
    echo 请前往“设置 → Windows 更新”，点击“暂停更新”旁边的下拉菜单，
    echo 即可看到延长后的日期。如果未立即显示，可先暂停一周，
    echo 然后重启电脑再查看。
) else (
    echo 修改失败，请检查权限或注册表路径。
)
echo.
echo 设置完毕，脚本将在 3 秒后自动退出...
timeout /t 3 >nul
goto end

:restoreDefault
cls
echo 正在备份当前注册表项...
reg export "%RegKey%" "%BackupFile%" /y >nul 2>&1
echo 备份完成：%BackupFile%
echo.
echo 正在删除自定义暂停天数（恢复默认）...
reg delete "%RegKey%" /v %ValueName% /f >nul 2>&1
if %errorlevel% equ 0 (
    echo 恢复成功！请前往 Windows 更新页面，点击“继续更新”即可。
) else (
    echo 恢复失败，可能该数值不存在，已经是默认状态。
)
echo.
echo 恢复操作完成，脚本将在 3 秒后自动退出...
timeout /t 3 >nul
goto end

:end
exit