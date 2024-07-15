const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
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
        inline fn set_pixel(self: *@This(), y:usize, x:usize, val:u32) void {
            self.data[y * self.width_pix + x] = val;
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
pub fn main() void {
    const screenWidth = 1600;
    const screenHeight = 800;
    rl.InitWindow(screenWidth, screenHeight, "My awesome emulator.");
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    const ram = @embedFile("zelda.dmp");
    const palette = ram[0xFF47];
    const lcdc:LCDC = @bitCast(ram[0xFF40]);

    var tile_buffer = TileBuffer(16, 24) {};
    for (0..tile_buffer.width_tiles * tile_buffer.height_tiles) |i| {
        const start = 0x8000 + i * 16;
        const end = start + 16;
        const width = tile_buffer.width_tiles;
        tile_buffer.write_tile(ram[start..end], palette, i / width, i % width);
    }
    const tile_buffer_tex = rl.LoadRenderTexture(@intCast(tile_buffer.width_pix), @intCast(tile_buffer.height_pix));
    rl.UpdateTexture(tile_buffer_tex.texture, &tile_buffer.data);

    var bg_buffer = TileBuffer(32, 32) {};
    //find which index buffer we're looking at, resolve addressing, then iterate over and write
    const map_addr = switch (lcdc.BgTileMap) { 0 => 0x9800, 1 => 0x9C00, };
    for (ram[map_addr..map_addr+32*32], 0..) |tile_id, i| {
        const tile_addr:usize = switch (lcdc.TileMapAddressing) {
            0 => switch (tile_id) {
                0...127 => 0x9000 + @as(usize, tile_id) * 16,
                128...255 => 0x8800 + @as(usize, tile_id - 128) * 16,
            },
            1 => 0x8000 + tile_id * 16,
        };
        const width = bg_buffer.width_tiles;
        bg_buffer.write_tile(ram[tile_addr..tile_addr+16], palette,  i / width, i % width);
    }
    const bg_buffer_tex = rl.LoadRenderTexture(@intCast(bg_buffer.width_pix), @intCast(bg_buffer.height_pix));
    rl.UpdateTexture(bg_buffer_tex.texture, &bg_buffer.data);

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.PURPLE);
        rl.DrawFPS(10, 10);

        const tile_buffer_pos: rl.Vector2 = rl.Vector2 { .x = 955, .y = 50, };
        rl.DrawTextureEx(tile_buffer_tex.texture, tile_buffer_pos, 0, 2, rl.WHITE);

        const bg_buffer_pos: rl.Vector2 = rl.Vector2 {.x = 955, .y = 350};
        rl.DrawTextureEx(bg_buffer_tex.texture, bg_buffer_pos, 0, 2, rl.WHITE);

        rl.EndDrawing();
    }
}
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
