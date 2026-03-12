#!/bin/bash
set -euo pipefail
SRC_DIR="$1"
cd "${SRC_DIR}"
log_info() { echo -e "\033[0;32m[PATCH]\033[0m $*"; }
log_info "Applying unique stub injection patches..."

# 1. Provide linker stubs - copy into src/ to satisfy CMake relative paths
cp /package/linker_stubs.c "${SRC_DIR}/src/linker_stubs.c"

# 2. Neutralize the webserver directory but KEEP cJSON
if [[ -f "src/webserver/CMakeLists.txt" ]]; then
    log_info "Neutralizing webserver and civetweb targets but keeping cJSON..."
    cat << 'SUB_EOF' > src/webserver/CMakeLists.txt
add_library(webserver INTERFACE)
add_library(civetweb INTERFACE)
add_subdirectory(cJSON)
SUB_EOF
fi

# 3. Patch src/CMakeLists.txt for main FTL binary
if [[ -f "src/CMakeLists.txt" ]]; then
    log_info "Neutralizing webserver and api references in src/CMakeLists.txt..."

    # Comment out subdirectories we don't want (keep webserver for cJSON)
    for dir in api zip; do
        sed -i "s|^add_subdirectory(${dir})|# add_subdirectory(${dir})|g" src/CMakeLists.txt
    done

    # Comment out target_compile_definitions for neutralized targets to avoid CMake errors
    sed -i 's|target_compile_definitions(civetweb|# target_compile_definitions(civetweb|g' src/CMakeLists.txt
    sed -i 's|target_compile_definitions(webserver|# target_compile_definitions(webserver|g' src/CMakeLists.txt

    # Remove TARGET_OBJECTS references for neutralized components from add_executable
    # KEEP cJSON, sqlite3, lua, etc.
    REMOVALS=("webserver" "civetweb" "api" "api_docs" "zip" "miniz")
    for target in "${REMOVALS[@]}"; do
        sed -i "s|\$<TARGET_OBJECTS:${target}>||g" src/CMakeLists.txt
    done

    # Add the stubs to the main executable
    # Use a more robust sed to ensure it's added only once and correctly
    if ! grep -q "linker_stubs.c" src/CMakeLists.txt; then
        sed -i 's|add_executable(pihole-FTL|add_executable(pihole-FTL linker_stubs.c|' src/CMakeLists.txt
    fi

    # Force link the math library at the end of all other libraries
    sed -i 's|target_link_libraries(pihole-FTL ${LIBMBEDTLS} ${LIBMBEDX509} ${LIBMBEDCRYPTO})|target_link_libraries(pihole-FTL ${LIBMBEDTLS} ${LIBMBEDX509} ${LIBMBEDCRYPTO} m)|g' src/CMakeLists.txt
fi

# 4. Neutralize password.c
if [[ -f "src/config/password.c" ]]; then
    echo "// Neutralized" > src/config/password.c
fi

# 5. Strip -Werror
find . -name "CMakeLists.txt" -print0 | while IFS= read -r -d '' f; do
    sed "s/-Werror//g" "$f" > "$f.tmp" && cat "$f.tmp" > "$f" && rm "$f.tmp"
done

log_info "Unique stub injection applied."
