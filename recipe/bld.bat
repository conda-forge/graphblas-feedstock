mkdir build
cd build

cmake -G "NMake Makefiles" ^
      -D CMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
      -D CMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
      -D RUNTIME_OUTPUT_DIRECTORY=%LIBRARY_BIN% ^
      -D ARCHIVE_OUTPUT_DIRECTORY=%LIBRARY_LIB% ^
      -D CMAKE_BUILD_TYPE=Release ^
      -D BUILD_SHARED_LIBS=ON ^
      %SRC_DIR%
if errorlevel 1 exit /b 1

cmake --build . --target install
if errorlevel 1 exit /b 1

