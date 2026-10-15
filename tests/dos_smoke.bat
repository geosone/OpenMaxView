@echo off
MAXVTSR.COM
DVPROBE.EXE
if errorlevel 1 goto failed
echo Open MaxView DOS smoke test passed.
goto end
:failed
echo Open MaxView DOS smoke test FAILED.
:end
