const std = @import("std");
const cli = @import("cli");
const context = @import("context");
const providers = @import("providers");
const config = @import("config");
const auth = @import("auth");
const http = @import("http");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stdout_file = std.fs.File.stdout();
    var stdout_buf: [4096]u8 = undefined;
    var stdout = stdout_file.writer(&stdout_buf);
    const stderr_file = std.fs.File.stderr();
    var stderr_buf: [4096]u8 = undefined;
    var stderr = stderr_file.writer(&stderr_buf);
    defer stdout.end() catch {};
    defer stderr.end() catch {};

    if (args.len < 2) {
        try cli.printHelp(&stdout);
        return;
    }

    const result = cli.parseArgs(allocator, args[1..]) catch |err| {
        switch (err) {
            error.HelpRequested => {
                try cli.printHelp(&stdout);
                return;
            },
            error.InvalidCommand => {
                try stderr_file.writeAll("error: unknown command '");
                try stderr_file.writeAll(args[1]);
                try stderr_file.writeAll("'\nRun 'gctl --help' for usage.\n");
                std.process.exit(1);
            },
            else => return err,
        }
    };

    // Resolve all contexts from git remotes
    const ctxs = context.resolve(allocator, result.provider_override, result.provider_url) catch |err| {
        switch (err) {
            error.NoGitRepo => {
                try stderr.interface.print("error: not a git repository\n", .{});
                try stderr.interface.print("Run gctl inside a git repo, or use --provider to specify one.\n", .{});
                stderr.end() catch {};
                std.process.exit(1);
            },
            error.NoRemote => {
                try stderr.interface.print("error: no git remote found\n", .{});
                try stderr.interface.print("Add a remote with 'git remote add origin <url>'.\n", .{});
                stderr.end() catch {};
                std.process.exit(1);
            },
            else => return err,
        }
    };
    defer context.contextsDeinit(ctxs, allocator);

    // Use first context for token resolution
    const first_ctx = ctxs[0];
    const token = blk: {
        if (result.command == .doctor) {
            break :blk auth.getToken(allocator, first_ctx.provider, result.account) catch null;
        }
        break :blk (auth.getToken(allocator, first_ctx.provider, result.account) catch |err| {
            switch (err) {
                error.NoToken => {
                    try stderr.interface.print("error: no token for {s}\n", .{first_ctx.provider});
                    try stderr.interface.print("Set {s}_TOKEN or run 'gctl auth login {s}'.\n", .{ upperProvider(first_ctx.provider), first_ctx.provider });
                    stderr.end() catch {};
                    std.process.exit(1);
                },
                else => return err,
            }
        });
    };

    try providers.execute(allocator, &stdout, &stderr, ctxs, token, result.command, result.number, result.provider_url, result.path, result.method, result.name, result.description, result.private, result.labels, result.title, result.base, result.quick, result.all, result.source, result.target);
}

fn upperProvider(name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, "github")) return "GITHUB";
    if (std.mem.eql(u8, name, "gitlab")) return "GITLAB";
    if (std.mem.eql(u8, name, "gitea")) return "GITEA";
    if (std.mem.eql(u8, name, "custom")) return "TOKEN";
    return "TOKEN";
}
