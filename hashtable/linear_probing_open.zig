const std = @import("std");
const print = @import("std").debug.print;
const expect = @import("std").testing.expect;

fn hash(key: []const u8, size: usize) usize {
    const base: u64 = 131;
    var h: u64 = 0;
    for (key) |c| {
        h = h *% base +% c;
    }
    return h % size;
}

fn is_prime(n: usize) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    var i: usize = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

fn next_prime(n: usize) usize {
    var next_number = n;
    
    while(!is_prime(next_number)) {
        next_number += 1;
    }

    return next_number;
}

fn HashMap(comptime V: type) type {
    return struct {
        const Self = @This();

        const Entry = struct {
            key: []const u8,
            value: V,
            active: bool,
        };

        allocator: std.mem.Allocator,
        table: []?Entry,
        size: usize,
        count: usize,

        const INITIAL_SIZE = 100;

        pub fn init() !Self {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            const allocator = gpa.allocator();

            const table = try allocator.alloc(?Entry, INITIAL_SIZE);
            @memset(table, null);

            return Self{
                .allocator = allocator,
                .table = table,
                .size = INITIAL_SIZE,
                .count = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.table);
        }

        fn insert(self: *Self, key: []const u8, value: V) void {
            var idx = hash(key, self.size);
            var steps: usize = 0;

            while (steps < self.size) : (steps += 1) {
                if (self.table[idx]) |*e| {
                    if (!e.active) {
                        e.* = Entry{ .key = key, .value = value, .active = true };
                        self.count += 1;
                        return;
                    }
                } else {
                    self.table[idx] = Entry{ .key = key, .value = value, .active = true };
                    self.count += 1;
                    return;
                }
                idx = (idx + 1) % self.size;
            }
        }

        fn resize(self: *Self, new_base: usize) !void {
            const new_size = next_prime(new_base);
            const new_table = try self.allocator.alloc(?Entry, new_size);
            @memset(new_table, null);

            const old_table = self.table;
            const old_size = self.size;

            self.table = new_table;
            self.size = new_size;
            self.count = 0;

            for (old_table[0..old_size]) |slot| {
                if (slot) |e| {
                    if (e.active) {
                        self.insert(e.key, e.value);
                    }
                }
            }

            self.allocator.free(old_table);
        }

        fn resize_up(self: *Self) !void {
            if (self.count * 100 / self.size > 70) {
                try self.resize(self.size * 2);
            }
        }

        fn resize_down(self: *Self) !void {
            if (self.size > INITIAL_SIZE and
                self.count * 100 / self.size < 10)
            {
                try self.resize(self.size / 2);
            }
        }

        pub fn put(self: *Self, key: []const u8, value: V) !void {
            const load = self.count * 100 / self.size;

            if (load > 70){
                try self.resize_up();
            } 

            var idx = hash(key, self.size);
            var tombstone: ?usize = null;
            var steps: usize = 0;

            while (steps < self.size) : (steps += 1) {
                if (self.table[idx]) |*e| {
                    if (e.active) {
                        if (std.mem.eql(u8, e.key, key)) {
                            print("There is already a value with a key `{s}` in the hashtable!, cannot insert the key \n", .{key});
                            return;
                        }
                    } else if (tombstone == null) {
                        tombstone = idx;
                    }
                } else {
                    break;
                }
                idx = (idx + 1) % self.size;
            }

            const insert_idx = tombstone orelse idx;
            self.table[insert_idx] = Entry{
                .key = key,
                .value = value,
                .active = true,
            };
            self.count += 1;
        }

        pub fn get(self: *Self, key: []const u8) ?V {
            var idx = hash(key, self.size);
            var steps: usize = 0;

            while (steps < self.size) : (steps += 1) {
                if (self.table[idx]) |e| {
                    if (e.active and std.mem.eql(u8, e.key, key)) {
                        return e.value;
                    }
                } else {
                    return null;
                }
                idx = (idx + 1) % self.size;
            }
            return null;
        }

        pub fn delete(self: *Self, key: []const u8) !void {
            var idx = hash(key, self.size);
            var steps: usize = 0;
            const load = self.count * 100 / self.size;

            while (steps < self.size) : (steps += 1) {
                if (self.table[idx]) |*e| {
                    if (e.active and std.mem.eql(u8, e.key, key)) {
                        e.active = false;
                        self.count -= 1;

                        if (load > 10) {
                            try self.resize_down();
                        }

                        return;
                    }
                } else {
                    break;
                }
                idx = (idx + 1) % self.size;
            }
            
            print("There is no value with the key `{s}`\n", .{key});
        }
    };
}

pub fn main() !void {

    const Map = HashMap([]const u8);
    var map = try Map.init();

    try map.put("dh", "male");
    try map.put("zz", "female");
    try map.delete("zz");
    try map.put("zz", "female");
    try map.put("water", "liquid");

    if (map.get("dh")) |v| {
        std.debug.print("dh -> {s}\n", .{v});
    }
    if (map.get("zz")) |v| {
        std.debug.print("zz -> {s}\n", .{v});
    }
    if (map.get("no")) |v| {
        std.debug.print("no -> {s}\n", .{v});
    } else {
        std.debug.print("no -> null\n", .{});
    }
}

test "core test" {
    const Human = struct {
        name: []const u8,
        age: u8,
        sex: u8,
    };

    const key = "abe_fb";
    const value = Human {.name = "Abebe", .age = 12, .sex = 'M'};

    const Map = HashMap(Human);
    var map = try Map.init();

    try map.put(key, value);

    var test_key = "abe_fb";

    if (map.get(test_key)) |v| {
        print("Item found: name = {s} \nage = {} \nsex = {c}\n", .{v.name, v .age, v.sex});
        try expect(std.mem.eql(u8, v.name, value.name) and v.age == value.age);
    }

    test_key = "abe_tg";

    if (map.get(test_key)) |_| {
        try expect(false);
    } else {
        try expect(true);
    }
}
