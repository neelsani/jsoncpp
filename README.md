# jsoncpp Zig Build Integration

Zig build system integration for [jsoncpp](https://github.com/open-source-parsers/jsoncpp) 

## Quick Start

1. Add to your project:
```bash
zig fetch --save git+https://github.com/neelsani/jsoncpp
```
2. Add to your build.zig

```zig
const jsoncpp_dep = b.dependency("jsoncpp", .{
    .target = target,
    .optimize = optimize,
});
const lib = jsoncpp_dep.artifact("jsoncpp");

//then link it to your exe

exe.linkLibrary(lib);
```