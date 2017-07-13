CP=cp -u -r -p
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	CP=rsync -au
endif

test_quiet:TRVPARAM=-f
test_detail:TRVPARAM=-d
test_qd:TRVPARAM=-f -d
windows:CMAKE_FLAGS=-DCMAKE_TOOLCHAIN_FILE=../cmake/Toolchain-mingw32.cmake -DCMAKE_INSTALL_PREFIX=/usr/i686-w64-mingw32/sys-root/mingw
VAPIDIR=/usr/share/vala/vapi

CMAKE_PREFIX=
ifeq "${MAKECMDGOALS}" "windows"
	CMAKE_PREFIX=-DCMAKE_INSTALL_PREFIX=/usr/i686-w64-mingw32/sys-root/mingw
endif

ifeq "${MAKECMDGOALS}" "windows64"
	CMAKE_PREFIX=-DCMAKE_INSTALL_PREFIX=/usr/x86_64-w64-mingw32/sys-root/mingw
endif

ifneq "${PREFIX}" ""
	CMAKE_PREFIX=-DCMAKE_INSTALL_PREFIX=${PREFIX}
endif

CMAKE_OPTS=${CMAKE_PREFIX} -DCMAKE_VALA_OPTS=${CMAKE_VALA_OPTS} -DVAPIDIRS=${VAPIDIRS} -DTARGET_GLIB=${TARGET_GLIB}

CMAKE_PREFIX=
ifneq "${PREFIX}" ""
	CMAKE_PREFIX=-DCMAKE_INSTALL_PREFIX=${PREFIX}
endif
CMAKE_OPTS=${CMAKE_PREFIX} -DVAPIDIRS=${VAPIDIRS}

all: build
	cp -u -r -p cmake build/
	cp -u -r -p doc build/
	cp -u -r -p src build/
	cp -u -r -p tests build/
	cp -u -r -p CMakeLists.txt build/
	find build/ -name CMakeCache.txt -delete
	cd build && cmake . ${CMAKE_OPTS} && make

install: build
	cd build && make install

clean: build
	rm -rf build

build:
	mkdir build
	mkdir build/log

testdir: build
	mkdir -p build/testdir

test: testdir
	cd build/tests && gtester ./test_dblib -k -o ../testdir/ergebnis.xml || exit 0
	cd build && trv ${TRVPARAM} -i testdir/ergebnis.xml

test_quiet: test
test_detail: test
test_qd: test
