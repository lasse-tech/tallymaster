@echo off
setlocal EnableDelayedExpansion

rem Windows counterpart to the Makefile - same targets, no make/zip needed.
rem Usage:  Makefile <target>        e.g.  Makefile install

set "ADDON=Tallymaster"
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
if not defined FLAVOR set "FLAVOR=_retail_"

set "INSTALL_DIRS=Core UI Locales Skin Media"
set "INSTALL_FILES=%ADDON%.toc embeds.xml Bindings.xml CHANGELOG.md"
set "KEEP_LIBS= LibStub CallbackHandler-1.0 LibDataBroker-1.1 LibDBIcon-1.0 LibElvUIPlugin-1.0 "

for /f "tokens=3" %%v in ('findstr /b /c:"## Version:" "%ROOT%\%ADDON%.toc"') do set "VERSION=%%v"
set "DIST=%ROOT%\dist"

set "TARGET_NAME=%~1"
if "%TARGET_NAME%"=="" set "TARGET_NAME=help"

if /i "%TARGET_NAME%"=="help"       goto :help
if /i "%TARGET_NAME%"=="version"    goto :version
if /i "%TARGET_NAME%"=="check"      goto :check
if /i "%TARGET_NAME%"=="libs"       goto :libs
if /i "%TARGET_NAME%"=="install"    goto :install
if /i "%TARGET_NAME%"=="uninstall"  goto :uninstall
if /i "%TARGET_NAME%"=="prune-libs" goto :prunelibs
if /i "%TARGET_NAME%"=="dist"       goto :dist
if /i "%TARGET_NAME%"=="clean"      goto :clean
if /i "%TARGET_NAME%"=="distclean"  goto :distclean
if /i "%TARGET_NAME%"=="purge"      goto :purge

echo unknown target "%TARGET_NAME%"
echo.
call :help
exit /b 1

:help
echo %ADDON% %VERSION%
echo.
echo   Makefile check        syntax-check every Lua file
echo   Makefile libs         report which embedded libraries are missing
echo   Makefile install      copy the addon into the live WoW client
echo   Makefile uninstall    remove it again ^(SavedVariables are kept^)
echo   Makefile prune-libs   drop installed libraries embeds.xml no longer lists
echo   Makefile dist         build dist\%ADDON%-%VERSION%.zip
echo   Makefile clean        remove build output
echo   Makefile distclean    clean + empty Libs\
echo   Makefile purge        uninstall + delete SavedVariables ^(needs CONFIRM=yes^)
echo.
echo   set FLAVOR=_classic_era_   to target another client
echo   set WOW_RETAIL_ADDON_FOLDER=D:\World of Warcraft\_retail_\Interface\AddOns
echo                              to install straight into that folder ^(retail only^)
echo   set WOW_DIR=D:\World of Warcraft   to override auto-detection
goto :eof

:version
echo %VERSION%
goto :eof

rem ---------------------------------------------------------------- locate WoW

:findwow
rem WOW_RETAIL_ADDON_FOLDER points straight at Interface\AddOns and skips the search.
rem It only applies to the flavor it names, so a FLAVOR override falls back to
rem WOW_DIR and auto-detection.
if /i "%FLAVOR%"=="_retail_" if defined WOW_RETAIL_ADDON_FOLDER (
    set "ADDONS=%WOW_RETAIL_ADDON_FOLDER%"
    for %%i in ("%WOW_RETAIL_ADDON_FOLDER%\..\..") do set "FLAVOR_DIR=%%~fi"
    goto :findaddons_done
)
set "WOW="
if defined WOW_DIR (
    if exist "%WOW_DIR%\%FLAVOR%" set "WOW=%WOW_DIR%"
    goto :findwow_done
)
for /f "usebackq tokens=2,*" %%a in (`reg query "HKLM\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft" /v InstallPath 2^>nul ^| findstr InstallPath`) do (
    if exist "%%b\%FLAVOR%" set "WOW=%%b"
)
if defined WOW goto :findwow_done
for %%d in (
    "%ProgramFiles(x86)%\World of Warcraft"
    "%ProgramFiles%\World of Warcraft"
    "C:\Program Files (x86)\World of Warcraft"
    "C:\Program Files\World of Warcraft"
    "D:\World of Warcraft"
    "C:\Games\World of Warcraft"
) do (
    if not defined WOW if exist "%%~d\%FLAVOR%" set "WOW=%%~d"
)
:findwow_done
if not defined WOW (
    echo AddOns folder not found. Set WOW_RETAIL_ADDON_FOLDER or WOW_DIR, e.g.:
    echo    set "WOW_RETAIL_ADDON_FOLDER=D:\World of Warcraft\_retail_\Interface\AddOns"
    echo    set "WOW_DIR=D:\World of Warcraft"
    exit /b 1
)
set "ADDONS=%WOW%\%FLAVOR%\Interface\AddOns"
set "FLAVOR_DIR=%WOW%\%FLAVOR%"
:findaddons_done
set "TARGET=%ADDONS%\%ADDON%"
exit /b 0

rem ---------------------------------------------------------------------- check

:check
where luac >nul 2>&1
if not errorlevel 1 (
    luac -p "%ROOT%\Core\*.lua" "%ROOT%\UI\*.lua" "%ROOT%\Locales\*.lua" "%ROOT%\Skin\*.lua"
    if errorlevel 1 exit /b 1
    echo luac: all files parse
    goto :eof
)
python -c "import lupa" >nul 2>&1
if not errorlevel 1 (
    pushd "%ROOT%"
    python -c "import io,glob,sys,lupa; m=getattr(lupa,'luajit21',None) or getattr(lupa,'lua51',None) or lupa; L=m.LuaRuntime(); ld=L.eval('function(s,n) local f,e=load(s,n) if f then return true,0 end return false,tostring(e) end'); fs=sorted(glob.glob('Core/*.lua')+glob.glob('UI/*.lua')+glob.glob('Locales/*.lua')+glob.glob('Skin/*.lua')); rs=[(f,)+tuple(ld(io.open(f,encoding='utf-8').read(),'@'+f)) for f in fs]; bad=[r for r in rs if not r[1]]; [print('FAIL',r[0],r[2]) for r in bad]; sys.exit(1) if bad else print('lupa: all files parse (' + str(len(fs)) + ')')"
    set "RC=!errorlevel!"
    popd
    if not "!RC!"=="0" exit /b 1
    goto :eof
)
echo no Lua available ^(install lua/luac, or "pip install lupa"^) - skipped
goto :eof

rem ----------------------------------------------------------------------- libs

:libs
set "MISSING=0"
set "SEEN= "
for /f "tokens=2 delims=\" %%l in ('findstr /c:"Libs" "%ROOT%\embeds.xml"') do (
    echo !SEEN! | findstr /c:" %%l " >nul || (
        set "SEEN=!SEEN!%%l "
        if exist "%ROOT%\Libs\%%l\" (
            echo   ok      Libs\%%l
        ) else (
            echo   MISSING Libs\%%l
            set "MISSING=1"
        )
    )
)
if "!MISSING!"=="1" (
    echo.
    echo Libraries are not vendored - see Libs\README.md. "Makefile install" keeps
    echo whatever is already installed in the client, so this is only fatal on
    echo a first install or for "Makefile dist".
)
goto :eof

rem -------------------------------------------------------------------- install

:install
call :findwow || exit /b 1
echo installing %ADDON% %VERSION% -^> %TARGET%
if not exist "%TARGET%" mkdir "%TARGET%"
for %%d in (%INSTALL_DIRS%) do (
    if exist "%TARGET%\%%d" rmdir /s /q "%TARGET%\%%d"
    robocopy "%ROOT%\%%d" "%TARGET%\%%d" /e /njh /njs /ndl /nc /ns /np >nul
    if errorlevel 8 echo   ERROR copying %%d& exit /b 1
)
for %%f in (%INSTALL_FILES%) do copy /y "%ROOT%\%%f" "%TARGET%\%%f" >nul

set "HAVELIBS=0"
for /d %%d in ("%ROOT%\Libs\*") do set "HAVELIBS=1"
if "!HAVELIBS!"=="1" (
    robocopy "%ROOT%\Libs" "%TARGET%\Libs" /e /njh /njs /ndl /nc /ns /np >nul
    if errorlevel 8 echo   ERROR copying Libs& exit /b 1
) else (
    if exist "%TARGET%\Libs\" (
        echo   keeping the libraries already installed in the client
    ) else (
        echo   warning: no Libs\ here and none installed - the addon will not load
    )
)

for %%x in (design .claude .git dist) do (
    if exist "%TARGET%\%%x\" (
        echo   removing stray %%x\ ^(not part of the addon^)
        rmdir /s /q "%TARGET%\%%x"
    )
)
for %%x in (README.md .gitignore .pkgmeta Makefile Makefile.bat) do (
    if exist "%TARGET%\%%x" (
        echo   removing stray %%x ^(not part of the addon^)
        del /q "%TARGET%\%%x"
    )
)

set "STALE="
if exist "%TARGET%\Libs\" (
    for /d %%d in ("%TARGET%\Libs\*") do (
        echo !KEEP_LIBS! | findstr /c:" %%~nxd " >nul || set "STALE=!STALE! %%~nxd"
    )
)
if defined STALE (
    echo   stale libraries still installed:!STALE!
    echo   run "Makefile prune-libs" to remove them
)
echo done - /reload in game
goto :eof

rem ------------------------------------------------------------------ uninstall

:uninstall
call :findwow || exit /b 1
if not exist "%TARGET%\" (
    echo not installed: %TARGET%
    goto :eof
)
rmdir /s /q "%TARGET%"
echo removed %TARGET%
echo SavedVariables kept - use "Makefile purge" with CONFIRM=yes to delete those too
goto :eof

rem ----------------------------------------------------------------- prune-libs

:prunelibs
call :findwow || exit /b 1
if not exist "%TARGET%\Libs\" (
    echo nothing installed
    goto :eof
)
for /d %%d in ("%TARGET%\Libs\*") do (
    echo !KEEP_LIBS! | findstr /c:" %%~nxd " >nul || (
        echo   removing %%~nxd
        rmdir /s /q "%%d"
    )
)
echo done
goto :eof

rem ----------------------------------------------------------------------- dist

:dist
set "HAVELIBS=0"
for /d %%d in ("%ROOT%\Libs\*") do set "HAVELIBS=1"
if "!HAVELIBS!"=="0" (
    echo Libs\ is empty - the zip would not load. Populate it first ^("Makefile libs"^).
    exit /b 1
)
if exist "%DIST%" rmdir /s /q "%DIST%"
mkdir "%DIST%\%ADDON%"
for %%d in (%INSTALL_DIRS% Libs) do (
    robocopy "%ROOT%\%%d" "%DIST%\%ADDON%\%%d" /e /njh /njs /ndl /nc /ns /np >nul
    if errorlevel 8 echo   ERROR copying %%d& exit /b 1
)
for %%f in (%INSTALL_FILES%) do copy /y "%ROOT%\%%f" "%DIST%\%ADDON%\%%f" >nul
if exist "%DIST%\%ADDON%\Libs\README.md" del /q "%DIST%\%ADDON%\Libs\README.md"
if exist "%DIST%\%ADDON%\Media\README.md" del /q "%DIST%\%ADDON%\Media\README.md"
rem bsdtar writes spec-compliant forward slashes; Compress-Archive on PS 5.1 does not
where tar >nul 2>&1
if not errorlevel 1 (
    tar -a -c -f "%DIST%\%ADDON%-%VERSION%.zip" -C "%DIST%" "%ADDON%"
) else (
    echo   warning: tar not found, falling back to Compress-Archive
    echo   ^(that writes backslash paths - fine on Windows, not for uploads^)
    powershell -NoProfile -Command "Compress-Archive -Path '%DIST%\%ADDON%' -DestinationPath '%DIST%\%ADDON%-%VERSION%.zip' -Force"
)
if errorlevel 1 exit /b 1
rmdir /s /q "%DIST%\%ADDON%"
echo built dist\%ADDON%-%VERSION%.zip
goto :eof

rem ---------------------------------------------------------------------- clean

:clean
if exist "%DIST%" rmdir /s /q "%DIST%"
echo cleaned
goto :eof

:distclean
call :clean
for /d %%d in ("%ROOT%\Libs\*") do rmdir /s /q "%%d"
for %%f in ("%ROOT%\Libs\*") do (
    if /i not "%%~nxf"=="README.md" del /q "%%f"
)
echo emptied Libs\
goto :eof

rem ---------------------------------------------------------------------- purge

:purge
if /i not "%CONFIRM%"=="yes" (
    echo refusing to delete SavedVariables without CONFIRM=yes
    echo    set "CONFIRM=yes" ^&^& Makefile purge
    exit /b 1
)
call :uninstall || exit /b 1
call :findwow || exit /b 1
set "FOUND=0"
for /d %%a in ("%FLAVOR_DIR%\WTF\Account\*") do (
    for %%e in (lua lua.bak) do (
        if exist "%%a\SavedVariables\%ADDON%.%%e" (
            echo   deleting %%a\SavedVariables\%ADDON%.%%e
            del /q "%%a\SavedVariables\%ADDON%.%%e"
            set "FOUND=1"
        )
    )
)
if "!FOUND!"=="0" echo   no SavedVariables found
goto :eof
