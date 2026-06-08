const std = @import("std");

/// Print a table to the writer.
/// Headers is a slice of column names. Rows is a slice of slices of strings.
/// Respects --json flag for machine-readable output.
pub fn printTable(writer: anytype, headers: []const []const u8, rows: []const []const []const u8, json: bool) !void {
    if (json) {
        // JSON array of objects
        try writer.interface.writeAll("[\n");
        for (rows, 0..) |row, i| {
            try writer.interface.writeAll("  {");
            for (headers, 0..) |header, j| {
                if (j > 0) try writer.interface.writeAll(", ");
                try writer.interface.print("\"{s}\": \"{s}\"", .{ header, row[j] });
            }
            try writer.interface.writeAll("}");
            if (i < rows.len - 1) try writer.interface.writeAll(",");
            try writer.interface.writeAll("\n");
        }
        try writer.interface.writeAll("]\n");
        return;
    }

    // Calculate column widths
    var widths = try std.ArrayList(usize).initCapacity(std.heap.page_allocator, headers.len);
    defer widths.deinit(std.heap.page_allocator);
    for (headers) |h| {
        try widths.append(std.heap.page_allocator, h.len);
    }
    for (rows) |row| {
        for (row, 0..) |cell, j| {
            if (cell.len > widths.items[j]) {
                widths.items[j] = cell.len;
            }
        }
    }

    // Print headers
    for (headers, 0..) |header, j| {
        if (j > 0) try writer.interface.writeAll("  ");
        try writer.interface.print("{s}", .{header});
    }
    try writer.interface.writeAll("\n");

    // Print separator
    for (widths.items) |w| {
        var i: usize = 0;
        while (i < w) : (i += 1) {
            try writer.interface.writeAll("-");
        }
        try writer.interface.writeAll("  ");
    }
    try writer.interface.writeAll("\n");

    // Print rows
    for (rows) |row| {
        for (row, 0..) |cell, j| {
            if (j > 0) try writer.interface.writeAll("  ");
            try writer.interface.print("{s}", .{cell});
        }
        try writer.interface.writeAll("\n");
    }
}

/// Print a key-value list (for detail views).
pub fn printKeyValue(writer: anytype, pairs: []const struct { []const u8, []const u8 }, json: bool) !void {
    if (json) {
        try writer.interface.writeAll("{");
        for (pairs, 0..) |pair, i| {
            if (i > 0) try writer.interface.writeAll(", ");
            try writer.interface.print("\"{s}\": \"{s}\"", .{ pair[0], pair[1] });
        }
        try writer.interface.writeAll("}\n");
        return;
    }

    // Find the longest key for alignment
    var max_key_len: usize = 0;
    for (pairs) |pair| {
        if (pair[0].len > max_key_len) max_key_len = pair[0].len;
    }

    for (pairs) |pair| {
        try writer.interface.print("  {s}: {s}\n", .{ pair[0], pair[1] });
    }
}

test {
    _ = printTable;
    _ = printKeyValue;
}
