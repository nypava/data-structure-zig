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

        const ExtendEntry = struct {
            entry: Entry,
            next_item: ?usize
        };

        allocator: std.mem.Allocator,
        table: []?Entry,
        extend_array: []?ExtendEntry,
        size: usize,
        extend_size: usize,
        count: usize,
        extend_count: usize,

        const INITIAL_SIZE = 100;
        const INITIAL_EXTEND_SIZE = 100;

        pub fn init(allocator: std.mem.Allocator) !Self {
            const table = try allocator.alloc(?Entry, INITIAL_SIZE);
            @memset(table, null);

            const extend_array = try allocator.alloc(?ExtendEntry, INITIAL_EXTEND_SIZE);
            @memset(extend_array, null);

            return Self {
                .allocator = allocator,
                .table = table,
                .extend_array = extend_array,
                .size = INITIAL_SIZE,
                .extend_size = INITIAL_EXTEND_SIZE,
                .count = 0,
                .extend_count = 0,
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
            try self.resize(self.size * 2);
        }

        fn resize_extend(self: *Self) !void {
            const new_size = self.extend_size * 2;
            const new_array = try self.allocator.alloc(?ExtendEntry, new_size);
            @memset(new_array, null);
            
            const old_array = self.extend_array;
            const old_size = self.extend_size;
            
            var index:usize = 0;
            for (old_array[0..old_size]) |slot| {
                new_array[index] = slot;
                index += 1;
            }

            self.extend_array = new_array;

            defer self.allocator.free(old_array);
            return;

        }

        pub fn put(self: *Self, key: []const u8, value: V) !void {
            if (self.count >= self.size) {
                try self.resize_up();
            } 
            
            if (self.extend_count >= self.extend_size){
                try self.resize_extend();
            }

            const idx = hash(key, self.size);

            if (self.table[idx]) |item| {
                if (item.active) {
                    if (std.mem.eql(u8, item.key, key)){
                        print("There is already a value with a key `{s}` in the hashtable!, cannot insert the key \n", .{key});
                        return;
                    }

                    for (self.extend_array[0..self.extend_count]) |*e_item| {
                        if (std.mem.eql(u8, e_item.*.?.entry.key, key) and e_item.*.?.entry.active){
                            print("There is already a value with a key `{s}` in the hashtable!, cannot insert the key \n", .{key});
                            return;
                        }
                        if (hash(e_item.*.?.entry.key, self.size) == idx) {
                            e_item.*.?.next_item = self.extend_count;
                            break;
                        }
                    }

                    self.extend_array[self.extend_count] = ExtendEntry {
                        .entry = Entry{
                            .key = key,
                            .value = value,
                            .active = true,
                        }, 
                        .next_item = null
                    };

                    self.extend_count += 1;
                    return;
                } 
            }

            self.table[idx] = Entry{
                .key = key,
                .value = value,
                .active = true,
            };

            self.count += 1;
        }

        pub fn get(self: *Self, key: []const u8) ?V {
            const idx = hash(key, self.size);
    
            if (self.table[idx]) |item| {
                if (item.active) {
                    if (std.mem.eql(u8, item.key, key)) {
                        return item.value;
                    } else {
                        for (self.extend_array[0..self.extend_count]) |e_item| {
                            if (hash(e_item.?.entry.key, self.size) == idx) {
                                var next_item:?usize = e_item.?.next_item;
                                while (next_item) |n_item| {
                                    if (std.mem.eql(u8, self.extend_array[n_item].?.entry.key, key) and self.extend_array[n_item].?.entry.active){
                                        break;
                                    }
                                    next_item = self.extend_array[n_item].?.next_item;
                                }

                                if (next_item) |n_item| {
                                    return self.extend_array[n_item].?.entry.value;
                                } else {
                                    if (std.mem.eql(u8, e_item.?.entry.key, key) and e_item.?.entry.active){
                                        return e_item.?.entry.value;
                                    }
                                }
                            }
                        }
                    }
                } 
            }
            return null;
        }

        pub fn delete(self: *Self, key: []const u8) !void {
            const idx = hash(key, self.size);

            if (self.table[idx]) |*e| {
                if (e.active and std.mem.eql(u8, e.key, key)) {
                    e.active = false;
                    return;
                }  
                for (self.extend_array[0..self.extend_count]) |*e_item| {
                    if (hash(e_item.*.?.entry.key, self.size) == idx) {
                        var next_item:?usize = e_item.*.?.next_item;
                        while (next_item) |n_item| {
                            if (std.mem.eql(u8, self.extend_array[n_item].?.entry.key, key)){
                                break;
                            }
                            next_item = self.extend_array[n_item].?.next_item;
                        }

                        if (next_item) |n_item| {
                            self.extend_array[n_item].?.entry.active = false;
                        } else {
                            if (std.mem.eql(u8, e_item.*.?.entry.key, key)){
                                e_item.*.?.entry.active = false;
                            }
                        }
                    }
                }
            }
        }

    };
}

pub fn main() !void {

    const Map = HashMap([]const u8);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var map = try Map.init(gpa.allocator());
    defer map.deinit();

    try map.put("dh", "male");
    try map.put("zz", "male");
    try map.put("lk", "male");
    try map.put("mn", "male");
    try map.put("ni", "female");
    try map.delete("zz");
    try map.put("zz", "male");
    // try map.put("water", "liquid");
    //
    if (map.get("dh")) |v| {
        std.debug.print("dh -> {s}\n", .{v});
    }

    if (map.get("zz")) |v| {
        std.debug.print("zz -> {s}\n", .{v});
    }

    if (map.get("lk")) |v| {
        std.debug.print("lk -> {s}\n", .{v});
    }

    if (map.get("mn")) |v| {
        std.debug.print("mn -> {s}\n", .{v});
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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var map = try Map.init(gpa.allocator());

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
