#!/usr/bin/env swift
import Foundation
// Inverse of compress_seed.swift: LZFSE .lzfse -> .sqlite
let a = CommandLine.arguments
guard a.count == 3 else { FileHandle.standardError.write(Data("usage: decompress_seed.swift <in.lzfse> <out.sqlite>\n".utf8)); exit(2) }
let comp = try Data(contentsOf: URL(fileURLWithPath: a[1])) as NSData
let raw = try comp.decompressed(using: .lzfse)
try raw.write(to: URL(fileURLWithPath: a[2]))
print(String(format: "decompressed: %.1f MB", Double(raw.count)/1_048_576))
