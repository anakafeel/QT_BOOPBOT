cmake_minimum_required(VERSION 3.16)
project(boopbot)

set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_add_executable(boopbot main.cpp camera_provider.cpp camera_provider.h)

target_link_libraries(boopbot PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    camapi
    screen
)

# QML files need to be beside the binary at runtime
