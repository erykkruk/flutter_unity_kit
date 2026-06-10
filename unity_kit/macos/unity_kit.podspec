Pod::Spec.new do |s|
  s.name             = 'unity_kit'
  s.version          = '0.9.1'
  s.summary          = 'Flutter plugin for Unity 3D integration (macOS)'
  s.homepage         = 'https://github.com/erykkruk/unity_kit'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Eryk Kruk' => 'eryk@ravenlab.tech' }
  s.source           = { :http => 'https://github.com/erykkruk/unity_kit' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :osx, '10.14'
  s.swift_version    = '5.0'
  s.dependency 'FlutterMacOS'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
