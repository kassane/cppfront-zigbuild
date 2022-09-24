# cppfront-zigbuild

Simple demonstration of Herb Sutter cppfront <https://github.com/hsutter/cppfront> use with Zig BuildSystem

## How to use

```shell
# install XMake and a C++20 compiler
> git clone https://github.com/kassane/cppfront-zigbuild.git
> cd cppfront-zigbuild
> zig build # to build
> zig build cppfront # to run the cppfront and generate example/hello.cpp
> zig build hello_cpp # to run C++ example
``` 