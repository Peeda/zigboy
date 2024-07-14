const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
fn byte_to_u2(in: u8) [4]u2 {
    const len = 4;
    var out = [_]u2 {0} ** len;
    var i:usize = 0;
    while (i < len) : (i += 1) {
        const shift:u3 = @intCast((3 - i) * 2);
        const val = (in & (@as(u8,0b11) << shift)) >> shift;
        out[i] = @intCast(val);
    }
    return out;
}
fn u16_to_u2(in:u16) [8]u2 {
    const len = 8;
    var out = [_]u2 {0} ** len;
    var i:usize = 0;
    while (i < len) : (i += 1) {
        const shift:u4 = @intCast((7 - i) * 2);
        const val = (in & (@as(u16,0b11) << shift)) >> shift;
        out[i] = @intCast(val);
    }
    return out;
}
fn spread_bits(bits: u8) u16 {
    var out:u16 = 0;
    var i:u16 = 0;
    while (i < 8) : (i += 1) {
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
        height:usize = height_pix,
        width:usize = width_pix,
        data: [height_pix * width_pix]u32 = [_]u32{0xff000000} ** (height_pix * width_pix),
        inline fn set_pixel(self: *@This(), y:usize, x:usize, val:u32) void {
            self.data[y * self.width + x] = val;
        }
        //here x and y are talking about tiles, so pixels * 8
        pub fn write_tile(self: *@This(), tile_data: []const u8, palette: u8, y:usize, x:usize) void {
            //white, light gray, dark gray, black
            const colors = [_]u32 {0xFF000000, 0xFF555555, 0xFFAAAAAA, 0xFFFFFFFF};
            const palette_arr = byte_to_u2(palette);
            std.debug.assert(tile_data.len == 16);
            const tile_len = 8;
            std.debug.assert(y * tile_len + tile_len - 1 < self.height);
            std.debug.assert(x * tile_len + tile_len - 1 < self.width);
            var row: usize = 0;
            while (row < tile_len) : (row += 1) {
                const ls_bits = spread_bits(tile_data[row*2]);
                const ms_bits = spread_bits(tile_data[row*2 + 1]);
                const row_data: [tile_len]u2 = u16_to_u2((ms_bits << 1) | ls_bits);
                var col:usize = 0;
                while (col < tile_len) : (col += 1) {
                    const color_id = row_data[col];
                    const palette_id = palette_arr[@intCast(color_id)];
                    const color = colors[@intCast(palette_id)];
                    self.set_pixel(y * tile_len + row, x * tile_len + col, color);
                }
            }
        }
    };
}
pub fn main() void {
    const screenWidth = 1600;
    const screenHeight = 800;
    rl.InitWindow(screenWidth, screenHeight, "My awesome emulator.");
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    const ram = @embedFile("pokemon.dmp");
    const palette = ram[0xff47];
    var tile_buffer = TileBuffer(16, 24) {};
    var i:usize = 0;
    while (i < 384) : (i += 1) {
        const start = 0x8000 + i * 16;
        const end = start + 16;
        tile_buffer.write_tile(ram[start..end], palette, i / 24, i % 24);
    }

    const tex = rl.LoadRenderTexture(@intCast(tile_buffer.width), @intCast(tile_buffer.height));
    rl.UpdateTexture(tex.texture, &tile_buffer.data);

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.PURPLE);
        rl.DrawFPS(10, 10);
        const pos: rl.Vector2 = rl.Vector2 { .x = 50, .y = 50, };
        rl.DrawTextureEx(tex.texture, pos, 0, 2, rl.WHITE);
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
