# Toolchain: Linux → Windows x86_64 (MinGW-w64)
# Використання:
#   cmake -B build-win -DCMAKE_TOOLCHAIN_FILE=mingw-w64-x86_64.cmake \
#         -DCMAKE_BUILD_TYPE=Release -G Ninja

set(CMAKE_SYSTEM_NAME    Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# MinGW-w64 toolchain
set(TOOLCHAIN_PREFIX x86_64-w64-mingw32)

set(CMAKE_C_COMPILER   ${TOOLCHAIN_PREFIX}-gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}-g++)
set(CMAKE_RC_COMPILER  ${TOOLCHAIN_PREFIX}-windres)

# Де шукати бібліотеки та хедери
set(CMAKE_FIND_ROOT_PATH /usr/${TOOLCHAIN_PREFIX})

# Не шукати програми host-системи
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Шукати бібліотеки/хедери тільки в cross-root
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# --- Статичне лінкування runtime-ів MinGW
# Щоб результатний .vst3 DLL не потребував libgcc_s_seh-1.dll, libstdc++-6.dll,
# libwinpthread-1.dll на комп'ютері користувача.
set(CMAKE_CXX_FLAGS_INIT "-static-libgcc -static-libstdc++")
set(CMAKE_EXE_LINKER_FLAGS_INIT    "-static -static-libgcc -static-libstdc++")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-static -static-libgcc -static-libstdc++")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-static -static-libgcc -static-libstdc++")
