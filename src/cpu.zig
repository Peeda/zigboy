const std = @import("std");
pub const CPU = struct {
    regs: Registers = Registers {},
    sp:u16 = 0xFFFE, pc:u16 = 0x0100,
    pub fn step(self: *CPU) u8 {
        const opcode = self.read(self.PC);
        self.pc += 1;
        return self.execute(opcode);
    }
    //does one instruction, returns number of clocks
    pub fn execute(self: *CPU, opcode: u8) u8 {
        //https://gb-archive.github.io/salvage/decoding_gbz80_opcodes/Decoding%20Gamboy%20Z80%20Opcodes.html
        const x: u2 = @intCast((opcode & 0b11000000) >> 6);
        const y: u3 = @intCast((opcode & 0b00111000) >> 3);
        const z: u3 = @intCast((opcode & 0b00000111));
        switch (x) {
            0 => @panic("todo"),
            1 => {
                if (y == 6 and z == 6) {
                    @panic("halt instruction todo");
                } else {
                    self.table_r8(y).* = self.table_r8(z).*;
                }
            },
            2 => {
                switch (y) {
                    0 => {
                        self.flags().n = false;
                        const to_add = self.table_r8(z).*;
                        const result = self.regs.a +% to_add;
                        self.flags().z = result == 0;
                        self.flags().c = result < self.regs.a;
                        self.flags().h = (self.regs.a & 0x0f) + (to_add & 0x0f) > 0x0f;
                        self.regs.a = result;
                    },
                    else => @panic("todo"),
                }
            },
            3 => @panic("todo"),
        }
        //TODO: remove this.
        return 0;
    }
    fn table_r8(self: *CPU, id: u3) *u8 {
        return switch (id) {
            0 => &self.regs.b,
            1 => &self.regs.c,
            2 => &self.regs.d,
            3 => &self.regs.e,
            4 => &self.regs.h,
            5 => &self.regs.l,
            6 => self.mem_ptr(self.regs_16().hl),
            7 => &self.regs.a,
        };
    }
    fn regs_16(self: *CPU) *Registers16 {
        return @ptrCast(&self.regs);
    }
    fn flags(self: *CPU) *Flags {
        return @ptrCast(&self.regs);
    }
    fn mem_ptr(self: *CPU, addr:u16) *u8 {
        _ = self;
        _ = addr;
        @panic("todo");
    }
    fn read(addr: u16) u8 {
        _ = addr;
        @panic("todo");
    }
    fn write(addr: u16, val: u8) void {
        _ = addr;
        _ = val;
        @panic("todo");
    }
};
const Registers = packed struct {
    a: u8 = 0x01, f:u8 = 0xB0, b:u8 = 0, c:u8 = 0x13, 
    d:u8 = 0, e:u8 = 0xD8, h:u8 = 0x01, l:u8 = 0x4D,
};
const Registers16 = packed struct {
    af:u16, bc:u16, de:u16, hl:u16,
};
const Flags = packed struct {
    _pad12: u12, c: bool, h: bool, n: bool, z:bool, _pad48: u48,
};
const testing = std.testing;
test "casting" {
    try testing.expectEqual(@bitSizeOf(Registers), @bitSizeOf(Registers16));
    try testing.expectEqual(@bitSizeOf(Registers), @bitSizeOf(Flags));
    try testing.expectEqual(@bitSizeOf(Flags), @bitSizeOf(Registers16));
    //making sure memory aligns
    var cpu = CPU {};
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
test "load" {
    var cpu = CPU {};
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
    var cpu = CPU {};
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
