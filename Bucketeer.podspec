Pod::Spec.new do |s|
  s.name     = 'Bucketeer'
  s.version  = '2.0.2' # x-release-please-version
  s.summary  = 'iOS SDK for Bucketeer'
  s.homepage = 'https://github.com/bucketeer-io/ios-client-sdk'

  s.ios.deployment_target = '11.0'
  s.tvos.deployment_target = '11.0'
  s.swift_version = '5.0'

  s.author = {
    'Bucketeer Team' => 'bucketeer@cyberagent.co.jp'
  }

  s.source_files = 'Bucketeer/Sources/**/*.{swift,h,m}'
  s.source = {
    :git => 'https://github.com/bucketeer-io/ios-client-sdk.git',
    :tag => "v#{s.version}",
  }

  s.license = {
    :type => 'Apache License, Version 2.0',
    :file => 'LICENSE',
  }
end
