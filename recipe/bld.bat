mkdir build
cd build

cmake -G "NMake Makefiles" ^
      -D CMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
      -D CMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
      -D CMAKE_LIBRARY_OUTPUT_DIRECTORY=%LIBRARY_LIB% ^
      -D CMAKE_RUNTIME_OUTPUT_DIRECTORY=%LIBRARY_BIN% ^
      -D CMAKE_ARCHIVE_OUTPUT_DIRECTORY=%LIBRARY_LIB% ^
      -D CMAKE_BUILD_TYPE=Release ^
      -D BUILD_SHARED_LIBS=ON ^
      -D GBNCPUFEAT=ON ^
      -D GBAVX2=0 ^
      -D GBAVX512F=0 ^
      %SRC_DIR%
if errorlevel 1 exit /b 1

nmake
if errorlevel 1 exit /b 1

nmake install
if errorlevel 1 exit /b 1

