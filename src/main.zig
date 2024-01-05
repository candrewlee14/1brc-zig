const std = @import("std");

const COUNTRIES_ARR_LEN = 256;

const Stat = struct {
    min: f32,
    max: f32,
    sum: f32,
    count: u32,

    pub fn mergeIn(self: *Stat, other: Stat) void {
        self.min = @min(self.min, other.min);
        self.max = @max(self.max, other.max);
        self.sum += other.sum;
        self.count += other.count;
    }
    pub fn addItem(self: *Stat, item: f32) void {
        self.min = @min(self.min, item);
        self.max = @max(self.max, item);
        self.sum += item;
        self.count += 1;
    }
};

const WorkerCtx = struct {
    map: std.StringHashMap(Stat),
    countries: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) !WorkerCtx {
        var self: WorkerCtx = undefined;
        self.map = std.StringHashMap(Stat).init(allocator);
        self.countries = try std.ArrayList([]const u8).initCapacity(allocator, COUNTRIES_ARR_LEN);
        return self;
    }
    pub fn deinit(self: *WorkerCtx) void {
        self.map.deinit();
        self.countries.deinit();
    }
};

fn threadRun(
    chunk: []const u8,
    chunk_idx: usize,
    main_ctx: *WorkerCtx,
    main_mutex: *std.Thread.Mutex,
    wg: *std.Thread.WaitGroup,
) void {
    defer wg.finish();
    var ctx = WorkerCtx.init(std.heap.c_allocator) catch unreachable;
    defer ctx.deinit();
    std.log.debug("Running thread {}!", .{chunk_idx});

    var line_it = std.mem.splitScalar(u8, chunk, '\n');
    while (line_it.next()) |line| {
        if (line.len == 0) continue;

        var chunk_it = std.mem.splitScalar(u8, line, ';');
        const city = chunk_it.next().?;
        const num_str = chunk_it.next().?;
        const num = std.fmt.parseFloat(f32, num_str) catch unreachable;
        const entry = ctx.map.getOrPut(city) catch unreachable;
        if (entry.found_existing) {
            entry.value_ptr.addItem(num);
        } else {
            ctx.countries.append(entry.key_ptr.*) catch unreachable;
            entry.value_ptr.* = Stat{ .min = num, .max = num, .sum = num, .count = 1 };
        }
    }
    for (ctx.countries.items) |country| {
        const stat = ctx.map.get(country).?;
        main_mutex.lock();
        if (main_ctx.map.getPtr(country)) |main_stat| {
            main_stat.mergeIn(stat);
        } else {
            main_ctx.countries.append(country) catch unreachable;
            main_ctx.map.put(country, stat) catch unreachable;
        }
        main_mutex.unlock();
    }
    std.log.debug("Finished thread {}!", .{chunk_idx});
}

fn strLessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == std.math.Order.lt;
}

pub fn main() !void {
    std.log.debug("Starting!", .{});
    var args = try std.process.argsWithAllocator(std.heap.c_allocator);
    defer args.deinit();
    _ = args.skip(); // skip program name
    const file_name = args.next() orelse "measurements.txt";
    const file = try std.fs.cwd().openFile(file_name, .{ .mode = .read_only });
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

    var tp: std.Thread.Pool = undefined;
    try tp.init(.{ .allocator = std.heap.c_allocator });
    var wg = std.Thread.WaitGroup{};

    var main_ctx = try WorkerCtx.init(std.heap.c_allocator);
    defer main_ctx.deinit();
    var main_mutex = std.Thread.Mutex{};

    var chunk_start: usize = 0;
    const job_count = try std.Thread.getCpuCount() - 1;
    for (0..job_count) |i| {
        std.log.debug("Got chunk {}!", .{i});
        const chunk_end = std.mem.indexOfScalarPos(u8, mapped_mem, mapped_mem.len / job_count * i, '\n') orelse mapped_mem.len;
        const chunk: []const u8 = mapped_mem[chunk_start..chunk_end];
        chunk_start = chunk_end + 1;
        wg.start();
        try tp.spawn(threadRun, .{ chunk, i, &main_ctx, &main_mutex, &wg });
    }
    std.log.debug("Waiting and working", .{});
    tp.waitAndWork(&wg);
    std.log.debug("Finished waiting and working", .{});

    std.mem.sortUnstable([]const u8, main_ctx.countries.items, {}, strLessThan);
    for (main_ctx.countries.items) |country| {
        const stat = main_ctx.map.get(country).?;
        const avg = stat.sum / @as(f32, @floatFromInt(stat.count));
        std.debug.print("{s}: min: {d:.3}, max: {d:.3}, avg: {d:.3}\n", .{ country, stat.min, stat.max, avg });
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
