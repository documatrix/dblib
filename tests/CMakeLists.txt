set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/dblib")
set (GETTEXT_PACKAGE "dblib")
set (CMAKE_C_FLAGS "")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions (${DEPS_CFLAGS})
add_definitions( ${MYSQL_CFLAGS} )
include_directories( ${CMAKE_SOURCE_DIR}/src )
link_libraries ( ${DEPS_LIBRARIES} )
link_libraries ( ${DBLIB_NAME} )
link_libraries ( ${MYSQL_LIBS} )
link_directories ( ${DEPS_LIBRARY_DIRS} )
find_package (Vala REQUIRED)
include( UseVala )

set (TEST_DBLIB_SOURCES ${TEST_DBLIB_SOURCES} test_dblib.vala)
set (CUSTOM_VAPIS_LIST ${CUSTOM_VAPIS_LIST} ${CMAKE_SOURCE_DIR}/src/mysql.vapi)

vala_precompile(TEST_DBLIB_VALA_C
  ${TEST_DBLIB_SOURCES}
PACKAGES
  ${VALA_PACKAGES} ${DBLIB_NAME}
OPTIONS
--thread --vapidir=${CMAKE_SOURCE_DIR}/src --vapidir=${CMAKE_INSTALL_PREFIX}/share/vala/vapi ${VAPIDIRS_ARGS}
CUSTOM_VAPIS
  ${CUSTOM_VAPIS_LIST}
)

add_executable(
  test_dblib
  ${TEST_DBLIB_VALA_C}
)

install(TARGETS
  test_dblib
RUNTIME DESTINATION
  bin/
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
