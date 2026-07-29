#pragma once
#include <stdint.h>
#include <math.h>

namespace SDK {

    struct Vector3 {
        float x, y, z;
        Vector3() : x(0), y(0), z(0) {}
        Vector3(float x, float y, float z) : x(x), y(y), z(z) {}
        
        float distance(const Vector3& other) const {
            float dx = x - other.x;
            float dy = y - other.y;
            float dz = z - other.z;
            return sqrtf(dx*dx + dy*dy + dz*dz);
        }
    };

    struct Vector2 {
        float x, y;
        Vector2() : x(0), y(0) {}
        Vector2(float x, float y) : x(x), y(y) {}
    };

    struct Matrix {
        float m[16];
    };

    // Helper to project 3D world coordinates to 2D screen coordinates
    inline bool WorldToScreen(const Vector3& pos, Vector2& screen, const Matrix& matrix, float width, float height) {
        float x = pos.x * matrix.m[0] + pos.y * matrix.m[4] + pos.z * matrix.m[8] + matrix.m[12];
        float y = pos.x * matrix.m[1] + pos.y * matrix.m[5] + pos.z * matrix.m[9] + matrix.m[13];
        float w = pos.x * matrix.m[3] + pos.y * matrix.m[7] + pos.z * matrix.m[11] + matrix.m[15];

        if (w < 0.1f) return false;

        float ndc_x = x / w;
        float ndc_y = y / w;

        screen.x = (width / 2.0f) + (ndc_x * width / 2.0f);
        screen.y = (height / 2.0f) - (ndc_y * height / 2.0f);
        return true;
    }

    class Actor {
    public:
        uintptr_t* getVTable() {
            return *(uintptr_t**)this;
        }

        Vector3 getPosition() {
            return *(Vector3*)((uintptr_t)this + 0x4C0);
        }

        void setPosition(const Vector3& pos) {
            *(Vector3*)((uintptr_t)this + 0x4C0) = pos;
        }

        Vector3 getVelocity() {
            return *(Vector3*)((uintptr_t)this + 0x4F0);
        }

        void setVelocity(const Vector3& vel) {
            *(Vector3*)((uintptr_t)this + 0x4F0) = vel;
        }

        Vector3 getLookAngle() {
            float pitch = *(float*)((uintptr_t)this + 0x138);
            float yaw = *(float*)((uintptr_t)this + 0x13C);
            return Vector3(0, 0, 0); 
        }

        Vector2 getViewAngles() {
            return *(Vector2*)((uintptr_t)this + 0x138);
        }

        void setViewAngles(const Vector2& angles) {
            *(Vector2*)((uintptr_t)this + 0x138) = angles;
        }

        bool isLocalPlayer() {
            // Usually a virtual check or class identity check
            // RTTI check or virtual method call at index 1 or 2
            return false; 
        }
    };

    class Player : public Actor {
    public:
        // Additional Player methods (e.g. getName, getHandSlot)
    };

    class LocalPlayer : public Player {
    public:
        // LocalPlayer specifics
    };
}
