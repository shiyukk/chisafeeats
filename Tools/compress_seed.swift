#!/usr/bin/env swift
import Foundation

// Build-time helper: compress the prebuilt seed DB with LZFSE so it can be
// bundled small and decompressed by SeedInstaller on first launch.
// Usage: swift Tools/compress_seed.swift <input.sqlite> <output.lzfse>

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write(Data("usage: compress_seed.swift <in.sqlite> <out.lzfse>\n".utf8))
    exit(2)
}
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])

let raw = try Data(contentsOf: input) as NSData
let compressed = try raw.compressed(using: .lzfse)
try compressed.write(to: output)

let inMB = Double(raw.count) / 1_048_576
let outMB = Double(compressed.count) / 1_048_576
print(String(format: "seed: %.1f MB -> %.1f MB (%.0f%%)", inMB, outMB, outMB / inMB * 100))
