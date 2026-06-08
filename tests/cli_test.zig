const std = @import("std");
const cli = @import("cli");

test "parseArgs: no args" {
    // TODO: Test that empty args returns error
}

test "parseArgs: context command" {
    // TODO: Test that "context" parses to Command.context
}

test "parseArgs: issue view with number" {
    // TODO: Test that "issue view 123" parses number=123
}

test "parseArgs: --provider flag" {
    // TODO: Test that --provider gitlab overrides provider
}

test "parseArgs: --help flag" {
    // TODO: Test that --help returns error.HelpRequested
}
