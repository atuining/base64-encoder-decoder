const std = @import("std");
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const text = "Testing some more stuff";
    const etext = "VGVzdGluZyBzb21lIG1vcmUgc3R1ZmY=";
    const base64 = try Base64.init(allocator);
    const encoded_text = try base64.encode(allocator, text);
    const decoded_text = try base64.decode(allocator, etext);
    try stdout.print("Encoded text: {s}\n", .{encoded_text});
    try stdout.print("Decoded text: {s}\n", .{decoded_text});
}

const Base64 = struct {
    _table: *const [64]u8,
    _map: std.AutoHashMap(u8, usize),

    pub fn init(allocator: std.mem.Allocator) !Base64 {
        const upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const lower = "abcdefghijklmnopqrstuvwxyz";
        const numbers_symb = "0123456789+/";
        const table = upper ++ lower ++ numbers_symb;
        var map = std.AutoHashMap(u8, usize).init(allocator);
        for (0..table.len) |i| {
            try map.put(table[i], i);
        }
        return Base64{
            ._table = table,
            ._map = map,
        };
    }

    pub fn _char_at(self: Base64, index: usize) u8 {
        return self._table[index];
    }

    // TODO: use binary search
    fn _char_index(self: Base64, char: u8) ?u8 {
        if (char == '=')
            return 64;
        const val: u8 = @intCast(self._map.get(char).?);
        return val;
    }

    pub fn encode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return "";
        }

        const n_out = try _calc_encode_length(input);
        var out = try allocator.alloc(u8, n_out);

        var buf = [3]u8{ 0, 0, 0 };
        var count: u8 = 0;
        var iout: u64 = 0;

        for (input, 0..) |_, i| {
            buf[count] = input[i];
            count += 1;
            if (count == 3) {
                out[iout] = self._char_at(buf[0] >> 2);
                iout += 1;
                out[iout] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
                iout += 1;
                out[iout] = self._char_at(((buf[1] & 0x0F) << 2) + (buf[2] >> 6));
                iout += 1;
                out[iout] = self._char_at(buf[2] & 0x3F);
                iout += 1;
                count = 0;
            }
        }

        if (count == 1) {
            out[iout] = self._char_at(buf[0] >> 2);
            iout += 1;
            out[iout] = self._char_at((buf[0] & 0x03) << 4);
            iout += 1;
            out[iout] = '=';
            iout += 1;
            out[iout] = '=';
            iout += 1;
        }

        if (count == 2) {
            out[iout] = self._char_at(buf[0] >> 2);
            out[iout + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
            out[iout + 2] = self._char_at((buf[1] & 0x0F) << 2);
            out[iout + 3] = '=';
            iout += 4;
        }

        return out;
    }

    fn decode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return "";
        }
        const n_output = try _calc_decode_length(input);
        var output = try allocator.alloc(u8, n_output);
        var iout: u64 = 0;
        var count: u8 = 0;
        var buf = [4]u8{ 0, 0, 0, 0 };

        for (input, 0..) |_, i| {
            buf[count] = self._char_index(input[i]).?;
            count += 1;
            if (count == 4) {
                output[iout] = (buf[0] << 2) + (buf[1] >> 4);
                if (buf[2] != 64) {
                    output[iout + 1] = (buf[1] << 4) + (buf[2] >> 2);
                }
                if (buf[3] != 64) {
                    output[iout + 2] = (buf[2] << 6) + buf[3];
                }
                iout += 3;
                count = 0;
            }
        }
        return output;
    }
};

fn _calc_encode_length(input: []const u8) !usize {
    if (input.len < 3) {
        return 4;
    }
    const n_groups: usize = try std.math.divCeil(usize, input.len, 3);
    return n_groups * 4;
}

fn _calc_decode_length(input: []const u8) !usize {
    if (input.len < 4) {
        return 3;
    }
    const n_groups: usize = try std.math.divFloor(usize, input.len, 4);
    var multiple_groups: usize = n_groups * 3;
    var i: usize = input.len - 1;
    while (i > 0) : (i -= 1) {
        if (input[i] == '=') {
            multiple_groups -= 1;
        } else {
            break;
        }
    }
    return multiple_groups;
}
