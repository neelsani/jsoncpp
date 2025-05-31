const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    // Configuration options
    //const version = "1.9.7";
    //const soversion = "27";
    const shared_lib = b.option(bool, "shared", "Build as shared library") orelse false;
    const build_tests = b.option(bool, "tests", "Build and run tests") orelse false;

    // Create the jsoncpp library
    const lib_type: std.builtin.LinkMode = if (shared_lib) .dynamic else .static;
    const jsoncpp = b.addLibrary(.{
        .name = "jsoncpp",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .linkage = lib_type,
    });

    if (shared_lib and target.result.abi == .msvc) {
        jsoncpp.root_module.addCMacro("JSON_DLL_BUILD", "");
    }

    // Add source files
    jsoncpp.addCSourceFiles(.{
        .files = &.{
            "src/lib_json/json_reader.cpp",
            "src/lib_json/json_value.cpp",
            "src/lib_json/json_writer.cpp",
        },
        .root = upstream.path(""),
    });

    // Add include directory
    jsoncpp.addIncludePath(upstream.path("include"));
    jsoncpp.linkLibCpp();

    // Install the library
    b.installArtifact(jsoncpp);

    // Install headers
    jsoncpp.installHeadersDirectory(upstream.path("include/json"), "json", .{});

    if (build_tests) {
        // Main test executable
        const jsoncpp_test = b.addExecutable(.{
            .name = "jsoncpp_test",
            .target = target,
            .optimize = optimize,
        });

        jsoncpp_test.addCSourceFiles(.{
            .files = &.{
                "src/test_lib_json/jsontest.cpp",
                "src/test_lib_json/main.cpp",
                "src/test_lib_json/fuzz.cpp",
            },
            .root = upstream.path(""),
        });

        jsoncpp_test.addIncludePath(upstream.path("include"));
        jsoncpp_test.linkLibrary(jsoncpp);
        jsoncpp_test.linkLibCpp();

        // Test runner executable
        const jsontestrunner = b.addExecutable(.{
            .name = "jsontestrunner",
            .target = target,
            .optimize = optimize,
        });

        jsontestrunner.addCSourceFile(.{
            .file = upstream.path("src/jsontestrunner/main.cpp"),
        });

        if (shared_lib and target.result.abi == .msvc) {
            jsontestrunner.root_module.addCMacro("JSON_DLL", "");
        }

        jsontestrunner.addIncludePath(upstream.path("include"));
        jsontestrunner.linkLibrary(jsoncpp);
        jsontestrunner.linkLibCpp();

        // Install test executables
        b.installArtifact(jsoncpp_test);
        b.installArtifact(jsontestrunner);

        // Create test step
        const test_step = b.step("test", "Run tests");

        // Unit test
        const run_jsoncpp_test = b.addRunArtifact(jsoncpp_test);
        test_step.dependOn(&run_jsoncpp_test.step);

        // Integration tests with Python runner
        const run_jsontests = b.addSystemCommand(&.{
            "python3", "-B", "test/runjsontests.py",
        });
        run_jsontests.addArtifactArg(jsontestrunner);
        run_jsontests.addArg("test/data");
        run_jsontests.setCwd(upstream.path(""));
        test_step.dependOn(&run_jsontests.step);

        // JSON checker tests
        const run_jsonchecker = b.addSystemCommand(&.{
            "python3", "-B", "test/runjsontests.py", "--with-json-checker",
        });
        run_jsonchecker.addArtifactArg(jsontestrunner);
        run_jsonchecker.addArg("test/data");
        run_jsonchecker.setCwd(upstream.path(""));
        test_step.dependOn(&run_jsonchecker.step);
    }
}
