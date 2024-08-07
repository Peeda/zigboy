const std = @import("std");
const PPU = @import("ppu.zig").PPU;
pub const DMA = struct {
    delay_t_cycles: u8 = 0,
    base_addr: u16 = 0,
    offset:u16 = 0,
    bus: *Bus,
    pub fn init(bus: *Bus) DMA {
        return DMA {
            .delay_t_cycles = 0,
            .base_addr = 0,
            .offset = 0,
            .bus = bus,
        };
    }
    pub fn activate(self: *DMA, in:u8) void {
        self.delay_cycles = 2;
        self.base_addr = @as(u16, in) << 8;
        self.offset = 0;
    }
    pub fn tick(self: *DMA, t_cycles: u8) void {
        var i = 0;
        while (i < t_cycles) : (i += 1) {
            if (self.delay_cycles > 0) {
                self.delay_t_cycles -= 1;
            } else {
                const OAM_START = 0xFE00;
                const fetched_byte = self.bus.read(self.base_addr + self.offset);
                self.bus.write(OAM_START + self.offset, fetched_byte);
                self.offset += 1;
            }
        }
    }
};
pub const Bus = struct {
    ppu: *PPU = undefined,
    ROM_0: [0x4000]u8 = [_]u8{0} ** 0x4000,
    ROM_1: [0x4000]u8 = [_]u8{0} ** 0x4000,
    ERAM: [0x2000]u8 = [_]u8{0} ** 0x2000,
    WRAM_0: [0x1000]u8 = [_]u8{0} ** 0x1000,
    WRAM_1: [0x1000]u8 = [_]u8{0} ** 0x1000,
    OAM: [0xA0]u8 = [_]u8{0} ** 0xA0,
    IO: [0x80]u8 = [_]u8{0} ** 0x80,
    HRAM: [0x7F]u8 = [_]u8{0} ** 0x7F,
    //TODO: check if ie should be initially 0
    IE: u8 = 0,
    pub fn read(self: *Bus, addr16: u16) u8 {
        const addr:usize = @intCast(addr16);
        return switch (addr) {
            0x0000...0x3FFF => self.ROM_0[addr],
            0x4000...0x7FFF => self.ROM_1[addr - 0x4000],
            0x8000...0x9FFF => self.ppu.vram[addr - 0x8000],
            0xA000...0xBFFF => self.ERAM[addr - 0xA000],
            0xC000...0xCFFF => self.WRAM_0[addr - 0xC000],
            0xD000...0xDFFF => self.WRAM_1[addr - 0xD000],
            //echo ram
            0xE000...0xEFFF => self.WRAM_0[addr - 0xE000],
            0xF000...0xFDFF => self.WRAM_1[addr - 0xF000],
            0xFE00...0xFE9F => self.OAM[addr - 0xFE00],
            //TODO: what to do with forbidden memory
            0xFEA0...0xFEFF => 0,
            0xFF00...0xFF7F => self.IO[addr - 0xFF00],
            0xFF80...0xFFFE => self.HRAM[addr - 0xFF80],
            0xFFFF => self.IE,
            else => @panic("what."),
        };
    }
    pub fn write(self: *Bus, addr16:u16, val:u8) void {
        const addr:usize = @intCast(addr16);
        switch (addr) {
            //don't write to rom.
            0x0000...0x3FFF => {},
            0x4000...0x7FFF => {},
            0x8000...0x9FFF => self.ppu.vram[addr - 0x8000] = val,
            0xA000...0xBFFF => self.ERAM[addr - 0xA000] = val,
            0xC000...0xCFFF => self.WRAM_0[addr - 0xC000] = val,
            0xD000...0xDFFF => self.WRAM_1[addr - 0xD000] = val,
            //echo ram
            0xE000...0xEFFF => self.WRAM_0[addr - 0xE000] = val,
            0xF000...0xFDFF => self.WRAM_1[addr - 0xF000] = val,
            0xFE00...0xFE9F => self.OAM[addr - 0xFE00] = val,
            //TODO: what to do with forbidden memory
            0xFEA0...0xFEFF => {},
            0xFF00...0xFF7F => {
                if (addr == 0xFF46) {
                    //DMA

                }
                self.IO[addr - 0xFF00] = val;
            },
            0xFF80...0xFFFE => self.HRAM[addr - 0xFF80] = val,
            0xFFFF => self.IE = val,
            //TODO: this is needed to compile but i don't see which case isn't handled
            else => @panic("what."),
        }
    }
};
