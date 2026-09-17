cmake_minimum_required(VERSION 3.14)
project(ai_helpdesk_client LANGUAGES CXX)

set(BINARY_NAME "ai_helpdesk_client")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Root directory of the Flutter project.
set(FLUTTER_PROJECT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/..")
