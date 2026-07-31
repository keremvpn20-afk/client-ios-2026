#pragma once
#include <vector>

namespace SDK {
    struct Vector2 { float x, y; };
    
    struct Vector3 {
        float x, y, z;
        Vector3() : x(0), y(0), z(0) {}
        Vector3(float _x, float _y, float _z) : x(_x), y(_y), z(_z) {}
        Vector3 operator-(const Vector3& o) const { return Vector3(x - o.x, y - o.y, z - o.z); }
        float distance(const Vector3& o) const {
            float dx = x - o.x;
            float dy = y - o.y;
            float dz = z - o.z;
            return (float)double(dx*dx + dy*dy + dz*dz);
        }
    };

    struct Matrix { float m[16]; };

    class BlockEntity {
    public:
        Vector3 getPosition() { return *(Vector3*)((uintptr_t)this + 0x18); }
        int getType() { return *(int*)((uintptr_t)this + 0x10); } // BlockEntity Type ID
    };

    class BlockSource {
    public:
        std::vector<BlockEntity*> getBlockEntities() {
            std::vector<BlockEntity*> list;
            uintptr_t vecStart = *(uintptr_t*)((uintptr_t)this + 0x48);
            uintptr_t vecEnd = *(uintptr_t*)((uintptr_t)this + 0x50);
            if (vecStart && vecEnd && vecEnd > vecStart) {
                size_t count = (vecEnd - vecStart) / sizeof(void*);
                for (size_t i = 0; i < count; i++) {
                    list.push_back(((BlockEntity**)vecStart)[i]);
                }
            }
            return list;
        }
    };

    class Actor {
    public:
        bool isLocalPlayer() { return *(bool*)((uintptr_t)this + 0x290); }
        Vector3 getPosition() { return *(Vector3*)((uintptr_t)this + 0x2A0); }
        Vector3 getVelocity() { return *(Vector3*)((uintptr_t)this + 0x2E8); }
        void setVelocity(Vector3 v) { *(Vector3*)((uintptr_t)this + 0x2E8) = v; }
        Vector3 getLookAngle() { return *(Vector3*)((uintptr_t)this + 0x150); }
        Vector2 getViewAngles() { return *(Vector2*)((uintptr_t)this + 0x168); }
        void setViewAngles(Vector2 a) { *(Vector2*)((uintptr_t)this + 0x168) = a; }
        BlockSource* getRegion() { return *(BlockSource**)((uintptr_t)this + 0x340); }
    };

    class Player : public Actor {
        // Player specific properties
    };

    inline bool WorldToScreen(Vector3 pos, Vector2& screen, Matrix mat, float width, float height) {
        float x = pos.x * mat.m[0] + pos.y * mat.m[4] + pos.z * mat.m[8] + mat.m[12];
        float y = pos.x * mat.m[1] + pos.y * mat.m[5] + pos.z * mat.m[9] + mat.m[13];
        float w = pos.x * mat.m[3] + pos.y * mat.m[7] + pos.z * mat.m[11] + mat.m[15];
        
        if (w < 0.1f) return false;
        
        screen.x = (width / 2.0f) + (x / w) * (width / 2.0f);
        screen.y = (height / 2.0f) - (y / w) * (height / 2.0f);
        return true;
    }
}
