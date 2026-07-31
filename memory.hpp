#pragma once
#include <stdint.h>
#include <stddef.h>

namespace Memory {
    uintptr_t GetBaseAddress();
    bool PatchMemory(void* target, void* patch, size_t size);
}
