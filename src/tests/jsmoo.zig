const std = @import("std");
const json = std.json;
const testing = std.testing;

test "temp" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Deserialize JSON
    const json_str =
        \\{
        \\  "userid": 103609,
        \\  "verified": true,
        \\  "deez": false,
        \\  "access_privileges": [
        \\    "user",
        \\    "admin"
        \\  ],
        \\  "nested_obj": {
        \\    "a": 123,
        \\    "b": 234
        \\  }
        \\}
    ;
    const nested = struct {
        a: u32,
        b: u32,
    };
    const T = struct { userid: i32, verified: bool, access_privileges: [][]u8, nested_obj: nested };
    const parsed = try json.parseFromSlice(T, allocator, json_str, .{.ignore_unknown_fields = true});
    defer parsed.deinit();

    const value = parsed.value;

    try testing.expect(value.userid == 103609);
    try testing.expect(value.verified);
    try testing.expectEqualStrings("user", value.access_privileges[0]);
    try testing.expectEqualStrings("admin", value.access_privileges[1]);
    try testing.expectEqual(123, parsed.value.nested_obj.a);
    try testing.expectEqual(234, parsed.value.nested_obj.b);
}
