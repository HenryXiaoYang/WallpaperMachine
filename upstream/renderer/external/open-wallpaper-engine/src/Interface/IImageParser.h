#pragma once
#include "Image.hpp"
#include <algorithm>
#include <bit>
//#include "Fs/VFS.h"
#include <memory>
#include <string>

namespace wallpaper
{
class IImageParser {
public:
    IImageParser()                                                 = default;
    virtual ~IImageParser()                                        = default;
    virtual std::shared_ptr<Image> Parse(const std::string&)       = 0;
    virtual ImageHeader            ParseHeader(const std::string&) = 0;

    // Set before preparing textures, including parallel prefetch. A zero-sized
    // surface keeps the authored resolution for asset-only callers.
    // ponytail: display-sized budget; use projected layer coverage if zoom needs finer detail.
    virtual void SetTextureSurfaceSize(uint32_t width, uint32_t height) {
        m_texture_dimension_limit = width && height
            ? std::bit_ceil(uint64_t(std::max(width, height))) : 0;
    }

protected:
    uint64_t m_texture_dimension_limit { 0 };
};
} // namespace wallpaper
