# biobricks-script-lib

A library of shared scripts for use in brick data processing.

## Usage

Recommended usage as git submodule:

```shell
git submodule add https://github.com/biobricks-ai/biobricks-script-lib.git vendor/biobricks-script-lib
```

Set up environment:

```shell
# Get local path
localpath=$(pwd)
echo "Local path: $localpath"

eval $( $localpath/vendor/biobricks-script-lib/activate.sh )
```

When using `git clone`, be sure to use get all submodules:

```shell
git clone --recurse-submodules git@github.com:biobricks-ai/my-brick.git
```
