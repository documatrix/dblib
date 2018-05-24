set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/dblib")
set (GETTEXT_PACKAGE "dblib")
set (CMAKE_C_FLAGS "-g -O3")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions( ${MYSQL_CFLAGS} )
link_libraries ( ${MYSQL_LIBS} )
find_package (Vala REQUIRED)
include( UseVala )


set (VALA_PACKAGES ${VALA_PACKAGES} gio-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} glib-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} gobject-2.0)
set (VALA_PACKAGES ${VALA_PACKAGES} dmtestlib-1.0)
set (VALA_PACKAGES ${VALA_PACKAGES} posix)
set (VALA_PACKAGES ${VALA_PACKAGES} zlib)
set (VALA_PACKAGES ${VALA_PACKAGES} open_dmlib-1.0)
set (VALA_PACKAGES ${VALA_PACKAGES} dm_logger-1.0)
set (VALA_PACKAGES ${VALA_PACKAGES} open_dmlib_io)
set (VALA_PACKAGES ${VALA_PACKAGES} sqlite3)

set (DBLIB_SOURCES ${DBLIB_SOURCES} dblib.vala)
set (DBLIB_SOURCES ${DBLIB_SOURCES} dblib_mysql.vala)
set (DBLIB_SOURCES ${DBLIB_SOURCES} dblib_sqlite.vala)

set (CUSTOM_VAPIS_LIST ${CUSTOM_VAPIS_LIST} mysql.vapi)

if(${CMAKE_SYSTEM_NAME} STREQUAL Windows)
  set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DOS_WINDOWS")
  set (CMAKE_VALA_OPTS ${CMAKE_VALA_OPTS} -D OS_WINDOWS)
elseif(${CMAKE_SYSTEM_NAME} STREQUAL Darwin)
  set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DOS_MACOSX")
else()
  set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DOS_LINUX")
endif()


vala_precompile(DBLIB_VALA_C
  ${DBLIB_SOURCES}
PACKAGES
  ${VALA_PACKAGES}
GENERATE_VAPI
  ${DBLIB_NAME}
CUSTOM_VAPIS
  ${CUSTOM_VAPIS_LIST}
GENERATE_HEADER
  dblib
OPTIONS
--thread -g --vapidir=. --vapidir=${CMAKE_INSTALL_PREFIX}/share/vala/vapi ${VAPIDIRS_ARGS}
)

add_library(
  ${DBLIB_NAME} SHARED
  ${DBLIB_VALA_C}
)

ADD_CUSTOM_TARGET( dblib_preprocessed DEPENDS dblib.vala )
ADD_CUSTOM_COMMAND(
  SOURCE src/dblib.vala
  OUTPUT src/dblib.vala
  COMMAND ${PREPROCESS_LOGGER} ${CMAKE_SOURCE_DIR}/src/ ../log/messages.mdb dblib
)
ADD_DEPENDENCIES( ${DBLIB_NAME} dblib_preprocessed )

# CREATE PKGCONFIG FILES
if(NOT DEFINED CMAKE_INSTALL_BINDIR)
  set(CMAKE_INSTALL_BINDIR bin)
endif(NOT DEFINED CMAKE_INSTALL_BINDIR)
if(NOT DEFINED CMAKE_INSTALL_LIBDIR)
  set(CMAKE_INSTALL_LIBDIR lib)
endif(NOT DEFINED CMAKE_INSTALL_LIBDIR)
set(prefix       ${CMAKE_INSTALL_PREFIX})
set(exec_prefix ${CMAKE_INSTALL_PREFIX})
if(${CMAKE_SYSTEM_NAME} STREQUAL Windows)
  set(libdir       ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR})
else()
  set(libdir       ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR})
endif()
set(includedir  ${CMAKE_INSTALL_PREFIX}/include)
set(LIBS         "")
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/libdblib.pc.in
  ${CMAKE_CURRENT_BINARY_DIR}/${DBLIB_NAME}.pc @ONLY)

if(${CMAKE_SYSTEM_NAME} STREQUAL Windows)
# Install shared object
install(
TARGETS
  ${DBLIB_NAME}
DESTINATION
bin/
)
else()
# Install shared object
install(
TARGETS
  ${DBLIB_NAME}
LIBRARY DESTINATION
lib/
)
endif( )

# Install header files
install(
FILES
  ${CMAKE_CURRENT_BINARY_DIR}/dblib.h
DESTINATION
  include/${DBLIB_NAME}/
)

# Install vapi files
install(
FILES
  ${CMAKE_CURRENT_BINARY_DIR}/${DBLIB_NAME}.vapi
  ${CMAKE_CURRENT_BINARY_DIR}/mysql.vapi
DESTINATION
  ${CMAKE_INSTALL_PREFIX}/share/vala/vapi/
)

# Install message database...
install(
FILES
  ${CMAKE_CURRENT_BINARY_DIR}/../log/messages.mdb
DESTINATION
  share/${DBLIB_NAME}/
)

# Install pkg-config file...
install( FILES
  ${CMAKE_CURRENT_BINARY_DIR}/${DBLIB_NAME}.pc
DESTINATION
  ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)

if(HAVE_VALADOC)
  valadoc(dblib
    ${CMAKE_BINARY_DIR}/valadoc/dblib
    ${APP_SOURCES}
  PACKAGES
    ${VALA_PACKAGES}
  CUSTOM_VAPIS
    ${CUSTOM_VAPIS_LIST}
  )
  install(DIRECTORY
    ${CMAKE_BINARY_DIR}/valadoc
  DESTINATION
    share/doc/dblib
  )
endif()
