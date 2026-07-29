#pragma once
#include <stdint.h>
#include <vector>
#include "sdk.hpp"

namespace Hooks {
    struct ESPObject {
        int type; // 0 = Player, 1 = Chest, 2 = Ender Chest, 3 = Hopper, 4 = Spawner, 5 = Piston, 6 = Barrel
        SDK::Vector2 screenPos;
        float distance;
    };
    extern std::vector<ESPObject> espObjects;

    void Initialize();
    bool HookFunction(void* target, void* replace, void** original);
    void SetupMinecraftHooks();
}
