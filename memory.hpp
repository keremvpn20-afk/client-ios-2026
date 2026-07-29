#pragma once
#include <stdint.h>
#include <vector>
#include <string>
#include <mach/mach.h>
#include <mach-o/dyld.h>

namespace Memory {
    inline uintptr_t GetBaseAddress() {
        return (uintptr_t)_dyld_get_image_header(0);
    }

    template <typename T>
    inline bool Write(uintptr_t address, T value) {
        kern_return_t kr;
        mach_port_t self = mach_task_self();
        
        kr = vm_protect(self, (vm_address_t)address, sizeof(T), FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        if (kr != KERN_SUCCESS) return false;

        *(T*)address = value;

        vm_protect(self, (vm_address_t)address, sizeof(T), FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
        return true;
    }

    inline bool Patch(uintptr_t address, const std::vector<uint8_t>& bytes) {
        kern_return_t kr;
        mach_port_t self = mach_task_self();

        kr = vm_protect(self, (vm_address_t)address, bytes.size(), FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        if (kr != KERN_SUCCESS) return false;

        memcpy((void*)address, bytes.data(), bytes.size());

        vm_protect(self, (vm_address_t)address, bytes.size(), FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
        return true;
    }

    template <typename T>
    inline T Read(uintptr_t address) {
        if (address == 0) return T{};
        return *(T*)address;
    }

    inline uintptr_t ResolvePointer(uintptr_t base, const std::vector<unsigned int>& offsets) {
        uintptr_t addr = base;
        for (unsigned int offset : offsets) {
            addr = Read<uintptr_t>(addr);
            if (addr == 0) return 0;
            addr += offset;
        }
        return addr;
    }
}
