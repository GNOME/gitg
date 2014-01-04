THIS_FILENAME = $(lastword $(MAKEFILE_LIST))
THIS_DIR = $(dir $(THIS_FILENAME))

all:
	$(MAKE) -C $(THIS_DIR) $(TARGETS)

.PHONY: all
