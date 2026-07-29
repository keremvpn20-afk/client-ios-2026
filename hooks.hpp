#pragma once
#include <stdint.h>

namespace Hooks {
    void Initialize();
    bool HookFunction(void* target, void* replace, void** original);
    void SetupMinecraftHooks();
}
