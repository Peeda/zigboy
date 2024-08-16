const std = @import("std");
const json = std.json;
const testing = std.testing;

test "json_parsing" {
    const alloc = testing.allocator;

    // Deserialize JSON
    //const file = try std.fs.cwd().openFile("z80/v1/00.json", .{});
    //defer file.close();
    //const json_str = try file.reader().readAllAlloc(alloc, 1e10);
    //defer alloc.free(json_str);

    const json_str = 
    \\   {
    \\    "name": "00 0000",
    \\    "initial": {
    \\        "pc": 19935,
    \\        "sp": 59438,
    \\        "a": 110,
    \\        "b": 185,
    \\        "c": 144,
    \\        "d": 208,
    \\        "e": 190,
    \\        "f": 250,
    \\        "h": 131,
    \\        "l": 147,
    \\        "i": 166,
    \\        "r": 16,
    \\        "ei": 1,
    \\        "wz": 62861,
    \\        "ix": 35859,
    \\        "iy": 45708,
    \\        "af_": 30257,
    \\        "bc_": 17419,
    \\        "de_": 13842,
    \\        "hl_": 28289,
    \\        "im": 0,
    \\        "p": 1,
    \\        "q": 0,
    \\        "iff1": 1,
    \\        "iff2": 1,
    \\        "ram": [
    \\            [
    \\                19935,
    \\                0
    \\            ]
    \\        ]
    \\    },
    \\    "final": {
    \\        "a": 110,
    \\        "b": 185,
    \\        "c": 144,
    \\        "d": 208,
    \\        "e": 190,
    \\        "f": 250,
    \\        "h": 131,
    \\        "l": 147,
    \\        "i": 166,
    \\        "r": 17,
    \\        "af_": 30257,
    \\        "bc_": 17419,
    \\        "de_": 13842,
    \\        "hl_": 28289,
    \\        "ix": 35859,
    \\        "iy": 45708,
    \\        "pc": 19936,
    \\        "sp": 59438,
    \\        "wz": 62861,
    \\        "iff1": 1,
    \\        "iff2": 1,
    \\        "im": 0,
    \\        "ei": 0,
    \\        "p": 0,
    \\        "q": 0,
    \\        "ram": [
    \\            [
    \\                19935,
    \\                0
    \\            ]
    \\        ]
    \\    },
    \\    "cycles": [
    \\        [
    \\            19935,
    \\            null,
    \\            "----"
    \\        ],
    \\        [
    \\            19935,
    \\            null,
    \\            "r-m-"
    \\        ],
    \\       [
    \\            42512,
    \\            0,
    \\            "----"
    \\        ],
    \\        [
    \\            42512,
    \\            null,
    \\           "----"
    \\        ]
    \\    ]
    \\}
    ;

    const GbState = struct {
        pc: u16,
        sp: u16,
        a: u8, b: u8, c: u8, d: u8, e: u8, f:u8, h:u8, l:u8,
        af_: u16, bc_:u16, de_:u16, hl_:u16,
    };
    const TestData = struct {
        name: []const u8,
        initial: GbState,
        final: GbState,
    };
    const parsed = try json.parseFromSlice(TestData, alloc, json_str, .{.ignore_unknown_fields = true});
    defer parsed.deinit();

    const value = parsed.value;
    const expected_initial = GbState {
        .pc = 19935, .sp = 59438,
        .a = 110, .b = 185, .c = 144, .d = 208,
        .e = 190, .f = 250, .h = 131, .l = 147,
        .af_ = 30257, .bc_ = 17419, 
        .de_ = 13842, .hl_ = 28289,
    };
    const expected_final = GbState {
        .pc = 19936, .sp = 59438,
        .a = 110, .b = 185, .c = 144, .d = 208,
        .e = 190, .f = 250, .h = 131, .l = 147,
        .af_ = 30257, .bc_ = 17419, 
        .de_ = 13842, .hl_ = 28289,
    };
    try testing.expectEqual(expected_initial, value.initial);
    try testing.expectEqual(expected_final, value.final);
    try testing.expectEqualStrings("00 0000", value.name);
}
