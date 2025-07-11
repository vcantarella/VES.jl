# PyGIMLi Installation Guide for VES.jl Testing

## Using Pixi

1. Install pixi:
    Check instructions at [Pixi Installation Guide](https://pixi.sh/latest/#installation).

2. Set folder for pixi project:
    ```bash
    pixi init /path/to/your/project
    cd /path/to/your/project
    ```
3. Configure pixi channels:
    ```bash
    pixi workspace channel add conda-forge gimli
    ```
4. Install PyGIMLi:
    ```bash
    pixi add pygimli
    ```


### Note for VES.jl Users

PyGIMLi is **only used for testing validation** - it's not required to use VES.jl for actual VES calculations. The core VES functionality is implemented in pure Julia and doesn't depend on PyGIMLi.
