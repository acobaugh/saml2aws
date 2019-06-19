NAME=saml2aws
ARCH=$(shell uname -m)
VERSION=2.15.0
ITERATION := 1
GOLANGCI_VERSION="v1.17.1"

SOURCE_FILES?=$$(go list ./... | grep -v /vendor/)
TEST_PATTERN?=.
TEST_OPTIONS?=

GOLANGCI_INSTALLED := $(shell which golangci-lint)
GO111MODULE=on

ci: deps test

deps:
	go get github.com/buildkite/github-release
	go get -u github.com/mitchellh/gox
ifndef GOLANGCI_INSTALLED
	curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s $(GOLANGCI_VERSION)
endif

compile:
	@rm -rf build/
	@gox -ldflags "-X main.Version=$(VERSION)" \
	-osarch="darwin/amd64" \
	-osarch="linux/i386" \
	-osarch="linux/amd64" \
	-osarch="windows/amd64" \
	-osarch="windows/i386" \
	-output "build/{{.Dir}}_$(VERSION)_{{.OS}}_{{.Arch}}/$(NAME)" \
	${SOURCE_FILES}

# Run all the linters
lint:
	golangci-lint run

# gofmt and goimports all go files
fmt:
	find . -name '*.go' -not -wholename './vendor/*' | while read -r file; do gofmt -w -s "$$file"; goimports -w "$$file"; done

install:
	go install ./cmd/saml2aws

dist:
	$(eval FILES := $(shell ls build))
	@rm -rf dist && mkdir dist
	@for f in $(FILES); do \
		(cd $(shell pwd)/build/$$f && tar -cvzf ../../dist/$$f.tar.gz *); \
		(cd $(shell pwd)/dist && shasum -a 512 $$f.tar.gz > $$f.sha512); \
		echo $$f; \
	done

release:
	@github-release "v$(VERSION)" dist/* --commit "$(git rev-parse HEAD)" --github-repository versent/$(NAME)

test:
	@go test -v -cover ./...

clean:
	@rm -fr ./build

packages:
	rm -rf package && mkdir package
	rm -rf stage && mkdir -p stage/usr/bin
	cp build/saml2aws_*_linux_amd64/saml2aws stage/usr/bin
	fpm --name $(NAME) -a x86_64 -t rpm -s dir --version $(VERSION) --iteration $(ITERATION) -C stage -p package/$(NAME)-$(VERSION)_$(ITERATION).rpm usr
	fpm --name $(NAME) -a x86_64 -t deb -s dir --version $(VERSION) --iteration $(ITERATION) -C stage -p package/$(NAME)-$(VERSION)_$(ITERATION).deb usr
	shasum -a 512 package/$(NAME)-$(VERSION)_$(ITERATION).rpm > package/$(NAME)-$(VERSION)_$(ITERATION).rpm.sha512
	shasum -a 512 package/$(NAME)-$(VERSION)_$(ITERATION).deb > package/$(NAME)-$(VERSION)_$(ITERATION).deb.sha512

generate-mocks:
	mockery -dir pkg/prompter --all

.PHONY: default deps compile lint fmt dist release test clean generate-mocks
