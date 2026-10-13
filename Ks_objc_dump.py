#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ks_objc_dump.py — 纯 Python 的 Mach-O / Objective-C 元数据提取器
（不依赖 lief / class-dump，任何有 python3 的地方都能跑）

用法:
    python3 ks_objc_dump.py 插件.dylib
    python3 ks_objc_dump.py 插件.dylib --grep select
    python3 ks_objc_dump.py 插件.dylib -o 报告.txt

会输出:
    1) Mach-O 基本信息(架构 / 类型 / 是否 chained fixups)
    2) 该 dylib 里定义的所有 ObjC 类
    3) 每个类的实例方法 / 类方法(直接从 class_ro_t 解出来,不是靠 strings 猜)
    4) 「点击候选」方法清单 —— 直接就是 Tweak.xm 里 ClickSelectors 的写法: 类名:选择器
    5) 全部选择器列表(给 grep 用)
"""

import argparse
import re
import struct
import sys

MH_MAGIC_64 = 0xFEEDFACF
FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF

LC_SEGMENT_64 = 0x19
LC_DYLD_CHAINED_FIXUPS = 0x80000034
LC_DYLD_INFO = 0x22
LC_DYLD_INFO_ONLY = 0x80000022

# 点击类方法的候选关键字(命中就把 类名:选择器 打到输出里,可直接粘进 Tweak.xm)
CLICK_HINTS = (
    "didselect", "selectrow", "rowtap", "didpick", "didchoose",
    "handletap", "tapped", "tapgesture",
    "onclick", "clicked", "didclick",
    "applyitem", "applytext", "pasteitem", "copyitem", "insertitem",
    "chooseitem", "menuaction", "itemselected",
)

TYPEENC_RE = re.compile(r"^[vrciqsfdlB@^]?\d*[@^]?\d*[@:]?\d*:?\d*$")


def looks_like_typeenc(s):
    """排除 'v16@0:8' / '@16@0:8' 这类方法类型编码，避免污染选择器清单。"""
    if not s:
        return True
    if "\x00" in s:
        return True
    if TYPEENC_RE.match(s) and ("@" in s or ":" in s) and s[0] in "vrciqsfdlB@^":
        return True
    return False


# ---------------------------------------------------------------------------
# 基础解析
# ---------------------------------------------------------------------------

def read_slices(data):
    """返回 [(cputype, offset, size), ...]；非 fat 就返回单切片。"""
    if len(data) < 8:
        return []
    magic_be = struct.unpack(">I", data[:4])[0]
    if magic_be in (FAT_MAGIC, FAT_MAGIC_64):
        nfat = struct.unpack(">I", data[4:8])[0]
        off = 8
        out = []
        for _ in range(nfat):
            if magic_be == FAT_MAGIC:
                cputype, cpusub, offset, size, align = struct.unpack_from(">iiIII", data, off)
                off += 20
            else:
                cputype, cpusub, offset, size, align, resv = struct.unpack_from(">iiQQII", data, off)
                off += 32
            out.append((cputype, offset, size))
        return out
    return [(None, 0, len(data))]


class MachO(object):
    def __init__(self, data, base, size):
        self.data = data
        self.base = base
        self.size = size
        self.end = base + size
        self.cputype = 0
        self.filetype = 0
        self.sections = []          # [{name, seg, addr, size, offset}]
        self.by_name = {}
        self.segments = []
        self.chained_format = None
        self.has_chained = False

    # ---- 地址 / 偏移换算 ----
    def sec_at_addr(self, addr):
        for s in self.sections:
            if s["size"] and s["addr"] <= addr < s["addr"] + s["size"]:
                return s, s["offset"] + (addr - s["addr"])
        for g in self.segments:
            if g["vmsize"] and g["vmaddr"] <= addr < g["vmaddr"] + g["vmsize"]:
                o = g["fileoff"] + (addr - g["vmaddr"])
                if self.base <= o < self.end:
                    return None, o
        return None, None

    def read(self, addr, n):
        s, o = self.sec_at_addr(addr)
        if o is None or o + n > self.end:
            return None
        return self.data[o:o + n]

    def section(self, name):
        return self.by_name.get(name)

    def section_bytes(self, name):
        s = self.by_name.get(name)
        if not s or not s["size"]:
            return b""
        off = s["offset"]
        return self.data[off:min(off + s["size"], self.end)]

    # ---- 指针解析 ----
    def ptr(self, off):
        if off + 8 > self.end:
            return None
        raw = struct.unpack_from("<Q", self.data, off)[0]
        if raw == 0:
            return 0
        if not self.has_chained:
            return raw                       # 老式 rebase：磁盘上就是 vmaddr
        f = self.chained_format
        if f in (1, 5):                      # PTR_64 / PTR_64_OFFSET
            if (raw >> 63) & 1:
                return None                  # bind（外部符号）
            t = raw & 0xFFFFFFFFFFF
            return t if f == 1 else self.image_base + t
        if f in (6, 7, 9, 10, 12):           # ARM64E 系列
            if (raw >> 62) & 1:
                return None
            return self.image_base + (raw & 0xFFFFFFFF)
        return None

    image_base = 0

    # ---- 载入命令 ----
    def parse(self):
        d = self.data
        try:
            magic, cputype, cpusub, filetype, ncmds, sizeofcmds, flags, resv = \
                struct.unpack_from("<IiiIIIII", d, self.base)
        except struct.error:
            return False
        if magic != MH_MAGIC_64:
            return False
        self.cputype = cputype
        self.filetype = filetype

        off = self.base + 32
        chained_off = None
        for _ in range(ncmds):
            if off + 8 > self.end:
                break
            cmd, cmdsize = struct.unpack_from("<II", d, off)
            if cmdsize < 8:
                break
            if cmd == LC_SEGMENT_64:
                segname = d[off + 8:off + 24].split(b"\x00")[0].decode("utf-8", "replace")
                vmaddr, vmsize, fileoff, filesize = struct.unpack_from("<QQQQ", d, off + 24)
                nsects = struct.unpack_from("<I", d, off + 64)[0]
                seg = {"name": segname, "vmaddr": vmaddr, "vmsize": vmsize,
                       "fileoff": fileoff, "filesize": filesize}
                self.segments.append(seg)
                if segname == "__TEXT" and self.image_base == 0:
                    self.image_base = vmaddr
                soff = off + 72
                for _i in range(nsects):
                    if soff + 80 > self.end:
                        break
                    sectname = d[soff:soff + 16].split(b"\x00")[0].decode("utf-8", "replace")
                    segn = d[soff + 16:soff + 32].split(b"\x00")[0].decode("utf-8", "replace")
                    addr, sz = struct.unpack_from("<QQ", d, soff + 32)
                    sfileoff, align, reloff, nreloc, sflags = struct.unpack_from("<IIIII", d, soff + 48)
                    sec = {"name": sectname, "seg": segn, "addr": addr,
                           "size": sz, "offset": self.base + sfileoff}
                    self.sections.append(sec)
                    self.by_name.setdefault(sectname, sec)
                    soff += 80
            elif cmd == LC_DYLD_CHAINED_FIXUPS:
                chained_off = struct.unpack_from("<I", d, off + 8)[0]
            off += cmdsize

        if chained_off is not None:
            self.has_chained = True
            self.chained_format = self._chained_ptr_format(self.base + chained_off)
        return True

    def _chained_ptr_format(self, fixups_off):
        try:
            hdr = struct.unpack_from("<7I", self.data, fixups_off)
            starts_offset = hdr[1]
            starts = fixups_off + starts_offset
            seg_count = struct.unpack_from("<I", self.data, starts)[0]
            for i in range(seg_count):
                seg_info_off = struct.unpack_from("<I", self.data, starts + 4 + i * 4)[0]
                if seg_info_off == 0:
                    continue
                p = starts + seg_info_off
                _size, _page_size = struct.unpack_from("<IH", self.data, p)
                fmt = struct.unpack_from("<H", self.data, p + 6)[0]
                return fmt
        except (struct.error, IndexError):
            pass
        return None

    # ---- ObjC 结构 ----
    def cstr_at(self, addr):
        if addr is None:
            return None
        _s, o = self.sec_at_addr(addr)
        if o is None:
            return None
        end = self.data.find(b"\x00", o)
        if end < 0:
            return None
        return self.data[o:end].decode("utf-8", "replace")

    def method_list(self, addr):
        """返回 [(选择器, 类型编码), ...]"""
        s, o = self.sec_at_addr(addr)
        if o is None or o + 8 > self.end:
            return []
        entsize_raw, count = struct.unpack_from("<II", self.data, o)
        if count > 20000:
            return []
        relative = bool(entsize_raw & 0x80000000)
        ent = (entsize_raw & 0x7FFFFFFF) or (12 if relative else 24)
        out = []
        for j in range(count):
            eo = o + 8 + j * ent
            if eo + (12 if relative else 24) > self.end:
                break
            try:
                if relative:
                    name_off, types_off, imp_off = struct.unpack_from("<iii", self.data, eo)
                    name = self.cstr_at(eo + name_off)
                    types = self.cstr_at(eo + types_off)
                else:
                    name_p = self.ptr(eo)
                    types_p = self.ptr(eo + 8)
                    name = self.cstr_at(name_p)
                    types = self.cstr_at(types_p)
            except (struct.error, IndexError):
                break
            if name:
                out.append((name, types or ""))
        return out

    def classes(self):
        """返回 [(类名, [方法名...], superclass_addr)]"""
        res = []
        for secname in ("__objc_classlist", "__objc_nlclslist"):
            data = self.section_bytes(secname)
            if not data:
                continue
            for i in range(0, len(data) - 7, 8):
                cls_addr = self.ptr(self.by_name[secname]["offset"] + i)
                if not cls_addr:
                    continue
                ro = self.ptr(self._addr_to_off(cls_addr) + 32)
                if not ro:
                    continue
                ro_off = self._addr_to_off(ro)
                if ro_off is None:
                    continue
                try:
                    flags, istart, isize, resv = struct.unpack_from("<IIII", self.data, ro_off)
                except struct.error:
                    continue
                name_p = self.ptr(ro_off + 24)
                methods_p = self.ptr(ro_off + 32)
                name = self.cstr_at(name_p)
                methods = self.method_list(methods_p) if methods_p else []
                if name:
                    res.append((name, [m[0] for m in methods], methods_p))
        return res

    def _addr_to_off(self, addr):
        if addr is None:
            return None
        _s, o = self.sec_at_addr(addr)
        return o


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

def dump(path, grep=None, out=sys.stdout):
    data = open(path, "rb").read()
    slices = read_slices(data)
    if not slices:
        print("不是 Mach-O 文件: %s" % path, file=out)
        return 1

    print("=" * 72, file=out)
    print("文件: %s   (%d 字节, %d 个架构切片)" % (path, len(data), len(slices)), file=out)

    for idx, (cputype, offset, size) in enumerate(slices):
        mo = MachO(data, offset, size)
        if not mo.parse():
            print("  切片 %d: 解析失败(可能不是 64 位 Mach-O,或已加密)" % idx, file=out)
            continue

        arch = {12: "arm64", 16777228: "arm64", 16777222: "arm64e"}.get(mo.cputype, hex(mo.cputype))
        print("-" * 72, file=out)
        print("切片 %d  架构=%s  chained_fixups=%s  ptr_format=%s"
              % (idx, arch, mo.has_chained, mo.chained_format), file=out)
        print("  段: %s" % ", ".join(g["name"] for g in mo.segments), file=out)

        classes = mo.classes()
        print("  ObjC 类: %d 个" % len(classes), file=out)

        click_rows = []
        for name, methods, _mp in classes:
            print("", file=out)
            print("  @interface %s  (%d 个方法)" % (name, len(methods)), file=out)
            for m in methods:
                low = m.lower()
                mark = ""
                if any(h in low for h in CLICK_HINTS):
                    mark = "   <<< 点击候选"
                    click_rows.append("%s:%s" % (name, m))
                if grep and grep.lower() not in low:
                    if not mark:
                        continue
                print("      - %s%s" % (m, mark), file=out)

        if click_rows:
            print("", file=out)
            print("  " + "=" * 60, file=out)
            print("  【点击候选】直接粘进 Tweak.xm 的 KS_DEFAULT_CLICK_SELECTORS:", file=out)
            for r in sorted(set(click_rows)):
                print('      @"%s",' % r, file=out)

        # 全选择器清单
        sels = set()
        for _n, methods, _mp in classes:
            sels.update(methods)
        meth_section = mo.section_bytes("__objc_methname")
        if meth_section:
            for s in meth_section.split(b"\x00"):
                if not s:
                    continue
                t = s.decode("utf-8", "replace")
                if looks_like_typeenc(t):
                    continue
                sels.add(t)
        print("", file=out)
        print("  全部选择器(%d 个):" % len(sels), file=out)
        for s in sorted(sels):
            if grep and grep.lower() not in s.lower():
                continue
            print("      %s" % s, file=out)

    return 0


def main():
    ap = argparse.ArgumentParser(description="Mach-O / ObjC 元数据提取器")
    ap.add_argument("path", help="dylib / 可执行文件路径")
    ap.add_argument("--grep", "-g", default=None, help="只显示含该关键字的方法/选择器")
    ap.add_argument("--out", "-o", default=None, help="输出到文件")
    args = ap.parse_args()

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            return dump(args.path, args.grep, f)
    return dump(args.path, args.grep, sys.stdout)


if __name__ == "__main__":
    sys.exit(main())