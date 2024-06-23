pub const Bus = struct {
    ROM_0: [0x4000]u8 = [_]u8{0} ** 0x4000,
    ROM_1: [0x4000]u8 = [_]u8{0} ** 0x4000,
    VRAM: [0x2000]u8 = [_]u8{0} ** 0x2000,
    ERAM: [0x2000]u8 = [_]u8{0} ** 0x2000,
    WRAM_0: [0x1000]u8 = [_]u8{0} * 0x1000,
    WRAM_1: [0x1000]u8 = [_]u8{0} * 0x1000,
    OAM: [0xA0]u8 = [_]u8{0} * 0xA0,
    IO: [0x80]u8 = [_]u8{0} * 0x80,
    HRAM: [0x7F]u8 = [_]u8{0} * 0x7F,
    IE: u8,
    fn read(self: *Bus, addr16: u16) u8 {
        const addr:usize = @intCast(addr16);
        return switch (addr) {
            0x0000...0x3FFF => self.ROM_0[addr],
            0x4000...0x7FFF => self.ROM_1[addr - 0x4000],
            0x8000...0x9FFF => self.VRAM[addr - 0x8000],
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
        };
    }
    fn write(self: *Bus, addr16:u16, val:u8) void {
        const addr:usize = @intCast(addr16);
        switch (addr) {
            0x0000...0x3FFF => self.ROM_0[addr] = val,
            0x4000...0x7FFF => self.ROM_1[addr - 0x4000] = val,
            0x8000...0x9FFF => self.VRAM[addr - 0x8000] = val,
            0xA000...0xBFFF => self.ERAM[addr - 0xA000] = val,
            0xC000...0xCFFF => self.WRAM_0[addr - 0xC000] = val,
            0xD000...0xDFFF => self.WRAM_1[addr - 0xD000] = val,
            //echo ram
            0xE000...0xEFFF => self.WRAM_0[addr - 0xE000] = val,
            0xF000...0xFDFF => self.WRAM_1[addr - 0xF000] = val,
            0xFE00...0xFE9F => self.OAM[addr - 0xFE00] = val,
            //TODO: what to do with forbidden memory
            0xFEA0...0xFEFF => {},
            0xFF00...0xFF7F => self.IO[addr - 0xFF00] = val,
            0xFF80...0xFFFE => self.HRAM[addr - 0xFF80] = val,
            0xFFFF => self.IE = val,
        }
    }
};
