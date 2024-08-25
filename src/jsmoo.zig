//jsmoo tests for the cpu
const std = @import("std");
const json = std.json;
const testing = std.testing;

const GbState = struct {
    pc: u16,
    sp: u16,
    a: u8, b: u8, c: u8, d: u8, e: u8, f:u8, h:u8, l:u8,
    ram: []const [2]u16 = ([_][2]u16 {[_]u16{0, 0}})[0..],
};
const TestData = struct {
    name: []const u8,
    initial: GbState,
    final: GbState,
    //not actually reading the bus states per cycle
    cycles: []json.Value,
};
fn run_test(json_value: []TestData) !void {
    for (json_value) |test_data| {
        //std.debug.print("{s}\n", .{test_data.name});
        var mem = @import("bus.zig").FlatMem {};
        var cpu = @import("cpu.zig").CPUFlatMem {.bus = &mem};

        //set gb values according to initial state
        const initial = test_data.initial;
        var reg_cnt:u8 = 0;
        inline for (std.meta.fields(GbState)) |field| {
            if (field.type == u8) {
                @field(cpu.regs, field.name) = @field(initial, field.name);
                reg_cnt += 1;
            }
        }
        try testing.expectEqual(reg_cnt, 8);
        cpu.sp = initial.sp;
        cpu.pc = initial.pc;
        for (initial.ram) |entry| {
            cpu.bus.write(entry[0], @intCast(entry[1]));
        }

        var cycles_left = test_data.cycles.len;
        while (cycles_left > 0) {
            const t_cycles = cpu.step();
            try testing.expect(t_cycles % 4 == 0);
            cycles_left -= t_cycles / 4;
        }
        try testing.expectEqual(0, cycles_left);

        const final = test_data.final;
        inline for (std.meta.fields(GbState)) |field| {
            if (field.type == u8) {
                try testing.expectEqual(@field(final, field.name), @field(cpu.regs, field.name));
            }
        }
        try testing.expectEqual(final.sp, cpu.sp);
        try testing.expectEqual(final.pc, cpu.pc);
        for (final.ram) |entry| {
            try testing.expectEqual(entry[1], cpu.bus.read(entry[0]));
        }
        //TODO: maybe check to see that there aren't extra writes in arbitrary ram locations
    }
}
test "jsmoo" {
    const illegal = [_]u8 {0xD3, 0xDB, 0xDD, 0xE3, 0xE4, 0xEB, 0xEC, 0xED, 0xF4, 0xFC, 0xFD, 0xCB};
    const unimplemented = [_]u8 {0x10, 0x76};
    const exclude = illegal ++ unimplemented;
    outer: for (0x00..0xFF+1) |opcode| {
        for (exclude) |excluded| {
            if (opcode == excluded) continue :outer;
        }
        const alloc = testing.allocator;
        const file_name = try std.fmt.allocPrint(alloc, "tests/sm83/v1/{x:0>2}.json", .{opcode});
        defer alloc.free(file_name);
        const file = try std.fs.cwd().openFile(file_name, .{});
        defer file.close();
        const json_str = try file.reader().readAllAlloc(alloc, 1e10);
        defer alloc.free(json_str);

        const parsed = try json.parseFromSlice([]TestData, alloc, json_str, .{.ignore_unknown_fields = true});
        defer parsed.deinit();
        const json_data = parsed.value;
        try run_test(json_data);
    }
}
//test "jsmoo cb opcodes" {
//    for (0..0xFF+1) |opcode| {
//        const alloc = testing.allocator;
//        const file_name = try std.fmt.allocPrint(alloc, "tests/sm83/v1/cb {x:0>2}.json", .{opcode});
//        defer alloc.free(file_name);
//        const file = try std.fs.cwd().openFile(file_name, .{});
//        defer file.close();
//        const json_str = try file.reader().readAllAlloc(alloc, 1e10);
//        defer alloc.free(json_str);
//
//        const parsed = try json.parseFromSlice([]TestData, alloc, json_str, .{.ignore_unknown_fields = true});
//        defer parsed.deinit();
//        const json_data = parsed.value;
//        try run_test(json_data);
//    }
//}
test "json_parsing" {
    const alloc = testing.allocator;
    //NOTE: this is a modified version of a test from jsmoo
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
    \\        "a": 111,
    \\        "b": 182,
    \\        "c": 143,
    \\        "d": 204,
    \\        "e": 195,
    \\        "f": 255,
    \\        "h": 137,
    \\        "l": 148,
    \\        "i": 166,
    \\        "r": 17,
    \\        "af_": 30251,
    \\        "bc_": 17412,
    \\        "de_": 13843,
    \\        "hl_": 28284,
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
    \\                19936,
    \\                1
    \\            ],
    \\            [
    \\                1234,
    \\                5
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

    const parsed = try json.parseFromSlice(TestData, alloc, json_str, .{.ignore_unknown_fields = true});
    defer parsed.deinit();

    const value = parsed.value;
    const expected_initial = GbState {
        .pc = 19935, .sp = 59438,
        .a = 110, .b = 185, .c = 144, .d = 208,
        .e = 190, .f = 250, .h = 131, .l = 147,
    };
    const expected_final = GbState {
        .pc = 19936, .sp = 59438,
        .a = 111, .b = 182, .c = 143, .d = 204,
        .e = 195, .f = 255, .h = 137, .l = 148,
    };
    inline for (std.meta.fields(GbState)) |field| {
        if (!std.mem.eql(u8, field.name, "ram")) {
            try testing.expectEqual(@field(expected_initial, field.name), @field(value.initial, field.name));
            try testing.expectEqual(@field(expected_final, field.name), @field(value.final, field.name));
        }
    }
    try testing.expectEqual(value.initial.ram[0], [_]u16{19935, 0});
    try testing.expectEqual(value.final.ram[0], [_]u16{19936, 1});
    try testing.expectEqual(value.final.ram[1], [_]u16{1234, 5});
    try testing.expectEqualStrings("00 0000", value.name);
    try testing.expectEqual(4, value.cycles.len);
}
