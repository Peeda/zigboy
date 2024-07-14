const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
//white, light gray, dark gray, black
const colors = [_]u32 {0xFF000000, 0xFF555555, 0xFFAAAAAA, 0xFFFFFFFF};
fn tile_to_buffer(tile_data: []const u8, buffer: []u32, palette: u8) void {
    std.debug.assert(tile_data.len == 16);
    std.debug.assert(buffer.len == 64);
    const tile_len = 8;
    var row: usize = 0;
    while (row < tile_len) : (row += 1) {
        const ls_bits = spread_bits(tile_data[row*2]);
        const ms_bits = spread_bits(tile_data[row*2 + 1]);
        const row_data: [tile_len]u2 = u16_to_u2((ms_bits << 1) | ls_bits);
        const palette_arr = byte_to_u2(palette);
        var col:usize = 0;
        while (col < tile_len) : (col += 1) {
            const color_id = row_data[col];
            const palette_id = palette_arr[@intCast(color_id)];
            const color = colors[@intCast(palette_id)];
            buffer[row * tile_len + col] = color;
        }
    }
}
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
pub fn main() void {
    const screenWidth = 1600;
    const screenHeight = 800;
    rl.InitWindow(screenWidth, screenHeight, "My awesome emulator.");
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    const ram = @embedFile("pokemon.dmp");
    var tile_buffer: [64]u32 = [_]u32{0} ** 64;
    tile_to_buffer(ram[0x8000..0x8010], tile_buffer[0..], ram[0xff47]);
    const deez = Buffer(100, 120);
    _ = deez;

    const tex = rl.LoadRenderTexture(8, 8);
    rl.UpdateTexture(tex.texture, &tile_buffer);

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.PURPLE);
        rl.DrawText("EEE", 100, 100, 12, rl.BLACK);
        rl.DrawFPS(10, 10);
        const pos: rl.Vector2 = rl.Vector2 { .x = 50, .y = 50, };
        rl.DrawTextureEx(tex.texture, pos, 0, 5, rl.WHITE);
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
