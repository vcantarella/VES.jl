# PyGIMLi Installation Guide for VES.jl Testing

The PyGIMLi installation can sometimes fail due to Python environment conflicts. Here are several approaches to get PyGIMLi working:

## Method 1: Manual Conda Environment (Recommended)

Create a separate conda environment specifically for PyGIMLi testing:

```bash
# Create a new conda environment with Python 3.11
conda create -n pygimli_env python=3.11 -c conda-forge

# Activate the environment
conda activate pygimli_env

# Install PyGIMLi
conda install pygimli -c gimli -c conda-forge

# Test the installation
python -c "import pygimli; print('PyGIMLi version:', pygimli.__version__)"
```

## Method 2: Using Mamba (Faster Alternative)

If you have mamba installed:

```bash
# Create environment with mamba
mamba create -n pygimli_env python=3.11 pygimli -c conda-forge -c gimli

# Activate and test
conda activate pygimli_env
python -c "import pygimli; print('PyGIMLi version:', pygimli.__version__)"
```

## Method 3: Docker Approach

For a completely isolated environment:

```bash
# Pull the official PyGIMLi Docker image
docker pull pygimli/pygimli

# Run container with mounted volume
docker run -it -v $(pwd):/workspace pygimli/pygimli bash
```

## Method 4: Fix Common Issues

If you get datetime module errors:

```bash
# Clean conda environment
conda clean --all

# Remove and reinstall problematic packages
conda remove python
conda install python=3.11 -c conda-forge
conda install pygimli -c gimli -c conda-forge --force-reinstall
```

## Running Tests with Manual PyGIMLi

Once you have PyGIMLi installed in a conda environment, you can run VES.jl tests by:

1. Activating your pygimli environment: `conda activate pygimli_env`
2. Starting Julia from that environment: `julia`
3. Running the tests: `using Pkg; Pkg.test("VES")`

## Troubleshooting

### Common Error Messages:

1. **"SystemError: initialization of _datetime did not return an extension module"**
   - This indicates a Python/conda environment conflict
   - Try Method 1 with a fresh environment

2. **"ImportError: No module named pygimli"**
   - PyGIMLi is not installed in the current environment
   - Make sure you're in the correct conda environment

3. **"CondaPkg.jl installation failed"**
   - CondaPkg is trying to create its own environment
   - This is normal - the test will fall back to analytical tests only

### Getting Help

If you continue to have issues:

1. Check the PyGIMLi documentation: https://www.pygimli.org/
2. Open an issue on the VES.jl repository
3. Include your OS, Python version, and full error message

### Note for VES.jl Users

PyGIMLi is **only used for testing validation** - it's not required to use VES.jl for actual VES calculations. The core VES functionality is implemented in pure Julia and doesn't depend on PyGIMLi.
