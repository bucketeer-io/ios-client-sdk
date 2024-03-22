# Changelog

## [2.1.4](https://github.com/bucketeer-io/ios-client-sdk/compare/v2.1.3...v2.1.4) (2024-03-22)


### Bug Fixes

* unknown error when handle invalid JSON responses ([#77](https://github.com/bucketeer-io/ios-client-sdk/issues/77)) ([ff7cec6](https://github.com/bucketeer-io/ios-client-sdk/commit/ff7cec6be5069aeaf4b1a88cab332f17fe8939ad))

## [2.1.3](https://github.com/bucketeer-io/ios-client-sdk/compare/v2.1.2...v2.1.3) (2024-03-11)


### Miscellaneous

* unify public method completion to call on the main thread ([#71](https://github.com/bucketeer-io/ios-client-sdk/issues/71)) ([b02f90e](https://github.com/bucketeer-io/ios-client-sdk/commit/b02f90e1051693e1a5bdde930046685a0bd65373))
* update error metrics report ([#68](https://github.com/bucketeer-io/ios-client-sdk/issues/68)) ([4092c00](https://github.com/bucketeer-io/ios-client-sdk/commit/4092c007202d71e4f646fe6a0384946db1a7e9d5))

## [2.1.2](https://github.com/bucketeer-io/ios-client-sdk/compare/v2.1.1...v2.1.2) (2023-12-19)


### Bug Fixes

* could not parser error when the body is a text or empty ([#51](https://github.com/bucketeer-io/ios-client-sdk/issues/51)) ([4a5dc0d](https://github.com/bucketeer-io/ios-client-sdk/commit/4a5dc0d14fc231aba74ee21442841da46028a42e))


### Miscellaneous

* reduce unnecessary API ([#49](https://github.com/bucketeer-io/ios-client-sdk/issues/49)) ([c790e2a](https://github.com/bucketeer-io/ios-client-sdk/commit/c790e2a3b353d289fd0b2437c91b8761965daf3b))


### Build System

* change Swiftlint not running when Carthage builds ([#54](https://github.com/bucketeer-io/ios-client-sdk/issues/54)) ([29938c9](https://github.com/bucketeer-io/ios-client-sdk/commit/29938c949bf9daebb46731cf5ed430661b828a14))
* clean up for Xcode project ([#57](https://github.com/bucketeer-io/ios-client-sdk/issues/57)) ([b59b226](https://github.com/bucketeer-io/ios-client-sdk/commit/b59b226d9725d5ea955637a4bc6c5fb1ad504c76))
* introduce XcodeGen ([#58](https://github.com/bucketeer-io/ios-client-sdk/issues/58)) ([b6cb562](https://github.com/bucketeer-io/ios-client-sdk/commit/b6cb5629814094a0d1a2394df6e235af860bdb17))
* remove "Test" of configuration ([#52](https://github.com/bucketeer-io/ios-client-sdk/issues/52)) ([7c77b7c](https://github.com/bucketeer-io/ios-client-sdk/commit/7c77b7c91e12a8d82b5b7e9b50559b08376d450b))

## [2.1.1](https://github.com/bucketeer-io/ios-client-sdk/compare/v2.1.0...v2.1.1) (2023-10-02)


### Bug Fixes

* missing timeout value in the timeout error event ([#45](https://github.com/bucketeer-io/ios-client-sdk/issues/45)) ([5a19b80](https://github.com/bucketeer-io/ios-client-sdk/commit/5a19b802e56ff0653266c17c54ce5a91dd1c2bd7))


### Miscellaneous

* add sdk_version to the network requests ([#48](https://github.com/bucketeer-io/ios-client-sdk/issues/48)) ([8c29c18](https://github.com/bucketeer-io/ios-client-sdk/commit/8c29c183d416251e82a4bb59b3430617b9cfc1a3))
* change to use feature_id for the active evaluations map ([#44](https://github.com/bucketeer-io/ios-client-sdk/issues/44)) ([a3b308d](https://github.com/bucketeer-io/ios-client-sdk/commit/a3b308d032be592f9fab35e29ccc0045c2a7594f))


### Build System

* change to get api credentials from xcconfig file ([#46](https://github.com/bucketeer-io/ios-client-sdk/issues/46)) ([cb76294](https://github.com/bucketeer-io/ios-client-sdk/commit/cb7629479f4afc3a7d78fef36b55e016c609914e))

## [2.1.0](https://github.com/bucketeer-io/ios-client-sdk/compare/v2.0.2...v2.1.0) (2023-09-08)

From this version, the SDK will only update the flags that have been updated on the server instead of deleting and inserting all flags every time a flag changes. This will improve response time and network traffic between the client and server.

### Features

* support for background mode iOS 13+ ([#28](https://github.com/bucketeer-io/ios-client-sdk/issues/28)) ([0161cdf](https://github.com/bucketeer-io/ios-client-sdk/commit/0161cdf905c2db405743db7e572582f9429eb611))
* change the API response format to improve the response time ([#19](https://github.com/bucketeer-io/ios-client-sdk/issues/19)) ([196c2c9](https://github.com/bucketeer-io/ios-client-sdk/commit/196c2c98501f5bb54548d7b9a71bf0fdf5c5fd38))

### Bug Fixes

* crash when flushing and destroy the client ([#40](https://github.com/bucketeer-io/ios-client-sdk/issues/40)) ([a2628f9](https://github.com/bucketeer-io/ios-client-sdk/commit/a2628f97948b806f914faf1b77dc664cbc197e78))
* evaluation scheduler not being reset when the request succeeds ([#37](https://github.com/bucketeer-io/ios-client-sdk/issues/37)) ([8df5ae3](https://github.com/bucketeer-io/ios-client-sdk/commit/8df5ae3955d31f74371351a055ecc66f318089e3))
* network error being reported as internal sdk error ([#39](https://github.com/bucketeer-io/ios-client-sdk/issues/39)) ([01d6119](https://github.com/bucketeer-io/ios-client-sdk/commit/01d6119e02869adabe261d2e072ad5db0767899b))

### Miscellaneous

* fix lint error in the podspec ([#41](https://github.com/bucketeer-io/ios-client-sdk/issues/41)) ([99fd16a](https://github.com/bucketeer-io/ios-client-sdk/commit/99fd16a9d7cbafaa6a8817f160af0444aa3cd37d))

## [2.0.2](https://github.com/bucketeer-io/ios-client-sdk/compare/v2.0.1...v2.0.2) (2023-08-23)


### Bug Fixes

* evaluation polling interval setting ([#31](https://github.com/bucketeer-io/ios-client-sdk/issues/31)) ([64da192](https://github.com/bucketeer-io/ios-client-sdk/commit/64da19220ed2e3a2520a9644cc14320e39c8eb76))
* events not being sent to the server ([#30](https://github.com/bucketeer-io/ios-client-sdk/issues/30)) ([0bb11c8](https://github.com/bucketeer-io/ios-client-sdk/commit/0bb11c8f3749c286f359a5cd4562ae50c06edeed))

## [2.0.1](https://github.com/bucketeer-io/ios-client-sdk/compare/v2.0.0...v2.0.1) (2023-08-09)


### Features

* support swift package manager ([#4](https://github.com/bucketeer-io/ios-client-sdk/issues/4)) ([276aa89](https://github.com/bucketeer-io/ios-client-sdk/commit/276aa89251fc85acdf98fcc6773dd34309d072e0))


### Bug Fixes

* concurrency while creating the client instance ([#11](https://github.com/bucketeer-io/ios-client-sdk/issues/11)) ([4b880a4](https://github.com/bucketeer-io/ios-client-sdk/commit/4b880a4c68ae3ed04b1d5e15d6f00517f9bc8ed4))
* functions are not accessible in the BKTUser struct ([#5](https://github.com/bucketeer-io/ios-client-sdk/issues/5)) ([c62bc8e](https://github.com/bucketeer-io/ios-client-sdk/commit/c62bc8ec0d76d175b182023ac9a390f1cb891074))
* sending duplicate events ([#24](https://github.com/bucketeer-io/ios-client-sdk/issues/24)) ([b84bb58](https://github.com/bucketeer-io/ios-client-sdk/commit/b84bb5840af722d02963c4b009f866961cff5461))


### Miscellaneous

* add variation name property to BKTEvaluation ([#12](https://github.com/bucketeer-io/ios-client-sdk/issues/12)) ([fb02f5a](https://github.com/bucketeer-io/ios-client-sdk/commit/fb02f5a6311a78ef31e2760438c0fa574eb8a155))
* added builder pattern to BKTConfig ([#13](https://github.com/bucketeer-io/ios-client-sdk/issues/13)) ([48dff87](https://github.com/bucketeer-io/ios-client-sdk/commit/48dff87dbe27791fde7dd47293741f4b64adebe2))
* added builder pattern to BKTUser ([#14](https://github.com/bucketeer-io/ios-client-sdk/issues/14)) ([b444efe](https://github.com/bucketeer-io/ios-client-sdk/commit/b444efee76559ee204c9deb0c76acae9ff190312))
* change background task id ([#22](https://github.com/bucketeer-io/ios-client-sdk/issues/22)) ([95ba45b](https://github.com/bucketeer-io/ios-client-sdk/commit/95ba45bb9dfbba44f6cc84b12e09a1c8a78627a1))
* change to throw an exception instead of using fatalError from BKTClient.shared ([#18](https://github.com/bucketeer-io/ios-client-sdk/issues/18)) ([881de7f](https://github.com/bucketeer-io/ios-client-sdk/commit/881de7fbd575fb1c01946ccbb62c13a179deea18))
* update bundle identifier ([#21](https://github.com/bucketeer-io/ios-client-sdk/issues/21)) ([7ec60d8](https://github.com/bucketeer-io/ios-client-sdk/commit/7ec60d82e9213e5f7fc4a21ef896f411ee8c406c))

## 2.0.0 (2023-05-31)


### Features

* add initial implementation ([5d85c6f](https://github.com/bucketeer-io/ios-client-sdk/commit/5d85c6fab1ddb47b32a689a4d6abf3ff79b7a779))
