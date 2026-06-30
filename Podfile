platform :ios, '16.0'
use_frameworks!
inhibit_all_warnings!

target 'AnokiXTrader' do
  # Same networking/JSON stack the Distributor app uses, so both projects work
  # the same way.
  pod 'Alamofire', '~> 5.9'
  pod 'SwiftyJSON', '~> 5.0'
  # Powerful image loading + memory & disk caching (smooth, robust remote images).
  pod 'Kingfisher', '~> 7.0'
  # Google Maps for the Create Account location step (same SDK/key as the
  # Distributor iOS app). Run `pod install` after adding this.
  pod 'GoogleMaps', '~> 9.0'
  # Firebase Cloud Messaging (push notifications). Run `pod install` after adding.
  pod 'Firebase/Messaging', '~> 11.0'
end

post_install do |installer|
  require 'fileutils'

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end

  # Pods *.sh scripts often lose +x when the repo is copied from Windows.
  support_root = File.join(installer.sandbox.root, 'Target Support Files')
  Dir.glob(File.join(support_root, '**', '*.sh')).each do |script|
    FileUtils.chmod(0o755, script)
  end

  # Invoke embed scripts via bash so build succeeds even if +x is missing.
  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.user_project.native_targets.each do |native_target|
      native_target.shell_script_build_phases.each do |phase|
        next unless phase.shell_script&.include?('Target Support Files')

        phase.shell_script = phase.shell_script.gsub(
          /(?<!\/bin\/bash )"(\$\{PODS_ROOT\}\/Target Support Files\/[^"]+\.sh)"/,
          '/bin/bash "\1"'
        )
      end
    end
  end
end
