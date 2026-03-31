.PHONY: build run shell gen-ssl extra-clean

HOST_HTTP_PROXY := $(or $(http_proxy),$(shell printf '%s' "$$HTTP_PROXY"))
HOST_HTTPS_PROXY := $(or $(https_proxy),$(shell printf '%s' "$$HTTPS_PROXY"))
HOST_ALL_PROXY := $(or $(all_proxy),$(shell printf '%s' "$$ALL_PROXY"))
HOST_NO_PROXY := $(or $(no_proxy),$(shell printf '%s' "$$NO_PROXY"))

PROXY_REWRITE_LOCALHOST ?= 0
HOST_GATEWAY_NAME ?= host.docker.internal
HOST_GATEWAY_MAP ?= $(HOST_GATEWAY_NAME):host-gateway

REPO  ?= dorowu/ubuntu-desktop-gnome-vnc
TAG   ?= latest
BUILD_NETWORK ?= host
HTTP_PROXY ?= $(HOST_HTTP_PROXY)
HTTPS_PROXY ?= $(or $(HOST_HTTPS_PROXY),$(HTTP_PROXY))
ALL_PROXY ?= $(HOST_ALL_PROXY)
NO_PROXY ?= localhost,127.0.0.1,::1,.cn,.com.cn,.net.cn,.org.cn,.gov.cn,.edu.cn,.mil.cn,mirrors.tuna.tsinghua.edu.cn,pypi.tuna.tsinghua.edu.cn,registry.npmmirror.com
http_proxy ?= $(HTTP_PROXY)
https_proxy ?= $(HTTPS_PROXY)
all_proxy ?= $(ALL_PROXY)
no_proxy ?= $(NO_PROXY)
APT_MIRROR ?= http://mirrors.tuna.tsinghua.edu.cn/ubuntu
APT_PORTS_MIRROR ?= http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports
NPM_REGISTRY ?= https://registry.npmmirror.com
PIP_INDEX_URL ?= https://pypi.tuna.tsinghua.edu.cn/simple
NVM_NODEJS_ORG_MIRROR ?= https://mirrors.tuna.tsinghua.edu.cn/nodejs-release
NODE_VERSION ?= 20.19.0
NVM_VERSION ?= v0.39.7
DESKTOP_USERNAME ?= ubuntu
DESKTOP_PASSWORD ?= ubuntu

ifeq ($(PROXY_REWRITE_LOCALHOST),1)
EFFECTIVE_HTTP_PROXY := $(subst localhost,$(HOST_GATEWAY_NAME),$(subst 127.0.0.1,$(HOST_GATEWAY_NAME),$(HTTP_PROXY)))
EFFECTIVE_HTTPS_PROXY := $(subst localhost,$(HOST_GATEWAY_NAME),$(subst 127.0.0.1,$(HOST_GATEWAY_NAME),$(HTTPS_PROXY)))
EFFECTIVE_ALL_PROXY := $(subst localhost,$(HOST_GATEWAY_NAME),$(subst 127.0.0.1,$(HOST_GATEWAY_NAME),$(ALL_PROXY)))
EFFECTIVE_NO_PROXY := $(subst localhost,$(HOST_GATEWAY_NAME),$(subst 127.0.0.1,$(HOST_GATEWAY_NAME),$(NO_PROXY)))
EFFECTIVE_http_proxy := $(EFFECTIVE_HTTP_PROXY)
EFFECTIVE_https_proxy := $(EFFECTIVE_HTTPS_PROXY)
EFFECTIVE_all_proxy := $(EFFECTIVE_ALL_PROXY)
EFFECTIVE_no_proxy := $(EFFECTIVE_NO_PROXY)
BUILD_ADD_HOST := --add-host=$(HOST_GATEWAY_MAP)
RUN_ADD_HOST := --add-host=$(HOST_GATEWAY_MAP)
else
EFFECTIVE_HTTP_PROXY := $(HTTP_PROXY)
EFFECTIVE_HTTPS_PROXY := $(HTTPS_PROXY)
EFFECTIVE_ALL_PROXY := $(ALL_PROXY)
EFFECTIVE_NO_PROXY := $(NO_PROXY)
EFFECTIVE_http_proxy := $(http_proxy)
EFFECTIVE_https_proxy := $(https_proxy)
EFFECTIVE_all_proxy := $(all_proxy)
EFFECTIVE_no_proxy := $(no_proxy)
endif

build:
	docker build --network=$(BUILD_NETWORK) \
		$(BUILD_ADD_HOST) \
		--build-arg HTTP_PROXY=$(EFFECTIVE_HTTP_PROXY) \
		--build-arg HTTPS_PROXY=$(EFFECTIVE_HTTPS_PROXY) \
		--build-arg ALL_PROXY=$(EFFECTIVE_ALL_PROXY) \
		--build-arg NO_PROXY=$(EFFECTIVE_NO_PROXY) \
		--build-arg http_proxy=$(EFFECTIVE_http_proxy) \
		--build-arg https_proxy=$(EFFECTIVE_https_proxy) \
		--build-arg all_proxy=$(EFFECTIVE_all_proxy) \
		--build-arg no_proxy=$(EFFECTIVE_no_proxy) \
		--build-arg APT_MIRROR=$(APT_MIRROR) \
		--build-arg APT_PORTS_MIRROR=$(APT_PORTS_MIRROR) \
		--build-arg NPM_REGISTRY=$(NPM_REGISTRY) \
		--build-arg PIP_INDEX_URL=$(PIP_INDEX_URL) \
		--build-arg NVM_NODEJS_ORG_MIRROR=$(NVM_NODEJS_ORG_MIRROR) \
		--build-arg NODE_VERSION=$(NODE_VERSION) \
		--build-arg NVM_VERSION=$(NVM_VERSION) \
		-t $(REPO):$(TAG) .

run:
	docker run --privileged --rm \
		-p 6080:80 -p 5900:5900 \
		-v /dev/shm:/dev/shm \
		$(RUN_ADD_HOST) \
		-e DESKTOP_USERNAME=$(DESKTOP_USERNAME) \
		-e DESKTOP_PASSWORD=$(DESKTOP_PASSWORD) \
		-e HTTP_PROXY=$(EFFECTIVE_HTTP_PROXY) \
		-e HTTPS_PROXY=$(EFFECTIVE_HTTPS_PROXY) \
		-e ALL_PROXY=$(EFFECTIVE_ALL_PROXY) \
		-e NO_PROXY=$(EFFECTIVE_NO_PROXY) \
		-e http_proxy=$(EFFECTIVE_http_proxy) \
		-e https_proxy=$(EFFECTIVE_https_proxy) \
		-e all_proxy=$(EFFECTIVE_all_proxy) \
		-e no_proxy=$(EFFECTIVE_no_proxy) \
		--name ubuntu-desktop-gnome-test \
		$(REPO):$(TAG)

shell:
	docker exec -it ubuntu-desktop-gnome-test bash

gen-ssl:
	mkdir -p ssl
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout ssl/nginx.key -out ssl/nginx.crt

extra-clean:
	docker rmi $(REPO):$(TAG)
	docker image prune -f
