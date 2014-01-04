THIS_FILENAME = $(lastword $(MAKEFILE_LIST))
THIS_DIR = $(dir $(THIS_FILENAME))

all:
	$(MAKE) -C $(THIS_DIR) $(TARGETS)

ifneq ($(INSTALL_TARGETS),)
install:
	$(MAKE) -C $(THIS_DIR) $(INSTALL_TARGETS)
else:
install:
endif

.PHONY: all install
