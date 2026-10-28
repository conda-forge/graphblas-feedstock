
//------------------------------------------------------------------------------
// graphblas-feedstock: FactoryKernels re-enabled for conda-forge
//------------------------------------------------------------------------------

// build.sh and build.bat append this file to Source/GB_control.h.  Upstream
// compiles these semirings out to save code size, but python-graphblas uses
// them by default.  Its JIT control is "run" (use FactoryKernels and cached
// JIT kernels, compile nothing new), so without these it runs the generic
// kernels, 2x to 8x slower.  The kernels test defined(GxB_NO_...), so #undef
// is enough, and it is a no-op if upstream turns one back on.

// ANY_FIRST and ANY_SECOND (off since v10.0.0): permutation and selection
// products such as P*A, and GrB_reduce to a vector with the ANY monoid.  With
// the JIT off, ANY_SECOND_FP64 applying a 1e6 permutation to 1e7 entries took
// 42 ms (generic) vs 15 ms for MIN_SECOND_FP64 (factory).
#undef GxB_NO_ANY_FIRST_BOOL
#undef GxB_NO_ANY_FIRST_INT32
#undef GxB_NO_ANY_FIRST_INT64
#undef GxB_NO_ANY_FIRST_UINT32
#undef GxB_NO_ANY_FIRST_UINT64
#undef GxB_NO_ANY_FIRST_FP32
#undef GxB_NO_ANY_FIRST_FP64
#undef GxB_NO_ANY_SECOND_BOOL
#undef GxB_NO_ANY_SECOND_INT32
#undef GxB_NO_ANY_SECOND_INT64
#undef GxB_NO_ANY_SECOND_UINT32
#undef GxB_NO_ANY_SECOND_UINT64
#undef GxB_NO_ANY_SECOND_FP32
#undef GxB_NO_ANY_SECOND_FP64

// The BOOL counterparts (MAX and PLUS on BOOL are renamed to LOR)
#undef GxB_NO_LOR_FIRST_BOOL
#undef GxB_NO_LOR_SECOND_BOOL

// GrB_reduce to a vector computes A*x with the (monoid, FIRST) semiring.
// With the JIT off vs on, reducing 1e7 entries rowwise: BOOL LOR 2.4 vs
// 0.8 ms, UINT64 PLUS 5.0 vs 1.2 ms, FP64 TIMES 4.8 vs 1.7 ms.  With the
// above, these cover every BOOL monoid.
#undef GxB_NO_LAND_FIRST_BOOL
#undef GxB_NO_LXOR_FIRST_BOOL
#undef GxB_NO_EQ_FIRST_BOOL
#undef GxB_NO_PLUS_FIRST_UINT32
#undef GxB_NO_PLUS_FIRST_UINT64
#undef GxB_NO_TIMES_FIRST_INT32
#undef GxB_NO_TIMES_FIRST_INT64
#undef GxB_NO_TIMES_FIRST_UINT32
#undef GxB_NO_TIMES_FIRST_UINT64
#undef GxB_NO_TIMES_FIRST_FP32
#undef GxB_NO_TIMES_FIRST_FP64
#undef GxB_NO_PLUS_FIRST_FC32
#undef GxB_NO_PLUS_FIRST_FC64
#undef GxB_NO_TIMES_FIRST_FC32
#undef GxB_NO_TIMES_FIRST_FC64

// PLUS_FIRST's flipped pair for unsigned sums through a selector, P*A, which
// mxm computes as PLUS_SECOND when the matrices are stored by row.  UINT32
// 8.9 vs 3.7 ms and UINT64 8.5 vs 4.1 ms with the JIT off vs on.
#undef GxB_NO_PLUS_SECOND_UINT32
#undef GxB_NO_PLUS_SECOND_UINT64
