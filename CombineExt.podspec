Pod::Spec.new do |s|
    s.name         = "CombineExt"
    s.version      = "1.8.0"
    s.summary      = "Combine operators and helpers not provided by Apple, and inspired by other Reactive Frameworks"
    s.description  = <<-DESC
      A collection of operators for Combine adding capabilities and utilities not provided by Apple,
      but common ones found and known from other Reactive Frameworks
                     DESC
    s.homepage     = "https://github.com/CombineCommunity/CombineExt"
    s.license      = { :type => "MIT", :file => "LICENSE" }
    s.authors      = { "Combine Community" => "https://github.com/CombineCommunity", "Shai Mishali" => "freak4pc@gmail.com" }

    s.ios.deployment_target = '12.0'
    s.osx.deployment_target = '10.14'
    s.watchos.deployment_target = '5.0'
    s.tvos.deployment_target = '12.0'

    s.source       = { :git => "https://github.com/pavelosipov/CombineExt.git", :tag => s.version }
    s.source_files = 'Sources/**/*.swift'
    s.swift_version = '5.6'

    s.dependency 'OpenCombine'
    s.dependency 'OpenCombineDispatch'
    s.dependency 'OpenCombineFoundation'
end
