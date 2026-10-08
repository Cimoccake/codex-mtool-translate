@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul

rem Keep user paths quoted and preserve the translator's exit code.
if "%~1"=="" goto usage
if not "%~2"=="" goto multiple_files
set "sourcePath=%~f1"
if /i not "%~x1"==".json" goto invalid_file
if not exist "%sourcePath%" goto invalid_file
set "sourceAttributes=%~a1"
if /i "%sourceAttributes:~0,1%"=="d" goto invalid_file
if not exist "%~dp0translate.py" goto missing_script
if not exist "%~dp0requirements.txt" goto missing_dependencies

python -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>&1
if not errorlevel 1 goto use_python
py -3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>&1
if not errorlevel 1 goto use_py
call :message "\u672a\u627e\u5230 Python 3.11 \u6216\u66f4\u65b0\u7248\u672c\uff0c\u8bf7\u5b89\u88c5\u5e76\u6dfb\u52a0\u5230 PATH\u3002"
set "exitCode=1"
goto finish

:use_python
set "pythonCmd=python"
goto check_dependencies

:use_py
set "pythonCmd=py -3"

:check_dependencies
%pythonCmd% -c "from importlib.metadata import version; import sys; v=tuple(int(x) for x in version('rich').split('.')[:2]); sys.exit(0 if (14,1)<=v<(15,0) else 1)" >nul 2>&1
if not errorlevel 1 goto translate
call :message "\u6b63\u5728\u5b89\u88c5\u7ec8\u7aef\u8fdb\u5ea6\u663e\u793a\u4f9d\u8d56 Rich..."
%pythonCmd% -m pip install -r "%~dp0requirements.txt"
if errorlevel 1 goto dependency_failed

:translate
%pythonCmd% -X utf8 "%~dp0translate.py" "%sourcePath%"
set "exitCode=%errorlevel%"
if not "%exitCode%"=="0" goto failed
echo.
call :message "\u5904\u7406\u7ed3\u675f\u3002\u8bf7\u67e5\u770b\u7ffb\u8bd1\u3001\u6a21\u578b\u8df3\u8fc7\u3001\u9519\u8bef\u4fdd\u7559\u53ca\u9057\u7559\u53ef\u7591\u9879\u7edf\u8ba1\u3002"
call :message "\u7ec8\u7a3f\u65c1\u540c\u65f6\u751f\u6210 .skipped.json \u548c .errors.json \u4e24\u4efd\u68c0\u67e5\u526f\u672c\u3002"
call :message "\u4e2d\u65ad\u540e\u518d\u6b21\u62d6\u5165\u540c\u4e00\u6587\u4ef6\u5373\u53ef\u7eed\u8dd1\u3002"
goto finish

:dependency_failed
call :message "\u81ea\u52a8\u5b89\u88c5\u5931\u8d25\uff0c\u7ffb\u8bd1\u5c1a\u672a\u542f\u52a8\u3002\u8bf7\u624b\u52a8\u6267\u884c\u4ee5\u4e0b\u547d\u4ee4\u540e\u91cd\u8bd5\uff1a"
echo %pythonCmd% -m pip install -r "%~dp0requirements.txt"
set "exitCode=1"
goto finish

:failed
echo.
call :message "\u7a0b\u5e8f\u5df2\u505c\u6b62\uff0c\u9000\u51fa\u7801\uff1a%exitCode%\u3002\u5df2\u4fdd\u5b58\u7684\u6279\u6b21\u53ef\u7eed\u8dd1\u3002"
goto finish

:usage
call :message "\u8bf7\u628a\u4e00\u4e2a JSON \u6587\u4ef6\u62d6\u5230\u672c BAT \u6587\u4ef6\u4e0a\u3002"
call :message "\u9ed8\u8ba4\u56db\u8def\u5e76\u53d1\uff0c\u76f4\u63a5\u8fd4\u56de\u4e2d\u6587\u5e76\u6c47\u603b\u672f\u8bed\uff0c\u7ed3\u675f\u540e\u68c0\u67e5\u5e76\u4fee\u590d\u4e00\u8f6e\u3002"
call :message "\u8f93\u51fa\u4e3a\u540c\u76ee\u5f55\u4e0b\u7684 \u6587\u4ef6\u540d.zh-CN.json\uff0c\u539f\u6587\u4ef6\u4e0d\u8986\u76d6\u3002"
set "exitCode=0"
goto finish

:multiple_files
call :message "\u4e00\u6b21\u53ea\u80fd\u62d6\u5165\u4e00\u4e2a JSON \u6587\u4ef6\uff0c\u8bf7\u5206\u522b\u8fd0\u884c\u3002"
set "exitCode=1"
goto finish

:invalid_file
call :message "\u8f93\u5165\u5fc5\u987b\u662f\u4e00\u4e2a\u5b58\u5728\u7684 .json \u6587\u4ef6\u3002"
set "exitCode=1"
goto finish

:missing_dependencies
call :message "\u627e\u4e0d\u5230 requirements.txt\uff0c\u8bf7\u5c06\u5b83\u4e0e BAT \u548c translate.py \u653e\u5728\u540c\u4e00\u76ee\u5f55\u3002"
set "exitCode=1"
goto finish

:missing_script
call :message "\u627e\u4e0d\u5230 translate.py\uff0c\u8bf7\u5c06\u5b83\u4e0e\u672c BAT \u653e\u5728\u540c\u4e00\u76ee\u5f55\u3002"
set "exitCode=1"

:finish
echo.
pause
exit /b %exitCode%

:message
rem Print trusted Unicode escapes from %~1 as Chinese; return the print status.
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "[Console]::OutputEncoding = [Text.Encoding]::UTF8; [Console]::WriteLine([regex]::Unescape('%~1'))"
exit /b %errorlevel%
