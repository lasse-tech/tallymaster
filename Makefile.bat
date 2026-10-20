@echo off
setlocal EnableDelayedExpansion

rem Windows counterpart to the Makefile; usage: Makefile <target>

set "ADDON=Tallymaster"
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
if not defined FLAVOR set "FLAVOR=_retail_"

set "INSTALL_DIRS=Core UI Locales Skin Media"
set "TOCS=%ADDON%_Mainline.toc %ADDON%_Mists.toc %ADDON%_Vanilla.toc"
set "INSTALL_FILES=%TOCS% embeds.xml Bindings.xml CHANGELOG.md LICENSE"
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
if /i "%TARGET_NAME%"=="luacheck"   goto :luacheck
if /i "%TARGET_NAME%"=="libs"       goto :libs
if /i "%TARGET_NAME%"=="fetch-libs" goto :fetchlibs
if /i "%TARGET_NAME%"=="debug"      goto :install
if /i "%TARGET_NAME%"=="install"    goto :install
if /i "%TARGET_NAME%"=="uninstall"  goto :uninstall
if /i "%TARGET_NAME%"=="prune-libs" goto :prunelibs
if /i "%TARGET_NAME%"=="stage"      goto :stage
if /i "%TARGET_NAME%"=="dist"       goto :dist
if /i "%TARGET_NAME%"=="clean"      goto :clean
if /i "%TARGET_NAME%"=="distclean"  goto :distclean
if /i "%TARGET_NAME%"=="purge"      goto :purge
if /i "%TARGET_NAME%"=="deploy"     goto :deploy

echo unknown target "%TARGET_NAME%"
echo.
call :help
exit /b 1

rem help: list the targets
:help
echo %ADDON% %VERSION%
for /f "tokens=1,*" %%a in ('findstr /b /r /c:"rem [abcdefghijklmnopqrstuvwxyz][abcdefghijklmnopqrstuvwxyz0123456789-]*: " "%~f0"') do echo   %%b
echo.
echo Variables ^(set NAME=value^): FLAVOR, WOW_RETAIL_ADDON_FOLDER, WOW_DIR
goto :eof

rem version: print the addon version
:version
echo %VERSION%
goto :eof

rem ---------------------------------------------------------------- locate WoW

:findwow
rem Search order: WOW_RETAIL_ADDON_FOLDER (retail), then WOW_DIR, registry, candidates, WoW folder above it
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

rem check: syntax-check every Lua file
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
echo no lua, luac or lupa found
exit /b 1

rem ----------------------------------------------------------------- fetch-libs

rem .pkgmeta externals -> "<path> <url>" via PowerShell
rem fetch-libs: download the .pkgmeta externals into Libs\ (needs svn and git)
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

rem only ignore entries inside a fetched external
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

rem check-tocs: flavor TOCs differ only in ## Interface:, every listed file exists
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

rem luacheck: static analysis, any warning fails
:luacheck
where luacheck >nul 2>&1
if errorlevel 1 (
    echo luacheck not found - install it ^(luarocks install luacheck^)
    exit /b 1
)
pushd "%ROOT%"
luacheck --no-color -q .
set "RC=!errorlevel!"
popd
if not "!RC!"=="0" exit /b 1
echo luacheck: no warnings
goto :eof

rem lint: check, check-tocs, luacheck (BLOCKER; Makefile comments: make lint)
:lint
call "%~f0" check
if errorlevel 1 exit /b 1
call "%~f0" check-tocs
if errorlevel 1 exit /b 1
call "%~f0" luacheck
if errorlevel 1 exit /b 1
goto :eof

rem ----------------------------------------------------------------------- libs

rem libs: report embedded libraries missing from Libs\
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
    echo run "Makefile fetch-libs"
)
goto :eof

rem -------------------------------------------------------------------- install

rem debug: same as install (Lua has no separate debug build)
rem install: copy the addon into the live client (FLAVOR picks the client)
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

for %%x in (design scripts .claude .git dist) do (
    if exist "%TARGET%\%%x\" (
        echo   removing stray %%x\ ^(not part of the addon^)
        rmdir /s /q "%TARGET%\%%x"
    )
)
rem %ADDON%.toc: pre-1.1.0 single TOC
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

rem uninstall: remove the addon from the client, SavedVariables stay
:uninstall
call :findwow || exit /b 1
if not exist "%TARGET%\" (
    echo not installed: %TARGET%
    goto :eof
)
rmdir /s /q "%TARGET%"
echo removed %TARGET%
goto :eof

rem ----------------------------------------------------------------- prune-libs

rem prune-libs: delete installed libraries embeds.xml no longer lists
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

rem stage: dist\<expansion>\Tallymaster per client, each with only its own TOC
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
        for %%f in (embeds.xml Bindings.xml CHANGELOG.md LICENSE) do copy /y "%ROOT%\%%f" "!OUT!\%%f" >nul
        copy /y "%ROOT%\%ADDON%_%%b.toc" "!OUT!\%ADDON%_%%b.toc" >nul
        echo   %%a  dist\%%a\%ADDON%  -^> %%c\Interface\AddOns\
    )
)
goto :eof

rem ----------------------------------------------------------------------- dist

rem dist: build dist\Tallymaster-<version>.zip with all three TOCs
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

rem clean: remove dist\
:clean
if exist "%DIST%" rmdir /s /q "%DIST%"
echo cleaned
goto :eof

rem distclean: clean and empty Libs\
:distclean
call :clean
if exist "%ROOT%\Libs" rmdir /s /q "%ROOT%\Libs"
echo removed Libs\
goto :eof

rem ---------------------------------------------------------------------- purge

rem purge: uninstall and delete the SavedVariables
:purge
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

rem deploy: none - releases are published by pushing a v* tag to GitHub
:deploy
echo No deploy: a v* tag pushed to github.com/lasse-tech/tallymaster publishes the release.
goto :eof
