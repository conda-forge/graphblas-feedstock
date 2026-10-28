#!/bin/bash
set -ex
# Use JITINIT=2 (=run) to use pre-JIT kernels that don't need a compiler at runtime
export CMAKE_ARGS="${CMAKE_ARGS} \
  -DCMAKE_INSTALL_PREFIX=${PREFIX}\
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DGRAPHBLAS_JITINIT=2 \
  -DCMAKE_C_COMPILER=${CC} \
  -DSUITESPARSE_USE_FORTRAN=OFF \
  -DSUITESPARSE_USE_CUDA=OFF \
  -DSUITESPARSE_USE_OPENMP=ON \
  -DSUITESPARSE_USE_STRICT=ON \
"

# Why each of the settings above:
#
# CMAKE_C_COMPILER: pin the compiler CMake uses. Without this it can pick up
# ${PREFIX}/bin/${HOST}-cc, which the GCC toolchain installs as a symlink to
# ${HOST}-gcc. That is how graphblas 10.5.0 came to be compiled by GNU gcc
# 15.3.0 on osx-arm64 (`about["compiler_name"]`). There is no C++ compiler to
# pin: with Fortran and CUDA off, GraphBLAS is C only.
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

# linux-ppc64le is the only config still cross-built (on linux-64), and its
# tests run anyway, under emulation: .scripts/build_steps.sh only adds
# `--test skip` when the host platform is non-linux. osx-arm64 was the one
# config that ever hit that branch; it builds natively now, as does linux-aarch64
# (conda-forge.yml), so the osx-64 cross-toolchain workaround and its
# native-toolchain.cmake are gone with it.
if [[ "${target_platform}" != "${build_platform}" ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_CROSSCOMPILING=ON"
fi

# No GBNCPUFEAT on macOS anymore. It turned off Google's cpu_features (a
# workaround from the 6.1.4 betas), which left osx-64 with no run-time
# AVX2/AVX512F detection, so its AVX kernels were never used. The PyPI wheels
# build cpu_features on macOS. On osx-arm64 it has nothing to detect.

# Compile in FactoryKernels that python-graphblas needs; see factory_kernels.h
cat "${RECIPE_DIR}/factory_kernels.h" >> Source/GB_control.h

# Use CMake's default generator (Unix Makefiles), not Ninja. When
# cross-compiling, GraphBLAS builds a native grb_jitpackage partway through the
# build, then re-runs CMake so that libgraphblas includes the GB_JITpackage.c
# it generates (JITpackage/CMakeLists.txt). Make picks up the re-generated
# build files; Ninja carries on with the old build.ninja. That is how the
# linux-ppc64le build of 10.5.2 (build 0) shipped a libgraphblas with
# GB_JITpackage_index_get and GB_JITpackage_nfiles_get undefined, which fails
# to load. The undefined-symbol check at the end guards against this.

# Show cmake output on failures (CMake >=3.26 writes only this log)
trap "cat $SRC_DIR/build/CMakeFiles/CMakeConfigureLog.yaml" ERR
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

# Every GB_/GrB_/GxB_ symbol that libgraphblas references must be defined in
# libgraphblas itself. A shared library on Linux links fine with undefined
# symbols and only fails when it is loaded, so this is how the 10.5.2
# linux-ppc64le build 0 got out without its JIT package (see the note on the
# generator above). Weak references are fine: on Linux, zstd makes its
# GB_ZSTD_trace_* hooks weak and calls them only if they are defined.
gb_undef=$(printf '%s\n' "${gb_syms}" | grep -vE '^[[:space:]]*[wv][[:space:]]' | grep -E '(^|[[:space:]])_?(GB|GrB|GxB)_[A-Za-z0-9_]*$' || true)
if [[ -n "${gb_undef}" ]]; then
  echo "ERROR: ${gb_lib} references GraphBLAS symbols it does not define:" >&2
  printf '%s\n' "${gb_undef}" >&2
  exit 1
fi
echo "Undefined-symbol check: ${gb_lib} defines every GraphBLAS symbol it references"
