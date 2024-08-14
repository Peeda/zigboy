//TODO: get basic scanline rendering going, connect CPU, PPU, Bus
//TODO: handle restricted reads/writes, does bus check ppu or does ppu control bus
//TODO: resolve timing between components, PPU updates after CPU so for one update CPU can access restricted mem
//TODO: write a test for the bus read write consistency
//TODO: allow bus to return pointer for cpu, or rewrite certain opcodes
//TODO: stop, halt, daa
const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const Bus = @import("bus.zig").Bus;
const PPU = @import("ppu.zig").PPU;
const CPU = @import("cpu.zig").CPU;
const TileMapType = @import("ppu.zig").TileMapType;
const DisplayTextures = struct {
    lcd: rl.RenderTexture2D,
    tile_buffer: rl.RenderTexture2D,
    bg_buffer: rl.RenderTexture2D,
    window_buffer: rl.RenderTexture2D,
    //all of these use raylib functions so they follow raylib rules about initialization and drawing modes
    fn init(ppu: *PPU) DisplayTextures {
        const out = DisplayTextures {
            .lcd = rl.LoadRenderTexture(@intCast(ppu.lcd.width_pix), @intCast(ppu.lcd.height_pix)),
            .tile_buffer = rl.LoadRenderTexture(@intCast(ppu.debug_tiles.width_pix), @intCast(ppu.debug_tiles.height_pix)),
            .bg_buffer = rl.LoadRenderTexture(@intCast(ppu.debug_bg.width_pix), @intCast(ppu.debug_bg.height_pix)),
            .window_buffer = rl.LoadRenderTexture(@intCast(ppu.debug_window.width_pix), @intCast(ppu.debug_window.height_pix)),
        };
        rl.UpdateTexture(out.lcd.texture, &ppu.lcd.data);
        rl.UpdateTexture(out.tile_buffer.texture, &ppu.debug_tiles.data);
        rl.UpdateTexture(out.bg_buffer.texture, &ppu.debug_bg.data);
        rl.UpdateTexture(out.window_buffer.texture, &ppu.debug_window.data);
        return out;
    }
    fn update_textures(self: *DisplayTextures, ppu: *PPU) void {
        rl.UpdateTexture(self.lcd.texture, &ppu.lcd.data);
        rl.UpdateTexture(self.tile_buffer.texture, &ppu.debug_tiles.data);
        rl.UpdateTexture(self.bg_buffer.texture, &ppu.debug_bg.data);
        rl.UpdateTexture(self.window_buffer.texture, &ppu.debug_window.data);
    }
    fn draw_textures(self: *DisplayTextures) void {
        const lcd_pos: rl.Vector2 = rl.Vector2 { .x = 255, .y = 200, };
        rl.DrawTextureEx(self.lcd.texture, lcd_pos, 0, 2, rl.WHITE);

        const tile_buffer_pos: rl.Vector2 = rl.Vector2 { .x = 955, .y = 50, };
        rl.DrawTextureEx(self.tile_buffer.texture, tile_buffer_pos, 0, 2, rl.WHITE);

        const bg_buffer_pos: rl.Vector2 = rl.Vector2 {.x = 925, .y = 350};
        rl.DrawTextureEx(self.bg_buffer.texture, bg_buffer_pos, 0, 1, rl.WHITE);

        const window_buffer_pos: rl.Vector2 = rl.Vector2 {.x = 1250, .y = 350};
        rl.DrawTextureEx(self.window_buffer.texture, window_buffer_pos, 0, 1, rl.WHITE);
    }
};
pub fn main() void {
    const screenWidth = 1600;
    const screenHeight = 800;
    rl.InitWindow(screenWidth, screenHeight, "My awesome emulator.");
    defer rl.CloseWindow();
    var bus = Bus {};
    var ppu = PPU {.bus = &bus};
    var cpu = CPU {.bus = &bus};
    bus.ppu = &ppu;

    const ram = @embedFile("zelda.dmp");
    for (0..0xFFFF) |i| {
        bus.write(@intCast(i), ram[i]);
    }
    const rom = @embedFile("dmg-acid2.gb");
    bus.load(rom);
    ppu.update_debug_tile_data();
    ppu.update_debug_tilemap(TileMapType.Background);
    ppu.update_debug_tilemap(TileMapType.Window);

    var display_textures = DisplayTextures.init(&ppu);

    while (!rl.WindowShouldClose()) {

        while (true) {
            const PpuMode = @import("ppu.zig").PpuMode;
            const old_mode = ppu.mode;
            const dots = cpu.step();
            ppu.step(dots);
            if (old_mode == PpuMode.VBlank and ppu.mode == PpuMode.OamScan) {break;}
        }

        ppu.update_debug_tile_data();
        ppu.update_debug_tilemap(TileMapType.Background);
        ppu.update_debug_tilemap(TileMapType.Window);
        display_textures.update_textures(&ppu);

        rl.BeginDrawing();
        rl.ClearBackground(rl.PURPLE);
        rl.DrawFPS(10, 10);

        display_textures.draw_textures();

        rl.EndDrawing();
    }
}
