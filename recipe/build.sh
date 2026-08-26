#!/bin/bash
set -ex
# Use JITINIT=2 (=run) to use pre-JIT kernels that don't need a compiler at runtime
export CMAKE_ARGS="${CMAKE_ARGS} \
  -DCMAKE_INSTALL_PREFIX=${PREFIX}\
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DGRAPHBLAS_JITINIT=2 \
  -DCMAKE_C_COMPILER=${CC} \
  -DCMAKE_CXX_COMPILER=${CXX} \
  -DSUITESPARSE_USE_FORTRAN=OFF \
  -DSUITESPARSE_USE_CUDA=OFF \
  -DSUITESPARSE_USE_OPENMP=ON \
  -DSUITESPARSE_USE_STRICT=ON \
"

# Why each of the settings above:
#
# CMAKE_C_COMPILER/CMAKE_CXX_COMPILER: pin the compiler CMake uses. Without
# this it can pick up ${PREFIX}/bin/${HOST}-cc, which the GCC toolchain
# installs as a symlink to ${HOST}-gcc. That is how graphblas 10.5.0 came to
# be compiled by GNU gcc 15.3.0 on osx-arm64 (`about["compiler_name"]`).
#
# SUITESPARSE_USE_FORTRAN=OFF: GraphBLAS compiles no Fortran. Saying so is
# the supported way to satisfy the common SuiteSparse config, and it lets the
# recipe drop {{ compiler('fortran') }}. That matters here: on osx-arm64,
# gfortran_osx-arm64 15.3.0 depends on gcc_osx-arm64 (14.3.0 depended on
# clang_osx-arm64), so requiring a Fortran compiler now drags a whole GCC
# toolchain into the build environment.
#
# SUITESPARSE_USE_CUDA=OFF: this one is *not* optional under strict mode.
# SuiteSparsePolicy.cmake defaults SUITESPARSE_USE_CUDA to ON, so strict mode
# would abort with "CUDA required for SuiteSparse but not found". GraphBLAS
# itself hard-sets GRAPHBLAS_USE_CUDA=OFF ("not deployed in production"), so
# turning the SuiteSparse-wide switch off loses nothing.
#
# SUITESPARSE_USE_OPENMP=ON: the default, stated explicitly so that the strict
# check below is actually load-bearing -- strict only errors on a *requested*
# feature that is missing.
#
# SUITESPARSE_USE_STRICT=ON: without it, GraphBLAS only *warns* when OpenMP
# is not found and happily builds a serial library (CMakeLists.txt ~line 177,
# and the warning at ~line 619). graphblas 10.5.0 shipped exactly that on
# osx-arm64 -- no libomp linkage, no omp symbols -- while still carrying
# `run: llvm-openmp`, so nothing about the package looked wrong. With strict
# on, a missing OpenMP fails the build instead. The only other features strict
# mode checks -- Fortran and CUDA -- are both explicitly disabled above.

# linux-aarch64 and linux-ppc64le are still cross-built on linux-64, but their
# tests do run, under emulation: .scripts/build_steps.sh only adds --no-test
# when the host platform is non-linux. osx-arm64 was the one config that hit
# that branch, and it builds natively now (conda-forge.yml), so the osx-64
# cross-toolchain workaround and its native-toolchain.cmake are gone with it.
if [[ "${target_platform}" != "${build_platform}" ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_CROSSCOMPILING=ON"
fi

if [[ "${target_platform}" != "linux"* ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DGBNCPUFEAT=1"
fi

# Show cmake output on failures
trap "cat $SRC_DIR/build/CMakeFiles/CMakeOutput.log $SRC_DIR/build/CMakeFiles/CMakeError.log" ERR
# make SuiteSparse
cmake -B build ${CMAKE_ARGS} .
cmake --build build --verbose --parallel "${CPU_COUNT:-1}"
cmake --install build

# Belt and braces for the OpenMP settings above. Strict mode fails the
# configure step when CMake cannot find OpenMP, but that only pins what CMake
# believed; this pins what actually got built. It inspects the binary instead
# of running it, so it costs nothing and works the same on every platform,
# cross-built or not. The test section cannot do this job: it only checks that
# files exist, so it passed cleanly on the serial 10.5.0 osx-arm64 build.
gb_lib=$(ls "${PREFIX}"/lib/libgraphblas.dylib "${PREFIX}"/lib/libgraphblas.so 2>/dev/null | head -n 1)
if [[ -z "${gb_lib}" ]]; then
  echo "ERROR: no libgraphblas found under ${PREFIX}/lib to check" >&2
  exit 1
fi
# ${NM} is the target-appropriate nm from the conda-forge toolchain. Try the
# dynamic symbol table first (ELF), then the plain one (Mach-O).
gb_syms=$("${NM:-nm}" -Du "${gb_lib}" 2>/dev/null || "${NM:-nm}" -u "${gb_lib}" 2>/dev/null || true)
if [[ -z "${gb_syms}" ]]; then
  echo "ERROR: could not read undefined symbols from ${gb_lib}" >&2
  echo "       The OpenMP check cannot run, so treat this as a recipe bug." >&2
  exit 1
fi
if ! printf '%s\n' "${gb_syms}" | grep -qE '(^|[^A-Za-z0-9_])_{0,3}(omp_|GOMP_|kmpc_)'; then
  echo "ERROR: ${gb_lib} references no OpenMP runtime symbols." >&2
  echo "       GraphBLAS was built serial. This is what shipped in 10.5.0 on" >&2
  echo "       osx-arm64: the package still depended on llvm-openmp, so nothing" >&2
  echo "       about it looked wrong from the outside." >&2
  exit 1
fi
echo "OpenMP check: ${gb_lib} references an OpenMP runtime"
