# lua-resty-qrcode
# LuaJIT FFI QR Code Generation

This module utilizes LuaJIT's FFI to bind to `libqrencode`, `cairo` and `gd` libraries, providing efficient functions for generating QR code images in various formats.

## Features

- Generates QR codes in SVG, PNG (using Cairo or GD), and Base64 encoded PNG formats.
- Allows customization of margins, cell size, and scale.
- Leverages FFI for performance optimization.

## Functions

### `generate_qr_code_svg(text, margin)`

Generates an SVG representation of a QR code.

- **`text`**: The text to encode in the QR code. Defaults to "Hello, World!".
- **`margin`**: The margin around the QR code in cells. Defaults to 4.

**Returns**: A string containing the SVG data.

### `create_red_image_base64()`

Creates a simple red square image encoded in Base64. This function serves as a demonstration of using Cairo to create and encode images.

**Returns**: A string containing the Base64 encoded PNG data.

### `generate_qr_code_cairo_png(text, margin, cellSize)`

Generates a PNG image of a QR code using the Cairo graphics library.

- **`text`**: The text to encode in the QR code. Defaults to "Hello, World!".
- **`margin`**: The margin around the QR code in cells. Defaults to 1.
- **`cellSize`**: The size of each module in the QR code, in pixels. Defaults to 2.

**Returns**: A string containing the Base64 encoded PNG data.

### `generate_qr_code_gd_png(text, scale)`

Generates a PNG image of a QR code using the GD graphics library.

- **`text`**: The text to encode in the QR code. Defaults to "Hello, World!".
- **`scale`**:  The scaling factor for the QR code image. Defaults to 1. Note: Using scales greater than 5 can impact performance.

**Returns**: A string containing the Base64 encoded PNG data.

## Example Usage

```lua
local ffi_qrencode = require("ffi_qrencode")
local base_encoding = require("resty.base_encoding")

-- Generate an SVG QR code
local svg_qr = ffi_qrencode.generate_qr_code_svg("This is a test", 2)
ngx.say(svg_qr)

-- Generate a PNG QR code using Cairo
local png_qr_cairo = ffi_qrencode.generate_qr_code_cairo_png("Cairo QR Code", 3, 4)
ngx.header.content_type = "image/png"
ngx.print(base_encoding.decode_base64(png_qr_cairo))

-- Generate a PNG QR code using GD
local png_qr_gd = ffi_qrencode.generate_qr_code_gd_png("GD QR Code", 2)
ngx.header.content_type = "image/png"
ngx.print(base_encoding.decode_base64(png_qr_gd))

```

## Dependencies

- LuaJIT
- libqrencode
- libcairo
- libgd
- resty.base_encoding

## Installation

1. Ensure the required libraries are installed on your system.
2. Copy the `qrcode.lua` file to your project.
3. Require the module in your Lua code:

```lua
local ffi_qrcode = require("qrcode")
```

## Notes

- Error handling is implemented to provide informative messages in case of failures.
- The `generate_qr_code_cairo_png` function includes dynamic buffer allocation to handle potentially larger image sizes.
- The module prioritizes performance optimization through FFI and careful memory management.
- Code readability is maintained while still focusing on efficiency.

---
