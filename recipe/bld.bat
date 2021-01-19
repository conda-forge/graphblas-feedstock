# make sure CMake install goes in the right place
SET INSTALL="%PREFIX%"
SET CMAKE_OPTIONS="-DCMAKE_INSTALL_PREFIX=%PREFIX% -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON"

# make SuiteSparse
make library VERBOSE=1 JOBS=16
make install VERBOSE=1
