cmake_minimum_required(VERSION 3.22)

project(Magnificator VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ---------------------------------------------------------------------------
# JUCE. Expects JUCE repo at ./JUCE (git submodule or clone).
#   git clone --depth 1 --branch 7.0.12 https://github.com/juce-framework/JUCE.git
# ---------------------------------------------------------------------------
if (NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/JUCE/CMakeLists.txt")
    message(FATAL_ERROR
        "JUCE not found. Run:\n"
        "  git clone --depth 1 --branch 7.0.12 https://github.com/juce-framework/JUCE.git\n"
        "inside the Magnificator directory.")
endif()

add_subdirectory(JUCE)

# ---------------------------------------------------------------------------
# Список форматів плагіна:
#   • VST3        — всюди
#   • Standalone  — зручно для тестів без DAW
#   • AU          — лише macOS
# ---------------------------------------------------------------------------
if(APPLE)
    set(MAGNIFICATOR_FORMATS VST3 AU Standalone)
else()
    set(MAGNIFICATOR_FORMATS VST3 Standalone)
endif()

juce_add_plugin(Magnificator
    COMPANY_NAME            "AudioLabs"
    BUNDLE_ID               "com.audiolabs.magnificator"
    PLUGIN_MANUFACTURER_CODE AuLb
    PLUGIN_CODE             Mgnf
    FORMATS                 ${MAGNIFICATOR_FORMATS}
    PRODUCT_NAME            "Magnificator"
    IS_SYNTH                FALSE
    NEEDS_MIDI_INPUT        FALSE
    NEEDS_MIDI_OUTPUT       FALSE
    IS_MIDI_EFFECT          FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE
    COPY_PLUGIN_AFTER_BUILD FALSE
    VST3_CATEGORIES         "Fx" "Reverb"
    AU_MAIN_TYPE            "kAudioUnitType_Effect")

juce_generate_juce_header(Magnificator)

target_sources(Magnificator PRIVATE
    Source/PluginProcessor.cpp
    Source/PluginEditor.cpp
    Source/DSP/FilterChain.cpp
    Source/DSP/ReverbEngine.cpp
    Source/GUI/MagnificatorLookAndFeel.cpp
    Source/GUI/BigKnob.cpp
    Source/GUI/ReverbSelectorWindow.cpp)

target_compile_definitions(Magnificator
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
        JUCE_DISPLAY_SPLASH_SCREEN=0
        JUCE_REPORT_APP_USAGE=0)

target_link_libraries(Magnificator
    PRIVATE
        juce::juce_audio_utils
        juce::juce_dsp
        juce::juce_gui_extra
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags)

target_include_directories(Magnificator PRIVATE Source)
