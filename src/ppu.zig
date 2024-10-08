const std = @import("std");
const Bus = @import("bus.zig").Bus;
const addrs = struct {
    const LCDC:u16 = 0xFF40;
    const palette:u16 = 0xFF47;
    const SCY:u16 = 0xFF42;
    const SCX:u16 = 0xFF43;
};
fn byte_to_u2(in: u8) [4]u2 {
    const len = 4;
    var out = [_]u2 {0} ** len;
    for (0..len) |i| {
        const shift:u3 = @intCast((3 - i) * 2);
        const val = (in & (@as(u8,0b11) << shift)) >> shift;
        out[i] = @intCast(val);
    }
    return out;
}
fn u16_to_u2(in:u16) [8]u2 {
    const len = 8;
    var out = [_]u2 {0} ** len;
    for (0..len) |i| {
        const shift:u4 = @intCast((7 - i) * 2);
        const val = (in & (@as(u16,0b11) << shift)) >> shift;
        out[i] = @intCast(val);
    }
    return out;
}
fn spread_bits(bits: u8) u16 {
    var out:u16 = 0;
    const len = 8;
    for (0..len) |i| {
        if (bits & (@as(u8, 1) << @intCast(i)) > 0) {
            out |= (@as(u16, 1) << @intCast(2 * i));
        }
    }
    return out;
}
fn TileBuffer(comptime height_tiles: comptime_int, comptime width_tiles: comptime_int) type {
    const height_pix = height_tiles * 8;
    const width_pix = width_tiles * 8;
    return struct {
        //these are struct fields because I don't to keep the types in consts to access declarations,
        //but should not vary at runtime
        height_tiles:usize = height_tiles,
        width_tiles:usize = width_tiles,
        height_pix:usize = height_pix,
        width_pix:usize = width_pix,
        data: [height_pix * width_pix]u32 = [_]u32{0xff000000} ** (height_pix * width_pix),
        pub fn tile_count(self: *@This()) usize {
            return self.height_tiles * self.width_tiles;
        }
        pub inline fn set_pixel(self: *@This(), y:usize, x:usize, val:u32) void {
            self.data[y * self.width_pix + x] = val;
        }
        pub inline fn get_pixel(self: @This(), y:usize, x:usize) u32 {
            return self.data[y * self.width_pix + x];
        }
        //here x and y are talking about tiles, so pixels * 8
        pub fn write_tile(self: *@This(), tile_data: []const u8, palette: u8, y:usize, x:usize) void {
            //white, light gray, dark gray, black
            const colors = [_]u32 {0xFF000000, 0xFF555555, 0xFFAAAAAA, 0xFFFFFFFF};
            const palette_arr = byte_to_u2(palette);
            std.debug.assert(tile_data.len == 16);
            const tile_len = 8;
            std.debug.assert(y * tile_len + tile_len - 1 < self.height_pix);
            std.debug.assert(x * tile_len + tile_len - 1 < self.width_pix);
            for (0..tile_len) |row| {
                const ls_bits = spread_bits(tile_data[row*2]);
                const ms_bits = spread_bits(tile_data[row*2 + 1]);
                const row_data: [tile_len]u2 = u16_to_u2((ms_bits << 1) | ls_bits);
                for (0..tile_len) |col| {
                    const color_id = row_data[col];
                    const palette_id = palette_arr[@intCast(color_id)];
                    const color = colors[@intCast(palette_id)];
                    self.set_pixel(y * tile_len + row, x * tile_len + col, color);
                }
            }
        }
    };
}
const LCDC = packed struct {
    BgWindowEnable: u1,
    ObjEnable: u1,
    ObjSize: u1,
    BgTileMap: u1,
    TileMapAddressing: u1,
    WindowEnable: u1,
    WindowTileMap: u1,
    LcdPpuEnable: u1,
};
pub const PpuMode = enum {
    HBlank,
    VBlank,
    OamScan,
    Drawing,
};
pub const DebugTilesBuffer = TileBuffer(16, 24);
pub const BgWindowBuffer = TileBuffer(32, 32);
pub const PPU = struct {
    bus: *Bus,
    vram: [0x2000]u8 = [_]u8{0} ** 0x2000,
    dots: u32 = 0,
    mode: PpuMode = PpuMode.OamScan,
    lcd: TileBuffer(18, 20) = TileBuffer(18, 20) {},
    debug_tiles: DebugTilesBuffer = DebugTilesBuffer {},
    debug_bg: BgWindowBuffer = BgWindowBuffer {},
    debug_window: BgWindowBuffer = BgWindowBuffer {},
    pub fn step(self: *PPU, t_cycles: u8) void {
        //just want to make sure we can't completely skip a mode
        std.debug.assert(t_cycles <= 80);

        const old_mode = self.mode;
        self.dots += t_cycles;
        const frame_len = 70224;
        self.dots %= frame_len;
        const next_mode = PPU.get_mode(self.dots);
        if (next_mode == old_mode) {return;}

        //make sure the transition is an expected case

        switch (old_mode) {
            PpuMode.HBlank => {},
            PpuMode.VBlank => {
                //disable OAM
            },
            PpuMode.OamScan => {
                //disable vram
            },
            PpuMode.Drawing => {
                //render a scanline
                const line_len = 456;
                self.render_scanline(@intCast(self.dots / line_len));
            },
        }
        self.mode = next_mode;
    }
    //TODO: should not be pub
    pub fn render_scanline(self: *PPU, scanline: u8) void {
        const screen_height = 144;
        const screen_width = 160;
        std.debug.assert(scanline < screen_height);
        const lcdc:LCDC = @bitCast(self.bus.read(addrs.LCDC));
        if (lcdc.BgWindowEnable == 0) {
            //@panic("TODO:, should draw white except objects");
        }
        if (lcdc.LcdPpuEnable == 0) {
            //@panic("TODO:, shoudn't draw and should allow bus reads/writes");
        }
        for (0..screen_width) |i| {
            //just use overflowing add since these are u8s, wrap around 256x256 tilemap
            const bg_y:u8 = self.bus.read(addrs.SCY) +% scanline;
            const bg_x:u8 = self.bus.read(addrs.SCX) +% @as(u8, @intCast(i));
            //find what tile in the bg map is contains this pixel
            const tile_y = bg_y / 8;
            const tile_x = bg_x / 8;
            std.debug.assert(tile_y < 32 and tile_x < 32);
            const map_addr:u16 = switch (lcdc.BgTileMap) { 0 => 0x1800, 1 => 0x1C00, };
            const tile_map_len:usize = 32;
            const tile_id = self.vram[map_addr + tile_y * tile_map_len + tile_x];
            //on the tile, which pixel are we looking at
            const pixel_y = bg_y % 8;
            const pixel_x = bg_x % 8;
            const tile_addr:usize = switch (lcdc.TileMapAddressing) {
                0 => switch (tile_id) {
                    0...127 => 0x1000 + @as(usize, tile_id) * 16,
                    128...255 => 0x800 + @as(usize, tile_id - 128) * 16,
                },
                1 => @as(usize, tile_id) * 16,
            };
            const tile_row_addr = tile_addr + pixel_y * 2;
            const ls_bits = spread_bits(self.vram[tile_row_addr]);
            const ms_bits = spread_bits(self.vram[tile_row_addr + 1]);
            const row_data: [8]u2 = u16_to_u2((ms_bits << 1) | ls_bits);
            const color_id = row_data[@intCast(pixel_x)];
            const palette_arr = byte_to_u2(self.bus.read(addrs.palette));
            const palette_id = palette_arr[@intCast(color_id)];
            const colors = [_]u32 {0xFF000000, 0xFF555555, 0xFFAAAAAA, 0xFFFFFFFF};
            const color = colors[@intCast(palette_id)];

            self.lcd.set_pixel(scanline, i, color);
        }
    }
    fn get_mode(dots:u32) PpuMode {
        //each line is 456 dots, 456 * 154 is 70224
        //456 * 144 = 65664
        //[0, 65663] is drawing, [65664, 70223] is vblank
        const line_len = 456;
        const lines_len = 65664;
        const frame_len = 70224;
        if (dots < lines_len) {
            //drawing a line
            return switch (dots % line_len) {
                0...79 => PpuMode.OamScan,
                80...251 => PpuMode.Drawing,
                252...455 => PpuMode.HBlank,
                else => unreachable,
            };
        } else {
            std.debug.assert(dots < frame_len);
            return PpuMode.VBlank;
        }
    }
    pub fn update_debug_tile_data(self: *PPU) void {
        var tile_buffer = &self.debug_tiles;
        const palette = self.bus.read(addrs.palette);
        for (0..tile_buffer.tile_count()) |i| {
            const width = tile_buffer.width_tiles;
            const start = i * 16;
            tile_buffer.write_tile(self.vram[start..start+16], palette, i / width, i % width);
        }
    }
    pub fn update_debug_tilemap(self: *PPU, map_type: TileMapType) void {
        const lcdc:LCDC = @bitCast(self.bus.read(addrs.LCDC));
        var map_buffer = switch (map_type) {
            .Background => &self.debug_bg,
            .Window => &self.debug_window,
        };
        //find which index buffer we're looking at, resolve addressing, then iterate over and write
        const lcdc_bit = switch (map_type) {
            .Background => lcdc.BgTileMap,
            .Window => lcdc.WindowTileMap,
        };
        //TODO: maybe do something about all these magic numbers, handle vram vs bus addr
        const palette = self.bus.read(addrs.palette);
        const map_addr:usize = switch (lcdc_bit) { 0 => 0x1800, 1 => 0x1C00, };
        for (self.vram[map_addr..map_addr+map_buffer.tile_count()], 0..) |tile_id, i| {
            const tile_addr:usize = switch (lcdc.TileMapAddressing) {
                0 => switch (tile_id) {
                    0...127 => 0x1000 + @as(usize, tile_id) * 16,
                    128...255 => 0x800 + @as(usize, tile_id - 128) * 16,
                },
                1 => @as(usize, tile_id) * 16,
            };
            const width = map_buffer.width_tiles;
            map_buffer.write_tile(self.vram[tile_addr..tile_addr+16], palette,  i / width, i % width);
        }
    }
};
pub const TileMapType = enum {
    Background,
    Window,
};
test "byte to u2 array" {
    var data:u8 = 0b00011011;
    var expected = [_]u2{0b00,0b01,0b10,0b11};
    data = 0b11100100;
    expected = [_]u2{0b11,0b10,0b01,0b00};
    try std.testing.expectEqual(expected, byte_to_u2(data));
}
test "u16 to u2 array" {
    const data:u16 = 0b0001101111100100;
    const expected = [_]u2{0b00,0b01,0b10,0b11} ++ [_]u2{0b11,0b10,0b01,0b00};
    try std.testing.expectEqual(expected, u16_to_u2(data));
}
