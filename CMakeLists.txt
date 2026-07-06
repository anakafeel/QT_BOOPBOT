cmake_minimum_required(VERSION 3.16)
project(boopbot)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Network)
qt_add_executable(boopbot
    main.cpp
    camera_provider.cpp camera_provider.h
    ros_bridge.cpp ros_bridge.h
)
qt_add_resources(boopbot "qml"
    PREFIX "/"
    FILES Main.qml
)
target_link_libraries(boopbot PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Network
    camapi
)
