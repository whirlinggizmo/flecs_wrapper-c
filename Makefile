# Makefile for flecs_wrapper

# Helper for recursive wildcard (find all .c files in subdirs)
rwildcard = $(wildcard $1$2) $(foreach d,$(wildcard $1*/),$(call rwildcard,$d,$2))

# Paths
WRAPPER_SRC_DIR     = ./src/
WRAPPER_INC_DIR     = ./include/
BUILD_DIR           = ./build
WRAPPER_BUILD_DIR   = $(BUILD_DIR)/wrapper
BIN_DIR             = ./lib
TEST_DIR            = ./tests

# Output
TARGET_DYNAMIC      = $(BIN_DIR)/libflecs_wrapper.so
TARGET_STATIC       = $(BIN_DIR)/libflecs_wrapper.a
TEST_SYSTEM_EX      = $(BIN_DIR)/test_system_ex
TEST_NATIVE_DIR     = $(TEST_DIR)/native

# Source files
WRAPPER_SRC = $(call rwildcard,$(WRAPPER_SRC_DIR),*.c)

# Compiler settings
CC      = gcc
CFLAGS  = -fPIC -Wall -O2 -fvisibility=default 
LDFLAGS = -shared

# Default target: build both static and dynamic libs
all: $(TARGET_DYNAMIC) $(TARGET_STATIC)

static: $(TARGET_STATIC)
dynamic: $(TARGET_DYNAMIC)

# Build dynamic library
$(TARGET_DYNAMIC): $(WRAPPER_SRC)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -I$(WRAPPER_INC_DIR) $(WRAPPER_SRC) -o $(TARGET_DYNAMIC) $(LDFLAGS)

# Build static library
$(TARGET_STATIC): $(WRAPPER_SRC)
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(WRAPPER_BUILD_DIR)
	$(foreach src,$(WRAPPER_SRC),$(CC) $(CFLAGS) -I$(WRAPPER_INC_DIR) -c $(src) -o $(WRAPPER_BUILD_DIR)/$(notdir $(basename $(src))).o;)
	ar rcs $(TARGET_STATIC) $(WRAPPER_BUILD_DIR)/*.o

# Clean build artifacts
clean:
	rm -f $(TARGET_DYNAMIC) $(TARGET_STATIC)
	rm -f $(TEST_SYSTEM_EX)
	rm -rf $(BUILD_DIR)

# Print build variables (for debugging)
print-srcs:
	@echo "TARGET_DYNAMIC: $(TARGET_DYNAMIC)"
	@echo "TARGET_STATIC: $(TARGET_STATIC)"
	@echo "BUILD_DIR: $(BUILD_DIR)"
	@echo "BIN_DIR: $(BIN_DIR)"
	@echo "WRAPPER_SRC_DIR: $(WRAPPER_SRC_DIR)"
	@echo "WRAPPER_INC_DIR: $(WRAPPER_INC_DIR)"
	@echo "WRAPPER_SRC: $(WRAPPER_SRC)"

test: $(TEST_SYSTEM_EX)
	$(TEST_SYSTEM_EX)

$(TEST_SYSTEM_EX): $(TEST_NATIVE_DIR)/test_system_ex.c $(TARGET_DYNAMIC)
	$(CC) -I$(WRAPPER_INC_DIR) $< -L$(BIN_DIR) -lflecs_wrapper -lm -Wl,-rpath,$(BIN_DIR) -o $@
