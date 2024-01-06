# 1BRC-zig

This is based on the challenge here: https://github.com/gunnarmorling/1brc/.

> The One Billion Row Challenge (1BRC) is a fun exploration of how far modern Java can be pushed for aggregating one billion rows from a text file. 
> Grab all your (virtual) threads, reach out to SIMD, optimize your GC, or pull any other trick, and create the fastest implementation for solving this task!

I decided to implement this in Zig as a learning experience.

# Run

First, you'll need a Zig binary from here: https://ziglang.org/download/.
I'm using the latest master version: `zig-0.12.0-dev.2059`.

Then run `zig build -Doptimize=ReleaseFast` to build.

If you don't already have a `measurements.txt` file available, run `./zig-out/bin/run-create-sample 1000000000` to build your ~12GB input file.
This can take several minutes.

Now run `time ./zig-out/bin/1brc-zig measurements.txt`. 

With a warm cache (as allowed by the challenge rules), I get this time on my AMD Ryzen 7 5800H:

```
Executed in    5.76 secs    fish           external
   usr time   37.81 secs  129.00 micros   37.81 secs
   sys time   10.11 secs  526.00 micros   10.11 secs
```

