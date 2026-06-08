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

    // If no args, show help
    if (args.len < 2) {
        try cli.printHelp(&stdout);
        return;
    }

    // Parse global flags + dispatch subcommand
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

    // Resolve context (provider, account, owner, repo)
    var ctx = context.resolve(allocator, result.provider_override, result.provider_url) catch |err| {
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
            error.UnknownProvider => {
                try stderr.interface.print("error: could not detect provider from remotes\n", .{});
                try stderr.interface.print("Run 'gctl context' to debug, or use --provider.\n", .{});
                stderr.end() catch {};
                std.process.exit(1);
            },
            else => return err,
        }
    };
    defer ctx.deinit(allocator);

    // Load auth token for the resolved provider
    const token = auth.getToken(allocator, ctx.provider, result.account) catch |err| {
        switch (err) {
            error.NoToken => {
                try stderr.interface.print("error: no token for {s}\n", .{ctx.provider});
                try stderr.interface.print("Set {s}_TOKEN or run 'gctl auth login {s}'.\n", .{ upperProvider(ctx.provider), ctx.provider });
                stderr.end() catch {};
                std.process.exit(1);
            },
            else => return err,
        }
    };
    // Note: token from env vars points to process memory, no need to free.

    // Look up provider & execute command
    try providers.execute(allocator, &stdout, &stderr, ctx, token, result.command, result.number, result.provider_url, result.name, result.description, result.private, result.labels);
}

fn upperProvider(name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, "github")) return "GITHUB";
    if (std.mem.eql(u8, name, "gitlab")) return "GITLAB";
    if (std.mem.eql(u8, name, "gitea")) return "GITEA";
    if (std.mem.eql(u8, name, "custom")) return "TOKEN";
    return "TOKEN";
}
