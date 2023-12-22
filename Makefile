SRCDIR ?= /opt/fpp/src
include ${SRCDIR}/makefiles/common/setup.mk
include $(SRCDIR)/makefiles/platform/*.mk

all: libfpp-plugin-BackgroundMusic.$(SHLIB_EXT)
debug: all

OBJECTS_fpp_BackgroundMusic_so += src/FPPBackgroundMusic.o
LIBS_fpp_BackgroundMusic_so += -L${SRCDIR} -lfpp -ljsoncpp -lhttpserver
CXXFLAGS_src/FPPBackgroundMusic.o += -I${SRCDIR}

%.o: %.cpp Makefile
	$(CCACHE) $(CC) $(CFLAGS) $(CXXFLAGS) $(CXXFLAGS_$@) -c $< -o $@

libfpp-plugin-BackgroundMusic.$(SHLIB_EXT): $(OBJECTS_fpp_BackgroundMusic_so) ${SRCDIR}/libfpp.$(SHLIB_EXT)
	$(CCACHE) $(CC) -shared $(CFLAGS_$@) $(OBJECTS_fpp_BackgroundMusic_so) $(LIBS_fpp_BackgroundMusic_so) $(LDFLAGS) -o $@

clean:
	rm -f libfpp-BackgroundMusic.so $(OBJECTS_fpp_BackgroundMusic_so)