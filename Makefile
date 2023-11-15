APP_NAME=Bucketeer

CONFIGURATION ?= Debug
SCHEME ?= $(APP_NAME)
DEVICE ?= "iPhone\ 13"

XCODEBUILD=xcodebuild

OPTIONS=\
	-project $(APP_NAME).xcodeproj \
	-scheme $(SCHEME)

EXAMPLE_OPTIONS=\
	-project $(APP_NAME).xcodeproj \
	-scheme Example

DESTINATION=-destination "name=$(DEVICE)"

CLEAN=rm -rf build
SHOW_BUILD_SETTINGS=$(XCODEBUILD) $(OPTIONS) $(DESTINATION) \
	-configuration $(CONFIGURATION) \
	-showBuildSettings
BUILD=$(XCODEBUILD) $(OPTIONS) $(DESTINATION) \
	-configuration $(CONFIGURATION) \
	build
BUILD_FOR_TESTING=$(XCODEBUILD) $(OPTIONS) $(DESTINATION) \
	-configuration $(CONFIGURATION) \
	build-for-testing
TEST_WITHOUT_BUILDING=$(XCODEBUILD) $(OPTIONS) $(DESTINATION) \
	-configuration $(CONFIGURATION) \
	-skip-testing:BucketeerTests/E2EBKTClientForceUpdateTests \
	-skip-testing:BucketeerTests/E2EEvaluationTests \
	-skip-testing:BucketeerTests/E2EEventTests \
	test-without-building
E2E_WITHOUT_BUILDING=$(XCODEBUILD) $(OPTIONS) $(DESTINATION) \
	-configuration $(CONFIGURATION) \
	-only-testing:BucketeerTests/E2EBKTClientForceUpdateTests \
	-only-testing:BucketeerTests/E2EEvaluationTests \
	-only-testing:BucketeerTests/E2EEventTests \
	test-without-building E2E_API_ENDPOINT=$(E2E_API_ENDPOINT) E2E_API_KEY=$(E2E_API_KEY)
ALL_TEST_WITHOUT_BUILDING=$(XCODEBUILD) $(OPTIONS) $(DESTINATION) \
	-configuration $(CONFIGURATION) \
	test-without-building
BUILD_EXAMPLE=$(XCODEBUILD) $(EXAMPLE_OPTIONS) $(DESTINATION) \
	-configuration $(CONFIGURATION) \
	build

.PHONY: clean
clean:
	$(CLEAN)

.PHONY: settings
settings:
	$(SHOW_BUILD_SETTINGS)

.PHONY: build
build:
	$(BUILD)

.PHONY: build-for-testing
build-for-testing:
	$(BUILD_FOR_TESTING)

.PHONY: install-mint
install-mint:
	./hack/mint.sh --install

.PHONY: bootstrap-mint
bootstrap-mint:
	./hack/mint.sh --bootstrap

.PHONY: run-lint
run-lint:
	./hack/lint.sh --run

.PHONY: test-without-building
test-without-building:
	$(TEST_WITHOUT_BUILDING)

.PHONY: e2e-without-building
e2e-without-building:
	$(E2E_WITHOUT_BUILDING)

.PHONY: all-test-without-building
all-test-without-building:
	$(ALL_TEST_WITHOUT_BUILDING)

.PHONY: build-example
build-example:
	$(BUILD_EXAMPLE)

.PHONY: environment-setup
environment-setup:
	./hack/environment-setup.sh

.PHONY: sort-proj
sort-proj:
	./hack/sort-Xcode-project-file $(APP_NAME).xcodeproj
