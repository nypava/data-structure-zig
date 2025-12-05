const print = @import("std").debug.print;
const expect = @import("std").testing.expect;
const std = @import("std");

const HASH_ARRAY_SIZE = 100;

fn HashMap(comptime TypeValue: type, size: usize) type {
    return struct {
        const Self = @This();

        const Value = union(enum) {
            Empty: void,
            Occupied: struct {
                key: []const u8,
                value: TypeValue,
            }
        };

        array: [size]Value,
        count: usize = 0,

        pub fn init() Self {
            return Self {
                .array = [_]Value{.{ .Empty = {}}} ** size,
                .count = 0
            };
        }

        pub fn put(self: *Self, key: []const u8, value: TypeValue) void {
            if (self.count >= size) @panic("map full");

            self.array[self.count] = .{.Occupied = .{.key = key, .value = value}};
            self.count += 1;
        }

        pub fn get(self: Self, key: []const u8) ?TypeValue {
            for (self.array[0..self.count]) |items| {
                if (std.mem.eql(u8, items.Occupied.key, key)){
                    return items.Occupied.value;
                }
            }
            return null;
        }
    };
}

pub fn main() !void {
    const Human = struct {
        name: []const u8,
        age: u8,
        sex: u8,
    };

    const key = "abe";
    const value: Human = .{.name="abebe", .age=2, .sex='M'};
    var hash_map = HashMap(Human, HASH_ARRAY_SIZE).init();
    hash_map.put(key, value);

    const test_key = "abef";
    if (hash_map.get(test_key)) |v| {
        print("Item found: name = {s} \nage = {} \nsex = {c}\n", .{v.name, v .age, v.sex});
    } else {
        print("Item not found\n", .{});
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
    const array_size:usize = HASH_ARRAY_SIZE;

    var map = HashMap(Human, array_size).init();
    map.put(key, value);

    var test_key = "abe_fb";

    if (map.get(test_key)) |v| {
        print("Item found: name = {s} \nage = {} \nsex = {c}\n", .{v.name, v .age, v.sex});
        try expect(std.mem.eql(u8, v.name, value.name) and v.age == value.age);
    }

    test_key = "abe_tg";
    if (map.get(test_key)) |v| {
        _ = v;
        try expect(false);
    } else {
        try expect(true);
    }
}
