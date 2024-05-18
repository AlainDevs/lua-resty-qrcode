-- @module ffi_qrencode, luajit ffi bindings for libqrencode, cairo and gd libraries

local _M = {}
local ngx_log = ngx.log
local ffi = require("ffi")
local band = require("bit").band
local base_encoding = require("resty.base_encoding")
local insert = table.insert
local concat = table.concat
local format = string.format
-- Define the functions and types you need from the library
ffi.cdef[[
  typedef enum {
    QR_MODE_NUL = -1,
    QR_MODE_NUM = 0,
    QR_MODE_AN,
    QR_MODE_8,
    QR_MODE_KANJI,
    QR_MODE_STRUCTURE,
    QR_MODE_ECI,
    QR_MODE_FNC1FIRST,
    QR_MODE_FNC1SECOND
} QRencodeMode;

typedef enum {
    QR_ECLEVEL_L = 0,
    QR_ECLEVEL_M,
    QR_ECLEVEL_Q,
    QR_ECLEVEL_H
} QRecLevel;

typedef struct {
    int version;
    int width;
    unsigned char *data;
} QRcode;

QRcode *QRcode_encodeString(const char *string, int version, QRecLevel level, QRencodeMode hint, int casesensitive);
QRcode *QRcode_encodeString8bitMQR(const char *string, int version, QRecLevel level);
QRcode *QRcode_encodeString8bit(const char *string, int version, QRecLevel level);
void QRcode_free(QRcode *qrcode);


/*please continue cairo cdef*/
typedef enum _cairo_status {
    CAIRO_STATUS_SUCCESS = 0,
    CAIRO_STATUS_NO_MEMORY,
    CAIRO_STATUS_INVALID_RESTORE,
    CAIRO_STATUS_INVALID_POP_GROUP,
    CAIRO_STATUS_NO_CURRENT_POINT,
    CAIRO_STATUS_INVALID_MATRIX,
    CAIRO_STATUS_INVALID_STATUS,
    CAIRO_STATUS_NULL_POINTER,
    CAIRO_STATUS_INVALID_STRING,
    CAIRO_STATUS_INVALID_PATH_DATA,
    CAIRO_STATUS_READ_ERROR,
    CAIRO_STATUS_WRITE_ERROR,
    CAIRO_STATUS_SURFACE_FINISHED,
    CAIRO_STATUS_SURFACE_TYPE_MISMATCH,
    CAIRO_STATUS_PATTERN_TYPE_MISMATCH,
    CAIRO_STATUS_INVALID_CONTENT,
    CAIRO_STATUS_INVALID_FORMAT,
    CAIRO_STATUS_INVALID_VISUAL,
    CAIRO_STATUS_FILE_NOT_FOUND,
    CAIRO_STATUS_INVALID_DASH,
    CAIRO_STATUS_INVALID_DSC_COMMENT,
    CAIRO_STATUS_INVALID_INDEX,
    CAIRO_STATUS_CLIP_NOT_REPRESENTABLE,
    CAIRO_STATUS_TEMP_FILE_ERROR,
    CAIRO_STATUS_INVALID_STRIDE,
    CAIRO_STATUS_FONT_TYPE_MISMATCH,
    CAIRO_STATUS_USER_FONT_IMMUTABLE,
    CAIRO_STATUS_USER_FONT_ERROR,
    CAIRO_STATUS_NEGATIVE_COUNT,
    CAIRO_STATUS_INVALID_CLUSTERS,
    CAIRO_STATUS_INVALID_SLANT,
    CAIRO_STATUS_INVALID_WEIGHT,
    CAIRO_STATUS_INVALID_SIZE,
    CAIRO_STATUS_USER_FONT_NOT_IMPLEMENTED,
    CAIRO_STATUS_DEVICE_TYPE_MISMATCH,
    CAIRO_STATUS_DEVICE_ERROR,
    CAIRO_STATUS_INVALID_MESH_CONSTRUCTION,
    CAIRO_STATUS_DEVICE_FINISHED,
    CAIRO_STATUS_LAST_STATUS
} cairo_status_t;
typedef enum _cairo_format {
    CAIRO_FORMAT_ARGB32,
    CAIRO_FORMAT_RGB24 = 1,
    CAIRO_FORMAT_A8 = 2,
    CAIRO_FORMAT_A1 = 3,
    CAIRO_FORMAT_RGB16_565 = 4,
    CAIRO_FORMAT_RGB30 = 5
} cairo_format_t;
typedef struct _cairo_surface cairo_surface_t;
typedef struct _cairo cairo_t;

typedef cairo_status_t (*cairo_write_func_t) (void *closure,
                                             const unsigned char *data,
                                             unsigned int length);
cairo_surface_t * cairo_image_surface_create (cairo_format_t format,
					      int width,
					      int height);
cairo_t * cairo_create (cairo_surface_t *target);
void cairo_destroy (cairo_t *cr);
cairo_status_t cairo_status (cairo_t *cr);
void cairo_set_source_rgb (cairo_t *cr,
			    double red, double green, double blue);
void cairo_rectangle (cairo_t *cr,
                      double x, double y,
                      double width, double height);
void cairo_fill (cairo_t *cr);
void cairo_paint (cairo_t *cr);
void cairo_new_path(cairo_t * cr);
cairo_surface_t * cairo_image_surface_create_for_data (unsigned char		*data,
						    cairo_format_t	format,
						    int			width,
						    int			height,
						    int			stride);
cairo_status_t cairo_surface_write_to_png_stream (cairo_surface_t *surface,
							cairo_write_func_t write_func,
							void *closure);
void cairo_surface_destroy (cairo_surface_t *surface);
cairo_status_t cairo_surface_status (cairo_surface_t *surface);
]]

-- Load the library
local libqrencode = ffi.load("qrencode")

function _M.generate_qr_code_svg(text, margin)
    margin = margin or 4
    text = text or "Hello, World!"
    local qr = libqrencode.QRcode_encodeString8bit(text, 0, libqrencode.QR_ECLEVEL_L)
    if not qr then error("Failed to generate QR code") end

    local width = qr.width
    local cellSize = 8 -- Reduced cell size
    local svgWidth = (width + 2 * margin) * cellSize
    local svg = { '<?xml version="1.0" encoding="UTF-8"?>',
                  '<svg xmlns="http://www.w3.org/2000/svg" width="' .. svgWidth .. '" height="' .. svgWidth .. '">',
                  '<rect width="100%" height="100%" fill="#fff"/>' } -- Optimized background

    local fixedMarginCellSize = margin * cellSize
    local pathTemplate = '<path d="%s" fill="%s"/>'
    local paths = {}
    for y = 0, width - 1 do
        local row = {}
        for x = 0, width - 1 do
            local color = band(qr.data[y * width + x], 1) == 1 and '#000' or '#fff'
            row[x + 1] = color == '#000' and format('M%d %dh%dv%dh-%dz', x * cellSize + fixedMarginCellSize, (y + margin) * cellSize, cellSize, cellSize, cellSize) or ''
        end
        paths[y + 1] = concat(row)
    end
    insert(svg, format(pathTemplate, concat(paths), '#000'))
    insert(svg, '</svg>')
    libqrencode.QRcode_free(qr)
    return concat(svg)
end


-- Load the libgd library
local libcairo = ffi.load("cairo")
      
function _M.create_red_image_base64()
    local width, height = 210, 210
    local surface = libcairo.cairo_image_surface_create(libcairo.CAIRO_FORMAT_A1, width, height)
    if libcairo.cairo_surface_status(surface) ~= libcairo.CAIRO_STATUS_SUCCESS then 
        return nil, "Failed to create surface"
    end

    local cr = libcairo.cairo_create(surface)
    if libcairo.cairo_status(cr) ~= libcairo.CAIRO_STATUS_SUCCESS then 
        libcairo.cairo_surface_destroy(surface)
        return nil, "Failed to create cairo context"
    end

    libcairo.cairo_set_source_rgb(cr, 1, 0, 0) -- red
    libcairo.cairo_paint(cr)

    -- Allocate a buffer for the PNG data
    local buffer_size = 1024 * 1024 -- 1MB should be enough for this simple image
    local buffer = ffi.new("unsigned char[?]", buffer_size)
    local buffer_offset = 0

    -- Define the write function
    local write_func = ffi.cast("cairo_write_func_t", function(closure, data, length)
        local char_ptr = ffi.cast("unsigned char *", closure) -- Cast to char *
        ffi.copy(char_ptr + buffer_offset, data, length) 
        buffer_offset = buffer_offset + length
        return libcairo.CAIRO_STATUS_SUCCESS
    end)

    local status = libcairo.cairo_surface_write_to_png_stream(surface, write_func, buffer)
    
    -- Free the callback
    write_func:free()

    if status ~= libcairo.CAIRO_STATUS_SUCCESS then 
        libcairo.cairo_destroy(cr)
        libcairo.cairo_surface_destroy(surface)
        return nil, "Failed to write PNG data"
    end

    libcairo.cairo_destroy(cr)
    libcairo.cairo_surface_destroy(surface)

    return base_encoding.encode_base64(ffi.string(buffer, buffer_offset)), nil
end

function _M.generate_qr_code_cairo_png(text, margin, cellSize)
    margin = margin or 1
    text = text or "Hello, World!"
    cellSize = cellSize or 2

    local qr = libqrencode.QRcode_encodeString8bit(text, 0, libqrencode.QR_ECLEVEL_L)
    if not qr then return nil, "Failed to generate QR code" end
    
    local width = qr.width
    local imageWidth = (width + 2 * margin) * cellSize

    local surface = libcairo.cairo_image_surface_create(libcairo.CAIRO_FORMAT_ARGB32, imageWidth, imageWidth)
    if libcairo.cairo_surface_status(surface) ~= libcairo.CAIRO_STATUS_SUCCESS then 
        libqrencode.QRcode_free(qr)
        return nil, "Failed to create surface"
    end

    local cr = libcairo.cairo_create(surface)
    if libcairo.cairo_status(cr) ~= libcairo.CAIRO_STATUS_SUCCESS then 
        libcairo.cairo_surface_destroy(surface)
        libqrencode.QRcode_free(qr)
        return nil, "Failed to create cairo context" 
    end

    -- White background
    libcairo.cairo_set_source_rgb(cr, 1, 1, 1) 
    libcairo.cairo_paint(cr)

    -- Draw QR code modules
    libcairo.cairo_set_source_rgb(cr, 0, 0, 0) 
    libcairo.cairo_new_path(cr) 

    for y = 0, width - 1 do
        for x = 0, width - 1 do
            if band(qr.data[y * width + x], 1) == 1 then
                local rect_x = (x + margin) * cellSize
                local rect_y = (y + margin) * cellSize
                -- Add rectangle to path
                libcairo.cairo_rectangle(cr, rect_x, rect_y, cellSize, cellSize)
            end
        end
    end
    libcairo.cairo_fill(cr)
    -- Allocate a buffer for the PNG data
    local width, height = 50, 50 -- (Or get dimensions from elsewhere)
    local initial_buffer_size = width * height * 4 * 1.5 -- Initial estimate
    local buffer = ffi.new("unsigned char[?]", initial_buffer_size)
    local buffer_offset = 0
    
    local write_func = ffi.cast("cairo_write_func_t", function(closure, data, length)
        if buffer_offset + length > initial_buffer_size then
            -- Reallocation logic
            local new_buffer_size = initial_buffer_size * 2 -- Double the size
            local new_buffer = ffi.new("unsigned char[?]", new_buffer_size)
    
            if new_buffer then -- Reallocation successful
                ffi.copy(new_buffer, buffer, buffer_offset) -- Copy existing data
                ffi.C.free(buffer) -- Free the old buffer
                buffer = new_buffer 
                initial_buffer_size = new_buffer_size
                ffi.copy(buffer + buffer_offset, data, length)
                buffer_offset = buffer_offset + length
                return libcairo.CAIRO_STATUS_SUCCESS
            else -- Reallocation failed
                return libcairo.CAIRO_STATUS_NO_MEMORY
            end
        else
            ffi.copy(buffer + buffer_offset, data, length)
            buffer_offset = buffer_offset + length
            return libcairo.CAIRO_STATUS_SUCCESS 
        end
    end)

    local status = libcairo.cairo_surface_write_to_png_stream(surface, write_func, buffer)

    -- Free the callback
    write_func:free()
    libcairo.cairo_destroy(cr)
    libcairo.cairo_surface_destroy(surface)
    libqrencode.QRcode_free(qr)
    if status ~= libcairo.CAIRO_STATUS_SUCCESS then
        ffi.C.free(buffer) -- Free the buffer in case of an error
        if status == libcairo.CAIRO_STATUS_NO_MEMORY then
            ngx_log(ngx.ERR, "PNG encoding failed: memory allocation error")
            return nil, "PNG encoding failed: memory allocation error" 
        else
            ngx_log(ngx.ERR, "PNG encoding failed: Cairo error")
            return nil, "PNG encoding failed: Cairo error"
        end
    end

    return base_encoding.encode_base64(ffi.string(buffer, buffer_offset)), nil
end

-- Load the libgd library
local libgd = ffi.load("gd")

function _M.generate_qr_code_gd_png(text, scale)
    scale = scale or 1  -- Default scale is 1 if not provided, not recommended to use scale > 5, performance will be affected
    text = text or "Hello, World!"
    local qr = libqrencode.QRcode_encodeString8bit(text, 0, libqrencode.QR_ECLEVEL_L)
    if not qr then error("Failed to generate QR code") end

    local width = qr.width * scale  -- Scale the width
    local img = libgd.gdImageCreateTrueColor(width, width)
    local white = libgd.gdImageColorAllocate(img, 255, 255, 255)
    local black = libgd.gdImageColorAllocate(img, 0, 0, 0)

    local color
    for y = 0, qr.width - 1 do
        for x = 0, qr.width - 1 do
            color = band(qr.data[y * qr.width + x], 1) == 1 and black or white
            -- Scale the QR code pixels
            libgd.gdImageFilledRectangle(img, x * scale, y * scale, (x + 1) * scale - 1, (y + 1) * scale - 1, color)
        end
    end

    local size = ffi.new("int[1]")
    local png = libgd.gdImagePngPtr(img, size)
    local png_str = ffi.string(png, size[0])
    libgd.gdFree(png)
    libgd.gdImageDestroy(img)
    libqrencode.QRcode_free(qr)

    return base_encoding.encode_base64(png_str)
end

return _M
