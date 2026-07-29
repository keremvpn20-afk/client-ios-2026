# iOS Minecraft Bedrock Cheat Client Makefile
# Bu Makefile macOS üzerinde Xcode/Command Line Tools yüklü ise iOS arm64 dylib derlemek için kullanılabilir.

TARGET = ios_mc_client.dylib
CC = xcrun -sdk iphoneos clang++
CFLAGS = -arch arm64 -miphoneos-version-min=14.0 -std=c++17 -shared -O2
LDFLAGS = -framework Foundation -framework UIKit -framework Metal -framework MetalKit

SRCS = main.mm hooks.cpp
HEADERS = memory.hpp hooks.hpp sdk.hpp

all: $(TARGET)

$(TARGET): $(SRCS) $(HEADERS)
	$(CC) $(CFLAGS) $(SRCS) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(TARGET)
