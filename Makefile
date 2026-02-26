# ─── Ferri Build System ───────────────────────────────

# Config
NDK_HOME    ?= $(ANDROID_NDK_HOME)
API_LEVEL    = 26
ENGINE_DIR   = engine
JNILIBS_DIR  = android/app/src/main/jniLibs

# Detect NDK prebuilt path (macOS vs Linux)
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	NDK_HOST = darwin-x86_64
else
	NDK_HOST = linux-x86_64
endif
NDK_CC = $(NDK_HOME)/toolchains/llvm/prebuilt/$(NDK_HOST)/bin

# ─── Go Engine Builds ─────────────────────────────────

.PHONY: build-engine-android
build-engine-android: build-engine-android-arm64

.PHONY: build-engine-android-arm64
build-engine-android-arm64:
	@mkdir -p $(JNILIBS_DIR)/arm64-v8a
	cd $(ENGINE_DIR) && \
	CGO_ENABLED=1 \
	GOOS=android \
	GOARCH=arm64 \
	CC=$(NDK_CC)/aarch64-linux-android$(API_LEVEL)-clang \
	go build -buildmode=c-shared \
		-trimpath \
		-tags netcgo \
		-ldflags="-s -w" \
		-o ../$(JNILIBS_DIR)/arm64-v8a/libferri.so \
		./mobile
	@echo "✓ libferri.so (arm64) → $(JNILIBS_DIR)/arm64-v8a/"

.PHONY: build-engine-android-x86
build-engine-android-x86:
	@mkdir -p $(JNILIBS_DIR)/x86_64
	cd $(ENGINE_DIR) && \
	CGO_ENABLED=1 \
	GOOS=android \
	GOARCH=amd64 \
	CC=$(NDK_CC)/x86_64-linux-android$(API_LEVEL)-clang \
	go build -buildmode=c-shared \
		-trimpath \
		-tags netcgo \
		-ldflags="-s -w" \
		-o ../$(JNILIBS_DIR)/x86_64/libferri.so \
		./mobile
	@echo "✓ libferri.so (x86_64) → $(JNILIBS_DIR)/x86_64/"

.PHONY: build-engine-android-all
build-engine-android-all: build-engine-android-arm64 build-engine-android-x86

# ─── Flutter ──────────────────────────────────────────

.PHONY: run-android
run-android: build-engine-android
	flutter run

.PHONY: run-android-emu
run-android-emu: build-engine-android-x86
	flutter run

.PHONY: run-dart
run-dart:
	flutter run

.PHONY: build-apk
build-apk: build-engine-android-all
	flutter build apk --release

# ─── Testing ──────────────────────────────────────────

.PHONY: test-engine
test-engine:
	cd $(ENGINE_DIR) && go test ./...

.PHONY: test-dart
test-dart:
	flutter test

.PHONY: test
test: test-engine test-dart

# ─── Lint ─────────────────────────────────────────────

.PHONY: lint
lint:
	cd $(ENGINE_DIR) && go vet ./...
	flutter analyze

# ─── Clean ────────────────────────────────────────────

.PHONY: clean
clean:
	rm -rf $(JNILIBS_DIR)/arm64-v8a/libferri.so
	rm -rf $(JNILIBS_DIR)/arm64-v8a/libferri.h
	rm -rf $(JNILIBS_DIR)/x86_64/libferri.so
	rm -rf $(JNILIBS_DIR)/x86_64/libferri.h
	flutter clean
	cd $(ENGINE_DIR) && go clean
