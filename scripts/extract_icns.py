"""Extract all icon images from a macOS .icns file to PNG files."""

import struct
import sys
import os
from pathlib import Path
from PIL import Image

# Icon type -> (width, height, description)
TYPE_INFO = {
    "is32": (16, 16, "16x16 ARGB"),
    "s8mk": (16, 16, "16x16 mask"),
    "il32": (32, 32, "32x32 ARGB"),
    "l8mk": (32, 32, "32x32 mask"),
    "ic11": (32, 32, "32x32@2x PNG"),
    "ic12": (64, 64, "64x64@2x PNG"),
    "ic07": (128, 128, "128x128@1x PNG"),
    "ic08": (256, 256, "256x256@1x PNG"),
    "ic13": (256, 256, "256x256@2x PNG"),
    "ic09": (512, 512, "512x512@1x PNG"),
    "ic14": (512, 512, "512x512@2x PNG"),
    "ic10": (1024, 1024, "1024x1024@1x PNG"),
}


def parse_icns(path):
    """Parse .icns file and return list of (icon_type, data) tuples."""
    with open(path, "rb") as f:
        magic = f.read(4)
        if magic != b"icns":
            raise ValueError("Not a valid .icns file")

        total_size = struct.unpack(">I", f.read(4))[0]
        entries = []

        while f.tell() < total_size:
            icon_type_raw = f.read(4)
            if len(icon_type_raw) < 4:
                break
            icon_type = icon_type_raw.decode("ascii", errors="replace")
            data_size = struct.unpack(">I", f.read(4))[0]
            data = f.read(data_size - 8)
            entries.append((icon_type, data))

        return entries


def get_filename(width, height, desc):
    """Build filename with scale suffix to avoid conflicts."""
    if "@2x" in desc:
        return f"icon_{width}x{height}@2x.png"
    return f"icon_{width}x{height}.png"


def save_png(icon_type, width, height, desc, data, output_dir):
    """Save PNG icon entry directly."""
    filename = get_filename(width, height, desc)
    filepath = os.path.join(output_dir, filename)

    # Check for PNG signature
    if data[:4] == b"\x89PNG":
        with open(filepath, "wb") as f:
            f.write(data)
        return filename, "PNG"

    return None, None


def save_argb(icon_type, width, height, data, output_dir):
    """Convert raw ARGB data to PNG and save."""
    filename = f"icon_{width}x{height}.png"
    filepath = os.path.join(output_dir, filename)

    expected_size = width * height * 4
    if len(data) != expected_size:
        print(f"  [WARN] {icon_type}: size mismatch (got {len(data)}, expected {expected_size})")
        return None, None

    # ARGB -> RGBA conversion
    img = Image.frombytes("RGBA", (width, height), data, "raw", "ARGB")
    img.save(filepath, "PNG")
    return filename, "ARGB"


def extract_icns(input_path, output_dir):
    """Main extraction function."""
    print(f"Reading: {input_path}")
    entries = parse_icns(input_path)
    print(f"Found {len(entries)} entries\n")

    os.makedirs(output_dir, exist_ok=True)

    png_entries = {}
    argb_entries = {}

    # First pass: categorize entries
    for icon_type, data in entries:
        if icon_type in ("is32", "il32"):
            argb_entries[icon_type] = data
        elif icon_type.startswith("ic") and len(icon_type) == 4 and icon_type[2:].isdigit():
            png_entries[icon_type] = data
        elif icon_type in TYPE_INFO:
            print(f"  [SKIP] {icon_type}: {TYPE_INFO[icon_type][2]} (mask or legacy)")
        else:
            print(f"  [SKIP] {icon_type}: unknown type, {len(data)} bytes")

    # Process PNG entries
    print("\n--- PNG entries ---")
    for icon_type, data in png_entries.items():
        w, h, desc = TYPE_INFO.get(icon_type, (0, 0, "Unknown"))
        filename, fmt = save_png(icon_type, w, h, desc, data, output_dir)
        if filename:
            print(f"  {icon_type} ({desc}) -> {filename} ({fmt}, {len(data)} bytes)")
        else:
            print(f"  [FAIL] {icon_type}: not valid PNG data")

    # Process ARGB entries
    print("\n--- ARGB entries ---")
    for icon_type, data in argb_entries.items():
        w, h, desc = TYPE_INFO.get(icon_type, (0, 0, "Unknown"))
        filename, fmt = save_argb(icon_type, w, h, data, output_dir)
        if filename:
            print(f"  {icon_type} ({desc}) -> {filename} ({fmt}, {len(data)} bytes)")

    # Summary
    print(f"\nDone. Files saved to: {output_dir}")
    files = sorted(os.listdir(output_dir))
    for f in files:
        fpath = os.path.join(output_dir, f)
        size_kb = os.path.getsize(fpath) / 1024
        print(f"  {f} ({size_kb:.1f} KB)")


if __name__ == "__main__":
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    input_file = project_root / "assets" / "icons" / "favicon.icns"
    output_dir = project_root / "assets" / "icons" / "extracted"

    if not input_file.exists():
        print(f"Input file not found: {input_file}")
        sys.exit(1)

    extract_icns(str(input_file), str(output_dir))
