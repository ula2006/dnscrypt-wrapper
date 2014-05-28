# The default target of this Makefile is...
all::

# Section starts with '###'.
#
# Define V=1 to have a more verbose compile.

### Defaults

BASIC_CFLAGS = -O2 -std=c99 -pedantic -Wall -I./argparse
BASIC_LDFLAGS = -lm -lsodium

# Guard against environment variables
LIB_H = 
LIB_OBJS = 
DEP_LIBS =

# Having this variable in your environment would break pipelines because you
# case "cd" to echo its destination to stdout.
unexport CDPATH

### Configurations

uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo not')
uname_M := $(shell sh -c 'uname -m 2>/dev/null || echo not')
uname_O := $(shell sh -c 'uname -o 2>/dev/null || echo not')
uname_R := $(shell sh -c 'uname -r 2>/dev/null || echo not')
uname_P := $(shell sh -c 'uname -p 2>/dev/null || echo not')
uname_V := $(shell sh -c 'uname -v 2>/dev/null || echo not')

# CFLAGS and LDFLAGS are for users to override
CFLAGS = -g -O2 -Wall
LDFLAGS =
STRIP ?= strip

# We use ALL_* variants
ALL_CFLAGS = $(CFLAGS) $(BASIC_CFLAGS)
ALL_LDFLAGS = $(LDFLAGS) $(BASIC_LDFLAGS)

prefix = /usr/local
bindir = $(prefix)/bin
sharedir = $(prefix)/share
mandir = share/man
infodir = share/info
export prefix bindir sharedir

CC = cc
RM = rm -rf
PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

ifeq ($(uname_S),Linux)
	ALL_LDFLAGS += -lrt
endif

ifeq ($(uname_S),OpenBSD)
	BASIC_LDFLAGS += -levent_core
else
	BASIC_LDFLAGS += -levent
endif

ifneq ($(findstring $(MAKEFLAGS),s), s)
ifndef V
	QUIET_CC   = @echo ' ' CC   $@;
	QUIET_AR   = @echo ' ' AR   $@;
	QUIET_LINK = @echo ' ' LINK $@;
	QUIET_GEN  = @echo ' ' GEN  $@;
endif
endif

# configuration generated by ./configure script
-include config.mak.autogen
# manual configuration
-include config.mak

### Dependencies

LIB_H = dnscrypt.h udp_request.h edns.h logger.h argparse/argparse.h

LIB_OBJS += dnscrypt.o
LIB_OBJS += udp_request.o
LIB_OBJS += tcp_request.o
LIB_OBJS += edns.o
LIB_OBJS += logger.o
LIB_OBJS += rfc1035.o
LIB_OBJS += safe_rw.o
LIB_OBJS += cert.o
LIB_OBJS += pidfile.o

DEP_LIBS += argparse/libargparse.a

### Automatically dependencies rules

OBJECTS := $(LIB_OBJS) main.o

ifndef COMPUTE_HEADER_DEPENDENCIES
COMPUTE_HEADER_DEPENDENCIES = auto
endif

ifeq ($(COMPUTE_HEADER_DEPENDENCIES),auto)
dep_check = $(shell $(CC) \
	-c -MF /dev/null -MMD -MP -x c /dev/null -o /dev/null 2>&1; \
	echo $$?)
ifeq ($(dep_check),0)
override COMPUTE_HEADER_DEPENDENCIES = yes
else
override COMPUTE_HEADER_DEPENDENCIES = no
endif
endif

ifeq ($(COMPUTE_HEADER_DEPENDENCIES),yes)
USE_COMPUTED_HEADER_DEPENDENCIES = YesPlease
else
ifneq ($(COMPUTE_HEADER_DEPENDENCIES),no)
$(error please set COMPUTE_HEADER_DEPENDENCIES to yes, no, or auto \
(not "$(COMPUTE_HEADER_DEPENDENCIES)"))
endif
endif

dep_files := $(foreach f,$(OBJECTS),$(dir $f).depend/$(notdir $f).d)
dep_dirs := $(addsuffix .depend,$(sort $(dir $(OBJECTS))))

ifeq ($(COMPUTE_HEADER_DEPENDENCIES),yes)
$(dep_dirs):
	@mkdir -p $@
missing_dep_dirs := $(filter-out $(wildcard $(dep_dirs)),$(dep_dirs))
dep_file = $(dir $@).depend/$(notdir $@).d
dep_args = -MF $(dep_file) -MMD -MP
endif

ifdef USE_COMPUTED_HEADER_DEPENDENCIES
# Take advantage of gcc's on-the-fly dependency generation
# See <http://gcc.gnu.org/gcc-3.0/features.html>.
dep_files_present := $(wildcard $(dep_files))
ifneq ($(dep_files_present),)
include $(dep_files_present)
endif
else
$(OBJECTS): $(LIB_H)
endif

### Build rules

configure: configure.ac
	$(QUIET_GEN)autoconf -o $@ $<

ifdef AUTOCONFIGURED
config.status: configure
	$(QUIET_GEN)if test -f config.status; then \
		./config.status --recheck; \
	else \
		./configure; \
	fi
reconfigure config.mak.autogen: config.status
	$(QUIET_LINK)./config.status
.PHONY: reconfigure # This is a convenience target.
endif

argparse/libargparse.a: argparse/argparse.h
	@$(MAKE) -C argparse libargparse.a

argparse/argparse.h:
	git submodule update --init argparse

$(LIB_OBJS): $(LIB_H)

TRACK_CFLAGS = $(CC):$(subst ','\'',$(ALL_CFLAGS))

MAIN-CFLAGS: FORCE
	@FLAGS='$(TRACK_CFLAGS)'; \
	if test x"$$FLAGS" != x"`cat MAIN-CFLAGS 2>/dev/null`"; then \
		echo "$$FLAGS" > $@; \
	fi

TRACK_LDFLAGS = $(subst ','\'',$(ALL_LDFLAGS))

MAIN-LDFLAGS: FORCE
	@FLAGS='$(TRACK_LDFLAGS)'; \
	if test x"$$FLAGS" != x"`cat MAIN-LDFLAGS 2>/dev/null`"; then \
		echo "$$FLAGS" > $@; \
	fi

$(OBJECTS): %.o: %.c $(missing_dep_dirs) MAIN-CFLAGS
	$(QUIET_CC)$(CC) -o $*.o -c $(dep_args) $(ALL_CFLAGS) $<

dnscrypt-wrapper: $(OBJECTS) $(DEP_LIBS) MAIN-LDFLAGS
	$(QUIET_LINK)$(CC) -o $@ $(filter %.o %.a,$^) $(ALL_LDFLAGS)

main.o: version.h

all:: dnscrypt-wrapper

### Misc rules

fmt:
	./format.sh

install: all
	install -p -m 755 dnscrypt-wrapper $(BINDIR)

uninstall:
	$(RM) $(BINDIR)/dnscrypt-wrapper

clean:
	$(RM) dnscrypt-wrapper
	$(RM) $(LIB_OBJS)

.PHONY: all install uninstall clean FORCE fmt
