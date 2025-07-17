
default: all

PSPDEV_BASE_VERSION ?= 1.0.0
PSPDEV_GITSHA       := $(shell git rev-parse --short HEAD)
PSPDEV_VERSION      := $(PSPDEV_BASE_VERSION)-$(PSPDEV_GITSHA)
FLAVOUR             ?=

SRC_TARBALL    = pspdev-$(PSPDEV_VERSION)-source.tgz
BIN_TARBALL    = pspdev-$(PSPDEV_VERSION)$(if $(FLAVOUR),-$(FLAVOUR)).tgz

.PHONY: build-sources build-all clean

build-sources:
	@echo "==> Packaging source tarball $(SRC_TARBALL)"
	@rm -f $(SRC_TARBALL)
	@./builder.sh download-sources
	@sed -E "s/^(PSPDEV_GITSHA[[:space:]]*:=).*/\1 $(PSPDEV_GITSHA)/" Makefile > .makefile
	@tar czf $(SRC_TARBALL) --transform='s|^\.makefile$$|Makefile|' \
	  .makefile builder.sh packages sources dist
	@rm -f .makefile

build-all:
	@echo "==> Building into $$PSPDEV"
	@PSPDEV=$(PSPDEV) FLAVOUR=$(FLAVOUR) PSPDEV_VERSION=$(PSPDEV_VERSION) ./builder.sh build
	@echo "==> Packaging binary tarball $(BIN_TARBALL)"
	@rm -f $(BIN_TARBALL)
	@tar czf $(BIN_TARBALL) -C $(PSPDEV) .

all:
	mkdir build
	$(MAKE) build-all PSPDEV=$$(realpath build) PATH=$$PATH:$$(realpath build)/bin

install:
	mkdir -p $(DESTDIR)/opt/
	cp -r build $(DESTDIR)/opt/pspdev

clean:
	@rm -rf $(SRC_TARBALL) $(BIN_TARBALL)

sources-clean:
	@rm -rf sources

