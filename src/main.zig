const std = @import("std");

const COUNTRIES_ARR_LEN = 256;

const Stat = struct {
    min: f32,
    max: f32,
    sum: f32,
    count: u32,
};

fn strLessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == std.math.Order.lt;
}

pub fn main() !void {
    const file = try std.fs.cwd().openFile("measurements.txt", .{ .mode = .read_only });
    defer file.close();
    //
    const file_len: usize = std.math.cast(usize, try file.getEndPos()) orelse std.math.maxInt(usize);
    const mapped_mem = try std.os.mmap(
        null,
        file_len,
        std.os.PROT.READ,
        std.os.MAP.PRIVATE,
        file.handle,
        0,
    );
    defer std.os.munmap(mapped_mem);

    var line_it = std.mem.splitScalar(u8, mapped_mem, '\n');
    var map = std.StringHashMap(Stat).init(std.heap.c_allocator);
    defer map.deinit();
    var countries = try std.ArrayList([]const u8).initCapacity(std.heap.c_allocator, COUNTRIES_ARR_LEN);
    while (line_it.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        var chunk_it = std.mem.splitScalar(u8, line, ';');
        const city = chunk_it.next().?;
        const num_str = chunk_it.next().?;
        const num = try std.fmt.parseFloat(f32, num_str);
        const entry = try map.getOrPut(city);
        if (entry.found_existing) {
            entry.value_ptr.min = @min(entry.value_ptr.min, num);
            entry.value_ptr.max = @max(entry.value_ptr.max, num);
            entry.value_ptr.sum += num;
            entry.value_ptr.count += 1;
        } else {
            try countries.append(entry.key_ptr.*);
            entry.value_ptr.* = Stat{ .min = num, .max = num, .sum = num, .count = 1 };
        }
    }

    std.mem.sortUnstable([]const u8, countries.items, {}, strLessThan);
    for (countries.items) |country| {
        const stat = map.get(country).?;
        const avg = stat.sum / @as(f32, @floatFromInt(stat.count));
        std.debug.print("{s}: min: {d}, max: {d}, avg: {d}\n", .{ country, stat.min, stat.max, avg });
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
