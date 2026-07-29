#include "hooks.hpp"
#include "sdk.hpp"
#include "memory.hpp"
#include <iostream>

extern "C" void MSHookFunction(void* symbol, void* replace, void** result);

namespace Hooks {
    
    void (*oActorTick)(SDK::Actor* self);
    void (*oPlayerNormalTick)(SDK::Player* self);
    void (*oClientInstanceTick)(void* self);
    float (*oGetReachDistance)(SDK::Player* self);
    void (*oLerpMotion)(SDK::Actor* self, const SDK::Vector3& delta);

    uintptr_t actorTickAddr = 0x1000000;
    uintptr_t playerNormalTickAddr = 0x1000500;
    uintptr_t getReachDistanceAddr = 0x1000800;
    uintptr_t lerpMotionAddr = 0x1000900;
    
    bool killauraEnabled = false;
    bool aimassistEnabled = false;
    bool triggerbotEnabled = false;
    bool flyEnabled = false;
    bool espEnabled = false;
    bool tracerEnabled = false;
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
                
                if (speedEnabled) {
                    SDK::Vector3 vel = self->getVelocity();
                    vel.x *= speedValue;
                    vel.z *= speedValue;
                    self->setVelocity(vel);
                }
            }
        }
        oActorTick(self);
    }

    float hkGetReachDistance(SDK::Player* self) {
        if (reachEnabled && self->isLocalPlayer()) {
            return reachDistance;
        }
        return oGetReachDistance(self);
    }

    void hkLerpMotion(SDK::Actor* self, const SDK::Vector3& delta) {
        if (velocityEnabled && self->isLocalPlayer()) {
            SDK::Vector3 scaledDelta = SDK::Vector3(delta.x * velocityValue, delta.y * velocityValue, delta.z * velocityValue);
            oLerpMotion(self, scaledDelta);
            return;
        }
        oLerpMotion(self, delta);
    }

    SDK::Vector2 CalculateAngles(const SDK::Vector3& from, const SDK::Vector3& to) {
        SDK::Vector3 delta = SDK::Vector3(to.x - from.x, to.y - from.y, to.z - from.z);
        float hyp = sqrtf(delta.x * delta.x + delta.z * delta.z);
        
        float pitch = -atan2f(delta.y, hyp) * (180.0f / M_PI);
        float yaw = atan2f(delta.z, delta.x) * (180.0f / M_PI) - 90.0f;
        
        return SDK::Vector2(pitch, yaw);
    }

    void hkPlayerNormalTick(SDK::Player* self) {
        if (self && self->isLocalPlayer()) {
            SDK::Vector3 localPos = self->getPosition();
            std::vector<SDK::Player*> targets; 

            espObjects.clear();

            SDK::Matrix viewMatrix = *(SDK::Matrix*)(Memory::GetBaseAddress() + 0x2A00000);

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

            if (triggerbotEnabled) {
                // triggerbot logic
            }
        }
        oPlayerNormalTick(self);
    }

    bool HookFunction(void* target, void* replace, void** original) {
        #ifdef USE_SUBSTRATE
            MSHookFunction(target, replace, original);
            return true;
        #else
            *original = target;
            return true;
        #endif
    }

    void Initialize() {
        uintptr_t base = Memory::GetBaseAddress();
        
        void* targetActorTick = (void*)(base + actorTickAddr);
        void* targetPlayerNormalTick = (void*)(base + playerNormalTickAddr);

        HookFunction(targetActorTick, (void*)&hkActorTick, (void**)&oActorTick);
        HookFunction(targetPlayerNormalTick, (void*)&hkPlayerNormalTick, (void**)&oPlayerNormalTick);
        HookFunction((void*)(base + getReachDistanceAddr), (void*)&hkGetReachDistance, (void**)&oGetReachDistance);
        HookFunction((void*)(base + lerpMotionAddr), (void*)&hkLerpMotion, (void**)&oLerpMotion);
    }

    void SetupMinecraftHooks() {
        Initialize();
    }
}
