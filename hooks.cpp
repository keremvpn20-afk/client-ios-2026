#include "hooks.hpp"
#include "memory.hpp"
#include <cmath>

namespace Hooks {
    typedef void (*tActorTick)(SDK::Actor*);
    tActorTick oActorTick = nullptr;

    typedef void (*tPlayerNormalTick)(SDK::Player*);
    tPlayerNormalTick oPlayerNormalTick = nullptr;

    typedef float (*tGetReachDistance)(SDK::Player*);
    tGetReachDistance oGetReachDistance = nullptr;

    typedef void (*tLerpMotion)(SDK::Actor*, SDK::Vector3);
    tLerpMotion oLerpMotion = nullptr;

    // v1.26.33 offsetleri bulunana kadar oyunu çökertmemek için 0x0 bırakıyoruz
    uintptr_t actorTickAddr = 0x0;
    uintptr_t playerNormalTickAddr = 0x0;
    uintptr_t getReachDistanceAddr = 0x0;
    uintptr_t lerpMotionAddr = 0x0;
    
    bool killauraEnabled = false;
    bool aimassistEnabled = false;
    bool triggerbotEnabled = false;
    bool flyEnabled = false;
    bool espEnabled = false;
    bool tracerEnabled = false;
    bool storageEspEnabled = false;
    bool storageChestEnabled = false;
    bool storageEnderChestEnabled = false;
    bool storageHopperEnabled = false;
    bool storageSpawnerEnabled = false;
    bool storagePistonEnabled = false;
    bool storageBarrelEnabled = false;
    float flySpeed = 1.5f;
    bool speedEnabled = false;
    float speedValue = 2.0f;
    bool reachEnabled = false;
    float reachDistance = 5.0f;
    bool velocityEnabled = false;
    float velocityValue = 0.0f;

    float espColor[3] = {1.0f, 0.0f, 0.0f};
    float tracerColor[3] = {0.5f, 0.0f, 0.5f};
    float storageChestColor[3] = {1.0f, 0.6f, 0.0f};
    float storageEnderChestColor[3] = {0.0f, 0.8f, 0.8f};
    float storageHopperColor[3] = {0.5f, 0.5f, 0.5f};
    float storageSpawnerColor[3] = {0.0f, 1.0f, 0.0f};
    float storagePistonColor[3] = {0.6f, 0.4f, 0.2f};
    float storageBarrelColor[3] = {0.9f, 0.8f, 0.2f};

    std::vector<ESPObject> espObjects;

    void hkActorTick(SDK::Actor* self) {
        if (self) {
            if (self->isLocalPlayer()) {
                if (flyEnabled) {
                    SDK::Vector3 vel = self->getVelocity();
                    vel.y = 0.0f;
                    
                    SDK::Vector3 look = self->getLookAngle();
                    vel.x = look.x * flySpeed;
                    vel.z = look.z * flySpeed;
                    
                    self->setVelocity(vel);
                }
            }
        }
        if (oActorTick) oActorTick(self);
    }

    SDK::Vector2 CalculateAngles(SDK::Vector3 from, SDK::Vector3 to) {
        SDK::Vector3 diff = to - from;
        float hyp = std::sqrt(diff.x * diff.x + diff.z * diff.z);
        
        SDK::Vector2 angles;
        angles.x = -std::atan2(diff.y, hyp) * 180.0f / M_PI;
        angles.y = std::atan2(diff.z, diff.x) * 180.0f / M_PI - 90.0f;
        return angles;
    }

    void hkPlayerNormalTick(SDK::Player* self) {
        if (self && self->isLocalPlayer()) {
            SDK::Vector3 localPos = self->getPosition();
            std::vector<SDK::Player*> targets;
            espObjects.clear();

            SDK::Matrix viewMatrix = *(SDK::Matrix*)(Memory::GetBaseAddress() + 0x2A00000);

            if (storageEspEnabled) {
                SDK::BlockSource* region = self->getRegion();
                if (region) {
                    auto blockEntities = region->getBlockEntities();
                    for (auto* blockEntity : blockEntities) {
                        if (blockEntity) {
                            SDK::Vector3 pos = blockEntity->getPosition();
                            SDK::Vector2 screen;
                            if (SDK::WorldToScreen(pos, screen, viewMatrix, 1920, 1080)) {
                                int type = blockEntity->getType();
                                int mappedType = -1;
                                
                                if (type == 1) mappedType = 1;
                                else if (type == 2) mappedType = 2;
                                else if (type == 8) mappedType = 3;
                                else if (type == 6) mappedType = 4;
                                else if (type == 10) mappedType = 5;
                                else if (type == 15) mappedType = 6;
                                
                                if (mappedType != -1) {
                                    float dist = localPos.distance(pos);
                                    espObjects.push_back({mappedType, screen, dist});
                                }
                            }
                        }
                    }
                }
            }

            if (killauraEnabled) {
                for (auto* target : targets) {
                    if (target && target != self) {
                        float dist = localPos.distance(target->getPosition());
                        if (dist < 4.5f) {
                            SDK::Vector2 targetAngles = CalculateAngles(localPos, target->getPosition());
                            self->setViewAngles(targetAngles);
                        }
                    }
                }
            }

            if (aimassistEnabled) {
                SDK::Player* closestTarget = nullptr;
                float closestDist = 9999.0f;
                for (auto* target : targets) {
                    if (target && target != self) {
                        float dist = localPos.distance(target->getPosition());
                        if (dist < 8.0f && dist < closestDist) {
                            closestDist = dist;
                            closestTarget = target;
                        }
                    }
                }
                
                if (closestTarget) {
                    SDK::Vector2 currentAngles = self->getViewAngles();
                    SDK::Vector2 targetAngles = CalculateAngles(localPos, closestTarget->getPosition());
                    
                    SDK::Vector2 smoothAngles;
                    smoothAngles.x = currentAngles.x + (targetAngles.x - currentAngles.x) * 0.15f;
                    smoothAngles.y = currentAngles.y + (targetAngles.y - currentAngles.y) * 0.15f;
                    self->setViewAngles(smoothAngles);
                }
            }
        }
        if (oPlayerNormalTick) oPlayerNormalTick(self);
    }

    bool HookFunction(void* target, void* replace, void** original) {
        if (!target || !replace) return false;

        *original = target;

        uint32_t patch[4];
        patch[0] = 0x58000050; // LDR X16, #8
        patch[1] = 0xD61F0200; // BR X16
        
        uintptr_t targetAddr = (uintptr_t)replace;
        patch[2] = targetAddr & 0xFFFFFFFF;
        patch[3] = (targetAddr >> 32) & 0xFFFFFFFF;

        return Memory::PatchMemory(target, patch, sizeof(patch));
    }

    void SetupMinecraftHooks() {
        uintptr_t base = Memory::GetBaseAddress();
        
        if (actorTickAddr != 0) {
            HookFunction((void*)(base + actorTickAddr), (void*)&hkActorTick, (void**)&oActorTick);
        }
        if (playerNormalTickAddr != 0) {
            HookFunction((void*)(base + playerNormalTickAddr), (void*)&hkPlayerNormalTick, (void**)&oPlayerNormalTick);
        }
    }
}
