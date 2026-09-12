@echo off
setlocal EnableDelayedExpansion

rem Windows counterpart to the Makefile - same targets, no make/zip needed.
rem Usage:  Makefile <target>        e.g.  Makefile install

set "ADDON=Tallymaster"
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
if not defined FLAVOR set "FLAVOR=_retail_"

set "INSTALL_DIRS=Core UI Locales Skin Media"
rem One folder serves every flavor: the client picks the TOC whose suffix matches,
rem so all three ship together and the version comes from the canonical one.
set "TOCS=%ADDON%_Mainline.toc %ADDON%_Mists.toc %ADDON%_Vanilla.toc"
set "INSTALL_FILES=%TOCS% embeds.xml Bindings.xml CHANGELOG.md"
set "KEEP_LIBS= LibStub CallbackHandler-1.0 LibDataBroker-1.1 LibDBIcon-1.0 LibElvUIPlugin-1.0 "

for /f "tokens=3" %%v in ('findstr /b /c:"## Version:" "%ROOT%\%ADDON%_Mainline.toc"') do set "VERSION=%%v"
set "DIST=%ROOT%\dist"

set "TARGET_NAME=%~1"
if "%TARGET_NAME%"=="" set "TARGET_NAME=help"

if /i "%TARGET_NAME%"=="help"       goto :help
if /i "%TARGET_NAME%"=="version"    goto :version
if /i "%TARGET_NAME%"=="check"      goto :check
if /i "%TARGET_NAME%"=="check-tocs" goto :checktocs
if /i "%TARGET_NAME%"=="lint"       goto :lint
if /i "%TARGET_NAME%"=="libs"       goto :libs
if /i "%TARGET_NAME%"=="fetch-libs" goto :fetchlibs
if /i "%TARGET_NAME%"=="install"    goto :install
if /i "%TARGET_NAME%"=="uninstall"  goto :uninstall
if /i "%TARGET_NAME%"=="prune-libs" goto :prunelibs
if /i "%TARGET_NAME%"=="stage"      goto :stage
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
echo   Makefile fetch-libs   download them into Libs\ ^(needs svn, and git for one^)
echo   Makefile install      copy the addon into the live WoW client
echo   Makefile uninstall    remove it again ^(SavedVariables are kept^)
echo   Makefile prune-libs   drop installed libraries embeds.xml no longer lists
echo   Makefile stage        build dist\^<expansion^>\%ADDON%, ready to copy over
echo   Makefile dist         build dist\%ADDON%-%VERSION%.zip
echo   Makefile clean        remove build output
echo   Makefile distclean    clean + empty Libs\
echo   Makefile purge        uninstall + delete SavedVariables ^(needs CONFIRM=yes^)
echo   Makefile check-tocs   verify the flavor TOCs only differ in ## Interface:
echo   Makefile lint         check + check-tocs
echo.
echo   set FLAVOR=_classic_    for Mists Classic, _classic_era_ for Vanilla
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
rem It only names the retail folder, so a FLAVOR override falls back to WOW_DIR and
rem auto-detection, and last to the WoW folder three levels above it, where every
rem other client sits next to _retail_.
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
if not defined WOW if defined WOW_RETAIL_ADDON_FOLDER (
    for %%i in ("!WOW_RETAIL_ADDON_FOLDER!\..\..\..") do if exist "%%~fi\%FLAVOR%" set "WOW=%%~fi"
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

rem ----------------------------------------------------------------- fetch-libs

rem .pkgmeta stays the single source for what to fetch and from where - the CI
rem packager reads the same file, so hardcoding the URLs here would only invite
rem drift. Batch has no awk, so PowerShell parses the externals block into
rem "<path> <url>" lines and the fetching stays here. CurseForge serves SVN;
rem LibDataBroker-1.1 lives in tekkub's git repo.
:fetchlibs
where svn >nul 2>&1
if errorlevel 1 (
    echo svn not found - needed for the CurseForge externals
    exit /b 1
)
where git >nul 2>&1
if errorlevel 1 (
    echo git not found - needed for LibDataBroker-1.1
    exit /b 1
)
set "EXT=%TEMP%\tm_externals.txt"
powershell -NoProfile -Command "$e=$false;$p=$null;Get-Content '%ROOT%\.pkgmeta' | ForEach-Object { if ($_ -match '^externals:') { $e=$true; return }; if ($_ -match '^[a-zA-Z]') { $e=$false }; if ($e -and $_ -match '^  ([^ \#][^:]*):\s*$') { $p=$matches[1]; return }; if ($e -and $p -and $_ -match '^\s+url:\s*(\S+)') { \"$p $($matches[1])\"; $p=$null } }" > "%EXT%"
if not exist "%EXT%" (
    echo could not read .pkgmeta
    exit /b 1
)
for /f "usebackq tokens=1,2" %%a in ("%EXT%") do (
    if exist "%ROOT%\%%a" rmdir /s /q "%ROOT%\%%a"
    echo %%b | findstr /c:"github.com" >nul
    if errorlevel 1 (
        svn export -q --force --non-interactive --trust-server-cert "%%b" "%ROOT%\%%a"
        if errorlevel 1 exit /b 1
    ) else (
        git clone -q --depth 1 "%%b" "%ROOT%\%%a.tmp"
        if errorlevel 1 exit /b 1
        rmdir /s /q "%ROOT%\%%a.tmp\.git"
        move "%ROOT%\%%a.tmp" "%ROOT%\%%a" >nul
    )
    echo   fetched %%a
)
del "%EXT%" >nul 2>&1

rem Only ignore entries *inside* a fetched external are ours to delete. Top-level
rem Libs\ entries like Libs\README.md are repo files the packager excludes from
rem the zip - deleting those here would remove a tracked file.
set "IGN=%TEMP%\tm_ignores.txt"
powershell -NoProfile -Command "$i=$false;Get-Content '%ROOT%\.pkgmeta' | ForEach-Object { if ($_ -match '^ignore:') { $i=$true; return }; if ($i -and $_ -match '^  - (Libs/[^/]+/.+)$') { $matches[1].Replace('/','\') } }" > "%IGN%"
for /f "usebackq delims=" %%p in ("%IGN%") do (
    if exist "%ROOT%\%%p\" (
        echo   dropping %%p ^(.pkgmeta ignores it^)
        rmdir /s /q "%ROOT%\%%p"
    ) else if exist "%ROOT%\%%p" (
        echo   dropping %%p ^(.pkgmeta ignores it^)
        del /q "%ROOT%\%%p"
    )
)
del "%IGN%" >nul 2>&1
for /r "%ROOT%\Libs" %%f in (.pkgmeta) do if exist "%%f" del /q "%%f"
call :libs
goto :eof

rem ----------------------------------------------------------------- check-tocs

rem The flavor TOCs carry the same file list three times over, so drift is the one
rem way this layout can rot. Compare everything but the Interface line.
:checktocs
set "REF="
set "FAIL=0"
for %%t in (%TOCS%) do (
    findstr /v /b /c:"## Interface:" "%ROOT%\%%t" > "%TEMP%\tm_%%t.txt"
    if not defined REF (
        set "REF=%%t"
    ) else (
        fc /w "%TEMP%\tm_!REF!.txt" "%TEMP%\tm_%%t.txt" >nul
        if errorlevel 1 (
            echo   DRIFT   %%t differs from !REF! beyond ## Interface:
            fc /w "%TEMP%\tm_!REF!.txt" "%TEMP%\tm_%%t.txt"
            set "FAIL=1"
        )
    )
)
for %%t in (%TOCS%) do del "%TEMP%\tm_%%t.txt" >nul 2>&1
if "!FAIL!"=="1" exit /b 1
echo tocs: 3 flavors agree

set "MISSINGFILE=0"
for /f "usebackq delims=" %%f in ("%ROOT%\%ADDON%_Mainline.toc") do (
    echo %%f | findstr /r /c:"^[A-Za-z].*\.lua$" /c:"^[A-Za-z].*\.xml$" >nul && (
        if not exist "%ROOT%\%%f" (
            echo   MISSING %%f ^(listed in the TOC^)
            set "MISSINGFILE=1"
        )
    )
)
if "!MISSINGFILE!"=="1" exit /b 1
echo tocs: every listed file exists
goto :eof

:lint
call "%~f0" check
if errorlevel 1 exit /b 1
call "%~f0" check-tocs
if errorlevel 1 exit /b 1
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
    echo Run "Makefile fetch-libs" to download them, or see Libs\README.md.
    echo "Makefile install" keeps whatever is already installed in the client, so
    echo this is only fatal on a first install or for "Makefile stage" / "dist".
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
rem %ADDON%.toc is the pre-1.1.0 single TOC: an install from before the flavor split
rem still has it, and it lists a file set that predates Core\Compat.lua.
for %%x in (README.md .gitignore .pkgmeta Makefile Makefile.bat %ADDON%.toc) do (
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

rem ---------------------------------------------------------------------- stage

:stage
set "HAVELIBS=0"
for /d %%d in ("%ROOT%\Libs\*") do set "HAVELIBS=1"
if "!HAVELIBS!"=="0" (
    echo Libs\ is empty - the staged folders would not load. Populate it first ^("Makefile libs"^).
    exit /b 1
)
rem Expansion, its TOC suffix, and the client folder it belongs in.
for %%p in ("Midnight:Mainline:_retail_" "Mists:Mists:_classic_" "Vanilla:Vanilla:_classic_era_") do (
    for /f "tokens=1,2,3 delims=:" %%a in (%%p) do (
        set "OUT=%DIST%\%%a\%ADDON%"
        if exist "%DIST%\%%a" rmdir /s /q "%DIST%\%%a"
        mkdir "!OUT!"
        for %%d in (%INSTALL_DIRS% Libs) do (
            robocopy "%ROOT%\%%d" "!OUT!\%%d" /e /njh /njs /ndl /nc /ns /np >nul
            if errorlevel 8 echo   ERROR copying %%d& exit /b 1
        )
        for %%f in (embeds.xml Bindings.xml CHANGELOG.md) do copy /y "%ROOT%\%%f" "!OUT!\%%f" >nul
        copy /y "%ROOT%\%ADDON%_%%b.toc" "!OUT!\%ADDON%_%%b.toc" >nul
        if exist "!OUT!\Libs\README.md" del /q "!OUT!\Libs\README.md"
        if exist "!OUT!\Media\README.md" del /q "!OUT!\Media\README.md"
        echo   %%a  dist\%%a\%ADDON%  -^> %%c\Interface\AddOns\
    )
)
echo.
echo Copy each %ADDON% folder into that client's Interface\AddOns.
echo Each folder carries only its own TOC, so it loads on that expansion alone.
goto :eof

rem ----------------------------------------------------------------------- dist

:dist
set "HAVELIBS=0"
for /d %%d in ("%ROOT%\Libs\*") do set "HAVELIBS=1"
if "!HAVELIBS!"=="0" (
    echo Libs\ is empty - the zip would not load. Populate it first ^("Makefile libs"^).
    exit /b 1
)
if exist "%DIST%\%ADDON%" rmdir /s /q "%DIST%\%ADDON%"
if exist "%DIST%\%ADDON%-%VERSION%.zip" del /q "%DIST%\%ADDON%-%VERSION%.zip"
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
