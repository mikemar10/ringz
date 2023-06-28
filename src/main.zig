const std = @import("std");

const iterations: usize = 500_000_000;
// the stack appears to overflow at large buffer sizes and causes a segfault
// curiously, only in the releasesafe mode though. I don't know what to make of that.
// I thought the kernel was in charge of killing processes that use too large of a stack.
// But maybe the kernel uses guard pages and we just blew right past the guard pages?
// But even then, why only segfault in ReleaseSafe instead of ReleaseFast?
const buffer_size: usize = 4096 << 8;
var ringbuffer: [buffer_size]usize = [_]usize{0} ** buffer_size;
// TODO not sure if this alignment actually matters, stole it from someone else's ringbuffer implementation.
var wi: usize align(64) = 0;
var ri: usize align(64) = 0;

fn writer_fn() void {
    var ri_: usize = 0;
    var wi_: usize = 0;
    var next: usize = 1;
    var x: usize = 0;
    while (x < iterations) {
        ri_ = @atomicLoad(usize, &ri, std.atomic.Ordering.Acquire);
        while (next != ri_) {
            ringbuffer[wi_] = 1;
            wi_ = next;
            next = (wi_ + 1) & (buffer_size - 1);
            x += 1;
            if (x >= iterations) {
                break;
            }
        }
        @atomicStore(usize, &wi, wi_, std.atomic.Ordering.Release);
    }
    //std.debug.print("Writing finished\n", .{});
}

fn reader_fn() void {
    var ri_: usize = 0;
    var wi_: usize = 0;
    var sum: usize = 0;
    var x: usize = 0;
    while (x < iterations) {
        wi_ = @atomicLoad(usize, &wi, std.atomic.Ordering.Acquire);
        while (ri_ != wi_) {
            sum += ringbuffer[ri_];
            ri_ = (ri_ + 1) & (buffer_size - 1);
            x += 1;
            if (x >= iterations) {
                break;
            }
        }
        @atomicStore(usize, &ri, ri_, std.atomic.Ordering.Release);
    }
    //std.debug.print("Reading finished\n", .{});
    std.debug.print("Final sum = {}\n", .{sum});
}

pub fn main() !void {
    // With a single writer thread and single reader thread, we can increment a counter 500 million times in ~1s
    var writer = try std.Thread.spawn(.{}, writer_fn, .{});
    var reader = try std.Thread.spawn(.{}, reader_fn, .{});
    std.Thread.join(writer);
    std.Thread.join(reader);
}
