#
# Be sure to run `pod lib lint AGVideoLoader.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AGVideoLoader'
  s.version          = '2.0.3'
  s.summary          = 'Library caches video to files and just AVPlayers'
  s.swift_versions   = '5.0'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
AGVideoLoader caches video to files and just AVPlayers
                       DESC

  s.homepage         = 'http://rucode.org'

  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'

  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'AlexStich' => 'alex@rucode.org' }
  s.source           = { :git => 'git@repos:common/video-loader-ios.git', :tag => s.version.to_s }

  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.0'
  s.source_files = 'AGVideoLoader/Classes/**/*'
  
  # s.resource_bundles = {
  #   'AGVideoLoader' => ['AGVideoLoader/Assets/*.png']
  # }
  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
