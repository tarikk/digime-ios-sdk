Pod::Spec.new do |s|

  s.name         	= "DigiMeFramework"
  s.version      	= "1.0.0"
  s.summary      	= "digi.me iOS Consent Access SDK"
  s.homepage     	= "http://www.digi.me"
  s.license      	= { :type => "MIT", :file => "LICENSE" }
  s.author       	= { "digi.me Ltd." => "ios@digi.me" }
  s.platform     	= :ios, "8.0"
  s.source       	= { :git => "https://github.com/digime/digime-ios-sdk.git", :branch => "#{s.version}", :tag => "#{s.version}" } 
  s.source_files  	= 'Pod/Classes/**/*', "DigiMeFramework/**/*", "DigiMeFramework/Classes/*"
  s.frameworks    	= "Foundation", "UIKit", "CoreGraphics", "Security"
  s.resource_bundles    = {'DigiMeFramework' => ['DigiMeFramework/Resources/**/*','DigiMeFramework/Assets/*','Pod/Assets/*']}
  s.resources           = ["DigiMeFramework/Assets/*.{der}","Pod/Assets/*"]

end