:: No CMAKE_*_OUTPUT_DIRECTORY overrides: they wrote build products straight
:: into the prefix, which shipped grb_jitpackage.exe (a build-time tool) and
:: graphblas.exp.  `cmake --install` puts everything where it belongs.
::
:: No GBNCPUFEAT either: GB_compiler.h always defines it for _WIN32.

type "%RECIPE_DIR%\factory_kernels.h" >> Source\GB_control.h
if errorlevel 1 exit /b 1

cmake -G Ninja ^
      -D CMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
      -D CMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
      -D CMAKE_BUILD_TYPE=Release ^
      -D BUILD_SHARED_LIBS=ON ^
      -D GRAPHBLAS_JITINIT=2 ^
      -D SUITESPARSE_USE_FORTRAN=OFF ^
      -D SUITESPARSE_USE_CUDA=OFF ^
      -D SUITESPARSE_USE_OPENMP=ON ^
      -D SUITESPARSE_USE_STRICT=ON ^
      -B build ^
      -S %SRC_DIR%
if errorlevel 1 exit /b 1

cmake --build build --parallel %CPU_COUNT%
if errorlevel 1 exit /b 1

cmake --install build
if errorlevel 1 exit /b 1
