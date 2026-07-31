TARGET = ios_mc_client.dylib
CC = xcrun -sdk iphoneos clang++
CFLAGS = -arch arm64 -miphoneos-version-min=14.0 -std=c++17 -shared -O2
LDFLAGS = -framework Foundation -framework UIKit -framework Metal -framework MetalKit -framework CoreGraphics -framework QuartzCore -framework WebKit

SRCS = main.mm hooks.cpp
HEADERS = client_mem.hpp hooks.hpp sdk.hpp

all: $(TARGET)

$(TARGET): $(SRCS) $(HEADERS)
	$(CC) $(CFLAGS) $(SRCS) -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(TARGET)
