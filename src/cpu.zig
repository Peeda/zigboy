//TODO: error handling with illegal opcodes
//TODO: logging
const std = @import("std");
pub const CPU = cpu_type(@import("bus.zig").Bus);
pub const CPUFlatMem = cpu_type(@import("bus.zig").FlatMem);
//creates a cpu type at comptime, using T as the bus type
//T just needs to have read and write fns
fn cpu_type(comptime T: type) type {
    return struct {
        bus: *T,
        regs: Registers = Registers {},
        sp:u16 = 0xFFFE, pc:u16 = 0x0100, ime:bool = false,
        //was an ie operation executed last step
        ie_next:bool = false,
        pub fn step(self: *@This()) u8 {
            var clocks_taken:u8 = 0;
            clocks_taken += self.execute(self.consume_byte());
            //handle interrupts
            return clocks_taken;
        }
        //does one instruction, returns number of clocks
        pub fn execute(self: *@This(), opcode: u8) u8 {
            //if (opcode != 0) {
            //    std.debug.print("executing {X}\n", .{opcode});
            //}
            //https://gb-archive.github.io/salvage/decoding_gbz80_opcodes/Decoding%20Gamboy%20Z80%20Opcodes.html
            const x: u2 = @intCast((opcode & 0b11000000) >> 6);
            const y: u3 = @intCast((opcode & 0b00111000) >> 3);
            const z: u3 = @intCast((opcode & 0b00000111));
            const q: u1 = @intCast(y & 1);
            const p: u2 = @intCast(y >> 1);
            var use_alt_clock = false;
            switch (x) {
                0 => switch (z) {
                    0 => switch (y) {
                        0 => {},
                        1 => {
                            //write sp to memory
                            const addr = self.consume_16();
                            self.write(addr, @as(u8, @intCast(self.sp & 0x0f)));
                            self.write(addr + 1, @as(u8, @intCast(self.sp >> 8)));
                        },
                        2 => @panic("TODO, stop instruction"),
                        3 => {
                            //relative jump
                            const disp = self.consume_byte();
                            if (disp < 128) {
                                self.pc +%= disp;
                            } else {
                                self.pc -%= (255 - disp) +% 1;
                            }
                        },
                        4...7 => {
                            const disp = self.consume_byte();
                            const cond = self.table_cond(@intCast(y - 4), &use_alt_clock);
                            if (cond) {
                                if (disp < 128) {
                                    self.pc +%= disp;
                                } else {
                                    self.pc -%= 255 - disp + 1;
                                }
                            }
                        }
                    },
                    1 => {
                        switch (q) {
                            0 => {
                                const imm = self.consume_16();
                                self.table_rp(p).* = imm;
                            },
                            1 => {
                                const to_add = self.table_rp(p).*;
                                const result = self.regs_16().hl +% to_add;
                                self.flags().n = false;
                                self.flags().h = (self.regs_16().hl & 0x0fff) + (to_add & 0x0fff) > 0x0fff;
                                self.flags().c = result < self.regs_16().hl;
                                self.regs_16().hl = result;
                            }
                        }
                    },
                    2 => {
                        switch (q) {
                            0 => {
                                switch (p) {
                                    0 => self.write(self.regs_16().bc, self.regs.a),
                                    1 => self.write(self.regs_16().de, self.regs.a),
                                    2 => {self.write(self.regs_16().hl, self.regs.a); self.regs_16().hl +%= 1;},
                                    3 => {self.write(self.regs_16().hl, self.regs.a); self.regs_16().hl -%= 1;},
                                }
                            },
                            1 => {
                                switch (p) {
                                    0 => self.regs.a = self.read(self.regs_16().bc),
                                    1 => self.regs.a = self.read(self.regs_16().de),
                                    2 => {self.regs.a = self.read(self.regs_16().hl); self.regs_16().hl +%= 1; },
                                    3 => {self.regs.a = self.read(self.regs_16().hl); self.regs_16().hl -%= 1; },
                                }
                            },
                        }
                    },
                    3 => {
                        switch (q) {
                            0 => self.table_rp(p).* +%= 1,
                            1 => self.table_rp(p).* -%= 1,
                        }
                    },
                    4 => {
                        self.flags().z = self.read_table_r8(y) +% 1 == 0;
                        self.flags().n = false;
                        self.flags().h = (self.read_table_r8(y) & 0xf) == 0x0f;
                        self.write_table_r8(y, self.read_table_r8(y) +% 1);
                    },
                    5 => {
                        self.flags().z = self.read_table_r8(y) == 1;
                        self.flags().n = true;
                        self.flags().h = (self.read_table_r8(y) & 0x0f) == 0;
                    },
                    6 => self.write_table_r8(y, self.consume_byte()),
                    7 => {
                        switch (y) {
                            0 => {
                                const top_set = (self.regs.a & (1 << 7)) > 0;
                                self.set_flags(false, false, false, top_set);
                                self.regs.a <<= 1;
                                if (top_set) self.regs.a |= 1;
                            },
                            1 => {
                                const bottom_set = (self.regs.a & 1) > 0;
                                self.set_flags(false, false, false, bottom_set);
                                self.regs.a >>= 1;
                                if (bottom_set) self.regs.a |= (1 << 7);
                            },
                            2 => {
                                const prev_c = self.flags().c;
                                const top_set = (self.regs.a & (1 << 7)) > 0;
                                self.regs.a <<= 1;
                                self.set_flags(false, false, false, top_set);
                                if (prev_c) self.regs.a |= 1;
                            },
                            3 => {
                                const prev_c = self.flags().c;
                                const bottom_set = (self.regs.a & 1) > 0;
                                self.regs.a >>= 1;
                                self.set_flags(false, false, false, bottom_set);
                                if (prev_c) self.regs.a |= (1 << 7);
                            },
                            4 => @panic("todo, DAA"),
                            5 => {
                                self.regs.a = ~self.regs.a;
                                self.flags().n = false;
                                self.flags().h = false;
                            },
                            6 => {
                                self.flags().n = false;
                                self.flags().h = false;
                                self.flags().c = true;
                            },
                            7 => {
                                self.flags().n = false;
                                self.flags().h = false;
                                self.flags().c = !self.flags().c;
                            },
                        }
                    },
                },
                1 => {
                    if (y == 6 and z == 6) {
                        @panic("halt instruction todo");
                    } else {
                        self.write_table_r8(y, self.read_table_r8(z));
                    }
                },
                2 => self.alu_8(y, self.read_table_r8(z)),
                3 => {
                    switch (z) {
                        0 => {
                            switch (y) {
                                0...3 => if (self.table_cond(@intCast(y), &use_alt_clock)) {self.pc = self.pop_16();},
                                4 => self.write(0xff00 + @as(u16, self.consume_byte()), self.regs.a),
                                5 => {
                                    //TODO: check this flag behavior, signed add to unsigned but still carry flags
                                    //also blocks 5 and 7 here are the same thing, maybe put in function
                                    const disp = self.consume_byte();
                                    self.flags().z = false;
                                    self.flags().n = false;
                                    if (disp < 128) {
                                        const low_byte:u8 = @intCast(self.sp >> 8);
                                        self.flags().h = (low_byte & 0xf) + (disp & 0xf) > 0xf;
                                        self.flags().c = low_byte +% disp < low_byte;
                                        self.sp +%= disp;
                                    } else {
                                        self.sp -%= (255 - disp) +% 1;
                                    }
                                },
                                6 => self.regs.a = self.read(0xff00 + @as(u16, self.consume_byte())),
                                7 => {
                                    const disp = self.consume_byte();
                                    self.flags().z = false;
                                    self.flags().n = false;
                                    if (disp < 128) {
                                        const low_byte:u8 = @intCast(self.sp >> 8);
                                        self.flags().h = (low_byte & 0xf) + (disp & 0xf) > 0xf;
                                        self.flags().c = low_byte +% disp < low_byte;
                                        self.regs_16().hl = self.sp +% disp;
                                    } else {
                                        self.regs_16().hl = self.sp -% (255 - disp) +% 1;
                                    }
                                },
                            }
                        },
                        1 => {
                            switch (q) {
                                0 => self.table_rp2(p).* = self.pop_16(),
                                1 => switch (p) {
                                    0 => self.pc = self.pop_16(),
                                    1 => {self.pc = self.pop_16(); self.ime = true; },
                                    2 => self.pc = self.regs_16().hl,
                                    3 => self.sp = self.regs_16().hl,
                                },
                            }
                        },
                        2 => {
                            switch (y) {
                                0...3 => {
                                    const addr = self.consume_16();
                                    if (self.table_cond(@intCast(y), &use_alt_clock)) {
                                        self.pc = addr;
                                    }
                                },
                                4 => self.write(0xff00 + @as(u16, self.regs.c), self.regs.a),
                                5 => self.write(self.consume_16(), self.regs.a),
                                6 => self.regs.a = self.read(0xff00 + @as(u16, self.regs.c)),
                                7 => self.regs.a = self.read(self.consume_16()),
                            }
                        },
                        3 => {
                            switch (y) {
                                //TODO: make sure I'm using cb x y z not the normal ones
                                //maybe move this into a function, too much indentation
                                //also shared flag behavior between bit ops
                                0 => self.pc = self.consume_16(),
                                1 => {
                                    const cb_opcode = self.consume_byte();
                                    const cb_x: u2 = @intCast((cb_opcode & 0b11000000) >> 6);
                                    const cb_y: u3 = @intCast((cb_opcode & 0b00111000) >> 3);
                                    const cb_z: u3 = @intCast((cb_opcode & 0b00000111));
                                    const val = self.read_table_r8(cb_z);
                                    const math = std.math;
                                    switch (cb_x) {
                                        0 => {
                                            switch (cb_y) {
                                                //rlc, rrc
                                                0, 1 => {
                                                    if (cb_y == 0) {
                                                        self.flags().c = (val & (1 << 7)) > 0;
                                                        const write_val = math.rotl(u8, val, @as(usize, 1));
                                                        self.write_table_r8(cb_z, write_val);
                                                    } else {
                                                        std.debug.assert(cb_y == 1);
                                                        self.flags().c = (val & 1) > 0;
                                                        const write_val = math.rotr(u8, val, @as(usize, 1));
                                                        self.write_table_r8(cb_z, write_val);
                                                    }
                                                    self.flags().z = self.read_table_r8(cb_z) == 0;
                                                    self.flags().n = false;
                                                    self.flags().h = false;
                                                },
                                                2, 3 => {
                                                    //rl, rr
                                                    if (cb_y == 2) {
                                                        const top_set = (val & (1 << 7)) > 0;
                                                        self.write_table_r8(cb_z, val << 1);
                                                        if (self.flags().c) {
                                                            self.write_table_r8(cb_z, self.read_table_r8(cb_z) | 1);
                                                        }
                                                        self.flags().c = top_set;
                                                    } else {
                                                        std.debug.assert(cb_y == 3);
                                                        const bottom_set = (val & 1) > 0;
                                                        self.write_table_r8(cb_z, val >> 1);
                                                        if (self.flags().c) {
                                                            self.write_table_r8(cb_z, self.read_table_r8(cb_z) | (1 << 7));
                                                        }
                                                        self.flags().c = bottom_set;
                                                    }
                                                    self.flags().z = self.read_table_r8(cb_z) == 0;
                                                    self.flags().n = false;
                                                    self.flags().h = false;
                                                },
                                                4, 5 => {
                                                    //sla, sra (arithmetic shift)
                                                    if (cb_y == 4) {
                                                        self.flags().c = (val & (1 << 7)) > 0;
                                                        self.write_table_r8(cb_z, val << 1);
                                                    } else {
                                                        std.debug.assert(cb_y == 5);
                                                        const top_set = (val & (1 << 7)) > 0;
                                                        self.flags().c = (val & 1) > 0;
                                                        self.write_table_r8(cb_z, val >> 1);
                                                        //when sra bit seven stays
                                                        if (top_set) {
                                                            self.write_table_r8(cb_z, self.read_table_r8(cb_z) | (1 << 7));
                                                        }
                                                    }
                                                    self.flags().z = self.read_table_r8(cb_z) == 0;
                                                    self.flags().n = false;
                                                    self.flags().h = false;
                                                },
                                                6 => {
                                                    //swap
                                                    var accum:u8 = 0;
                                                    const top_half = (val & 0xf0);
                                                    const bottom_half = val & 0xf;
                                                    accum |= top_half >> 4;
                                                    accum |= bottom_half << 4;
                                                    self.set_flags(self.read_table_r8(cb_z) == 0, false, false, false);
                                                },
                                                7 => {
                                                    //srl, logical shift
                                                    self.flags().c = (val & 1) > 0;
                                                    self.write(cb_z, val >> 1);
                                                    self.flags().z = self.read_table_r8(cb_z) == 0;
                                                    self.flags().n = false;
                                                    self.flags().h = false;
                                                },
                                            }
                                        },
                                        1 => {
                                            //test bit y of reg z
                                            self.flags().z = (val & (@as(u8,1) << cb_y)) > 0;
                                            self.flags().n = false;
                                            self.flags().h = true;
                                        },
                                        2 => {
                                            //reset bit y of reg z
                                            const mask = ~(@as(u8,1) << cb_y);
                                            self.write_table_r8(cb_z, val & mask);
                                        },
                                        3 => {
                                            //set bit y of reg z
                                            self.write_table_r8(cb_z, val | (@as(u8,1) << cb_y));
                                        },
                                    }
                                },
                                2...5 => @panic("Illegal Opcode"),
                                6 => self.ime = false,
                                7 => self.ie_next = true,
                            }
                        },
                        4 => {
                            if (y >= 4) @panic("Illegal Opcode");
                            const cond = self.table_cond(@intCast(y), &use_alt_clock);
                            const addr = self.consume_16();
                            if (cond) self.call(addr);
                        },
                        5 => {
                            switch (q) {
                                0 => self.push_16(self.table_rp2(p).*),
                                1 => {
                                    if (p != 0) @panic("Illegal Opcode");
                                    const addr = self.consume_16();
                                    self.call(addr);
                                }
                            }
                        },
                        6 => self.alu_8(y, self.consume_byte()),
                        7 => self.call(@as(u16, y) * 8),
                    }
                }
            }
            if (self.ie_next) {
                self.ime = true;
                self.ie_next = false;
            }
            //don't use the alt table if this opcode doesn't have an alternative clock len
            std.debug.assert(!(use_alt_clock and ALT_CLOCK[@intCast(opcode)] == 0));
            return if (use_alt_clock) ALT_CLOCK[@intCast(opcode)] else CLOCK[@intCast(opcode)];
        }
        fn read_table_r8(self: *@This(), id: u3) u8 {
            return switch (id) {
                0 => self.regs.b,
                1 => self.regs.c,
                2 => self.regs.d,
                3 => self.regs.e,
                4 => self.regs.h,
                5 => self.regs.l,
                6 => self.read(self.regs_16().hl),
                7 => self.regs.a,
            };
        } 
        fn write_table_r8(self: *@This(), id:u3, val:u8) void {
            switch (id) {
                0 => {self.regs.b = val;},
                1 => {self.regs.c = val;},
                2 => {self.regs.d = val;},
                3 => {self.regs.e = val;},
                4 => {self.regs.h = val;},
                5 => {self.regs.l = val;},
                6 => {self.write(self.regs_16().hl, val);},
                7 => {self.regs.a = val;},
            }
        }
        fn table_rp(self: *@This(), id: u2) *u16 {
            return switch (id) {
                0 => &self.regs_16().bc,
                1 => &self.regs_16().de,
                2 => &self.regs_16().hl,
                3 => &self.sp,
            };
        }
        fn table_rp2(self: *@This(), id: u2) *u16 {
            return switch (id) {
                0 => &self.regs_16().bc,
                1 => &self.regs_16().de,
                2 => &self.regs_16().hl,
                3 => &self.regs_16().af,
            };
        }
        //have this function mutate the variable that determines clock vs alt clock cycles
        fn table_cond(self: *@This(), cond: u2, alt_clock: *bool) bool {
            const result = switch (cond) {
                0 => !self.flags().z,
                1 => self.flags().z,
                2 => !self.flags().c,
                3 => self.flags().c,
            };
            alt_clock.* = result;
            return result;
        }
        pub fn regs_16(self: *@This()) *Registers16 {
            return @ptrCast(&self.regs);
        }
        fn flags(self: *@This()) *Flags {
            return @ptrCast(&self.regs);
        }
        fn read(self: *@This(), addr: u16) u8 {
            return self.bus.read(addr);
        }
        fn write(self: *@This(), addr: u16, val: u8) void {
            self.bus.write(addr, val);
        }
        fn consume_byte(self: *@This()) u8 {
            const val = self.read(self.pc);
            self.pc +%= 1;
            return val;
        }
        fn consume_16(self: *@This()) u16 {
            const low:u16 = @intCast(self.consume_byte());
            const high:u16 = @intCast(self.consume_byte());
            return ((high << 8) | low);
        }
        fn set_flags(self: *@This(), z: bool, n: bool, h:bool, c:bool) void {
            self.flags().z = z;
            self.flags().n = n;
            self.flags().h = h;
            self.flags().c = c;
        }
        fn push_16(self: *@This(), val: u16) void {
            self.sp -%= 1;
            self.write(self.sp, @intCast(val >> 8));
            self.sp -%= 1;
            self.write(self.sp, @intCast(val & 0xf));
        }
        fn pop_16(self: *@This()) u16 {
            const low_byte:u16 = @intCast(self.read(self.sp));
            self.sp +%= 1;
            const hi_byte:u16 = @intCast(self.read(self.sp));
            self.sp +%= 1;
            return low_byte | (hi_byte << 8);
        }
        fn call(self: *@This(), addr: u16) void {
            self.push_16(self.pc);
            self.pc = addr;
        }
        fn alu_8(self: *@This(), op_id: u3, arg_original: u8) void {
            //8 bit arithmetic between registers
            const AluOp = enum {
                ADD, ADC, SUB, SBC, AND, XOR, OR, CP,
            };
            const op:AluOp = @enumFromInt(op_id);
            var arg = arg_original;
            if ((op == .ADC or op == .SBC) and self.flags().c) arg +%= 1;
            const result = switch (op) {
                .ADD, .ADC => self.regs.a +% arg,
                .SUB, .SBC, .CP => self.regs.a -% arg,
                .AND => self.regs.a & arg,
                .XOR => self.regs.a ^ arg,
                .OR => self.regs.a | arg,
            };
            self.flags().z = result == 0;
            self.flags().n = switch (op) {
                .SUB, .SBC, .CP  => true,
                .ADD, .ADC, .AND, .XOR, .OR => false,
            };
            self.flags().h = switch (op) {
                .ADD, .ADC => (self.regs.a & 0xf) + (arg & 0xf) > 0xf,
                .SUB, .SBC, .CP => (self.regs.a & 0xf) < (arg & 0xf),
                .AND, .OR, .XOR => false,
            };
            self.flags().c = switch (op) {
                .ADD, .ADC => result < self.regs.a,
                .SUB, .SBC, .CP => result > self.regs.a,
                .AND, .OR, .XOR => false,
            };
            if (op != .CP) self.regs.a = result;
        }
    };
}
const Registers = packed struct {
    l:u8 = 0x4D, h:u8 = 0x01, e:u8 = 0xD8, d:u8 = 0x00,
    c:u8 = 0x13, b:u8 = 0x00, f:u8 = 0xB0, a:u8 = 0x01,
};
const Registers16 = packed struct {
    hl:u16, de:u16, bc:u16, af:u16,
};
const Flags = packed struct {
    _pad52: u52, c:bool, h:bool, n:bool, z:bool, _pad8: u8,
};
const testing = std.testing;
test "casting" {
    try testing.expectEqual(@bitSizeOf(Registers), @bitSizeOf(Registers16));
    try testing.expectEqual(@bitSizeOf(Registers), @bitSizeOf(Flags));
    try testing.expectEqual(@bitSizeOf(Flags), @bitSizeOf(Registers16));
    //making sure memory aligns
    var bus = @import("bus.zig").Bus {};
    var cpu = CPU {.bus = &bus};
    cpu.regs.f = 0b10110000;
    try testing.expectEqual(true, cpu.flags().z); try testing.expectEqual(false, cpu.flags().n);
    try testing.expectEqual(true, cpu.flags().h); try testing.expectEqual(true, cpu.flags().c);
    cpu.regs.f = 0b00001101;
    try testing.expectEqual(false, cpu.flags().z); try testing.expectEqual(false, cpu.flags().n);
    try testing.expectEqual(false, cpu.flags().h); try testing.expectEqual(false, cpu.flags().c);
    cpu.regs.f = 0b01001101;
    try testing.expectEqual(false, cpu.flags().z); try testing.expectEqual(true, cpu.flags().n);
    try testing.expectEqual(false, cpu.flags().h); try testing.expectEqual(false, cpu.flags().c);
}
test "16 bit registers" {
    var bus = @import("bus.zig").Bus {};
    var cpu = CPU {.bus = &bus};
    cpu.regs.a = 0b11010010;
    cpu.regs.f = 0b01001010;
    try testing.expectEqual(cpu.regs_16().af, 0b1101001001001010);
    cpu.regs.b = 0b10010100;
    cpu.regs.c = 0b00011000;
    try testing.expectEqual(cpu.regs_16().bc, 0b1001010000011000);
    cpu.regs.d = 0b11100100;
    cpu.regs.e = 0b00101000;
    try testing.expectEqual(cpu.regs_16().de, 0b1110010000101000);
    cpu.regs.h = 0b11000010;
    cpu.regs.l = 0b10000100;
    try testing.expectEqual(cpu.regs_16().hl, 0b1100001010000100);
}
test "load" {
    var bus = @import("bus.zig").Bus {};
    var cpu = CPU {.bus = &bus};
    cpu.regs.b = 4;
    cpu.regs.c = 5;
    _ = cpu.execute(0x41);
    try testing.expectEqual(5, cpu.regs.b);
    try testing.expectEqual(5, cpu.regs.c);
    cpu.regs.d = 9;
    _ = cpu.execute(0x4a);
    try testing.expectEqual(9, cpu.regs.c);
}
test "add_flags" {
    var bus = @import("bus.zig").Bus {};
    var cpu = CPU {.bus = &bus};
    cpu.regs.a = 1;
    cpu.regs.e = 0xff;
    _ = cpu.execute(0x83);
    try testing.expectEqual(0, cpu.regs.a);
    //z = 1 n = 0 h = 1 c = 1
    try testing.expectEqual(true, cpu.flags().c); try testing.expectEqual(true, cpu.flags().z);
    try testing.expectEqual(true, cpu.flags().h); try testing.expectEqual(false, cpu.flags().n);
    try testing.expect(cpu.regs.f & (1 << 7) > 0);
    try testing.expect(cpu.regs.f & (1 << 6) == 0);
    try testing.expect(cpu.regs.f & (1 << 5) > 0);
    try testing.expect(cpu.regs.f & (1 << 4) > 0);
}
const CLOCK = [_]u8 {
 4, 12,  8,  8,  4,  4,  8,  4, 20,  8,  8,  8,  4,  4,  8,  4,
 4, 12,  8,  8,  4,  4,  8,  4, 12,  8,  8,  8,  4,  4,  8,  4,
 8, 12,  8,  8,  4,  4,  8,  4,  8,  8,  8,  8,  4,  4,  8,  4,
 8, 12,  8,  8, 12, 12, 12,  4,  8,  8,  8,  8,  4,  4,  8,  4,
 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,
 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,
 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,
 8,  8,  8,  8,  8,  8,  4,  8,  4,  4,  4,  4,  4,  4,  8,  4,
 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,
 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,
 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,
 4,  4,  4,  4,  4,  4,  8,  4,  4,  4,  4,  4,  4,  4,  8,  4,
 8, 12, 12, 16, 12, 16,  8, 16,  8, 16, 12,  4, 12, 24,  8, 16,
 8, 12, 12,  4, 12, 16,  8, 16,  8, 16, 12,  4, 12,  4,  8, 16,
12, 12,  8,  4,  4, 16,  8, 16, 16,  4, 16,  4,  4,  4,  8, 16,
12, 12,  8,  4,  4, 16,  8, 16, 12,  8, 16,  4,  4,  4,  8, 16,
};
pub const ALT_CLOCK = [_]u8 {
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
12,  0,  0,  0,  0,  0,  0,  0, 12,  0,  0,  0,  0,  0,  0,  0,
12,  0,  0,  0,  0,  0,  0,  0, 12,  0,  0,  0,  0,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
20,  0, 16,  0, 24,  0,  0,  0, 20,  0, 16,  0, 24,  0,  0,  0,
20,  0, 16,  0, 24,  0,  0,  0, 20,  0, 16,  0, 24,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
};
