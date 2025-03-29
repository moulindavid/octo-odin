tools\sokol-shdc.exe -i shader.glsl -o shader.odin -l hlsl5 -f sokol_odin
@if %ERRORLEVEL% neq 0 exit /b 1

odin build . -debug
@if %ERRORLEVEL% neq 0 exit /b 1

@if "%~1" == "run" (
	rew.exe
)