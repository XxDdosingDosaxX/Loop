#!/usr/bin/env ruby
# Adds a watchOS Widget Extension target to Loop.xcodeproj
# Uses the xcodeproj gem (bundled with Fastlane)

require 'xcodeproj'

project_path = ARGV[0] || 'Loop.xcodeproj'
team_id = ARGV[1] || ENV['TEAMID']

puts "Adding WatchWidget Extension target to #{project_path}..."

project = Xcodeproj::Project.open(project_path)

# Check if target already exists
if project.targets.any? { |t| t.name == 'WatchWidget Extension' }
  puts "WatchWidget Extension target already exists, skipping."
  exit 0
end

# Find the WatchApp target to embed the widget in
watch_app_target = project.targets.find { |t| t.name == 'WatchApp' }
watch_ext_target = project.targets.find { |t| t.name == 'WatchApp Extension' }

unless watch_app_target
  puts "ERROR: Could not find WatchApp target"
  exit 1
end

# Create the widget extension target
widget_target = project.new_target(
  :app_extension,
  'WatchWidget Extension',
  :watchos,
  '10.0'
)

# Add source files
widget_group = project.main_group.new_group('WatchWidget Extension', 'WatchWidget Extension')

Dir.glob('WatchWidget Extension/*.swift').each do |file|
  file_ref = widget_group.new_reference(File.basename(file))
  widget_target.source_build_phase.add_file_reference(file_ref)
  puts "  Added source: #{File.basename(file)}"
end

# Add Info.plist
plist_ref = widget_group.new_reference('Info.plist')

# Configure build settings
widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.#{team_id}.loopkit.Loop.LoopWatch.GlucoseWidget"
  config.build_settings['INFOPLIST_FILE'] = 'WatchWidget Extension/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'WatchWidget Extension/WatchWidget.entitlements'
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  config.build_settings['SWIFT_VERSION'] = '5.9'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = team_id
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['APP_GROUP_IDENTIFIER'] = 'group.com.' + team_id + '.loopkit.LoopGroup'
  config.build_settings['ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME'] = 'WidgetBackground'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
end

# Embed widget in watch app
watch_app_target.add_dependency(widget_target)

# Add embed extension build phase
embed_phase = watch_app_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13' # PlugIns
embed_phase.add_file_reference(widget_target.product_reference, true)

project.save

puts "WatchWidget Extension target added successfully!"
puts "Bundle ID: com.#{team_id}.loopkit.Loop.LoopWatch.GlucoseWidget"
