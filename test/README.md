# VES.jl Testing with PyGIMLi Integration

This package provides 1D Vertical Electrical Sounding (VES) forward modeling capabilities. The test suite includes both basic functionality tests and optional comparisons with PyGIMLi for validation.

## Test Configuration

The test suite is designed to work in two modes:

1. **Basic Mode**: Tests core functionality without external dependencies
2. **Validation Mode**: Compares results with PyGIMLi when available

## Running Tests

### Basic Tests (No Python Dependencies)

```bash
julia --project=. -e "using Pkg; Pkg.test()"
```

This will run all basic functionality tests without requiring Python or PyGIMLi.

### With PyGIMLi Validation (Optional)

To enable PyGIMLi comparison tests, you need to:

1. Install PyCall.jl (already included in test dependencies)
2. Install PyGIMLi using conda (PyGIMLi is not available via pip):

```bash
conda install -c conda-forge -c gimli pygimli
```

or

```bash
conda install -c gimli pygimli
```

**Note**: PyGIMLi requires a conda environment and is not available through pip. If you don't have conda, you can install it via:
- [Miniconda](https://docs.conda.io/en/latest/miniconda.html) (recommended)
- [Anaconda](https://www.anaconda.com/products/distribution)

Then run the tests as usual. The test suite will automatically detect PyGIMLi availability and run additional validation tests.

## Test Structure

- `test_analytical_ves.jl`: Main test file with VES function tests
- `runtests.jl`: Test runner that includes all test files

## Key Features Tested

1. **Integration Points**: Quality and accuracy of numerical integration
2. **Homogeneous Half-space**: Validates against analytical solution
3. **Multi-layer Models**: Tests complex layered earth models
4. **Error Handling**: Validates proper error handling for invalid inputs
5. **PyGIMLi Comparison**: Cross-validates with established library (when available)

## Expected Test Results

For a homogeneous half-space with 100 Ω·m resistivity, the apparent resistivity should be very close to 100 Ω·m for all electrode spacings.

For multi-layer models, the tests validate:
- Monotonic behavior for increasing/decreasing resistivity profiles
- Reasonable bounds on apparent resistivity values
- Consistency across different electrode spacings

## Troubleshooting

If PyGIMLi tests fail:
1. Check that PyGIMLi is properly installed: `python -c "import pygimli; print('OK')"`
2. Verify PyCall.jl is using the correct Python: `using PyCall; PyCall.python`
3. Run tests without PyGIMLi validation to ensure basic functionality works

The test suite is designed to be robust and will provide useful feedback even if PyGIMLi is not available.
