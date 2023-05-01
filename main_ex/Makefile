DEV_ID := $(shell source ../IDs.sh && echo $$DEV_ID)
ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
CFLAGS = -mmacosx-version-min=10.9
else
CFLAGS = -mmacosx-version-min=11.0
endif
all: SageMath.c
	gcc $(CFLAGS) -o SageMath -framework CoreFoundation SageMath.c
	codesign -v -s $(DEV_ID) --timestamp --options runtime --force SageMath

