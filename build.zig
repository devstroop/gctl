const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ── Create all modules once, in dependency order ──────────────

    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    const auth_mod = b.createModule(.{
        .root_source_file = b.path("src/auth/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "config", .module = config_mod },
        },
    });

    const http_mod = b.createModule(.{
        .root_source_file = b.path("src/http/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "auth", .module = auth_mod },
        },
    });

    const cli_mod = b.createModule(.{
        .root_source_file = b.path("src/cli/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    const context_mod = b.createModule(.{
        .root_source_file = b.path("src/context/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "config", .module = config_mod },
        },
    });

    const providers_mod = b.createModule(.{
        .root_source_file = b.path("src/providers/mod.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "http", .module = http_mod },
            .{ .name = "auth", .module = auth_mod },
            .{ .name = "context", .module = context_mod },
            .{ .name = "cli", .module = cli_mod },
        },
    });

    // ── gctl executable ───────────────────────────────────────────

    const exe = b.addExecutable(.{
        .name = "gctl",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "cli", .module = cli_mod },
                .{ .name = "context", .module = context_mod },
                .{ .name = "providers", .module = providers_mod },
                .{ .name = "config", .module = config_mod },
                .{ .name = "auth", .module = auth_mod },
                .{ .name = "http", .module = http_mod },
            },
        }),
    });

    b.installArtifact(exe);

    // ── Run step ──────────────────────────────────────────────────

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // ── Tests ─────────────────────────────────────────────────────

    const test_step = b.step("test", "Run all tests");

    // Unit tests from source modules (inline test {} blocks)
    {
        const main_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "cli", .module = cli_mod },
                    .{ .name = "context", .module = context_mod },
                    .{ .name = "providers", .module = providers_mod },
                    .{ .name = "config", .module = config_mod },
                    .{ .name = "auth", .module = auth_mod },
                    .{ .name = "http", .module = http_mod },
                },
            }),
        });
        const run_tests = b.addRunArtifact(main_tests);
        test_step.dependOn(&run_tests.step);
    }

    // Integration test files
    const test_files = [_][]const u8{ "context_test", "cli_test", "github_test" };
    for (test_files) |name| {
        const test_path = b.fmt("tests/{s}.zig", .{name});
        const test_exe = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_path),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "context", .module = context_mod },
                    .{ .name = "cli", .module = cli_mod },
                    .{ .name = "providers", .module = providers_mod },
                },
            }),
        });
        const run_test = b.addRunArtifact(test_exe);
        test_step.dependOn(&run_test.step);
    }
}
